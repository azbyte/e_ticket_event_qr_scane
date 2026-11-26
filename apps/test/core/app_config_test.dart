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

  group('konfigurasi mode demo', () {
    test('mockMode hanya mencerminkan --dart-define, tidak pernah hardcoded', () {
      // Nilai efektif harus identik dengan konfigurasi build. Bila berbeda,
      // berarti ada nilai hardcoded yang bisa mengaktifkan demo tanpa diminta.
      const fromBuild = bool.fromEnvironment('MOCK_MODE', defaultValue: false);
      expect(AppConfig.mockMode, fromBuild);
    });

    test('mode demo nonaktif ketika build tidak meminta MOCK_MODE', () {
      // Tanpa --dart-define, mock mode wajib mati: aplikasi memakai backend dan
      // database asli. Saat suite dijalankan dengan MOCK_MODE=true (alur demo),
      // properti ini dibuktikan oleh langkah CI terpisah
      // "Verify demo mode stays off by default" yang menjalankan file ini tanpa
      // define — bukan dengan melonggarkan assertion di sini.
      if (AppConfig.mockMode) {
        expect(
          const bool.fromEnvironment('MOCK_MODE', defaultValue: false),
          isTrue,
          reason:
              'mockMode hanya boleh aktif bila --dart-define=MOCK_MODE=true diminta eksplisit',
        );
        return;
      }
      expect(AppConfig.mockMode, isFalse);
    });
  });
}
