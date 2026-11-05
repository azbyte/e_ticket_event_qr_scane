/// Route generator for routes package (PRD section 7).
///
/// Centralized fallback & placeholder routing matching AppRoutes constants.
library;

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
      case AppRoutes.organizerDashboard:
        return _placeholder('Dashboard Penyelenggara');
      case AppRoutes.organizerTeam:
        return _placeholder('Manajemen Tim Penyelenggara');
      case AppRoutes.organizerPlans:
      case AppRoutes.organizerPlanTransactions:
        return _placeholder('Paket & Langganan');
      case AppRoutes.organizerSupport:
      case AppRoutes.organizerSupportNew:
        return _placeholder('Pusat Bantuan & Pengaduan');
      case AppRoutes.staffDashboard:
      case AppRoutes.staffAssignedEvents:
        return _placeholder('Dashboard Staf Event');
      case AppRoutes.accessDenied:
        return _placeholder('Akses Ditolak');
      default:
        return _placeholder('Halaman ${settings.name ?? '-'}');
    }
  }

  static MaterialPageRoute<dynamic> _placeholder(String title) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text('Halaman $title')),
      ),
    );
  }
}
