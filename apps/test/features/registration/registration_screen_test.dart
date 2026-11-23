import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/registration/screens/registration_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import '../../helpers/test_mock_server.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await TestMockServer.start();

  setUp(() {
    TestMockServer.attachHttpOverrides();
  });

  tearDown(() {
    TestMockServer.resetReports();
  });

  final testEvent = EventModel(
    id: 'evt-test-101',
    organizerId: 'org-101',
    title: 'Festival Musik Kreatif 2026',
    description: 'Konser musik spektakuler outdoor',
    startDateTime: DateTime(2026, 12, 1, 18, 0),
    endDateTime: DateTime(2026, 12, 1, 23, 0),
    location: 'Stadion Utama Gelora',
    eventType: 'offline',
    category: 'Musik',
    attendeeFields: const ['name', 'email', 'phone'],
    status: 'PUBLISHED',
    isPublic: true,
  );

  Widget createTestWidget(Widget child) {
    final auth = AuthProvider(AuthService())
      ..setUser(
        const UserModel(
          id: 'usr-buyer-01',
          name: 'Pembeli Tiket',
          email: 'buyer@example.com',
          role: UserRole.attendee,
        ),
      );

    return ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('RegistrationScreen Widget Tests (Tahap 1 D3)', () {
    testWidgets('RegistrationScreen renders title and event summary', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(RegistrationScreen(event: testEvent)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Pemesanan Tiket'), findsOneWidget);
      expect(find.text('Festival Musik Kreatif 2026'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Attempting submission without selecting ticket shows warning', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(RegistrationScreen(event: testEvent)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final submitBtn = find.byType(ElevatedButton);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pemesanan harus berisi tepat 1 tiket.'), findsOneWidget);
    });
  });
}
