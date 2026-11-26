import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/organizer/operations/organizer_scan_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/shell/organizer_shell.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';

class _NoopAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

Widget _scanApp(MockOrganizerEventRepository repository) {
  final auth = AuthProvider(_NoopAuthService())
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
    child: MaterialApp(home: OrganizerScanScreen(repository: repository)),
  );
}

void main() {
  testWidgets('tab Scan QR menampilkan event milik Organizer dari repository', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scanApp(MockOrganizerEventRepository(latency: Duration.zero)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pindai Tiket'), findsOneWidget);
    expect(find.text('Pilih event'), findsOneWidget);
    expect(find.text('Webinar Produk Digital 2026'), findsOneWidget);
    expect(find.text('Lari Komunitas 5K'), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.destinations.length, 3);
    expect(navigationBar.selectedIndex, 1);
  });

  testWidgets('tab Scan QR menampilkan empty state bila belum ada event', (
    tester,
  ) async {
    await tester.pumpWidget(_scanApp(MockOrganizerEventRepository.empty()));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada event untuk dipindai'), findsOneWidget);
    expect(find.text('Buat event'), findsOneWidget);
  });

  testWidgets('halaman turunan tidak menampilkan bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OrganizerShell(
          currentRoute: '/organizer/team',
          title: 'Manajemen Tim & Staf',
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byTooltip('Notifikasi'), findsOneWidget);
  });

  testWidgets('layar lebar memakai sidebar dengan tiga menu yang sama', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: OrganizerShell(
          currentRoute: '/organizer',
          title: 'Dashboard',
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Portal Penyelenggara'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });
}
