import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/services/staff_session_store.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/staff_access_screen.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/staff_scanner_session_screen.dart';
import 'package:e_ticket_event_qr_scane/routes/app_routes.dart';
import 'package:e_ticket_event_qr_scane/services/staff_access/staff_access_service.dart';

/// Service palsu: tidak memanggil HTTP, hasil diatur per test.
class _FakeStaffAccessService extends StaffAccessService {
  _FakeStaffAccessService({
    this.preview,
    this.previewError,
    this.session,
    this.accessError,
    this.restored,
  });

  final StaffInvitationPreview? preview;
  final StaffAccessException? previewError;
  final StaffSession? session;
  final StaffAccessException? accessError;
  final StaffSession? restored;

  int previewCalls = 0;
  int accessCalls = 0;
  int restoreCalls = 0;
  String? lastCode;

  @override
  Future<StaffInvitationPreview> previewInvitation(String invitationId) async {
    previewCalls += 1;
    if (previewError != null) throw previewError!;
    return preview!;
  }

  @override
  Future<StaffSession> requestAccess({
    required String invitationId,
    required String accessCode,
  }) async {
    accessCalls += 1;
    lastCode = accessCode;
    if (accessError != null) throw accessError!;
    return session!;
  }

  @override
  Future<StaffSession?> restoreSession({bool verify = true}) async {
    restoreCalls += 1;
    return restored;
  }

  @override
  Future<void> logout() async {}
}

StaffInvitationPreview _preview({
  String status = 'PENDING',
  bool requiresNewCode = false,
}) => StaffInvitationPreview(
  id: 'inv-1',
  staffName: 'Budi Santoso',
  status: status,
  eventId: 'evt-1',
  eventTitle: 'Konser Musik 2026',
  eventDate: DateTime(2026, 12, 1),
  location: 'Jakarta',
  expiresAt: DateTime(2026, 12, 7),
  requiresNewCode: requiresNewCode,
);

StaffSession _session({String eventId = 'evt-1'}) => StaffSession(
  token: 'staff-token',
  staffName: 'Budi Santoso',
  eventId: eventId,
  eventTitle: 'Konser Musik 2026',
  expiresAt: DateTime.now().add(const Duration(hours: 12)),
);

Widget _accessApp(_FakeStaffAccessService service) => MaterialApp(
  home: StaffAccessScreen(invitationId: 'inv-1', service: service),
  onGenerateRoute: (settings) {
    if (settings.name == AppRoutes.staffScannerAccess) {
      return MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('SCANNER-STUB'))),
      );
    }
    return null;
  },
);

void main() {
  group('Halaman akses staf', () {
    testWidgets('menampilkan form kode dan TIDAK langsung membuka scanner', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(preview: _preview());
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-card')), findsOneWidget);
      expect(find.text('Konser Musik 2026'), findsOneWidget);
      expect(find.textContaining('Budi Santoso'), findsOneWidget);
      expect(find.byKey(const Key('staff-access-code-field')), findsOneWidget);
      // Belum ada navigasi ke scanner sebelum kode dimasukkan.
      expect(find.text('SCANNER-STUB'), findsNothing);
      expect(service.accessCalls, 0);
    });

    testWidgets('kode akses benar mengarahkan staf ke scanner event undangan', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        preview: _preview(),
        session: _session(),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('staff-access-code-field')),
        'ABCD-2345',
      );
      await tester.tap(find.byKey(const Key('staff-access-submit')));
      await tester.pumpAndSettle();

      expect(service.accessCalls, 1);
      expect(service.lastCode, 'ABCD-2345');
      expect(find.text('SCANNER-STUB'), findsOneWidget);
    });

    testWidgets('kode akses salah ditolak dan scanner tetap tertutup', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        preview: _preview(),
        accessError: const StaffAccessException(
          'Kode akses salah. Periksa kembali kode dari Organizer.',
          statusCode: 401,
        ),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('staff-access-code-field')),
        'ZZZZ-9999',
      );
      await tester.tap(find.byKey(const Key('staff-access-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-error')), findsOneWidget);
      expect(find.textContaining('Kode akses salah'), findsOneWidget);
      expect(find.text('SCANNER-STUB'), findsNothing);
    });

    testWidgets('kode kurang dari 8 karakter tidak dikirim ke backend', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        preview: _preview(),
        session: _session(),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('staff-access-code-field')),
        'ABC',
      );
      await tester.tap(find.byKey(const Key('staff-access-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('8 karakter'), findsWidgets);
      expect(service.accessCalls, 0);
      expect(find.text('SCANNER-STUB'), findsNothing);
    });

    testWidgets('undangan yang dicabut tidak menampilkan form kode', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        preview: _preview(status: 'REVOKED'),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-blocked')), findsOneWidget);
      expect(find.textContaining('dicabut'), findsOneWidget);
      expect(find.byKey(const Key('staff-access-code-field')), findsNothing);
    });

    testWidgets('undangan lama tanpa kode akses diarahkan minta kode baru', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        preview: _preview(requiresNewCode: true),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-blocked')), findsOneWidget);
      expect(find.textContaining('belum memiliki kode akses'), findsOneWidget);
      expect(find.byKey(const Key('staff-access-code-field')), findsNothing);
    });

    testWidgets('tautan undangan tidak valid menampilkan penolakan', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(
        previewError: const StaffAccessException(
          'Undangan staf tidak ditemukan atau tidak valid',
          statusCode: 404,
        ),
      );
      await tester.pumpWidget(_accessApp(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-denied')), findsOneWidget);
      expect(find.byKey(const Key('staff-access-code-field')), findsNothing);
    });
  });

  group('Scanner sesi staf', () {
    Widget scannerApp(_FakeStaffAccessService service, {String? eventId}) =>
        MaterialApp(
          home: StaffScannerSessionScreen(
            eventId: eventId,
            service: service,
            scannerBuilder: (session) => Scaffold(
              body: Center(child: Text('SCANNER:${session.eventId}')),
            ),
          ),
        );

    testWidgets('tanpa sesi staf, scanner tidak dapat dibuka', (tester) async {
      final service = _FakeStaffAccessService(restored: null);
      await tester.pumpWidget(scannerApp(service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-scanner-denied')), findsOneWidget);
      expect(find.textContaining('Tidak memiliki akses'), findsOneWidget);
      expect(find.textContaining('SCANNER:'), findsNothing);
    });

    testWidgets('sesi event A tidak dapat membuka scanner event B', (
      tester,
    ) async {
      final service = _FakeStaffAccessService(restored: _session());
      await tester.pumpWidget(scannerApp(service, eventId: 'evt-2'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-scanner-denied')), findsOneWidget);
      expect(find.textContaining('hanya berlaku untuk event'), findsOneWidget);
      expect(find.textContaining('SCANNER:'), findsNothing);
    });

    testWidgets('sesi valid membuka scanner event undangannya', (tester) async {
      final service = _FakeStaffAccessService(restored: _session());
      await tester.pumpWidget(scannerApp(service, eventId: 'evt-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-scanner-denied')), findsNothing);
      expect(find.text('SCANNER:evt-1'), findsOneWidget);
      expect(service.restoreCalls, 1);
    });
  });

  group('Model sesi staf', () {
    test('serialisasi JSON mempertahankan identitas staf + event', () {
      final session = _session();
      final restored = StaffSession.fromJson(session.toJson());
      expect(restored.token, 'staff-token');
      expect(restored.staffName, 'Budi Santoso');
      expect(restored.eventId, 'evt-1');
      expect(restored.eventTitle, 'Konser Musik 2026');
      expect(restored.isExpired, isFalse);
    });

    test('sesi yang melewati masa berlaku dianggap kedaluwarsa', () {
      final expired = StaffSession(
        token: 'x',
        staffName: 'Budi',
        eventId: 'evt-1',
        eventTitle: 'Konser',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(expired.isExpired, isTrue);
    });
  });
}
