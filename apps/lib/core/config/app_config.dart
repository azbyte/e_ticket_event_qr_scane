import 'package:flutter/foundation.dart';

/// Application-wide configuration.
///
/// The application uses the backend unless demo mode is explicitly enabled.
class AppConfig {
  AppConfig._();

  /// Human-readable application name.
  static const String appName = 'E-Ticket Event QR Scanner';

  /// Override at build time, e.g. --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Base URL backend.
  ///
  /// Tanpa `--dart-define=API_BASE_URL`, alamat default mengikuti target yang
  /// sedang dijalankan agar aplikasi tetap dapat terhubung ke backend lokal:
  /// - Web: `127.0.0.1` (loopback mesin yang menjalankan browser),
  /// - Emulator Android: `10.0.2.2` (loopback host dari emulator),
  /// - target lain (iOS simulator/desktop): `127.0.0.1`.
  ///
  /// Sebelumnya default selalu `10.0.2.2`. Nilai itu hanya dapat dijangkau
  /// emulator Android, sehingga build web tanpa `--dart-define` membuat SEMUA
  /// request (login dan registrasi) gagal dengan pesan koneksi.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://127.0.0.1:5000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }

  /// URL pemeriksaan kesehatan backend (`GET /health`, di luar `/api`).
  ///
  /// Dipakai layar login untuk membuktikan aplikasi benar-benar terhubung ke
  /// backend dan database sebelum pengguna mencoba masuk.
  static String get healthUrl {
    var base = apiBaseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return '$base/health';
  }

  /// Connection timeout in seconds.
  static const int connectTimeoutSeconds = 30;

  /// Receive timeout in seconds.
  static const int receiveTimeoutSeconds = 30;

  /// Enable mock/demo data explicitly with `--dart-define=MOCK_MODE=true`.
  static const bool mockMode = bool.fromEnvironment(
    'MOCK_MODE',
    defaultValue: false,
  );

  /// Override origin aplikasi publik, mis.
  /// `--dart-define=APP_PUBLIC_URL=https://tiket.example.com`.
  static const String _publicAppUrlOverride = String.fromEnvironment(
    'APP_PUBLIC_URL',
  );

  /// Origin aplikasi (tanpa trailing slash) tempat tautan pendaftaran dibuka.
  ///
  /// Urutan prioritas:
  /// 1. `--dart-define=APP_PUBLIC_URL` (dipakai pada build Android/rilis),
  /// 2. origin browser saat berjalan di Flutter Web,
  /// 3. `null` bila tidak dapat ditentukan (mis. Android tanpa override).
  static String? get publicAppOrigin {
    final override = _publicAppUrlOverride.trim();
    if (override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
      return Uri.base.origin;
    }
    return null;
  }

  /// Tautan pendaftaran peserta yang benar-benar dapat dibuka.
  ///
  /// [serverPublicUrl] adalah `public_url` dari backend (`APP_PUBLIC_URL` milik
  /// server). Nilai itu dipakai sebagai fallback, tetapi origin aplikasi yang
  /// sedang berjalan lebih diutamakan agar QR/tautan tidak menunjuk ke host
  /// backend (yang tidak melayani halaman Flutter) ketika konfigurasi server
  /// belum disesuaikan.
  static String? publicRegistrationUrl(
    String eventId, {
    String? serverPublicUrl,
  }) {
    final id = eventId.trim();
    if (id.isEmpty) return null;
    final origin = publicAppOrigin;
    if (origin != null) return '$origin/e/$id';
    final fallback = serverPublicUrl?.trim();
    return (fallback == null || fallback.isEmpty) ? null : fallback;
  }

  /// Origin backend (tanpa `/api`) untuk memuat media seperti desain tiket.
  static String get apiOrigin {
    var base = apiBaseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }

  /// URL absolut untuk path media relatif dari backend (`/media/...`).
  static String mediaUrl(String path) {
    final value = path.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return value.startsWith('/') ? '$apiOrigin$value' : '$apiOrigin/$value';
  }
}

