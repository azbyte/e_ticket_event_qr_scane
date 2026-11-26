import 'package:e_ticket_event_qr_scane/app_router.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/login_screen.dart';
import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_event_screen.dart';
import 'package:e_ticket_event_qr_scane/features/public_event/screens/public_registration_screen.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NoopAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

/// Regresi deep link tautan pendaftaran: route publik harus terbuka tanpa login
/// meskipun tautan datang dalam bentuk URL absolut atau hash strategy lama.
void main() {
  Widget appForGuest(String route) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(_NoopAuthService()),
      child: MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(route),
                child: const Text('Open route'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openRoute(WidgetTester tester, String route) async {
    await tester.pumpWidget(appForGuest(route));
    await tester.tap(find.text('Open route'));
    // `pump` (bukan `pumpAndSettle`) karena layar publik memuat data dari API
    // dan akan terus menampilkan indikator loading di lingkungan test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('URL absolut /e/{id} membuka halaman event publik', (
    tester,
  ) async {
    await openRoute(tester, 'http://localhost:3100/e/evt-abc');
    expect(find.byType(PublicEventScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('URL absolut dengan query tetap dikenali', (tester) async {
    await openRoute(tester, 'http://localhost:3100/e/evt-abc?src=qr');
    expect(find.byType(PublicEventScreen), findsOneWidget);
  });

  testWidgets('hash strategy lama #/e/{id} tetap membuka event publik', (
    tester,
  ) async {
    await openRoute(tester, '/#/e/evt-abc');
    expect(find.byType(PublicEventScreen), findsOneWidget);
  });

  testWidgets('URL absolut /registration/{id} memakai formulir guest', (
    tester,
  ) async {
    await openRoute(tester, 'http://localhost:3100/registration/evt-abc');
    expect(find.byType(PublicRegistrationScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('route internal tetap menolak guest', (tester) async {
    await openRoute(tester, '/organizer/dashboard');
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
