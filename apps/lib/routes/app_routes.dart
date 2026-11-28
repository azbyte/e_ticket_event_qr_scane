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
  static const String organizerScan = '/organizer/scan';
  static const String organizerProfile = '/organizer/profile';
  static const String profileEdit = '/profile/edit';
  static const String adminProfile = '/admin/profile';
  static const String organizerEvents = '/organizer/events';
  static const String organizerEventCreate = '/organizer/events/create';
  static const String organizerEventDetail = '/organizer/events/:id';
  static const String organizerEventForm = '/organizer/events/:id/edit';
  static const String organizerAttendees = '/organizer/events/:id/attendees';
  static const String organizerOrders = '/organizer/events/:id/orders';
  static const String organizerEventScanner = '/organizer/events/:id/scanner';
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
  static const String adminAccounts = '/admin/accounts';
  static const String adminEventModeration = '/admin/events';
  static const String adminReports = '/admin/reports';
  static const String adminPackages = '/admin/packages';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminTransactions = '/admin/transactions';
  static const String adminSettings = '/admin/settings';
  static const String adminAuditLog = '/admin/audit-log';

  // Organizer extensions (FR-60-65, FR-76-79, FR-95-96)
  static const String organizerPlans = '/organizer/plans';
  static const String organizerPlanTransactions =
      '/organizer/plans/transactions';
  static const String organizerSupport = '/organizer/support';
  static const String organizerSupportNew = '/organizer/support/new';
  static const String organizerTeam = '/organizer/team';
  static const String staffAssignedEvents = '/staff/events';
  static const String accessDenied = '/access-denied';

  // ---------------------------------------------------------------
  // Route publik (D1-1) — dapat diakses tanpa login.
  // ---------------------------------------------------------------
  static const String publicEvent = '/e/:eventId';
  static const String publicEventRegister = '/e/:eventId/register';
  static const String publicEventOrder = '/e/:eventId/order/:orderId';
  static const String publicEventPayment = '/e/:eventId/payment/:orderId';
  static const String publicEventTicket = '/e/:eventId/ticket/:ticketId';

  /// Penerimaan undangan panitia: login lalu kembali ke halaman ini.
  static const String invitationAccept = '/invite/:token';

  /// Akses staf berbasis kode akses: tautan undangan (publik) dan scanner
  /// ber-sesi staf. Keduanya tidak memerlukan akun Organizer/Admin.
  static const String staffAccess = '/staff-access/:invitationId';
  static const String staffScannerAccess = '/staff-access/scanner';

  /// Workspace staf untuk satu event.
  static const String staffWorkspace = '/staff/:eventId';

  static String publicEventPath(String eventId) => '/e/$eventId';

  static String publicEventRegisterPath(String eventId) =>
      '/e/$eventId/register';

  static String publicEventPaymentPath(String eventId, String orderId) =>
      '/e/$eventId/payment/$orderId';

  static String publicEventTicketPath(String eventId, String ticketId) =>
      '/e/$eventId/ticket/$ticketId';

  static String invitationAcceptPath(String token) => '/invite/$token';

  static String staffAccessPath(String invitationId) =>
      '/staff-access/$invitationId';

  static String staffWorkspacePath(String eventId) => '/staff/$eventId';

  static String organizerEventAttendeesPath(String eventId) =>
      '/organizer/events/$eventId/attendees';

  static String organizerEventOrdersPath(String eventId) =>
      '/organizer/events/$eventId/orders';

  static String organizerEventScannerPath(String eventId) =>
      '/organizer/events/$eventId/scanner';

  static String organizerEventStaffPath(String eventId) =>
      '/organizer/events/$eventId/staff';

  static String organizerEventEditPath(String eventId) =>
      '/organizer/events/$eventId/edit';
}
