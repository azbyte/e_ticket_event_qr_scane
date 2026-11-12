import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_edit_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/admin/screens/account_management_screen.dart';
import 'features/admin/screens/admin_profile_screen.dart';
import 'features/admin/screens/admin_settings_screen.dart';
import 'features/admin/screens/audit_log_screen.dart';
import 'features/admin/screens/event_moderation_screen.dart';
import 'features/admin/screens/package_management_screen.dart';
import 'features/admin/screens/report_management_screen.dart';
import 'features/admin/screens/subscription_management_screen.dart';
import 'features/admin/screens/transaction_revenue_screen.dart';
import 'features/admin/tabs/admin_tab_controller.dart';
import 'features/events/screens/event_detail_screen.dart';
import 'features/events/screens/event_list_screen.dart';
import 'features/organizer/membership/team_management_screen.dart';
import 'features/organizer/plans/subscription_screen.dart';
import 'features/organizer/events/screens/organizer_event_detail_screen.dart';
import 'features/organizer/screens/attendee_list_screen.dart';
import 'features/organizer/screens/event_form_screen.dart';
import 'features/organizer/screens/event_management_screen.dart';
import 'features/organizer/screens/organizer_profile_screen.dart';
import 'features/organizer/screens/staff_management_screen.dart';
import 'features/organizer/operations/organizer_scanner_screen.dart';
import 'features/organizer/shell/access_denied_screen.dart';
import 'features/organizer/support/organizer_support_screen.dart';
import 'services/organizer_operations/organizer_permission.dart';
import 'features/staff/screens/staff_dashboard_screen.dart';
import 'features/tickets/screens/ticket_detail_screen.dart';
import 'features/tickets/screens/ticket_list_screen.dart';
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '/');
    final path = uri?.path ?? '/';
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final args = settings.arguments is Map
        ? settings.arguments as Map
        : const {};
    Widget page;

    switch (path) {
      case AppRoutes.initial:
        page = const AuthGate();
        break;
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.register:
        page = const RegisterScreen();
        break;
      case AppRoutes.profileEdit:
        page = const ProfileEditScreen();
        break;
      case AppRoutes.home:
      case AppRoutes.organizerDashboard:
        page = const RoleGuard(admin: false);
        break;
      case AppRoutes.organizerProfile:
        page = const OrganizerProfileScreen();
        break;
      case AppRoutes.organizerEvents:
        page = const EventManagementScreen();
        break;
      case AppRoutes.organizerEventCreate:
        page = const EventFormScreen();
        break;
      case AppRoutes.organizerTeam:
        page = TeamManagementScreen(
          eventId: args['eventId']?.toString() ?? 'evt-1001',
          eventTitle:
              args['eventTitle']?.toString() ?? 'Tech Innovation Summit 2026',
        );
        break;
      case AppRoutes.organizerPlans:
        page = const SubscriptionScreen();
        break;
      case AppRoutes.organizerPlanTransactions:
        page = const SubscriptionScreen(initialTab: 1);
        break;
      case AppRoutes.organizerSupport:
        page = const OrganizerSupportScreen();
        break;
      case AppRoutes.organizerSupportNew:
        page = const OrganizerSupportScreen(initialTab: 2);
        break;
      case AppRoutes.accessDenied:
        page = AccessDeniedScreen(
          reason: args['reason']?.toString(),
          returnRoute: args['returnRoute']?.toString() ?? AppRoutes.home,
        );
        break;
      case AppRoutes.staffDashboard:
      case AppRoutes.staffAssignedEvents:
      case AppRoutes.staffScanner:
      case AppRoutes.staffScanResult:
      case AppRoutes.checkInHistory:
        page = const StaffDashboardScreen();
        break;
      case AppRoutes.adminDashboard:
        page = const AdminTabController();
        break;
      case AppRoutes.adminEventModeration:
        page = const EventModerationScreen();
        break;
      case AppRoutes.adminAccounts:
        page = const AccountManagementScreen();
        break;
      case AppRoutes.adminReports:
        page = const ReportManagementScreen();
        break;
      case AppRoutes.adminPackages:
        page = const PackageManagementScreen();
        break;
      case AppRoutes.adminSubscriptions:
        page = const SubscriptionManagementScreen();
        break;
      case AppRoutes.adminTransactions:
        page = const TransactionRevenueScreen();
        break;
      case AppRoutes.adminSettings:
        page = const AdminSettingsScreen();
        break;
      case AppRoutes.adminAuditLog:
        page = const AuditLogScreen();
        break;
      case AppRoutes.adminProfile:
        page = const AdminProfileScreen();
        break;
      case AppRoutes.eventList:
        page = const EventListScreen();
        break;
      case AppRoutes.ticketList:
        page = const TicketListScreen();
        break;
      default:
        if (parts.length == 2 && parts[0] == 'events') {
          page = EventDetailScreen(eventId: parts[1]);
        } else if (parts.length == 2 && parts[0] == 'tickets') {
          page = TicketDetailScreen(ticketId: parts[1]);
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'edit') {
          page = EventFormScreen(eventId: parts[2]);
        } else if (parts.length == 3 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events') {
          page = OrganizerEventDetailScreen(eventId: parts[2]);
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'staff') {
          page = StaffManagementScreen(
            eventId: parts[2],
            eventName: args['eventName']?.toString() ?? 'Event',
          );
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'attendees') {
          page = const AttendeeListScreen();
        } else if (parts.length == 4 &&
            parts[0] == 'organizer' &&
            parts[1] == 'events' &&
            parts[3] == 'scanner') {
          page = OrganizerScannerScreen(
            eventId: parts[2],
            contextScope: OrganizerMembershipContext.owner(
              userId: 'usr-org-001',
              userName: 'Penyelenggara Tech (Owner)',
              eventId: parts[2],
            ),
          );
        } else if (parts.length >= 2 && parts.first == 'admin') {
          page = const RoleGuard(admin: true);
        } else if (parts.length >= 2 && parts.first == 'organizer') {
          page = const RoleGuard(admin: false);
        } else {
          page = const Scaffold(
            body: Center(child: Text('Halaman tidak ditemukan')),
          );
        }
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        final auth = context.read<AuthProvider>();
        final role = auth.user?.role.name;
        final adminRoute =
            path == AppRoutes.adminDashboard || path.startsWith('/admin/');
        final organizerRoute =
            path == AppRoutes.organizerDashboard ||
            path.startsWith('/organizer/');

        // Public / non-auth routes
        if (path == AppRoutes.initial ||
            path == AppRoutes.login ||
            path == AppRoutes.register ||
            path == AppRoutes.accessDenied) {
          if ((path == AppRoutes.login || path == AppRoutes.register) &&
              auth.isAuthenticated) {
            return role == 'admin'
                ? const RoleGuard(admin: true)
                : const RoleGuard(admin: false);
          }
          return page;
        }

        // Must be authenticated for other routes
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Admin route guard
        if (adminRoute && role != 'admin') {
          return AccessDeniedScreen(
            reason: 'Halaman ini khusus untuk Administrator Platform.',
            returnRoute: _homeRouteForRole(role),
          );
        }

        // Organizer route guard
        if (organizerRoute && role != 'organizer') {
          return AccessDeniedScreen(
            reason: 'Halaman ini khusus untuk Penyelenggara Acara (Organizer).',
            returnRoute: _homeRouteForRole(role),
          );
        }

        return page;
      },
    );
  }

  static String _homeRouteForRole(String? role) => switch (role) {
    'admin' => AppRoutes.adminDashboard,
    'organizer' => AppRoutes.organizerDashboard,
    'staff' => AppRoutes.staffDashboard,
    _ => AppRoutes.eventList,
  };
}
