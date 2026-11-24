import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_registration_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/providers/order_provider.dart';
import 'package:e_ticket_event_qr_scane/services/order/order_service.dart';
import 'package:e_ticket_event_qr_scane/services/public_event/public_event_service.dart';

import '../../helpers/test_mock_server.dart';

class _FakePublicEventService extends PublicEventService {
  _FakePublicEventService(this.loader);

  final Future<PublicEventData> Function(String eventId) loader;

  @override
  Future<PublicEventData> loadEvent(String eventId) => loader(eventId);
}

class _RecordingOrderService extends OrderService {
  _RecordingOrderService(this.responder);

  final Map<String, dynamic> Function(Map<String, dynamic> payload) responder;
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    lastPayload = payload;
    return responder(payload);
  }
}

Map<String, dynamic> orderJson({
  String status = 'paid',
  double grandTotal = 0,
}) => <String, dynamic>{
  'id': 'ord-pub-1',
  'event_id': 'evt-pub-1',
  'event_title': 'Festival Publik 2026',
  'status': status,
  'total_amount': grandTotal,
  'service_fee': 0,
  'grand_total': grandTotal,
  'items': const <dynamic>[],
};

EventModel buildEvent() => EventModel(
  id: 'evt-pub-1',
  organizerId: 'org-1',
  title: 'Festival Publik 2026',
  description: 'Acara musik terbuka untuk umum.',
  startDateTime: DateTime(2026, 12, 1, 18),
  endDateTime: DateTime(2026, 12, 1, 22),
  location: 'Stadion Utama',
  eventType: 'offline',
  category: 'Musik',
  organizerName: 'Komunitas Musik',
  contactInfo: 'halo@festival.test',
  attendeeFields: const <String>['name', 'email', 'organization'],
  status: 'published',
  isPublic: true,
);

TicketTypeModel buildTicketType() => const TicketTypeModel(
  id: 'tt-1',
  eventId: 'evt-pub-1',
  name: 'Reguler',
  price: 50000,
  quota: 100,
);

PublicEventData buildData({List<TicketTypeModel>? ticketTypes}) =>
    PublicEventData(
      event: buildEvent(),
      ticketTypes: ticketTypes ?? <TicketTypeModel>[buildTicketType()],
    );

Widget wrap(Widget child) => MaterialApp(home: child);

/// Viewport tinggi agar seluruh isi ListView (termasuk tombol submit) dibangun.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestMockServer.start();
  });

  setUp(() {
    TestMockServer.attachHttpOverrides();
  });

  testWidgets('menampilkan state loading formulir', (tester) async {
    final completer = Completer<PublicEventData>();
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService((_) => completer.future),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('public-registration-loading')), findsOneWidget);
  });

  testWidgets('menampilkan state tidak tersedia untuk event tidak tayang', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => throw const PublicEventUnavailableException(
              'Event tidak ditemukan atau belum dipublikasikan.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('public-registration-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('submit tanpa memilih kategori menampilkan peringatan', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService((_) async => buildData()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('public-registration-submit')),
    );
    await tester.tap(find.byKey(const Key('public-registration-submit')));
    await tester.pump();

    expect(
      find.text('Pilih satu kategori tiket terlebih dahulu.'),
      findsOneWidget,
    );
  });

  testWidgets('field wajib peserta divalidasi sebelum order dibuat', (
    tester,
  ) async {
    useTallViewport(tester);
    final orderService = _RecordingOrderService((_) => orderJson());
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService((_) async => buildData()),
          orderProvider: OrderProvider(orderService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('public-registration-ticket-tt-1')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('public-registration-submit')),
    );
    await tester.tap(find.byKey(const Key('public-registration-submit')));
    await tester.pump();

    expect(find.text('"Nama lengkap" wajib diisi.'), findsOneWidget);
    expect(find.text('"Email" wajib diisi.'), findsOneWidget);
    expect(orderService.lastPayload, isNull);
  });

  testWidgets('submit valid membuat satu order, satu tiket, dan custom_fields', (
    tester,
  ) async {
    useTallViewport(tester);

    final orderService = _RecordingOrderService((_) => orderJson());
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService((_) async => buildData()),
          orderProvider: OrderProvider(orderService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('public-registration-ticket-tt-1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('public-registration-field-name')),
      'Budi Santoso',
    );
    await tester.enterText(
      find.byKey(const Key('public-registration-field-email')),
      'budi@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('public-registration-field-organization')),
      'Universitas Negeri Padang',
    );
    await tester.ensureVisible(
      find.byKey(const Key('public-registration-submit')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('public-registration-submit')));
    await tester.pumpAndSettle();

    final payload = orderService.lastPayload!;
    expect(payload['event_id'], 'evt-pub-1');
    expect(payload['items'], <String, int>{'tt-1': 1});
    final attendees = payload['attendees'] as List<dynamic>;
    expect(attendees.length, 1);
    final attendee = attendees.single as Map<String, dynamic>;
    expect(attendee['ticket_type_id'], 'tt-1');
    expect(attendee['name'], 'Budi Santoso');
    expect(attendee['email'], 'budi@example.test');
    expect(
      (attendee['custom_fields'] as Map<String, dynamic>)['organization'],
      'Universitas Negeri Padang',
    );
  });

  testWidgets('kategori yang tidak tersedia tidak dapat dipilih', (
    tester,
  ) async {
    useTallViewport(tester);
    await tester.pumpWidget(
      wrap(
        PublicRegistrationScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => buildData(
              ticketTypes: <TicketTypeModel>[
                const TicketTypeModel(
                  id: 'tt-sold',
                  eventId: 'evt-pub-1',
                  name: 'Habis',
                  price: 10000,
                  quota: 5,
                  sold: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('public-registration-ticket-tt-sold')),
    );
    await tester.pump();

    expect(find.text('Tidak tersedia'), findsOneWidget);
    // Tombol submit tetap ada tetapi order tidak bisa dibuat tanpa pilihan.
    await tester.ensureVisible(
      find.byKey(const Key('public-registration-submit')),
    );
    await tester.tap(find.byKey(const Key('public-registration-submit')));
    await tester.pump();
    expect(
      find.text('Pilih satu kategori tiket terlebih dahulu.'),
      findsOneWidget,
    );
  });
}
