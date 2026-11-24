import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/accept_invitation_screen.dart';
import 'package:e_ticket_event_qr_scane/features/tickets/widgets/qr_ticket_display.dart';
import 'package:e_ticket_event_qr_scane/providers/check_in_provider.dart';
import 'package:e_ticket_event_qr_scane/routes/app_routes.dart';
import 'package:e_ticket_event_qr_scane/services/check_in/check_in_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/invitation_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/organizer_membership_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';
import 'package:e_ticket_event_qr_scane/services/scanner/scanner_service.dart';

/// Test integrasi Tahap 2 sisi klien (integrator/Developer 4).
///
/// Fixture JSON meniru bentuk response backend setelah serialisasi
/// (`presentScanTicket`, `listEventAttendees`, `listEventCheckIns`). Tujuan test:
/// membuktikan rantai tiket -> validasi QR -> check-in -> riwayat -> daftar
/// peserta memakai service/provider yang sama dengan aplikasi, tanpa HTTP nyata
/// dan tanpa fallback mock (`MOCK_MODE` default `false`).
const String _eventId = '44444444-4444-4444-8444-444444444444';
const String _ticketId = '77777777-7777-4777-8777-777777777777';
const String _qrToken = 'qr-ticket-token-stage2-opaque-value-0123456789';

const Map<String, dynamic> _scanTicketJson = {
  'id': _ticketId,
  'ticket_code': 'TKT-STAGE2-0001',
  'event_id': _eventId,
  'attendee_name': 'Peserta Uji',
  'attendee_email': 'peserta@example.test',
  'attendee_phone': '081200000001',
  'ticket_type_name': 'Reguler',
  'status': 'valid',
  'purchased_at': '2026-11-24T08:00:00.000Z',
  'used_at': null,
};

const List<Map<String, dynamic>> _checkInRows = [
  {
    'id': 'chk-1',
    'ticket_id': _ticketId,
    'event_id': _eventId,
    'actor_user_id': '22222222-2222-4222-8222-222222222222',
    'event_member_id': '99999999-9999-4999-8999-999999999999',
    'source': 'ONLINE',
    'checked_in_at': '2026-11-24T09:00:00.000Z',
    'ticket_code': 'TKT-STAGE2-0001',
    'ticket_status': 'used',
    'actor_name': 'Staf Uji',
    'actor_email': 'staff@example.test',
  },
];

const List<Map<String, dynamic>> _attendeeRows = [
  {
    'id': 'item-paid',
    'ticket_id': 'tkt-paid',
    'ticket_code': 'TKT-PAID-1',
    'registration_number': 'ORD-2026-0001',
    'order_id': '66666666-6666-4666-8666-666666666666',
    'order_number': 'ORD-2026-0001',
    'attendee_name': 'Peserta Lunas',
    'attendee_email': 'lunas@example.test',
    'attendee_phone': '081200000002',
    'ticket_type': 'VIP',
    'status': 'checked_in',
    'purchased_at': '2026-11-01T08:00:00.000Z',
    'used_at': '2026-11-24T09:00:00.000Z',
    'payment_status': 'PAID',
    'order_status': 'PAID',
    'custom_fields': {'instansi': 'Informatika'},
    'checked_in_at': '2026-11-24T09:00:00.000Z',
  },
  {
    'id': 'item-pending',
    'ticket_id': 'tkt-pending',
    'ticket_code': 'TKT-PENDING-1',
    'registration_number': 'ORD-2026-0002',
    'order_id': 'ord-2',
    'order_number': 'ORD-2026-0002',
    'attendee_name': 'Peserta Menunggu',
    'attendee_email': 'pending@example.test',
    'attendee_phone': '081200000003',
    'ticket_type': 'Reguler',
    'status': 'valid',
    'purchased_at': '2026-11-24T08:00:00.000Z',
    'used_at': null,
    'payment_status': 'PENDING',
    'order_status': 'PENDING_PAYMENT',
    'custom_fields': <String, dynamic>{},
    'checked_in_at': null,
  },
];

/// Mencatat setiap request yang benar-benar dikirim service ke "backend".
class _RecordedCall {
  _RecordedCall(this.method, this.path, this.body);

  final String method;
  final String path;
  final Map<String, dynamic> body;

  @override
  String toString() => '$method $path';
}

class _Stage2HttpOverrides extends HttpOverrides {
  _Stage2HttpOverrides(this.calls);

  final List<_RecordedCall> calls;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _Stage2HttpClient(calls);
}

class _Stage2HttpClient implements HttpClient {
  _Stage2HttpClient(this.calls);

  final List<_RecordedCall> calls;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Stage2Request(method, url, calls);

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {}

  @override
  void addProxyCredentials(String host, int port, String realm,
      HttpClientCredentials credentials) {}

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String? realm)? f) {}

  @override
  set authenticateProxy(
      Future<bool> Function(
              String host, int port, String scheme, String? realm)?
          f) {}

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {}

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {}

  @override
  set keyLog(Function(String line)? callback) {}

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}


class _Stage2ResponseData {
  const _Stage2ResponseData(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Meniru response backend Tahap 2 (bentuk setelah serialisasi).
_Stage2ResponseData _respondTo(
  String method,
  String path,
  Map<String, dynamic> body,
) {
  if (method == 'POST' && path == '/api/tickets/validate') {
    final token = (body['token'] ?? body['ticket_code'] ?? '').toString();
    if (token.contains('used')) {
      return const _Stage2ResponseData(200, {
        'success': true,
        'valid': false,
        'status': 'ALREADY_USED',
        'message': 'Tiket sudah digunakan untuk check-in sebelumnya.',
        'ticket': _scanTicketJson,
      });
    }
    if (token.contains('unpaid')) {
      return const _Stage2ResponseData(200, {
        'success': true,
        'valid': false,
        'status': 'PAYMENT_REQUIRED',
        'message': 'Pembayaran belum terkonfirmasi.',
        'ticket': _scanTicketJson,
      });
    }
    if (token.contains('invalid')) {
      return const _Stage2ResponseData(200, {
        'success': true,
        'valid': false,
        'status': 'INVALID',
        'message': 'Tiket tidak ditemukan atau token QR tidak valid.',
        'ticket': null,
      });
    }
    return const _Stage2ResponseData(200, {
      'success': true,
      'valid': true,
      'status': 'VALID',
      'message': 'Tiket valid. Siap untuk check-in.',
      'ticket': _scanTicketJson,
    });
  }

  if (method == 'POST' && path == '/api/check-ins') {
    return _Stage2ResponseData(201, {
      'success': true,
      'message': 'Check-in berhasil dicatat.',
      'check_in': const {
        'id': 'chk-2',
        'ticket_id': _ticketId,
        'event_id': _eventId,
        'source': 'ONLINE',
        'checked_in_at': '2026-11-24T09:30:00.000Z',
      },
      'ticket': {
        ..._scanTicketJson,
        'status': 'checked_in',
        'checked_in_at': '2026-11-24T09:30:00.000Z',
      },
    });
  }

  if (method == 'GET' && path.startsWith('/api/check-ins/events/')) {
    return const _Stage2ResponseData(200, {
      'success': true,
      'count': 1,
      'check_ins': _checkInRows,
    });
  }

  if (method == 'GET' && path == '/api/me/memberships') {
    return const _Stage2ResponseData(200, {
      'success': true,
      'count': 1,
      'memberships': [
        {
          'member_id': '99999999-9999-4999-8999-999999999999',
          'event_id': _eventId,
          'event_title': 'Konser Uji Integrasi',
          'status': 'ACTIVE',
          'role': 'staff',
          'joined_at': '2026-11-24T08:00:00.000Z',
          'expires_at': null,
          'permissions': ['SCAN_TICKET', 'VIEW_PARTICIPANTS'],
        },
      ],
    });
  }

  if (method == 'GET' && path.endsWith('/members')) {
    return const _Stage2ResponseData(200, {
      'success': true,
      'members': [
        {
          'member_id': '99999999-9999-4999-8999-999999999999',
          'user_id': '22222222-2222-4222-8222-222222222222',
          'role': 'staff',
          'created_at': '2026-11-24T08:00:00.000Z',
          'name': 'Staf Uji',
          'email': 'staff@example.test',
          'permissions': ['SCAN_TICKET', 'CHECK_IN_TICKET'],
        },
      ],
    });
  }

  if (method == 'POST' && path.endsWith('/invitations')) {
    return const _Stage2ResponseData(201, {
      'success': true,
      'invitation': {
        'id': 'inv-1',
        'event_id': _eventId,
        'email': 'staff@example.test',
        'status': 'PENDING',
        'expires_at': '2026-12-01T08:00:00.000Z',
        'invite_url':
            'https://app.eticket.test/invite/pratinjau-undangan-token-000001',
        'permissions': ['SCAN_TICKET'],
      },
    });
  }

  if (method == 'POST' && path.endsWith('/accept')) {
    return const _Stage2ResponseData(200, {
      'success': true,
      'message': 'Undangan diterima. Anda adalah staf pada event ini.',
      'invitation': {'id': 'inv-1', 'event_id': _eventId, 'status': 'ACCEPTED'},
      'member': {'member_id': '99999999-9999-4999-8999-999999999999'},
    });
  }

  if (method == 'GET' && path.startsWith('/api/invitations/')) {
    return const _Stage2ResponseData(200, {
      'success': true,
      'invitation': {
        'status': 'PENDING',
        'expires_at': '2026-12-01T08:00:00.000Z',
        'invited_email': 'st***@example.test',
        'permissions': ['SCAN_TICKET', 'CHECK_IN_TICKET'],
        'event': {
          'id': _eventId,
          'title': 'Konser Uji Integrasi',
          'status': 'PUBLISHED',
          'event_date': '2026-12-01T10:00:00.000Z',
          'end_date_time': '2026-12-01T13:00:00.000Z',
          'location': 'Auditorium Uji',
          'event_format': 'OFFLINE',
          'online_url': null,
        },
      },
    });
  }

  if (method == 'GET' && path.startsWith('/api/events/')) {
    return const _Stage2ResponseData(200, {
      'success': true,
      'count': 2,
      'attendees': _attendeeRows,
    });
  }

  return const _Stage2ResponseData(404, {
    'success': false,
    'message': 'Endpoint tidak dikenal pada test harness',
  });
}


class _Stage2Request implements HttpClientRequest {
  _Stage2Request(this.method, this.uri, this.calls);

  @override
  final String method;
  @override
  final Uri uri;
  final List<_RecordedCall> calls;

  final List<int> _bodyBytes = [];
  final Completer<HttpClientResponse> _completer =
      Completer<HttpClientResponse>();

  @override
  HttpHeaders get headers => _Stage2Headers();

  @override
  void add(List<int> data) => _bodyBytes.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  void write(Object? object) {
    if (object != null) _bodyBytes.addAll(utf8.encode(object.toString()));
  }

  @override
  Future<HttpClientResponse> get done => _completer.future;

  @override
  Future<HttpClientResponse> close() async {
    final raw = utf8.decode(_bodyBytes, allowMalformed: true);
    Map<String, dynamic> body = const <String, dynamic>{};
    if (raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    calls.add(_RecordedCall(method, uri.path, body));
    final data = _respondTo(method, uri.path, body);
    final response = _Stage2Response(
      data.statusCode,
      utf8.encode(jsonEncode(data.body)),
    );
    if (!_completer.isCompleted) _completer.complete(response);
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Stage2Response extends Stream<List<int>> implements HttpClientResponse {
  _Stage2Response(this.statusCode, this._bytes);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _Stage2Headers();

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Stage2Headers implements HttpHeaders {
  final Map<String, List<String>> _values = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => <String>[]).add('$value');
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = <String>['$value'];
  }

  @override
  String? value(String name) => _values[name.toLowerCase()]?.first;

  @override
  ContentType? get contentType => ContentType.json;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  late List<_RecordedCall> calls;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    // `ApiClient` adalah singleton yang membuat `http.Client` sekali, sehingga
    // HttpOverrides harus dipasang sekali untuk seluruh file test.
    calls = <_RecordedCall>[];
    HttpOverrides.global = _Stage2HttpOverrides(calls);
  });

  setUp(() {
    calls.clear();
  });

  group(
    'Tahap 2 - kontrak klien tiket/scan/check-in/peserta',
    () {
    test('riwayat check-in memakai path backend yang benar dan envelope check_ins',
        () async {
      final service = CheckInService();
      final rows = await service.listCheckIns(eventId: _eventId);

      expect(calls.map((call) => call.path), [
        '/api/check-ins/events/$_eventId/check-ins',
      ]);
      expect(rows, hasLength(1));
      expect(rows.first['ticket_code'], 'TKT-STAGE2-0001');
      expect(rows.first['checked_in_at'], '2026-11-24T09:00:00.000Z');
    });

    test('daftar peserta mempertahankan field kontrak D3', () async {
      final service = CheckInService();
      final attendees = await service.listAttendees(eventId: _eventId);

      expect(calls.map((call) => call.path), ['/api/events/$_eventId/attendees']);
      expect(attendees, hasLength(2));

      final paid = attendees.first;
      expect(paid['payment_status'], 'PAID');
      expect(paid['order_number'], 'ORD-2026-0001');
      expect(paid['registration_number'], 'ORD-2026-0001');
      expect(paid['custom_fields'], {'instansi': 'Informatika'});
      expect(paid['checked_in_at'], '2026-11-24T09:00:00.000Z');

      final pending = attendees.last;
      expect(pending['payment_status'], 'PENDING');
      expect(pending['checked_in_at'], isNull);
    });

    test('ScannerService memetakan hasil validasi backend tanpa fallback mock',
        () async {
      final scanner = ScannerService(checkInService: CheckInService());

      final valid = await scanner.validateTicket(_qrToken);
      expect(valid['valid'], isTrue);
      expect(valid['status'], 'VALID');
      expect((valid['ticket'] as Map<String, dynamic>).containsKey('token_hash'),
          isFalse);
      expect((valid['ticket'] as Map<String, dynamic>).containsKey('token'),
          isFalse);

      final used = await scanner.validateTicket('used-$_qrToken');
      expect(used['valid'], isFalse);
      expect(used['status'], 'ALREADY_USED');

      final unpaid = await scanner.validateTicket('unpaid-$_qrToken');
      expect(unpaid['status'], 'PAYMENT_REQUIRED');

      final invalid = await scanner.validateTicket('invalid-$_qrToken');
      expect(invalid['status'], 'INVALID');
      expect(invalid['ticket'], isNull);

      expect(
        calls.map((call) => '${call.method} ${call.path}').toSet(),
        {'POST /api/tickets/validate'},
        reason: 'mode API tidak boleh memakai data mock scanner',
      );
    });

    test('alur scan valid: validasi -> check-in -> muat ulang riwayat & peserta',
        () async {
      final provider = CheckInProvider(CheckInService());

      final result = await provider.processTicketScan(
        _qrToken,
        staffId: '22222222-2222-4222-8222-222222222222',
        staffName: 'Staf Uji',
        eventId: _eventId,
      );

      expect(result['status'], 'valid');
      expect(result['valid'], isTrue);
      expect(result['is_offline'], isFalse);
      expect(provider.error, isNull);
      expect(provider.isOfflineMode, isFalse);

      final paths = calls.map((call) => '${call.method} ${call.path}').toList();
      expect(paths.first, 'POST /api/tickets/validate');
      expect(paths, contains('POST /api/check-ins'));
      expect(paths, contains('GET /api/check-ins/events/$_eventId/check-ins'));
      expect(paths, contains('GET /api/events/$_eventId/attendees'));

      final checkInCall =
          calls.firstWhere((call) => call.path == '/api/check-ins');
      expect(checkInCall.body['ticket_id'], _ticketId);
      expect(checkInCall.body['event_id'], _eventId);
      expect(checkInCall.body['is_offline'], isNull);

      expect(provider.checkIns, hasLength(1));
      expect(provider.attendees, hasLength(2));
    });

    test('tiket sudah dipakai tidak memicu check-in baru', () async {
      final provider = CheckInProvider(CheckInService());

      final result = await provider.processTicketScan(
        'used-$_qrToken',
        staffId: '22222222-2222-4222-8222-222222222222',
        eventId: _eventId,
      );

      expect(result['status'], 'ALREADY_USED');
      expect(result['valid'], isFalse);
      expect(
        calls.any((call) => call.path == '/api/check-ins'),
        isFalse,
        reason: 'scan ganda tidak boleh menulis check-in baru',
      );
    });

    test('membership staf dibaca dari GET /api/me/memberships (bukan mock)',
        () async {
      final service = OrganizerMembershipService();
      final assigned = await service.getAssignedActiveEvents('staff@example.test');

      expect(
        calls.map((call) => '${call.method} ${call.path}'),
        contains('GET /api/me/memberships'),
      );
      expect(assigned, hasLength(1));
      expect(assigned.first.eventId, _eventId);
      expect(assigned.first.isStaff, isTrue);
      expect(assigned.first.isAccepted, isTrue);
      expect(
        assigned.first.hasPermission(OrganizerPermission.scanTicket),
        isTrue,
      );
    });

    test('daftar anggota tim & undangan memakai endpoint backend', () async {
      final service = OrganizerMembershipService();

      final members = await service.listMembers(_eventId, eventTitle: 'Event Uji');
      expect(calls.last.path, '/api/events/$_eventId/members');
      expect(members, hasLength(1));
      expect(members.first.email, 'staff@example.test');
      expect(
        members.first.hasPermission(OrganizerPermission.checkInTicket),
        isTrue,
      );

      final invited = await service.inviteStaff(
        eventId: _eventId,
        eventTitle: 'Event Uji',
        email: 'staf.baru@example.test',
        name: 'Staf Baru',
        permissions: {OrganizerPermission.scanTicket},
      );
      final inviteCall = calls.last;
      expect('${inviteCall.method} ${inviteCall.path}',
          'POST /api/events/$_eventId/invitations');
      expect(inviteCall.body['permissions'], ['SCAN_TICKET']);
      expect(invited.isPending, isTrue);
      expect(
        invited.inviteUrl,
        'https://app.eticket.test/invite/pratinjau-undangan-token-000001',
      );
    });

    test('pratinjau & penerimaan undangan memakai endpoint publik/terautentikasi',
        () async {
      final service = InvitationService();

      final preview = await service.preview('token-abc');
      expect(calls.last.path, '/api/invitations/token-abc');
      expect(preview.eventTitle, 'Konser Uji Integrasi');
      expect(preview.isPending, isTrue);
      expect(preview.invitedEmail.contains('*'), isTrue);
      expect(preview.permissions, ['SCAN_TICKET', 'CHECK_IN_TICKET']);

      final accepted = await service.accept('token-abc');
      expect('${calls.last.method} ${calls.last.path}',
          'POST /api/invitations/token-abc/accept');
      expect(accepted['success'], isTrue);
    });

    },
    // Test ini menguji mode API; pada `MOCK_MODE=true` service memakai data
    // demo sehingga request HTTP tidak terjadi.
    skip: AppConfig.mockMode
        ? 'Kontrak API-mode tidak berlaku pada MOCK_MODE=true'
        : false,
  );

  group('Tahap 2 - QR e-ticket nyata (AC-06)', () {
    testWidgets('QrTicketDisplay merender QR asli, bukan pola pseudo-QR',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrTicketDisplay(ticketData: 'qr-token-opaque-0123456789abcdef'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-image')), findsOneWidget);

      final qr = tester.widget<QrImageView>(
        find.byKey(const Key('ticket-qr-image')),
      );
      expect(qr.semanticsLabel, 'QR code e-ticket');
      expect(find.text('KODE TIKET UNIK'), findsOneWidget);
    });
  });

  group('Tahap 2 - halaman penerimaan undangan (D2-2)', () {
    testWidgets('menampilkan pratinjau event dan tombol terima', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AcceptInvitationScreen(token: 'token-abc'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Undangan Panitia Event'), findsOneWidget);
      expect(find.text('Konser Uji Integrasi'), findsOneWidget);
      expect(find.text('Menunggu diterima'), findsOneWidget);
      expect(find.text('Terima Undangan'), findsOneWidget);
    });

    testWidgets('menerima undangan memanggil endpoint accept', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.staffWorkspacePath(_eventId): (_) =>
                const Scaffold(body: Text('workspace-staf')),
            AppRoutes.staffDashboard: (_) =>
                const Scaffold(body: Text('dashboard-staf')),
          },
          home: const AcceptInvitationScreen(token: 'token-abc'),
        ),
      );
      await tester.pumpAndSettle();

      final acceptButton = find.byKey(const Key('invitation-accept-button'));
      await tester.ensureVisible(acceptButton);
      await tester.pumpAndSettle();
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      expect(
        calls.any(
          (call) =>
              call.method == 'POST' &&
              call.path == '/api/invitations/token-abc/accept',
        ),
        isTrue,
      );
    });
  });
}

