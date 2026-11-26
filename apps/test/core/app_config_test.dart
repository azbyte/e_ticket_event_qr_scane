import 'package:e_ticket_event_qr_scane/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi: default `API_BASE_URL` tidak boleh selalu `10.0.2.2`.
///
/// `10.0.2.2` hanya dapat dijangkau emulator Android. Ketika nilai itu dipakai
/// pada build web, seluruh request (termasuk login dan registrasi Organizer)
/// gagal dengan pesan koneksi karena browser tidak dapat menjangkau alamat
/// tersebut.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('AppConfig.apiBaseUrl tanpa --dart-define', () {
    test('emulator Android memakai loopback host 10.0.2.2', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:5000/api');
    });

    test('target non-Android memakai 127.0.0.1 (dapat dijangkau browser)', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          AppConfig.apiBaseUrl,
          'http://127.0.0.1:5000/api',
          reason: 'platform $platform harus memakai loopback lokal',
        );
      }
    });

    test('base URL berbentuk absolut dan berakhiran /api', () {
      final uri = Uri.parse(AppConfig.apiBaseUrl);
      expect(uri.hasScheme, isTrue);
      expect(uri.hasAuthority, isTrue);
      expect(uri.path, '/api');
    });
  });

  test('mode demo tetap nonaktif secara default', () {
    expect(AppConfig.mockMode, isFalse);
  });
}
