/// App Router for the E-Ticket Event QR Scanner application.
/// Generates routes based on the AppRoutes constants.
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.initial:
        return _buildPageRoute(settings, const AuthWrapper());
      case AppRoutes.login:
        return _buildPageRoute(settings, const LoginScreen());
      case AppRoutes.register:
        return _buildPageRoute(settings, const RegisterScreen());
      case AppRoutes.home:
        return _buildPageRoute(settings, const HomeScreen());
      case AppRoutes.eventList:
        return _buildPageRoute(settings, const EventListScreen());
      case AppRoutes.eventDetail:
        return _buildPageRoute(settings, EventDetailScreen(eventId: settings.parameters['id']!));
      case AppRoutes.ticketList:
        return _buildPageRoute(settings, const TicketListScreen());
      case AppRoutes.ticketDetail:
        return _buildPageRoute(settings, TicketDetailScreen(ticketId: settings.parameters['id']!));
      case AppRoutes.organizerDashboard:
        return _buildPageRoute(settings, const OrganizerDashboardScreen());
      case AppRoutes.organizerEvents:
        return _buildPageRoute(settings, const OrganizerEventsScreen());
      case AppRoutes.staffDashboard:
        return _buildPageRoute(settings, const StaffDashboardScreen());
      case AppRoutes.staffScanner:
        return _buildPageRoute(settings, const StaffScannerScreen());
      case AppRoutes.checkInHistory:
        return _buildPageRoute(settings, const CheckInHistoryScreen());
      case AppRoutes.adminDashboard:
        return _buildPageRoute(settings, const AdminDashboardScreen());
      case AppRoutes.adminEventModeration:
        return _buildPageRoute(settings, const AdminEventModerationScreen());
      case AppRoutes.adminReports:
        return _buildPageRoute(settings, const AdminReportsScreen());
      case AppRoutes.reportList:
        return _buildPageRoute(settings, const ReportListScreen());
      case AppRoutes.reportForm:
        return _buildPageRoute(settings, const ReportFormScreen());
      default:
        return _buildPageRoute(settings, const Scaffold(
          body: Center(child: Text('Route not implemented')),
        ));
    }
  }

  static MaterialPageRoute _buildPageRoute(RouteSettings settings, Widget page) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }
}