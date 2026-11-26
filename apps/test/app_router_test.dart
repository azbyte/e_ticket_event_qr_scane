import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/app_router.dart';
import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_profile_screen.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/login_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/membership/team_management_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/operations/organizer_scanner_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/attendee_list_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/organizer_order_list_screen.dart';
import 'package:e_ticket_event_qr_scane/features/scanner/screens/scanner_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/shell/access_denied_screen.dart';
import 'package:e_ticket_event_qr_scane/features/public_event/screens/invitation_entry_screen.dart';
import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_event_screen.dart';
import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_registration_screen.dart';
import 'package:e_ticket_event_qr_scane/features/registration/screens/registration_screen.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/staff_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'helpers/test_mock_server.dart';

class _NoopAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

Widget _appFor(String route, UserRole role) {
  final auth = AuthProvider(_NoopAuthService())
    ..setUser(
      UserModel(name: 'Test User', email: 'test@example.com', role: role),
    );
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pushNamed(context, route),
            child: const Text('Open route'),
          ),
        ),
      ),
      onGenerateRoute: AppRouter.generateRoute,
    ),
  );
}

Widget _appForGuest(String route) {
  final auth = AuthProvider(_NoopAuthService());
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pushNamed(context, route),
            child: const Text('Open route'),
          ),
        ),
      ),
      onGenerateRoute: AppRouter.generateRoute,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestMockServer.start();
  });

  setUp(() {
    TestMockServer.attachHttpOverrides();
  });

  testWidgets('Admin profile route opens the Admin profile screen', (
    tester,
  ) async {
    await tester.pumpWidget(_appFor('/admin/profile', UserRole.admin));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminProfileScreen), findsOneWidget);
    expect(find.text('Profil Administrator'), findsOneWidget);
  });

  testWidgets('non-admin users are denied Admin routes', (tester) async {
    await tester.pumpWidget(_appFor('/admin/profile', UserRole.organizer));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('Profil Administrator'), findsNothing);
  });

  testWidgets('staff scanner route checks membership before opening scanner', (
    tester,
  ) async {
    await tester.pumpWidget(_appFor('/staff/scanner', UserRole.attendee));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffDashboardScreen), findsOneWidget);
    expect(find.text('Dashboard Staf Event'), findsOneWidget);
    expect(find.text('Belum ada penugasan event aktif'), findsOneWidget);
  });

  testWidgets(
    'organizer event scanner route opens the permission-aware screen',
    (tester) async {
      await tester.pumpWidget(
        _appFor('/organizer/events/evt-1001/scanner', UserRole.organizer),
      );
      await tester.tap(find.text('Open route'));
      await tester.pumpAndSettle();

      // Identitas layar: route harus membuka OrganizerScannerScreen milik event
      // yang diminta, bukan halaman lain atau scanner tanpa konteks event.
      final organizerScanner = tester.widget<OrganizerScannerScreen>(
        find.byType(OrganizerScannerScreen),
      );
      expect(organizerScanner.eventId, 'evt-1001');

      // Perilaku: pemilik event memiliki izin SCAN_TICKET, sehingga yang tampil
      // adalah pemindai - bukan layar "Akses Ditolak".
      expect(
        organizerScanner.contextScope.hasPermission(
          OrganizerPermission.scanTicket,
        ),
        isTrue,
      );
      expect(find.text('Akses Ditolak'), findsNothing);

      if (AppConfig.mockMode) {
        // Mode demo eksplisit: layar simulasi milik OrganizerScannerScreen.
        expect(find.byType(ScannerScreen), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Pemindai Tiket QR'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Input Kode / Token Tiket QR'),
          findsOneWidget,
        );
      } else {
        // Mode API (dipakai produksi): OrganizerScannerScreen mendelegasikan ke
        // ScannerScreen ber-event-id sama, dengan judul nyata tanpa penanda demo
        // dan input token manual sebagai fallback kamera.
        final page = tester.widget<ScannerScreen>(find.byType(ScannerScreen));
        expect(page.eventId, 'evt-1001');
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Pemindai QR Tiket'),
          ),
          findsOneWidget,
        );
        expect(find.text('Input Kode / Token Tiket'), findsOneWidget);
      }
      // Penanda demo tidak boleh kembali muncul di mana pun pada layar ini.
      expect(find.textContaining('(demo)'), findsNothing);
    },
  );

  testWidgets('guest dapat membuka tautan publik event tanpa login (K1 D1-1)', (
    tester,
  ) async {
    await tester.pumpWidget(_appForGuest('/e/evt-pub-1'));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicEventScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('guest dapat membuka formulir pendaftaran publik', (tester) async {
    await tester.pumpWidget(_appForGuest('/e/evt-pub-1/register'));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(PublicRegistrationScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('/registration/:eventId memakai formulir guest tanpa login', (
    tester,
  ) async {
    await tester.pumpWidget(_appForGuest('/registration/evt-pub-1'));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    // Alur ini wajib memakai layar guest (bukan layar registrasi berakun),
    // agar peserta tanpa login dapat mengisi formulir sesuai konfigurasi event.
    expect(find.byType(PublicRegistrationScreen), findsOneWidget);
    expect(find.byType(RegistrationScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Halaman tidak ditemukan'), findsNothing);
  });

  testWidgets('guest tetap ditolak pada route Admin (K2 D1-1)', (tester) async {
    await tester.pumpWidget(_appForGuest('/admin/dashboard'));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AdminProfileScreen), findsNothing);
  });

  testWidgets('/invite/:token tanpa login diarahkan ke login dengan redirect', (
    tester,
  ) async {
    await tester.pumpWidget(_appForGuest('/invite/token-abc'));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    expect(login.redirectRoute, '/invite/token-abc');
  });

  testWidgets('/invite/:token setelah login membuka halaman penerimaan (K3)', (
    tester,
  ) async {
    await tester.pumpWidget(_appFor('/invite/token-abc', UserRole.organizer));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(InvitationEntryScreen), findsOneWidget);
    expect(find.text('Undangan Panitia Event'), findsOneWidget);
  });

  testWidgets('/staff/:eventId membuka workspace staf', (tester) async {
    await tester.pumpWidget(_appFor('/staff/evt-1001', UserRole.staff));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffDashboardScreen), findsOneWidget);
  });

  // ---------------------------------------------------------------
  // Regresi T3-D1-02: defect routing yang ditemukan Developer 1.
  // ---------------------------------------------------------------

  testWidgets('D1-G1: /organizer/events/:id/attendees memakai eventId nyata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appFor('/organizer/events/evt-real-42/attendees', UserRole.organizer),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    final screen = tester.widget<AttendeeListScreen>(
      find.byType(AttendeeListScreen),
    );
    expect(screen.eventId, 'evt-real-42');
  });

  testWidgets('D1-G3: /organizer/events/:id/orders tersedia', (tester) async {
    await tester.pumpWidget(
      _appFor('/organizer/events/evt-real-42/orders', UserRole.organizer),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    final screen = tester.widget<OrganizerOrderListScreen>(
      find.byType(OrganizerOrderListScreen),
    );
    expect(screen.eventId, 'evt-real-42');
  });

  testWidgets('D1-G2: /staff/scanner dengan eventId membuka ScannerScreen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appForGuest('/staff/scanner'),
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    // Guest diarahkan ke login untuk route non-publik.
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('D1-G2: /staff/scanner tanpa eventId jatuh ke dashboard staf', (
    tester,
  ) async {
    await tester.pumpWidget(_appFor('/staff/scanner', UserRole.staff));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffDashboardScreen), findsOneWidget);
    expect(find.byType(ScannerScreen), findsNothing);
  });

  testWidgets('D1-G2: /organizer/team tanpa argument tidak memakai evt-1001', (
    tester,
  ) async {
    await tester.pumpWidget(_appFor('/organizer/team', UserRole.organizer));
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();

    final screen = tester.widget<TeamManagementScreen>(
      find.byType(TeamManagementScreen),
    );
    expect(screen.eventId, isEmpty);
    expect(screen.eventId, isNot('evt-1001'));
  });
}
