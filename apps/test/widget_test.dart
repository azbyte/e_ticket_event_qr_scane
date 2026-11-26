import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/app.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/login_screen.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/register_screen.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/profile_edit_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/organizer_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/organizer_profile_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_shell/organizer_shell_service.dart';

import 'helpers/test_mock_server.dart';

class _UnauthenticatedAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>> me() async =>
      throw Exception('No active session');
  @override
  Future<void> logout() async {}
}

class _ProfileAuthService extends _UnauthenticatedAuthService {
  @override
  Future<Map<String, dynamic>> updateProfile({required String name}) async => {
    'name': name,
    'email': 'admin@event.com',
    'role': 'admin',
  };
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await TestMockServer.start();

  setUp(() {
    TestMockServer.attachHttpOverrides();
  });
  testWidgets('launching without a session displays login', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) =>
            AuthProvider(_UnauthenticatedAuthService())..restoreSession(),
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Event Ticket'), findsOneWidget);
    expect(find.text('Email atau username'), findsOneWidget);
    expect(find.text('Kata sandi'), findsOneWidget);
  });

  testWidgets('login displays a registration link', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_UnauthenticatedAuthService()),
        child: MaterialApp(
          home: const LoginScreen(),
          routes: {'/register': (_) => const RegisterScreen()},
        ),
      ),
    );
    await tester.tap(
      find.text('Belum punya akun? Daftar sebagai penyelenggara'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daftar Penyelenggara'), findsOneWidget);
  });

  testWidgets(
    'organizer dashboard keeps a minimal header and exactly three main tabs',
    (tester) async {
      await tester.pumpWidget(_organizerDashboardApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.destinations.length, 3);
      expect(
        navigationBar.destinations
            .cast<NavigationDestination>()
            .map((destination) => destination.label)
            .toList(),
        <String>['Dashboard', 'Scan QR', 'Profil'],
      );
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.byIcon(Icons.menu), findsNothing);

      // Header ringkas: tanpa drawer/hamburger dan tanpa avatar profil.
      expect(find.byType(Drawer), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircleAvatar),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Notifikasi'), findsOneWidget);

      // Pengelolaan event tetap mudah ditemukan.
      expect(find.text('Event Milik Saya'), findsOneWidget);
      expect(find.text('Tambah Event'), findsOneWidget);
      expect(find.text('Webinar Produk Digital 2026'), findsOneWidget);
    },
  );

  testWidgets('organizer dashboard reaches notifications and the profile tab', (
    tester,
  ) async {
    await tester.pumpWidget(_organizerDashboardApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifikasi'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Notifikasi'), findsOneWidget);
    expect(find.text('Event Disetujui'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('organizer@event.com'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Logout'), 200);
    expect(find.text('Paket & Langganan'), findsOneWidget);
    expect(find.text('Pusat Bantuan & Laporan'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('organizer dashboard responsif pada layar sempit dan lebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_organizerDashboardApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Event Milik Saya'), findsOneWidget);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpWidget(_organizerDashboardApp());
    await tester.pumpAndSettle();

    // Layar lebar memakai sidebar dengan menu yang sama.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Portal Penyelenggara'), findsOneWidget);
    expect(find.text('Event Milik Saya'), findsOneWidget);
  });

  testWidgets('admin dashboard has profile and notification actions', (
    tester,
  ) async {
    final auth = AuthProvider(_UnauthenticatedAuthService())
      ..setUser(
        const UserModel(
          name: 'Super Admin',
          email: 'admin@event.com',
          role: UserRole.admin,
        ),
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Profil'), findsOneWidget);
    expect(find.byTooltip('Notifikasi'), findsOneWidget);
    expect(find.text('Pengelolaan akun'), findsOneWidget);
  });

  testWidgets('profile edit saves the updated name', (tester) async {
    final auth = AuthProvider(_ProfileAuthService())
      ..setUser(
        const UserModel(
          name: 'Super Admin',
          email: 'admin@event.com',
          role: UserRole.admin,
        ),
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Admin Baru');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(auth.user?.name, 'Admin Baru');
  });
}

/// Dashboard Organizer dengan repository in-memory agar test tidak bergantung
/// pada jaringan, plus route tab Scan QR dan Profil.
Widget _organizerDashboardApp() {
  final auth = AuthProvider(_UnauthenticatedAuthService())
    ..setUser(
      const UserModel(
        id: 'org-001',
        name: 'Event Organizer',
        email: 'organizer@event.com',
        role: UserRole.organizer,
      ),
    );

  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: OrganizerDashboardScreen(
        dashboardService: OrganizerShellService.forRepository(
          MockOrganizerEventRepository(latency: Duration.zero),
        ),
      ),
      routes: {
        '/organizer/scan': (_) =>
            const Scaffold(body: Center(child: Text('Halaman Scan QR'))),
        '/organizer/profile': (_) => const OrganizerProfileScreen(),
      },
    ),
  );
}
