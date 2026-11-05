/// Implementasi mock in-memory domain Event/TicketType (Tahap 0).
///
/// Tidak ada HTTP/backend/database: seluruh state hidup di memori proses dan
/// hilang saat aplikasi ditutup. Nilai order/peserta/check-in adalah simulasi.
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import 'organizer_event_contract.dart';
import 'organizer_event_exceptions.dart';
import 'organizer_event_fixtures.dart';
import 'organizer_event_repository.dart';
import 'organizer_event_validators.dart';

class MockOrganizerEventRepository implements OrganizerEventRepository {
  MockOrganizerEventRepository({
    List<EventModel>? events,
    List<TicketTypeModel>? ticketTypes,
    Map<String, OrganizerEventMetrics>? metrics,
    Map<String, List<OrganizerEventSalesPoint>>? salesPoints,
    this.latency = const Duration(milliseconds: 200),
    DateTime Function()? clock,
  })  : _events = List<EventModel>.from(
          events ?? OrganizerEventFixtures.seedEvents(),
        ),
        _ticketTypes = List<TicketTypeModel>.from(
          ticketTypes ?? OrganizerEventFixtures.seedTicketTypes(),
        ),
        _metrics = Map<String, OrganizerEventMetrics>.from(
          metrics ?? OrganizerEventFixtures.seedMetrics(),
        ),
        _salesPoints = Map<String, List<OrganizerEventSalesPoint>>.from(
          salesPoints ?? OrganizerEventFixtures.seedSalesPoints(),
        ),
        _clock = clock ?? DateTime.now;

  /// Repository kosong untuk demo state empty.
  factory MockOrganizerEventRepository.empty() {
    return MockOrganizerEventRepository(
      events: const <EventModel>[],
      ticketTypes: const <TicketTypeModel>[],
      metrics: const <String, OrganizerEventMetrics>{},
      salesPoints: const <String, List<OrganizerEventSalesPoint>>{},
    );
  }

  static MockOrganizerEventRepository? _shared;

  /// Instance bersama untuk alur UI nyata.
  ///
  /// Dipakai sebagai default agar event yang dibuat dari layar mana pun tetap
  /// terlihat pada daftar "Event Saya" (state in-memory yang sama). Test wajib
  /// membuat repository sendiri agar tidak berbagi state.
  factory MockOrganizerEventRepository.shared() =>
      _shared ??= MockOrganizerEventRepository();

  /// Mengosongkan instance bersama (mis. saat logout demo).
  static void resetShared() => _shared = null;

  final Duration latency;
  final DateTime Function() _clock;

  final List<EventModel> _events;
  final List<TicketTypeModel> _ticketTypes;
  final Map<String, OrganizerEventMetrics> _metrics;
  final Map<String, List<OrganizerEventSalesPoint>> _salesPoints;

  int _eventSequence = 5000;
  int _ticketSequence = 5000;

  /// Bila true, semua pembacaan gagal untuk mendemokan state error + retry.
  bool failRequests = false;

  OrganizerEventActivityLogger _logger = _noopLogger;

  static Future<void> _noopLogger(OrganizerEventActivityEntry entry) async {}

  @override
  void bindActivityLogger(OrganizerEventActivityLogger logger) {
    _logger = logger;
  }

  /// Mengosongkan/mengisi kembali flag kegagalan simulasi.
  void setFailure({required bool value}) => failRequests = value;

  @override
  Future<List<EventModel>> listEvents({
    required String ownerId,
    String search = '',
    OrganizerEventFilter filter = OrganizerEventFilter.all,
  }) async {
    await _settle();
    final keyword = search.trim().toLowerCase();
    final owned = _events
        .where((event) => event.organizerId == ownerId)
        .where((event) => filter.matches(event.status))
        .where((event) {
      if (keyword.isEmpty) return true;
      final haystack = <String?>[
        event.title,
        event.location,
        event.category,
        event.organizerName,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(keyword);
    }).toList(growable: false);

    final sorted = List<EventModel>.from(owned)
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    return sorted;
  }

  @override
  Future<EventModel> getEvent({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    return _requireOwned(ownerId, eventId);
  }

  @override
  Future<EventModel> createEvent({
    required String ownerId,
    required OrganizerEventDraft draft,
  }) async {
    await _settle();
    _throwIfInvalidDraft(draft);

    final now = _clock();
    final id = 'evt-${_eventSequence++}';
    final created = EventModel(
      id: id,
      organizerId: ownerId,
      title: draft.title.trim(),
      description: _trimToNull(draft.description),
      posterUrl: _trimToNull(draft.posterUrl),
      category: draft.category,
      startDateTime: draft.startDateTime,
      endDateTime: draft.endDateTime,
      timeZone: draft.timeZone,
      location: _trimToNull(draft.location),
      onlineUrl: _trimToNull(draft.onlineUrl),
      eventType: draft.format,
      contactInfo: draft.contactInfo.trim(),
      organizerName: draft.organizerName.trim(),
      publicInfo: _trimToNull(draft.publicInfo),
      attendeeFields: List<String>.unmodifiable(draft.attendeeFields),
      status: OrganizerEventStatus.draft,
      isPublic: false,
      createdAt: now,
      updatedAt: now,
    );
    _events.add(created);
    await _log(
      created.id,
      ownerId,
      OrganizerActivityActions.eventCreated,
      'Membuat draft event "${created.title}".',
    );
    return created;
  }

  @override
  Future<EventModel> updateEvent({
    required String ownerId,
    required String eventId,
    required OrganizerEventDraft draft,
  }) async {
    await _settle();
    final existing = _requireOwned(ownerId, eventId);
    if (!OrganizerEventStatus.isEditable(existing.status)) {
      throw OrganizerEventException(
        'Event berstatus ${existing.statusLabel} tidak dapat diubah.',
      );
    }
    _throwIfInvalidDraft(draft);

    final updated = existing.copyWith(
      title: draft.title.trim(),
      description: _trimToNull(draft.description),
      clearDescription: _trimToNull(draft.description) == null,
      posterUrl: _trimToNull(draft.posterUrl),
      clearPosterUrl: _trimToNull(draft.posterUrl) == null,
      category: draft.category,
      startDateTime: draft.startDateTime,
      endDateTime: draft.endDateTime,
      timeZone: draft.timeZone,
      location: _trimToNull(draft.location),
      clearLocation: _trimToNull(draft.location) == null,
      onlineUrl: _trimToNull(draft.onlineUrl),
      clearOnlineUrl: _trimToNull(draft.onlineUrl) == null,
      eventType: draft.format,
      contactInfo: draft.contactInfo.trim(),
      organizerName: draft.organizerName.trim(),
      publicInfo: _trimToNull(draft.publicInfo),
      attendeeFields: List<String>.unmodifiable(draft.attendeeFields),
      updatedAt: _clock(),
    );
    _replaceEvent(updated);
    await _log(
      updated.id,
      ownerId,
      OrganizerActivityActions.eventUpdated,
      'Memperbarui informasi event "${updated.title}".',
    );
    return updated;
  }

  @override
  Future<void> deleteEvent({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    final existing = _requireOwned(ownerId, eventId);
    if (!OrganizerEventStatus.canDelete(existing.status)) {
      throw OrganizerEventException(
        'Hanya event berstatus Draft yang dapat dihapus.',
      );
    }
    _events.removeWhere((event) => event.id == eventId);
    _ticketTypes.removeWhere((type) => type.eventId == eventId);
    _metrics.remove(eventId);
    _salesPoints.remove(eventId);
    await _log(
      eventId,
      ownerId,
      OrganizerActivityActions.eventDeleted,
      'Menghapus draft event "${existing.title}".',
    );
  }

  @override
  Future<EventModel> submitForReview({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    final existing = _requireOwned(ownerId, eventId);
    if (!OrganizerEventStatus.canSubmit(existing.status)) {
      throw OrganizerEventException(
        'Event berstatus ${existing.statusLabel} tidak dapat diajukan moderasi.',
      );
    }
    return _moveToPendingReview(existing, ownerId, resubmission: false);
  }

  @override
  Future<EventModel> resubmitForReview({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    final existing = _requireOwned(ownerId, eventId);
    if (!OrganizerEventStatus.canResubmit(existing.status)) {
      throw OrganizerEventException(
        'Event berstatus ${existing.statusLabel} tidak dapat diajukan ulang.',
      );
    }
    return _moveToPendingReview(existing, ownerId, resubmission: true);
  }

  @override
  Future<EventModel> simulateModeratorDecision({
    required String ownerId,
    required String eventId,
    required OrganizerModerationDecision decision,
    String? note,
  }) async {
    await _settle();
    final existing = _requireOwned(ownerId, eventId);
    if (!existing.isPendingReview) {
      throw OrganizerEventException(
        'Simulasi moderasi hanya untuk event berstatus menunggu moderasi.',
      );
    }

    final trimmedNote = _trimToNull(note);
    final moderated = switch (decision) {
      OrganizerModerationDecision.approve => existing.copyWith(
          status: OrganizerEventStatus.approved,
          isPublic: true,
          publicUrl: 'https://demo.eticket.local/e/${existing.id}',
          registrationQrUrl: 'https://demo.eticket.local/qr/${existing.id}',
          clearReviewNote: true,
          updatedAt: _clock(),
        ),
      OrganizerModerationDecision.requestRevision => existing.copyWith(
          status: OrganizerEventStatus.revisionRequested,
          reviewNote: trimmedNote ??
              'Fixture demo: moderator meminta perbaikan sebelum event tayang.',
          updatedAt: _clock(),
        ),
      OrganizerModerationDecision.reject => existing.copyWith(
          status: OrganizerEventStatus.rejected,
          reviewNote:
              trimmedNote ?? 'Fixture demo: event ditolak oleh moderator.',
          isPublic: false,
          clearPublicUrl: true,
          updatedAt: _clock(),
        ),
    };

    _replaceEvent(moderated);
    await _log(
      moderated.id,
      ownerId,
      OrganizerActivityActions.eventModerated,
      'Simulasi moderator: ${decision.label} untuk "${moderated.title}".',
    );
    return moderated;
  }

  @override
  Future<List<TicketTypeModel>> listTicketTypes({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    _requireOwned(ownerId, eventId);
    return _ticketTypes
        .where((type) => type.eventId == eventId)
        .toList(growable: false);
  }

  @override
  Future<TicketTypeModel> createTicketType({
    required String ownerId,
    required String eventId,
    required OrganizerTicketTypeDraft draft,
  }) async {
    await _settle();
    final event = _requireOwned(ownerId, eventId);
    if (!event.canBeEdited) {
      throw OrganizerTicketTypeException(
        'Kategori tiket tidak dapat ditambah saat event berstatus '
        '${event.statusLabel}.',
      );
    }
    final errors = OrganizerEventValidators.validateTicketTypeDraft(draft);
    if (errors.isNotEmpty) {
      throw OrganizerEventValidationException(errors);
    }
    _ensureUniqueTicketName(eventId, draft.name);

    final created = TicketTypeModel(
      id: 'tt-${_ticketSequence++}',
      eventId: eventId,
      name: draft.name.trim(),
      description: _trimToNull(draft.description),
      price: draft.price,
      quota: draft.quota,
      sold: 0,
      held: 0,
      maxPerOrder: draft.maxPerOrder,
      salesStart: draft.salesStart,
      salesEnd: draft.salesEnd,
      isActive: draft.isActive,
    );
    _ticketTypes.add(created);
    await _log(
      eventId,
      ownerId,
      OrganizerActivityActions.ticketTypeCreated,
      'Menambah kategori tiket "${created.name}".',
    );
    return created;
  }

  @override
  Future<TicketTypeModel> updateTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required OrganizerTicketTypeDraft draft,
  }) async {
    await _settle();
    _requireOwned(ownerId, eventId);
    final existing = _requireTicketType(eventId, ticketTypeId);

    final errors = OrganizerEventValidators.validateTicketTypeDraft(
      draft,
      sold: existing.sold,
      held: existing.held,
    );
    if (errors.isNotEmpty) {
      throw OrganizerEventValidationException(errors);
    }
    _ensureUniqueTicketName(eventId, draft.name, exceptId: ticketTypeId);

    // Harga/kuota baru hanya berlaku untuk order berikutnya; order lama
    // mempertahankan snapshot harga (PRD 9.7 butir 8–9).
    final updated = existing.copyWith(
      name: draft.name.trim(),
      description: _trimToNull(draft.description),
      clearDescription: _trimToNull(draft.description) == null,
      price: draft.price,
      quota: draft.quota,
      maxPerOrder: draft.maxPerOrder,
      clearMaxPerOrder: draft.maxPerOrder == null,
      salesStart: draft.salesStart,
      clearSalesStart: draft.salesStart == null,
      salesEnd: draft.salesEnd,
      clearSalesEnd: draft.salesEnd == null,
      isActive: draft.isActive,
    );
    _replaceTicketType(updated);
    await _log(
      eventId,
      ownerId,
      OrganizerActivityActions.ticketTypeUpdated,
      'Memperbarui kategori tiket "${updated.name}".',
    );
    return updated;
  }

  @override
  Future<void> deleteTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
  }) async {
    await _settle();
    _requireOwned(ownerId, eventId);
    final existing = _requireTicketType(eventId, ticketTypeId);
    if (existing.hasTransactions) {
      throw OrganizerTicketTypeException(
        'Kategori "${existing.name}" sudah memiliki '
        '${existing.sold} tiket terjual dan ${existing.held} kuota tertahan '
        'sehingga tidak dapat dihapus. Nonaktifkan saja.',
      );
    }
    _ticketTypes.removeWhere((type) => type.id == ticketTypeId);
    await _log(
      eventId,
      ownerId,
      OrganizerActivityActions.ticketTypeDeleted,
      'Menghapus kategori tiket "${existing.name}".',
    );
  }

  @override
  Future<TicketTypeModel> setTicketTypeActive({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required bool isActive,
  }) async {
    await _settle();
    _requireOwned(ownerId, eventId);
    final existing = _requireTicketType(eventId, ticketTypeId);
    final updated = existing.copyWith(isActive: isActive);
    _replaceTicketType(updated);
    await _log(
      eventId,
      ownerId,
      OrganizerActivityActions.ticketTypeUpdated,
      '${isActive ? 'Mengaktifkan' : 'Menonaktifkan'} kategori tiket '
      '"${existing.name}".',
    );
    return updated;
  }

  @override
  Future<OrganizerEventSummary> eventSummary({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    final event = _requireOwned(ownerId, eventId);
    final types = _ticketTypes.where((type) => type.eventId == eventId);
    final metrics =
        _metrics[eventId] ?? const OrganizerEventMetrics(pendingOrders: 0);

    var sold = 0;
    var remaining = 0;
    var gross = 0.0;
    for (final type in types) {
      sold += type.sold;
      remaining += type.remainingQuota;
      gross += type.price * type.sold;
    }

    return OrganizerEventSummary(
      eventId: eventId,
      status: event.status,
      ticketsSold: sold,
      ticketsRemaining: remaining,
      pendingOrders: metrics.pendingOrders,
      participants: metrics.participants,
      checkedIn: metrics.checkedIn,
      grossSales: gross,
    );
  }

  @override
  Future<Map<String, OrganizerEventSummary>> eventSummaries({
    required String ownerId,
  }) async {
    await _settle();
    final result = <String, OrganizerEventSummary>{};
    for (final event in _events.where((e) => e.organizerId == ownerId)) {
      final types = _ticketTypes.where((type) => type.eventId == event.id);
      final metrics =
          _metrics[event.id] ?? const OrganizerEventMetrics(pendingOrders: 0);
      var sold = 0;
      var remaining = 0;
      var gross = 0.0;
      for (final type in types) {
        sold += type.sold;
        remaining += type.remainingQuota;
        gross += type.price * type.sold;
      }
      result[event.id] = OrganizerEventSummary(
        eventId: event.id,
        status: event.status,
        ticketsSold: sold,
        ticketsRemaining: remaining,
        pendingOrders: metrics.pendingOrders,
        participants: metrics.participants,
        checkedIn: metrics.checkedIn,
        grossSales: gross,
      );
    }
    return result;
  }

  @override
  Future<List<OrganizerEventSalesPoint>> salesPoints({
    required String ownerId,
    required String eventId,
  }) async {
    await _settle();
    _requireOwned(ownerId, eventId);
    return List<OrganizerEventSalesPoint>.unmodifiable(
      _salesPoints[eventId] ?? const <OrganizerEventSalesPoint>[],
    );
  }

  @override
  Future<OrganizerOverview> overview({required String ownerId}) async {
    await _settle();
    final owned = _events
        .where((event) => event.organizerId == ownerId)
        .toList(growable: false);

    var draft = 0;
    var pending = 0;
    var revision = 0;
    var published = 0;
    for (final event in owned) {
      switch (event.status) {
        case OrganizerEventStatus.draft:
          draft++;
        case OrganizerEventStatus.pendingReview:
          pending++;
        case OrganizerEventStatus.revisionRequested:
          revision++;
        case OrganizerEventStatus.approved:
        case OrganizerEventStatus.published:
          published++;
        default:
          break;
      }
    }

    var sold = 0;
    var gross = 0.0;
    var pendingOrders = 0;
    var participants = 0;
    var checkedIn = 0;
    for (final event in owned) {
      for (final type in _ticketTypes.where((t) => t.eventId == event.id)) {
        sold += type.sold;
        gross += type.price * type.sold;
      }
      final metrics = _metrics[event.id];
      if (metrics != null) {
        pendingOrders += metrics.pendingOrders;
        participants += metrics.participants;
        checkedIn += metrics.checkedIn;
      }
    }

    final recent = List<EventModel>.from(owned)
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    return OrganizerOverview(
      draftCount: draft,
      pendingReviewCount: pending,
      revisionCount: revision,
      publishedCount: published,
      ticketsSold: sold,
      pendingOrders: pendingOrders,
      participants: participants,
      checkedIn: checkedIn,
      grossSales: gross,
      recentEvents: recent.take(5).toList(growable: false),
    );
  }

  // ---------------------------------------------------------------
  // Helper internal
  // ---------------------------------------------------------------

  /// Mensimulasikan jeda jaringan agar state loading dapat diuji.
  Future<void> _settle() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (failRequests) {
      throw const OrganizerEventException(
        'Gagal memuat data event (simulasi). Silakan coba lagi.',
      );
    }
  }

  EventModel _requireOwned(String ownerId, String eventId) {
    final matches = _events.where((event) => event.id == eventId);
    if (matches.isEmpty) {
      throw const OrganizerEventNotFoundException();
    }
    final event = matches.first;
    if (event.organizerId != ownerId) {
      // Tidak menyertakan detail event pada pesan agar tidak bocor.
      throw const OrganizerEventAccessDeniedException();
    }
    return event;
  }

  TicketTypeModel _requireTicketType(String eventId, String ticketTypeId) {
    final matches = _ticketTypes.where(
      (type) => type.id == ticketTypeId && type.eventId == eventId,
    );
    if (matches.isEmpty) {
      throw const OrganizerTicketTypeException(
        'Kategori tiket tidak ditemukan pada event ini.',
      );
    }
    return matches.first;
  }

  void _replaceEvent(EventModel updated) {
    final index = _events.indexWhere((event) => event.id == updated.id);
    if (index >= 0) _events[index] = updated;
  }

  void _replaceTicketType(TicketTypeModel updated) {
    final index = _ticketTypes.indexWhere((type) => type.id == updated.id);
    if (index >= 0) _ticketTypes[index] = updated;
  }

  void _ensureUniqueTicketName(String eventId, String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    final duplicate = _ticketTypes.any(
      (type) =>
          type.eventId == eventId &&
          type.id != exceptId &&
          type.name.trim().toLowerCase() == normalized,
    );
    if (duplicate) {
      throw OrganizerEventValidationException(
        <String, String>{
          OrganizerEventValidators.fieldTicketName:
              'Nama kategori tiket sudah dipakai pada event ini.',
        },
      );
    }
  }

  void _throwIfInvalidDraft(OrganizerEventDraft draft) {
    final errors = OrganizerEventValidators.validateEventDraft(draft);
    if (errors.isNotEmpty) {
      throw OrganizerEventValidationException(errors);
    }
  }

  Future<EventModel> _moveToPendingReview(
    EventModel event,
    String ownerId, {
    required bool resubmission,
  }) async {
    final updated = event.copyWith(
      status: OrganizerEventStatus.pendingReview,
      submittedAt: _clock(),
      updatedAt: _clock(),
      clearReviewNote: true,
    );
    _replaceEvent(updated);
    await _log(
      updated.id,
      ownerId,
      resubmission
          ? OrganizerActivityActions.eventResubmitted
          : OrganizerActivityActions.eventSubmitted,
      resubmission
          ? 'Mengajukan ulang event "${updated.title}" untuk moderasi.'
          : 'Mengajukan event "${updated.title}" untuk moderasi.',
    );
    return updated;
  }

  Future<void> _log(
    String eventId,
    String actorId,
    String action,
    String summary,
  ) {
    return _logger(
      OrganizerEventActivityEntry(
        eventId: eventId,
        actorId: actorId,
        action: action,
        summary: summary,
        timestamp: _clock(),
      ),
    );
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
