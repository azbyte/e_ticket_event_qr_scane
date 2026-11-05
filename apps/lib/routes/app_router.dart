import 'package:flutter/material.dart';

import '../features/admin/screens/event_moderation_screen.dart';
import '../features/admin/screens/report_management_screen.dart';
import '../features/admin/tabs/admin_tab_controller.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/check_in/screens/check_in_history_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/event_list_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notifications/screens/notification_list_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/order_list_screen.dart';
import '../features/organizer/screens/event_management_screen.dart';
import '../features/organizer/tabs/organizer_tab_controller.dart';
import '../features/payments/screens/payment_screen.dart';
import '../features/payments/screens/payment_status_screen.dart';
import '../features/registration/screens/registration_screen.dart';
import '../features/reports/screens/report_form_screen.dart';
import '../features/reports/screens/report_list_screen.dart';
import '../features/scanner/screens/scanner_screen.dart';
import '../features/staff/screens/staff_dashboard_screen.dart';
import '../features/tickets/screens/ticket_detail_screen.dart';
import '../features/tickets/screens/ticket_list_screen.dart';
import 'app_routes.dart';

/// App Router for the E-Ticket Event QR Scanner application.
/// Generates routes based on the AppRoutes constants.
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case AppRoutes.initial:
      case AppRoutes.home:
        return _buildPageRoute(settings, const HomeScreen());
      case AppRoutes.login:
        return _buildPageRoute(settings, const LoginScreen());
      case AppRoutes.register:

      default:
        return _buildPageRoute(
          settings,
          Scaffold(
            appBar: AppBar(title: const Text('Halaman Tidak Ditemukan')),
            body: Center(
              child: Text('Route ${settings.name ?? '-'} belum diimplementasikan.'),
            ),
          ),
        );
    }
  }


    );
  }
}
