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
        return _buildPageRoute(settings, const RegisterScreen());
      case AppRoutes.eventList:
        return _buildPageRoute(settings, const EventListScreen());
      case AppRoutes.eventDetail:
        return _buildPageRoute(
          settings,
          EventDetailScreen(eventId: args is String ? args : null),
        );
      case AppRoutes.registration:
        return _buildPageRoute(
          settings,
          RegistrationScreen(eventId: args is String ? args : null),
        );
      case AppRoutes.ticketList:
        return _buildPageRoute(settings, const TicketListScreen());
      case AppRoutes.ticketDetail:
        return _buildPageRoute(
          settings,
          TicketDetailScreen(ticketId: args is String ? args : null),
        );
      case AppRoutes.orderList:
        return _buildPageRoute(settings, const OrderListScreen());
      case AppRoutes.orderDetail:
        return _buildPageRoute(
          settings,
          OrderDetailScreen(orderId: args is String ? args : null),
        );
      case AppRoutes.payment:
        return _buildPageRoute(
          settings,
          PaymentScreen(orderId: args is String ? args : null),
        );
      case AppRoutes.paymentStatus:
        return _buildPageRoute(
          settings,
          PaymentStatusScreen(orderId: args is String ? args : null),
        );
      case AppRoutes.organizerDashboard:
        return _buildPageRoute(settings, const OrganizerTabController());
      case AppRoutes.organizerEvents:
        return _buildPageRoute(settings, const EventManagementScreen());
      case AppRoutes.staffDashboard:
        return _buildPageRoute(settings, const StaffDashboardScreen());
      case AppRoutes.staffScanner:
        return _buildPageRoute(settings, const ScannerScreen());
      case AppRoutes.checkInHistory:
        return _buildPageRoute(settings, const CheckInHistoryScreen());
      case AppRoutes.adminDashboard:
        return _buildPageRoute(settings, const AdminTabController());
      case AppRoutes.adminEventModeration:
        return _buildPageRoute(settings, const EventModerationScreen());
      case AppRoutes.adminReports:
        return _buildPageRoute(settings, const ReportManagementScreen());
      case AppRoutes.reportList:
        return _buildPageRoute(settings, const ReportListScreen());
      case AppRoutes.reportForm:
        return _buildPageRoute(
          settings,
          ReportFormScreen(
            initialOrderReference: args is String ? args : null,
          ),
        );
      case AppRoutes.notificationList:
        return _buildPageRoute(settings, const NotificationListScreen());
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

  static MaterialPageRoute<dynamic> _buildPageRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => page,
    );
  }
}
