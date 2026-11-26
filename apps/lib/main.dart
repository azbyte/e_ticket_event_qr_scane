import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  if (kIsWeb) {
    // Tautan pendaftaran publik yang dibagikan Organizer berbentuk
    // `{APP_PUBLIC_URL}/e/{eventId}` tanpa `#`. Tanpa path URL strategy,
    // Flutter Web membaca route dari fragment sehingga path `/e/...` diabaikan
    // dan pengguna berakhir di halaman login. Path strategy membuat browser
    // benar-benar memakai `/e/{eventId}` sebagai route aplikasi.
    usePathUrlStrategy();
  }
  runApp(const MyApp());
}
