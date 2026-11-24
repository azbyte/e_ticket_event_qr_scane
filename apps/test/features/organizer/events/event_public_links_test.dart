import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/organizer/events/screens/organizer_event_detail_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';

const String ownerId = OrganizerEventFixtures.demoOwnerId;

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

Future<void> pumpDetail(WidgetTester tester, String eventId) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    wrap(
      OrganizerEventDetailScreen(
        eventId: eventId,
        ownerId: ownerId,
        repository: MockOrganizerEventRepository(latency: Duration.zero),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('event draft menampilkan dua panel tautan dengan salin nonaktif', (
    tester,
  ) async {
    await pumpDetail(tester, 'evt-1004');

    expect(find.text('Tautan Pendaftaran Peserta'), findsOneWidget);
    expect(find.text('Tautan Undangan Panitia'), findsOneWidget);
    expect(
      find.text('Belum tersedia — terbitkan event terlebih dahulu.'),
      findsOneWidget,
    );

    final copyButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('event-public-link-copy')),
    );
    expect(copyButton.onPressed, isNull);
    expect(find.byKey(const Key('event-staff-invite-open')), findsOneWidget);
  });

  testWidgets('event tayang menampilkan public_url dan salin aktif', (
    tester,
  ) async {
    await pumpDetail(tester, 'evt-1001');

    expect(
      find.text('https://demo.eticket.local/e/evt-1001'),
      findsOneWidget,
    );
    final copyButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('event-public-link-copy')),
    );
    expect(copyButton.onPressed, isNotNull);

    // Tautan undangan panitia tetap panel terpisah (bukan URL yang sama).
    expect(find.text('Tautan Undangan Panitia'), findsOneWidget);
    expect(
      find.text(
        'Undangan panitia berbeda dari tautan pendaftaran peserta. '
        'Tautan dibuat per undangan (email, permission, masa berlaku) dan '
        'hanya dapat diterima akun dengan email yang cocok.',
      ),
      findsOneWidget,
    );
  });
}
