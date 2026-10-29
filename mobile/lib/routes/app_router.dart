/// Route generator.
///
/// Routes are stubs pending UI implementation (PRD section 7). Each route
/// returns a MaterialPageRoute to a placeholder screen.
import 'package:flutter/material.dart';

import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.initial:
        return _placeholder('Beranda');
      case AppRoutes.login:
        return _placeholder('Login');
      case AppRoutes.register:
        return _placeholder('Registrasi');
      default:
        return _placeholder('Halaman ${settings.name ?? '-'}');
    }
  }

  static MaterialPageRoute<dynamic> _placeholder(String title) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text('Halaman $title belum diimplementasi.')),
      ),
    );
  }
}
