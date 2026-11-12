/// Route generator for named routes not covered by the static [routes] map
/// in [app.dart].
///
/// Routes already handled by the static map in [app.dart]:
/// - [AppRoutes.initial] → AuthGate
/// - [AppRoutes.login] → LoginScreen
/// - [AppRoutes.register] → RegisterScreen
/// - [AppRoutes.adminDashboard] → RoleGuard(admin: true)
/// - [AppRoutes.organizerDashboard] → RoleGuard(admin: false)
///
/// All other named routes are resolved here via [generateRoute].
library;

import 'package:flutter/material.dart';

import '../features/admin/screens/account_management_screen.dart';
import '../features/admin/screens/event_moderation_screen.dart';
import '../features/admin/screens/report_management_screen.dart';
import '../features/auth/screens/profile_edit_screen.dart';
import '../features/check_in/screens/check_in_history_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/event_list_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notifications/screens/notification_list_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/order_list_screen.dart';
import '../features/payments/screens/payment_screen.dart';
import '../features/payments/screens/payment_status_screen.dart';
import '../features/registration/screens/attendee_form_screen.dart';
import '../features/registration/screens/registration_screen.dart';
import '../features/registration/screens/ticket_selection_screen.dart';
import '../features/reports/screens/report_form_screen.dart';
import '../features/reports/screens/report_list_screen.dart';
import '../features/reports/screens/report_status_screen.dart';
import '../features/tickets/screens/ticket_detail_screen.dart';
import '../features/tickets/screens/ticket_list_screen.dart';
import '../features/organizer/screens/attendee_list_screen.dart';
import '../features/organizer/screens/event_form_screen.dart';
import '../features/organizer/screens/event_management_screen.dart';
import '../features/organizer/screens/organizer_profile_screen.dart';
import '../features/organizer/screens/staff_management_screen.dart';
import '../features/organizer/shell/access_denied_screen.dart';
import '../features/organizer/support/organizer_support_screen.dart';
import '../features/organizer/membership/team_management_screen.dart';
import '../features/organizer/operations/organizer_scanner_screen.dart';
import '../features/organizer/plans/subscription_screen.dart';
import '../features/scanner/screens/scan_result_screen.dart';
import '../features/staff/screens/staff_dashboard_screen.dart';
import '../services/organizer_operations/organizer_permission.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return _materialRoute(const HomeScreen(), settings);

      case AppRoutes.eventList:
        return _materialRoute(const EventListScreen(), settings);

      case AppRoutes.eventDetail:
        final eventId = settings.arguments as String?;
        return _materialRoute(EventDetailScreen(eventId: eventId), settings);

      case AppRoutes.registration:
        final eventId = settings.arguments as String?;
        return _materialRoute(RegistrationScreen(eventId: eventId), settings);

      case AppRoutes.ticketSelection:
        final eventId = settings.arguments as String?;
        return _materialRoute(
          TicketSelectionScreen(eventId: eventId),
          settings,
        );

      case AppRoutes.attendeeForm:
        final eventId = settings.arguments as String?;
        return _materialRoute(AttendeeFormScreen(eventId: eventId), settings);

      case AppRoutes.payment:
        final orderId = settings.arguments as String?;
        return _materialRoute(PaymentScreen(orderId: orderId), settings);

      case AppRoutes.paymentStatus:
        final orderId = settings.arguments as String?;
        return _materialRoute(PaymentStatusScreen(orderId: orderId), settings);

      case AppRoutes.orderList:
        return _materialRoute(const OrderListScreen(), settings);

      case AppRoutes.orderDetail:
        final orderId = settings.arguments as String?;
        return _materialRoute(OrderDetailScreen(orderId: orderId), settings);

      case AppRoutes.ticketList:
        return _materialRoute(const TicketListScreen(), settings);

      case AppRoutes.ticketDetail:
        final ticketId = settings.arguments as String?;
        return _materialRoute(TicketDetailScreen(ticketId: ticketId), settings);

      case AppRoutes.reportList:
        return _materialRoute(const ReportListScreen(), settings);

      case AppRoutes.reportForm:
        return _materialRoute(const ReportFormScreen(), settings);

      case AppRoutes.reportStatus:
        final ticketNumber = settings.arguments as String?;
        return _materialRoute(
          ReportStatusScreen(ticketNumber: ticketNumber),
          settings,
        );

      case AppRoutes.notificationList:
        return _materialRoute(const NotificationListScreen(), settings);

      case AppRoutes.organizerProfile:
        return _materialRoute(const OrganizerProfileScreen(), settings);

      case AppRoutes.profileEdit:
        return _materialRoute(const ProfileEditScreen(), settings);

      case AppRoutes.organizerEvents:
        return _materialRoute(const EventManagementScreen(), settings);

      case AppRoutes.organizerEventForm:
        final eventId = settings.arguments as String?;
        return _materialRoute(EventFormScreen(eventId: eventId), settings);

      case AppRoutes.organizerAttendees:
        final eventId = settings.arguments as String? ?? 'evt-001';
        return _materialRoute(AttendeeListScreen(eventId: eventId), settings);

      case AppRoutes.organizerStaff:
        final eventId = settings.arguments as String? ?? 'evt-001';
        return _materialRoute(
          StaffManagementScreen(eventId: eventId),
          settings,
        );

      case AppRoutes.organizerPlans:
        return _materialRoute(const SubscriptionScreen(), settings);

      case AppRoutes.organizerSupport:
        return _materialRoute(const OrganizerSupportScreen(), settings);

      case AppRoutes.organizerTeam:
        return _materialRoute(const TeamManagementScreen(), settings);

      case AppRoutes.staffDashboard:
        return _materialRoute(const StaffDashboardScreen(), settings);

      case AppRoutes.staffScanner:
        return _materialRoute(
          OrganizerScannerScreen(
            eventId: 'evt-001',
            contextScope: OrganizerMembershipContext.owner(eventId: 'evt-001'),
          ),
          settings,
        );

      case AppRoutes.staffScanResult:
        return _materialRoute(
          const ScanResultScreen(result: <String, dynamic>{}),
          settings,
        );

      case AppRoutes.checkInHistory:
        return _materialRoute(const CheckInHistoryScreen(), settings);

      case AppRoutes.adminProfile:
        return _materialRoute(const AccountManagementScreen(), settings);

      case AppRoutes.adminEventModeration:
        return _materialRoute(const EventModerationScreen(), settings);

      case AppRoutes.adminReports:
        return _materialRoute(const ReportManagementScreen(), settings);

      case AppRoutes.accessDenied:
        return _materialRoute(const AccessDeniedScreen(), settings);

      case AppRoutes.splash:
      case AppRoutes.organizerPlanTransactions:
      case AppRoutes.organizerSupportNew:
      case AppRoutes.staffAssignedEvents:
        return null;

      default:
        return null;
    }
  }

  static MaterialPageRoute<dynamic> _materialRoute(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
      fullscreenDialog: false,
    );
  }
}
