import '../../core/errors/app_exception.dart';
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import '../api/api_service.dart';
import 'organizer_event_contract.dart';
import 'organizer_event_exceptions.dart';
import 'organizer_event_repository.dart';
import 'organizer_event_validators.dart';

class ApiOrganizerEventRepository implements OrganizerEventRepository {
  ApiOrganizerEventRepository({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  @override
  void bindActivityLogger(OrganizerEventActivityLogger logger) {}

  @override
  Future<List<EventModel>> listEvents({
    required String ownerId,
    String search = '',
    OrganizerEventFilter filter = OrganizerEventFilter.all,
  }) => _request(() async {
    final response = await _api.get(
      '/events/mine',
      query: search.trim().isEmpty ? null : {'q': search.trim()},
    );
    return _eventList(
      response,
      'events',
    ).where((event) => filter.matches(event.status)).toList(growable: false);
  });

  @override
  Future<List<EventModel>> listPlatformEvents({
    String search = '',
    OrganizerEventFilter filter = OrganizerEventFilter.all,
  }) => _request(() async {
    final response = await _api.get('/events');
    return _eventList(response, 'events')
        .where((event) => filter.matches(event.status))
        .where((event) => _matchesSearch(event, search))
        .toList(growable: false);
  });

  @override
  Future<EventModel> simulatePlatformModeration({
    required String eventId,
    required String status,
    String? note,
  }) => _request(() async {
    final response = await _api.put(
      '/admin/events/$eventId/moderation',
      body: {'status': _statusToApi(status), 'note': note},
    );
    return _event(response, 'event');
  });

  @override
  Future<EventModel> getEvent({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    final response = await _api.get('/events/$eventId');
    return _event(response, 'event');
  });

  @override
  Future<EventModel> createEvent({
    required String ownerId,
    required OrganizerEventDraft draft,
  }) => _request(() async {
    _validateDraft(draft);
    final response = await _api.post('/events', body: _eventPayload(draft));
    return _event(response, 'event');
  });

  @override
  Future<EventModel> updateEvent({
    required String ownerId,
    required String eventId,
    required OrganizerEventDraft draft,
  }) => _request(() async {
    _validateDraft(draft);
    final response = await _api.put(
      '/events/$eventId',
      body: _eventPayload(draft),
    );
    return _event(response, 'event');
  });

  @override
  Future<void> deleteEvent({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    await _api.delete('/events/$eventId');
  });

  @override
  Future<EventModel> submitForReview({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    final response = await _api.post('/events/$eventId/submit-review');
    return _event(response, 'event');
  });

  @override
  Future<EventModel> resubmitForReview({
    required String ownerId,
    required String eventId,
  }) => submitForReview(ownerId: ownerId, eventId: eventId);

  @override
  Future<EventModel> simulateModeratorDecision({
    required String ownerId,
    required String eventId,
    required OrganizerModerationDecision decision,
    String? note,
  }) => _request(() async {
    final status = switch (decision) {
      OrganizerModerationDecision.approve => OrganizerEventStatus.approved,
      OrganizerModerationDecision.requestRevision =>
        OrganizerEventStatus.revisionRequested,
      OrganizerModerationDecision.reject => OrganizerEventStatus.rejected,
    };
    final response = await _api.put(
      '/admin/events/$eventId/moderation',
      body: {'status': _statusToApi(status), 'note': note},
    );
    return _event(response, 'event');
  });

  @override
  Future<List<TicketTypeModel>> listTicketTypes({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    final response = await _api.get('/events/$eventId/ticket-types');
    return _ticketTypeList(response, 'ticketTypes');
  });

  @override
  Future<TicketTypeModel> createTicketType({
    required String ownerId,
    required String eventId,
    required OrganizerTicketTypeDraft draft,
  }) => _request(() async {
    _validateTicketTypeDraft(draft);
    final response = await _api.post(
      '/events/$eventId/ticket-types',
      body: _ticketTypePayload(draft),
    );
    return _ticketType(response, 'ticketType');
  });

  @override
  Future<TicketTypeModel> updateTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required OrganizerTicketTypeDraft draft,
  }) => _request(() async {
    _validateTicketTypeDraft(draft);
    final response = await _api.put(
      '/events/$eventId/ticket-types/$ticketTypeId',
      body: _ticketTypePayload(draft),
    );
    return _ticketType(response, 'ticketType');
  });

  @override
  Future<void> deleteTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
  }) => _request(() async {
    await _api.delete('/events/$eventId/ticket-types/$ticketTypeId');
  });

  @override
  Future<TicketTypeModel> setTicketTypeActive({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required bool isActive,
  }) => _request(() async {
    final response = await _api.put(
      '/events/$eventId/ticket-types/$ticketTypeId',
      body: {'is_active': isActive},
    );
    return _ticketType(response, 'ticketType');
  });

  @override
  Future<OrganizerEventSummary> eventSummary({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    final response = await _api.get('/events/$eventId/summary');
    final summary = _requiredMap(response, 'summary');
    return _summaryFromJson(eventId, summary);
  });

  @override
  Future<Map<String, OrganizerEventSummary>> eventSummaries({
    required String ownerId,
  }) => _request(() async {
    final response = await _api.get('/organizer/events/summaries');
    final rows = _requiredList(response, 'summaries');
    final summaries = <String, OrganizerEventSummary>{};
    for (final row in rows) {
      if (row is! Map || row['event_id'] == null) {
        throw const FormatException('Invalid event summary entry.');
      }
      final eventId = row['event_id'].toString();
      summaries[eventId] = _summaryFromJson(eventId, _map(row));
    }
    return summaries;
  });

  @override
  Future<List<OrganizerEventSalesPoint>> salesPoints({
    required String ownerId,
    required String eventId,
  }) => _request(() async {
    final response = await _api.get('/events/$eventId/sales');
    return _requiredList(response, 'points')
        .map((row) {
          final point = _map(row);
          final date = DateTime.tryParse(point['date']?.toString() ?? '');
          if (date == null) {
            throw const FormatException('Invalid sales point date.');
          }
          return OrganizerEventSalesPoint(
            date: date,
            tickets: _intValue(point['tickets']),
            checkIns: _intValue(point['check_ins']),
          );
        })
        .toList(growable: false);
  });

  @override
  Future<OrganizerOverview> overview({required String ownerId}) =>
      _request(() async {
        final response = await _api.get('/organizer/overview');
        final data = _requiredMap(response, 'overview');
        final recent = _requiredList(data, 'recent_events');
        return OrganizerOverview(
          draftCount: _intValue(data['draft_count']),
          pendingReviewCount: _intValue(data['pending_review_count']),
          revisionCount: _intValue(data['revision_count']),
          publishedCount: _intValue(data['published_count']),
          ticketsSold: _intValue(data['tickets_sold']),
          pendingOrders: _intValue(data['pending_orders']),
          participants: _intValue(data['participants']),
          checkedIn: _intValue(data['checked_in']),
          grossSales: _doubleValue(data['gross_sales']),
          recentEvents: recent
              .map((row) => EventModel.fromJson(_map(row)))
              .toList(),
        );
      });

  static Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException catch (error) {
      if (error.statusCode == 403) {
        throw OrganizerEventAccessDeniedException(error.message);
      }
      if (error.statusCode == 404) {
        throw OrganizerEventNotFoundException(error.message);
      }
      throw OrganizerEventException(error.message);
    } on FormatException catch (error) {
      throw OrganizerEventException(
        'Respons API event tidak valid: ${error.message}',
      );
    }
  }

  static void _validateDraft(OrganizerEventDraft draft) {
    final errors = OrganizerEventValidators.validateEventDraft(draft);
    if (errors.isNotEmpty) throw OrganizerEventValidationException(errors);
  }

  static void _validateTicketTypeDraft(OrganizerTicketTypeDraft draft) {
    final errors = OrganizerEventValidators.validateTicketTypeDraft(draft);
    if (errors.isNotEmpty) throw OrganizerEventValidationException(errors);
  }

  static Map<String, dynamic> _eventPayload(OrganizerEventDraft draft) => {
    'title': draft.title.trim(),
    'description': _trimToNull(draft.description),
    'poster_url': _trimToNull(draft.posterUrl),
    'category': draft.category,
    'event_date': draft.startDateTime.toIso8601String(),
    'end_date_time': draft.endDateTime.toIso8601String(),
    'time_zone': draft.timeZone,
    'location': _trimToNull(draft.location),
    'online_url': _trimToNull(draft.onlineUrl),
    'event_format': draft.format.toUpperCase(),
    'contact_info': draft.contactInfo.trim(),
    'organizer_name': draft.organizerName.trim(),
    'public_info': _trimToNull(draft.publicInfo),
    'attendee_fields': draft.attendeeFields,
  };

  static Map<String, dynamic> _ticketTypePayload(
    OrganizerTicketTypeDraft draft,
  ) => {
    'name': draft.name.trim(),
    'description': _trimToNull(draft.description),
    'price': draft.price,
    'quota': draft.quota,
    'max_per_order': draft.maxPerOrder,
    'sales_start': draft.salesStart?.toIso8601String(),
    'sales_end': draft.salesEnd?.toIso8601String(),
    'is_active': draft.isActive,
  };

  static OrganizerEventSummary _summaryFromJson(
    String eventId,
    Map<String, dynamic> json,
  ) => OrganizerEventSummary(
    eventId: eventId,
    status: _statusFromApi(json['status']?.toString()),
    ticketsSold: _intValue(json['tickets_sold']),
    ticketsRemaining: _intValue(json['tickets_remaining']),
    pendingOrders: _intValue(json['pending_orders']),
    participants: _intValue(json['participants']),
    checkedIn: _intValue(json['checked_in']),
    grossSales: _doubleValue(json['gross_sales']),
  );

  static List<EventModel> _eventList(
    Map<String, dynamic> response,
    String key,
  ) => _requiredList(
    response,
    key,
  ).map((row) => EventModel.fromJson(_map(row))).toList(growable: false);

  static EventModel _event(Map<String, dynamic> response, String key) =>
      EventModel.fromJson(_requiredMap(response, key));

  static List<TicketTypeModel> _ticketTypeList(
    Map<String, dynamic> response,
    String key,
  ) => _requiredList(
    response,
    key,
  ).map((row) => TicketTypeModel.fromJson(_map(row))).toList(growable: false);

  static TicketTypeModel _ticketType(
    Map<String, dynamic> response,
    String key,
  ) => TicketTypeModel.fromJson(_requiredMap(response, key));

  static List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('Missing API list "$key".');
    return value;
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! Map) throw FormatException('Missing API object "$key".');
    return _map(value);
  }

  static Map<String, dynamic> _map(Map value) =>
      Map<String, dynamic>.from(value);

  static bool _matchesSearch(EventModel event, String search) {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      event.title,
      event.location ?? '',
      event.category ?? '',
      event.organizerName ?? '',
    ].any((value) => value.toLowerCase().contains(query));
  }

  static String _statusToApi(String status) => switch (status) {
    OrganizerEventStatus.approved => 'APPROVED',
    OrganizerEventStatus.revisionRequested => 'REVISION_REQUESTED',
    OrganizerEventStatus.rejected => 'REJECTED',
    OrganizerEventStatus.suspended => 'SUSPENDED',
    _ => status.toUpperCase(),
  };

  static String _statusFromApi(String? status) {
    if (status == null || status.isEmpty) {
      throw const FormatException('Event status is missing.');
    }
    return status.toLowerCase();
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ??
        (throw const FormatException('Expected an integer value.'));
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ??
        (throw const FormatException('Expected a numeric value.'));
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
