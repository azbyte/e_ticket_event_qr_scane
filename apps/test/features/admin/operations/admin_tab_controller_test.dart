import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/admin/tabs/admin_tab_controller.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

class FakeAdminAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>> me() async => {
        'id': 'usr-admin',
        'name': 'Super Admin',
        'email': 'admin@event.com',
        'role': 'admin',
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createAdminTabWidget(AuthProvider auth, {int initialIndex = 0}) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: AdminTabController(initialIndex: initialIndex),
      ),
    );
  }

  group('AdminTabController Widget Tests (PRD section 6.1, 7.6)', () {
    testWidgets('Menampilkan 4 menu navigasi Admin utama (Dashboard, Moderasi, Akun, Support)',
        (tester) async {
      final auth = AuthProvider(FakeAdminAuthService());
      await auth.restoreSession();

      await tester.pumpWidget(createAdminTabWidget(auth, initialIndex: 0));
      await tester.pumpAndSettle();

      // Navigation bar labels
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Moderasi'), findsOneWidget);
      expect(find.text('Akun'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Bisnis'), findsOneWidget);

      // Default index 0: Dashboard Screen
      expect(find.text('Super Admin Dashboard'), findsOneWidget);

      // Pastikan background event loader timer selesai sebelum teardown
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Beralih antar tab navigasi Admin dengan mulus',
        (tester) async {
      final auth = AuthProvider(FakeAdminAuthService());
      await auth.restoreSession();

      await tester.pumpWidget(createAdminTabWidget(auth, initialIndex: 0));
      await tester.pumpAndSettle();

      // Tap tab Moderasi
      await tester.tap(find.text('Moderasi'));
      await tester.pumpAndSettle();

      expect(find.text('Moderasi & Event Platform'), findsOneWidget);

      // Tap tab Akun
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(find.text('Pengelolaan Akun Platform'), findsOneWidget);

      // Tap tab Support
      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Support Center'), findsOneWidget);

      await tester.tap(find.text('Bisnis'));
      await tester.pumpAndSettle();
      expect(find.text('Modul Bisnis Platform'), findsOneWidget);
      expect(find.text('Langganan Organizer'), findsOneWidget);
    });
  });
}
