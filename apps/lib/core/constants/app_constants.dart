/// Constants shared across the application (roles, statuses, limits).
///
/// These mirror the business statuses defined in PRD section 6. They are kept
/// in sync with the backend once the API contract is finalized.
class AppConstants {
  AppConstants._();

  // ----------------------------------------------------------------
  // User roles (PRD section 2)
  // ----------------------------------------------------------------
  static const String roleAttendee = 'attendee';
  static const String roleOrganizer = 'organizer';
  static const String roleStaff = 'staff';
  static const String roleAdmin = 'admin';

  // ----------------------------------------------------------------
  // Event statuses (PRD section 6.1)
  // ----------------------------------------------------------------
  static const String eventStatusDraft = 'draft';
  static const String eventStatusPendingReview = 'pending_review';
  static const String eventStatusRevisionRequired = 'revision_required';
  static const String eventStatusApproved = 'approved';
  static const String eventStatusPublished = 'published';
  static const String eventStatusRejected = 'rejected';
  static const String eventStatusCompleted = 'completed';
  static const String eventStatusCancelled = 'cancelled';

  // ----------------------------------------------------------------
  // Order statuses (PRD section 6.2)
  // ----------------------------------------------------------------
  static const String orderStatusPendingPayment = 'pending_payment';
  static const String orderStatusPaid = 'paid';
  static const String orderStatusExpired = 'expired';
  static const String orderStatusCancelled = 'cancelled';

  // ----------------------------------------------------------------
  // Ticket statuses (PRD section 6.3)
  // ----------------------------------------------------------------
  static const String ticketStatusValid = 'valid';
  static const String ticketStatusCheckedIn = 'checked_in';
  static const String ticketStatusCancelled = 'cancelled';
  static const String ticketStatusRevoked = 'revoked';

  // ----------------------------------------------------------------
  // Payment statuses
  // ----------------------------------------------------------------
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusExpired = 'expired';

  // ----------------------------------------------------------------
  // Support report statuses (PRD section 4.10)
  // ----------------------------------------------------------------
  static const String reportStatusOpen = 'open';
  static const String reportStatusInProgress = 'in_progress';
  static const String reportStatusWaitingForUser = 'waiting_for_user';
  static const String reportStatusResolved = 'resolved';
  static const String reportStatusClosed = 'closed';

  // ----------------------------------------------------------------
  // Miscellaneous limits
  // ----------------------------------------------------------------
  static const int maxTicketsPerOrder = 10;
  static const int defaultPageSize = 20;
}
