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

void main() {
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
    'organizer dashboard only offers adding an event and profile access',
    (tester) async {
      final auth = AuthProvider(_UnauthenticatedAuthService())
        ..setUser(
          const UserModel(
            name: 'Event Organizer',
            email: 'organizer@event.com',
            role: UserRole.organizer,
          ),
        );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: const OrganizerDashboardScreen(),
            routes: {
              '/organizer/profile': (_) => const OrganizerProfileScreen(),
            },
          ),
        ),
      );

      expect(find.text('Tambah Event'), findsOneWidget);
      expect(find.text('Event saya'), findsNothing);
      expect(find.text('Profil'), findsNothing);
      expect(find.byTooltip('Profil'), findsOneWidget);
      expect(find.byTooltip('Notifikasi'), findsOneWidget);

      await tester.tap(find.byTooltip('Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notifikasi'), findsOneWidget);
      expect(find.text('Event Disetujui'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('organizer@event.com'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    },
  );

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
