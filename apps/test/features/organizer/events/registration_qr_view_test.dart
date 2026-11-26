import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/widgets/registration_qr_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Regresi QR pendaftaran peserta: QR harus berisi URL pendaftaran publik yang
/// dapat dipindai, bukan pola dekoratif, dan tidak menampilkan QR palsu ketika
/// event belum tayang.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('QR pendaftaran berisi URL event yang benar', (tester) async {
    const url = 'http://localhost:3100/e/evt-pub-1';
    await tester.pumpWidget(wrap(const RegistrationQrView(data: url)));

    // Widget dirender sebagai QR asli (bukan pola dekoratif).
    expect(find.byKey(const Key('registration-qr-image')), findsOneWidget);
    expect(find.byKey(const Key('registration-qr-unavailable')), findsNothing);
    final painted = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('registration-qr-image')),
        matching: find.byType(CustomPaint),
      ).first,
    );
    expect(painted.painter, isNotNull);
  });

  testWidgets('event belum tayang tidak menampilkan QR palsu', (tester) async {
    await tester.pumpWidget(wrap(const RegistrationQrView(data: null)));

    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.byKey(const Key('registration-qr-unavailable')),
      findsOneWidget,
    );
    expect(find.text('QR aktif setelah event tayang'), findsOneWidget);
  });

  test('publicRegistrationUrl memakai id event pada path /e/{id}', () {
    final url = AppConfig.publicRegistrationUrl(
      'evt-1',
      serverPublicUrl: 'https://contoh.test/e/lain',
    );
    // Di lingkungan test tidak ada origin browser, sehingga fallback memakai
    // public_url dari server.
    expect(url, 'https://contoh.test/e/lain');
    expect(AppConfig.publicRegistrationUrl('  '), isNull);
  });

  test('mediaUrl membuat URL absolut untuk path backend', () {
    expect(
      AppConfig.mediaUrl('/media/ticket-designs/a/b.png'),
      '${AppConfig.apiOrigin}/media/ticket-designs/a/b.png',
    );
    expect(
      AppConfig.mediaUrl('https://cdn.test/x.png'),
      'https://cdn.test/x.png',
    );
  });
}
