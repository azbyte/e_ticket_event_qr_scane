import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_event_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/services/public_event/public_event_service.dart';

class _FakePublicEventService extends PublicEventService {
  _FakePublicEventService(this.loader);

  final Future<PublicEventData> Function(String eventId) loader;

  @override
  Future<PublicEventData> loadEvent(String eventId) => loader(eventId);
}

EventModel buildEvent({String status = 'published', bool isPublic = true}) =>
    EventModel(
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
      attendeeFields: const <String>['name', 'email'],
      status: status,
      isPublic: isPublic,
    );

TicketTypeModel buildTicketType({
  String id = 'tt-1',
  String name = 'Reguler',
  double price = 50000,
  int quota = 100,
  int sold = 0,
  DateTime? salesEnd,
}) => TicketTypeModel(
  id: id,
  eventId: 'evt-pub-1',
  name: name,
  price: price,
  quota: quota,
  sold: sold,
  salesEnd: salesEnd,
);

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('menampilkan state loading saat event dimuat', (tester) async {
    final completer = Completer<PublicEventData>();
    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService((_) => completer.future),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('public-event-loading')), findsOneWidget);
    expect(find.text('Memuat informasi event...'), findsOneWidget);
  });

  testWidgets('menampilkan state error saat API gagal', (tester) async {
    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => throw Exception('koneksi gagal'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-event-error')), findsOneWidget);
    expect(find.text('Gagal memuat event'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });

  testWidgets('menampilkan state tidak tersedia untuk event belum tayang', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => throw const PublicEventUnavailableException(
              'Event belum dipublikasikan atau sudah tidak tersedia.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-event-unavailable')), findsOneWidget);
    expect(find.text('Event tidak tersedia'), findsOneWidget);
  });

  testWidgets('menampilkan data event, kategori, dan tombol daftar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => PublicEventData(
              event: buildEvent(),
              ticketTypes: <TicketTypeModel>[
                buildTicketType(),
                buildTicketType(id: 'tt-2', name: 'VIP', price: 150000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-event-content')), findsOneWidget);
    expect(find.text('Festival Publik 2026'), findsOneWidget);
    expect(find.text('Reguler'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('public-event-register-button')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('kategori habis membuat tombol daftar nonaktif', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => PublicEventData(
              event: buildEvent(),
              ticketTypes: <TicketTypeModel>[
                buildTicketType(quota: 10, sold: 10),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiket tidak tersedia'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('public-event-register-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('event tanpa kategori tiket menampilkan state kosong', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrap(
        PublicEventScreen(
          eventId: 'evt-pub-1',
          service: _FakePublicEventService(
            (_) async => PublicEventData(
              event: buildEvent(),
              ticketTypes: const <TicketTypeModel>[],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('public-event-empty-tickets')), findsOneWidget);
    expect(
      find.text('Belum ada kategori tiket untuk acara ini.'),
      findsOneWidget,
    );
  });
}
