/// Named route constants for the application.
///
/// Centralizing route names avoids typos and makes navigation consistent
/// across roles (attendee, organizer, staff, admin).
class AppRoutes {
  AppRoutes._();

  static const String initial = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String eventList = '/events';
  static const String eventDetail = '/events/:id';
  static const String registration = '/registration/:eventId';
  static const String ticketSelection = '/registration/:eventId/tickets';
  static const String attendeeForm = '/registration/:eventId/attendee';
  static const String payment = '/payment/:orderId';
  static const String paymentStatus = '/payment/:orderId/status';
  static const String orderList = '/orders';
  static const String orderDetail = '/orders/:id';
  static const String ticketList = '/tickets';
  static const String ticketDetail = '/tickets/:id';
  static const String organizerDashboard = '/organizer';
  static const String organizerEvents = '/organizer/events';
  static const String organizerEventForm = '/organizer/events/:id/edit';
  static const String organizerAttendees = '/organizer/events/:id/attendees';
  static const String organizerStaff = '/organizer/events/:id/staff';
  static const String staffDashboard = '/staff';
  static const String staffScanner = '/staff/scanner';
  static const String staffScanResult = '/staff/scanner/result';
  static const String checkInHistory = '/staff/check-ins';
  static const String reportList = '/reports';
  static const String reportForm = '/reports/new';
  static const String reportStatus = '/reports/:ticketNumber/status';
  static const String notificationList = '/notifications';
  static const String adminDashboard = '/admin';
  static const String adminEventModeration = '/admin/events';
  static const String adminReports = '/admin/reports';
}
