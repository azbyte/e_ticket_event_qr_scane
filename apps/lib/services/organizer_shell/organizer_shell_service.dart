/// Organizer shell and dashboard aggregation service (FR-66).
///
/// Collects and summarizes organizer-owned metrics (gross sales, tickets sold,
/// pending orders, check-in counts, moderation alerts) without exposing platform revenue.
library;

import '../../core/config/app_config.dart';

class OrganizerDashboardMetrics {
  final int totalEvents;
  final int draftEvents;
  final int pendingReviewEvents;
  final int publishedEvents;
  final int totalTicketsSold;
  final int pendingOrders;
  final int attendeesCheckedIn;
  final double grossSales; // Own-event gross sales, NOT platform revenue
  final double checkInRate;
  final List<Map<String, dynamic>> recentEvents;
  final List<String> moderationAlerts;

  const OrganizerDashboardMetrics({
    required this.totalEvents,
    required this.draftEvents,
    required this.pendingReviewEvents,
    required this.publishedEvents,
    required this.totalTicketsSold,
    required this.pendingOrders,
    required this.attendeesCheckedIn,
    required this.grossSales,
    required this.checkInRate,
    required this.recentEvents,
    required this.moderationAlerts,
  });
}

class OrganizerShellService {
  OrganizerShellService._internal();
  static final OrganizerShellService instance = OrganizerShellService._internal();
  factory OrganizerShellService() => instance;

  static const OrganizerDashboardMetrics _mockMetrics = OrganizerDashboardMetrics(
    totalEvents: 3,
    draftEvents: 1,
    pendingReviewEvents: 1,
    publishedEvents: 1,
    totalTicketsSold: 205,
    pendingOrders: 12,
    attendeesCheckedIn: 156,
    grossSales: 58500000.0, // Organizer gross ticket revenue
    checkInRate: 0.76,
    moderationAlerts: [
      'Event "Workshop Flutter & Backend Modern" sedang menunggu moderasi admin platform.',
    ],
    recentEvents: [
      {
        'id': 'evt-001',
        'title': 'Tech Innovation Summit 2026',
        'category': 'Teknologi',
        'status': 'published',
        'start_date': '14 Nov 2026',
        'tickets_sold': 205,
        'location': 'Grand Ballroom Hotel Indonesia',
      },
      {
        'id': 'evt-002',
        'title': 'Workshop Flutter & Backend Modern',
        'category': 'Edukasi',
        'status': 'pending_review',
        'start_date': '21 Nov 2026',
        'tickets_sold': 30,
        'location': 'Auditorium Fasilkom UI',
      },
      {
        'id': 'evt-003',
        'title': 'Festival Musik Indie Nusantara',
        'category': 'Seni & Musik',
        'status': 'draft',
        'start_date': '30 Des 2026',
        'tickets_sold': 0,
        'location': 'GBK Park Jakarta',
      },
    ],
  );

  /// Loads aggregated dashboard metrics for an organizer.
  Future<OrganizerDashboardMetrics> getDashboardMetrics(String organizerId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _mockMetrics;
    }
    return _mockMetrics;
  }
}

