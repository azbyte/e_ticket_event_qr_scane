/// Organizer shell and dashboard aggregation service (FR-66).
///
/// Dashboard values are derived from the same local event repository used by
/// Event Management; they are not platform revenue or backend data.
library;

import 'package:flutter/foundation.dart';

import '../organizer_events/organizer_event_contract.dart';
import '../organizer_events/organizer_event_repository.dart';
import '../organizer_events/mock_organizer_event_repository.dart';

class OrganizerDashboardMetrics {
  final int totalEvents;
  final int draftEvents;
  final int pendingReviewEvents;
  final int revisionEvents;
  final int publishedEvents;
  final int totalTicketsSold;
  final int pendingOrders;
  final int totalParticipants;
  final int attendeesCheckedIn;
  final double grossSales;
  final double checkInRate;
  final List<Map<String, dynamic>> recentEvents;
  final List<String> moderationAlerts;

  const OrganizerDashboardMetrics({
    required this.totalEvents,
    required this.draftEvents,
    required this.pendingReviewEvents,
    required this.revisionEvents,
    required this.publishedEvents,
    required this.totalTicketsSold,
    required this.pendingOrders,
    required this.totalParticipants,
    required this.attendeesCheckedIn,
    required this.grossSales,
    required this.checkInRate,
    required this.recentEvents,
    required this.moderationAlerts,
  });
}

class OrganizerShellService {
  OrganizerShellService._(this._repository);

  static final OrganizerShellService instance = OrganizerShellService._(
    MockOrganizerEventRepository.shared(),
  );

  @Deprecated('Use OrganizerShellService.instance in the Organizer UI.')
  factory OrganizerShellService() => instance;

  @visibleForTesting
  OrganizerShellService.forRepository(OrganizerEventRepository repository)
    : _repository = repository;

  final OrganizerEventRepository _repository;

  /// Loads a local summary for events owned by [organizerId].
  Future<OrganizerDashboardMetrics> getDashboardMetrics(
    String organizerId,
  ) async {
    final events = await _repository.listEvents(ownerId: organizerId);
    final summaries = await _repository.eventSummaries(ownerId: organizerId);
    final overview = await _repository.overview(ownerId: organizerId);

    return OrganizerDashboardMetrics(
      totalEvents: events.length,
      draftEvents: overview.draftCount,
      pendingReviewEvents: overview.pendingReviewCount,
      revisionEvents: overview.revisionCount,
      publishedEvents: overview.publishedCount,
      totalTicketsSold: overview.ticketsSold,
      pendingOrders: overview.pendingOrders,
      totalParticipants: overview.participants,
      attendeesCheckedIn: overview.checkedIn,
      grossSales: overview.grossSales,
      checkInRate: overview.participants == 0
          ? 0
          : overview.checkedIn / overview.participants,
      recentEvents: overview.recentEvents
          .map((event) {
            final summary = summaries[event.id];
            return <String, dynamic>{
              'id': event.id,
              'title': event.title,
              'category': event.category ?? '',
              'status': event.status,
              'start_date': event.startDateTime
                  .toLocal()
                  .toString()
                  .split(' ')
                  .first,
              'tickets_sold': summary?.ticketsSold ?? 0,
              'participants': summary?.participants ?? 0,
              'location': event.location ?? event.onlineUrl ?? '-',
            };
          })
          .toList(growable: false),
      moderationAlerts: events
          .where(
            (event) =>
                event.status == OrganizerEventStatus.pendingReview ||
                event.status == OrganizerEventStatus.revisionRequested ||
                event.status == OrganizerEventStatus.rejected,
          )
          .map((event) {
            final note = event.reviewNote;
            return note == null || note.trim().isEmpty
                ? 'Event "${event.title}" berstatus ${event.statusLabel}.'
                : 'Event "${event.title}": $note';
          })
          .toList(growable: false),
    );
  }
}
