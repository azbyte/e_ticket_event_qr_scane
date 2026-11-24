import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/screens/organizer_event_detail_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';

const String ownerId = OrganizerEventFixtures.demoOwnerId;

/// Repository yang mengembalikan event draft dengan alasan validasi server.
class _InvalidEventRepository extends MockOrganizerEventRepository {
  _InvalidEventRepository() : super(latency: Duration.zero);

  final EventModel event = EventModel(
    id: 'evt-invalid-1',
    organizerId: ownerId,
    title: 'Event Belum Lengkap',
    description: 'Belum ada kategori tiket.',
    startDateTime: DateTime(2026, 12, 10, 9),
    endDateTime: DateTime(2026, 12, 10, 17),
    location: 'Auditorium',
    eventType: 'offline',
    category: 'Seminar',
    organizerName: 'Panitia Uji',
    contactInfo: 'panitia@example.test',
    attendeeFields: const <String>['name', 'email'],
    status: OrganizerEventStatus.draft,
    isPublic: false,
    validationErrors: const <String>[
      'Minimal satu kategori tiket aktif diperlukan',
      'Kuota kategori "Reguler" minimal 1',
    ],
  );

  @override
  Future<EventModel> getEvent({
    required String ownerId,
    required String eventId,
  }) async => event;

  @override
  Future<List<TicketTypeModel>> listTicketTypes({
    required String ownerId,
    required String eventId,
  }) async => const <TicketTypeModel>[];

  @override
  Future<OrganizerEventSummary> eventSummary({
    required String ownerId,
    required String eventId,
  }) async => OrganizerEventSummary.empty(eventId);

  @override
  Future<List<OrganizerEventSalesPoint>> salesPoints({
    required String ownerId,
    required String eventId,
  }) async => const <OrganizerEventSalesPoint>[];
}

Widget wrap(Widget child) => ChangeNotifierProvider<AuthProvider>.value(
  value: AuthProvider(AuthService())
    ..setUser(
      const UserModel(
        id: ownerId,
        name: 'Demo Owner',
        email: 'owner@example.test',
        role: UserRole.organizer,
      ),
    ),
  child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
);

void main() {
  testWidgets('detail event menampilkan alasan validasi dari server (K6)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrap(
        OrganizerEventDetailScreen(
          eventId: 'evt-invalid-1',
          ownerId: ownerId,
          repository: _InvalidEventRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Informasi'));
    await tester.pumpAndSettle();

    expect(find.text('Catatan validasi / revisi'), findsOneWidget);
    expect(find.text('Event belum dapat tayang karena:'), findsOneWidget);
    expect(
      find.text('Minimal satu kategori tiket aktif diperlukan'),
      findsOneWidget,
    );
    expect(find.text('Kuota kategori "Reguler" minimal 1'), findsOneWidget);
  });

  testWidgets('event draft menampilkan tombol Terbitkan event (D1-2 K1)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrap(
        OrganizerEventDetailScreen(
          eventId: 'evt-invalid-1',
          ownerId: ownerId,
          repository: _InvalidEventRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-publish-button')), findsOneWidget);
    expect(find.text('Terbitkan event'), findsOneWidget);
    // Aksi moderasi lama tidak ditampilkan pada mode API.
    expect(find.byKey(const Key('summary-submit-button')), findsNothing);
  },
      // Mode demo menampilkan aksi moderasi simulasi, bukan alur publish API.
      skip: AppConfig.mockMode);
}
