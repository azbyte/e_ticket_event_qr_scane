import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/events/screens/event_list_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/screens/organizer_ticket_type_form_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/event_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';

import '../../../helpers/test_mock_server.dart';

Widget wrapWithAuth(Widget child) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: AuthProvider(AuthService())
      ..setUser(
        const UserModel(
          id: 'org-test-001',
          name: 'Organizer Test',
          email: 'organizer@test.com',
          role: UserRole.organizer,
        ),
      ),
    child: MaterialApp(home: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TestMockServer.start();
  });

  setUp(() {
    TestMockServer.attachHttpOverrides();
  });

  group('EventListScreen State Tests (Loading, Error, Empty)', () {
    testWidgets(
      'EventListScreen displays events and shows empty state when search finds nothing',
      (tester) async {
        await tester.pumpWidget(wrapWithAuth(const EventListScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Jelajahi Event'), findsOneWidget);

        // Enter search for non-existent event
        await tester.enterText(
          find.byType(TextField),
          'tidak-ada-event-xyz-9999',
        );
        await tester.pumpAndSettle();

        expect(find.text('Tidak ada event ditemukan'), findsOneWidget);
      },
    );
  });

  group('OrganizerTicketTypeFormScreen Pricing Consistency Tests', () {
    testWidgets(
      'Form rejects adding paid ticket category to an all-free event',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockOrganizerEventRepository(latency: Duration.zero);
        final provider = EventProvider(
          repository: repo,
          ownerId: 'org-test-001',
        );

        const freeCategory = TicketTypeModel(
          id: 'tt-free-1',
          eventId: 'evt-test-1',
          name: 'Gratis Masuk',
          price: 0,
          quota: 100,
        );

        await tester.pumpWidget(
          wrapWithAuth(
            OrganizerTicketTypeFormScreen(
              eventId: 'evt-test-1',
              provider: provider,
              existingTypes: const [freeCategory],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill in name
        await tester.enterText(
          find.byKey(const Key('ticket-name-field')),
          'Tiket VIP Berbayar',
        );

        // Fill in paid price
        await tester.enterText(
          find.byKey(const Key('ticket-price-field')),
          '50000',
        );

        // Fill in quota
        await tester.enterText(
          find.byKey(const Key('ticket-quota-field')),
          '50',
        );

        // Submit form
        final saveButton = find.byKey(const Key('ticket-save-button'));
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Expect validation error
        expect(
          find.text(
            'Event gratis tidak boleh memiliki kategori tiket berbayar.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Form rejects adding free ticket category to an all-paid event',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = MockOrganizerEventRepository(latency: Duration.zero);
        final provider = EventProvider(
          repository: repo,
          ownerId: 'org-test-001',
        );

        const paidCategory = TicketTypeModel(
          id: 'tt-paid-1',
          eventId: 'evt-test-2',
          name: 'Tiket Reguler',
          price: 25000,
          quota: 100,
        );

        await tester.pumpWidget(
          wrapWithAuth(
            OrganizerTicketTypeFormScreen(
              eventId: 'evt-test-2',
              provider: provider,
              existingTypes: const [paidCategory],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill in name
        await tester.enterText(
          find.byKey(const Key('ticket-name-field')),
          'Tiket Masuk Gratis',
        );

        // Fill in free price 0
        await tester.enterText(find.byKey(const Key('ticket-price-field')), '0');

        // Fill in quota
        await tester.enterText(
          find.byKey(const Key('ticket-quota-field')),
          '50',
        );

        // Submit form
        final saveButton = find.byKey(const Key('ticket-save-button'));
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Expect validation error
        expect(
          find.text(
            'Event berbayar tidak boleh memiliki kategori tiket gratis.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
