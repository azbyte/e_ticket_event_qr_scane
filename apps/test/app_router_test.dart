import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/app_router.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_profile_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/operations/organizer_scanner_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/shell/access_denied_screen.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/staff_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

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

void main() {
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

      expect(find.byType(OrganizerScannerScreen), findsOneWidget);
      expect(find.text('Pemindai Tiket QR (Mock)'), findsOneWidget);
    },
  );
}
