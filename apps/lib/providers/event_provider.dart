/// Event state provider (PRD sections 4.2, 4.4).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
/// State domain Event/TicketType untuk layar Organizer (Tahap 0).
///
/// Sumber data adalah [OrganizerEventRepository] (mock in-memory), bukan
/// [EventService] yang melakukan HTTP. `EventService` tetap dipertahankan untuk
/// fase integrasi backend berikutnya dan tidak dipakai pada alur prototipe ini.
import 'package:flutter/foundation.dart';

import '../models/event/event_model.dart';
import '../models/event/ticket_type_model.dart';
import '../services/organizer_events/organizer_event_contract.dart';
import '../services/organizer_events/organizer_event_exceptions.dart';
import '../services/organizer_events/organizer_event_fixtures.dart';
import '../services/organizer_events/organizer_event_repository.dart';
import '../services/organizer_events/mock_organizer_event_repository.dart';

/// Status pemuatan daftar event.
enum EventLoadStatus { idle, loading, ready, error, accessDenied }

class EventProvider extends ChangeNotifier {
  EventProvider({
    OrganizerEventRepository? repository,
    this.ownerId = OrganizerEventFixtures.demoOwnerId,
  }) : _repository = repository ?? MockOrganizerEventRepository.shared();

  final OrganizerEventRepository _repository;

  /// Repository yang dipakai provider ini.
  ///
  /// Diekspos agar layar dapat meneruskan instance yang sama ke layar lain
  /// (mis. daftar → form) sehingga state fixture tetap konsisten.
  OrganizerEventRepository get repository => _repository;

  /// Owner aktif; seluruh pembacaan dibatasi pada nilai ini.
  final String ownerId;

  EventLoadStatus _status = EventLoadStatus.idle;
  String? _loadError;
  String _searchQuery = '';
  OrganizerEventFilter _filter = OrganizerEventFilter.all;

  List<EventModel> _events = const <EventModel>[];
  EventModel? _selectedEvent;
  List<TicketTypeModel> _ticketTypes = const <TicketTypeModel>[];
  OrganizerEventSummary? _summary;
  List<OrganizerEventSalesPoint> _salesPoints =
      const <OrganizerEventSalesPoint>[];
  OrganizerOverview? _overview;

  Map<String, OrganizerEventSummary> _summaries =
      const <String, OrganizerEventSummary>{};

  bool _isSaving = false;
  String? _actionError;
  Map<String, String> _fieldErrors = const <String, String>{};

  EventLoadStatus get status => _status;

  /// True saat daftar/event sedang dimuat.
  bool get isLoading => _status == EventLoadStatus.loading;

  /// True bila pemuatan terakhir gagal karena kendala simulasi/IO.
  bool get hasError => _status == EventLoadStatus.error;

  /// True bila event yang diminta bukan milik Owner aktif.
  bool get hasAccessDenied => _status == EventLoadStatus.accessDenied;

  String? get loadError => _loadError;
  String get searchQuery => _searchQuery;
  OrganizerEventFilter get filter => _filter;

  /// Seluruh event milik Owner pada fixture (setelah filter status).
  List<EventModel> get events => List<EventModel>.unmodifiable(_events);

  /// Hasil pencarian lokal di atas [events].
  List<EventModel> get visibleEvents {
    final keyword = _searchQuery.trim().toLowerCase();
    if (keyword.isEmpty) return events;
    return _events
        .where((event) {
          final haystack = <String?>[
            event.title,
            event.location,
            event.category,
            event.organizerName,
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  /// True bila Owner belum punya event sama sekali (state empty awal).
  bool get isEmpty => _status == EventLoadStatus.ready && _events.isEmpty;

  /// True bila filter/pencarian tidak menemukan hasil (empty karena filter).
  bool get hasNoMatch =>
      _status == EventLoadStatus.ready &&
      _events.isNotEmpty &&
      visibleEvents.isEmpty;

  EventModel? get selectedEvent => _selectedEvent;
  List<TicketTypeModel> get ticketTypes =>
      List<TicketTypeModel>.unmodifiable(_ticketTypes);
  OrganizerEventSummary? get summary => _summary;
  List<OrganizerEventSalesPoint> get salesPointSeries =>
      List<OrganizerEventSalesPoint>.unmodifiable(_salesPoints);
  OrganizerOverview? get overview => _overview;

  /// Ringkasan operasional event berdasarkan id (kosong bila belum dimuat).
  OrganizerEventSummary? summaryFor(String eventId) => _summaries[eventId];

  bool get isSaving => _isSaving;

  /// Error aksi terakhir (submit/hapus/simpan) untuk snackbar atau banner.
  String? get actionError => _actionError;

  /// Error validasi per field dari aksi terakhir.
  Map<String, String> get fieldErrors =>
      Map<String, String>.unmodifiable(_fieldErrors);

  // ---------------------------------------------------------------
  // Pemuatan data
  // ---------------------------------------------------------------

  /// Memuat daftar event milik Owner aktif.
  Future<void> loadEvents() async {
    _status = EventLoadStatus.loading;
    _loadError = null;
    _actionError = null;
    _events = const <EventModel>[];
    _summaries = const <String, OrganizerEventSummary>{};
    notifyListeners();
    try {
      _events = await _repository.listEvents(ownerId: ownerId, filter: _filter);
    } on OrganizerEventAccessDeniedException catch (error) {
      _status = EventLoadStatus.accessDenied;
      _loadError = error.message;
      notifyListeners();
      return;
    } on OrganizerEventException catch (error) {
      _status = EventLoadStatus.error;
      _loadError = error.message;
      _events = const <EventModel>[];
      _summaries = const <String, OrganizerEventSummary>{};
      notifyListeners();
      return;
    }
    _status = EventLoadStatus.ready;
    try {
      _summaries = await _repository.eventSummaries(ownerId: ownerId);
    } on OrganizerEventException catch (error) {
      _summaries = const <String, OrganizerEventSummary>{};
      _loadError = error.message;
    }
    notifyListeners();
  }

  /// Memuat satu event beserta kategori tiket, ringkasan, dan grafiknya.
  Future<void> loadEvent(String eventId) async {
    _status = EventLoadStatus.loading;
    _loadError = null;
    notifyListeners();
    try {
      _selectedEvent = await _repository.getEvent(
        ownerId: ownerId,
        eventId: eventId,
      );
      _ticketTypes = await _repository.listTicketTypes(
        ownerId: ownerId,
        eventId: eventId,
      );
      _summary = await _repository.eventSummary(
        ownerId: ownerId,
        eventId: eventId,
      );
      _salesPoints = await _repository.salesPoints(
        ownerId: ownerId,
        eventId: eventId,
      );
      _status = EventLoadStatus.ready;
    } on OrganizerEventAccessDeniedException catch (error) {
      _status = EventLoadStatus.accessDenied;
      _loadError = error.message;
      _selectedEvent = null;
      _ticketTypes = const <TicketTypeModel>[];
      _summary = null;
      _salesPoints = const <OrganizerEventSalesPoint>[];
    } on OrganizerEventException catch (error) {
      _status = EventLoadStatus.error;
      _loadError = error.message;
      _selectedEvent = null;
    } finally {
      notifyListeners();
    }
  }

  /// Memuat ringkasan lintas event (kontrak dashboard Developer 3).
  Future<void> loadOverview() async {
    try {
      _overview = await _repository.overview(ownerId: ownerId);
    } on OrganizerEventException catch (error) {
      _actionError = error.message;
    } finally {
      notifyListeners();
    }
  }

  /// Mengubah kata kunci pencarian lokal.
  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  /// Mengubah filter status; memuat ulang daftar dari repository.
  Future<void> setFilter(OrganizerEventFilter value) async {
    if (_filter == value) return;
    _filter = value;
    await loadEvents();
  }

  void clearSelectedEvent() {
    _selectedEvent = null;
    _ticketTypes = const <TicketTypeModel>[];
    _summary = null;
    _salesPoints = const <OrganizerEventSalesPoint>[];
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    _fieldErrors = const <String, String>{};
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // Aksi mutasi (semua lokal, tanpa HTTP)
  // ---------------------------------------------------------------

  /// Membuat draft event baru. Mengembalikan event atau null bila gagal.
  Future<EventModel?> createEvent(OrganizerEventDraft draft) async {
    return _runAction(() async {
      final created = await _repository.createEvent(
        ownerId: ownerId,
        draft: draft,
      );
      await loadEvents();
      return created;
    });
  }

  /// Memperbarui event yang masih boleh diedit.
  Future<EventModel?> updateEvent(
    String eventId,
    OrganizerEventDraft draft,
  ) async {
    return _runAction(() async {
      final updated = await _repository.updateEvent(
        ownerId: ownerId,
        eventId: eventId,
        draft: draft,
      );
      _selectedEvent = updated;
      await loadEvents();
      return updated;
    });
  }

  /// Menghapus draft event (dengan konfirmasi di lapisan UI).
  Future<bool> deleteEvent(String eventId) async {
    final result = await _runAction(() async {
      await _repository.deleteEvent(ownerId: ownerId, eventId: eventId);
      if (_selectedEvent?.id == eventId) clearSelectedEvent();
      await loadEvents();
      return true;
    });
    return result ?? false;
  }

  /// Mengajukan moderasi (draft) atau mengajukan ulang (revisi/ditolak).
  Future<EventModel?> submitForReview(String eventId, {bool resubmit = false}) {
    return _runAction(() async {
      final updated = resubmit
          ? await _repository.resubmitForReview(
              ownerId: ownerId,
              eventId: eventId,
            )
          : await _repository.submitForReview(
              ownerId: ownerId,
              eventId: eventId,
            );
      if (_selectedEvent?.id == eventId) _selectedEvent = updated;
      await loadEvents();
      return updated;
    });
  }

  /// Simulasi keputusan moderator (demo) — bukan aksi Owner.
  Future<EventModel?> simulateModeration(
    String eventId,
    OrganizerModerationDecision decision, {
    String? note,
  }) {
    return _runAction(() async {
      final updated = await _repository.simulateModeratorDecision(
        ownerId: ownerId,
        eventId: eventId,
        decision: decision,
        note: note,
      );
      if (_selectedEvent?.id == eventId) _selectedEvent = updated;
      await loadEvents();
      return updated;
    });
  }

  /// Menyimpan kategori tiket (baru atau perubahan).
  Future<TicketTypeModel?> saveTicketType({
    required String eventId,
    required OrganizerTicketTypeDraft draft,
    String? ticketTypeId,
  }) {
    return _runAction(() async {
      final saved = ticketTypeId == null
          ? await _repository.createTicketType(
              ownerId: ownerId,
              eventId: eventId,
              draft: draft,
            )
          : await _repository.updateTicketType(
              ownerId: ownerId,
              eventId: eventId,
              ticketTypeId: ticketTypeId,
              draft: draft,
            );
      await _refreshEventDetail(eventId);
      return saved;
    });
  }

  /// Menghapus kategori tiket yang belum memiliki transaksi.
  Future<bool> deleteTicketType({
    required String eventId,
    required String ticketTypeId,
  }) async {
    final result = await _runAction(() async {
      await _repository.deleteTicketType(
        ownerId: ownerId,
        eventId: eventId,
        ticketTypeId: ticketTypeId,
      );
      await _refreshEventDetail(eventId);
      return true;
    });
    return result ?? false;
  }

  /// Mengaktifkan/menonaktifkan kategori tiket.
  Future<bool> setTicketTypeActive({
    required String eventId,
    required String ticketTypeId,
    required bool isActive,
  }) async {
    final result = await _runAction(() async {
      await _repository.setTicketTypeActive(
        ownerId: ownerId,
        eventId: eventId,
        ticketTypeId: ticketTypeId,
        isActive: isActive,
      );
      await _refreshEventDetail(eventId);
      return true;
    });
    return result ?? false;
  }

  // ---------------------------------------------------------------
  // Helper internal
  // ---------------------------------------------------------------

  /// Menjalankan aksi dengan state saving + penanganan error terpusat.
  Future<T?> _runAction<T>(Future<T> Function() action) async {
    _isSaving = true;
    _actionError = null;
    _fieldErrors = const <String, String>{};
    notifyListeners();
    try {
      return await action();
    } on OrganizerEventValidationException catch (error) {
      _fieldErrors = Map<String, String>.unmodifiable(error.fieldErrors);
      _actionError = error.firstMessage;
      return null;
    } on OrganizerEventAccessDeniedException catch (error) {
      _actionError = error.message;
      return null;
    } on OrganizerEventException catch (error) {
      _actionError = error.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _refreshEventDetail(String eventId) async {
    _ticketTypes = await _repository.listTicketTypes(
      ownerId: ownerId,
      eventId: eventId,
    );
    _summary = await _repository.eventSummary(
      ownerId: ownerId,
      eventId: eventId,
    );
    if (_summary != null) {
      _summaries = <String, OrganizerEventSummary>{
        ..._summaries,
        eventId: _summary!,
      };
    }
    _selectedEvent = await _repository.getEvent(
      ownerId: ownerId,
      eventId: eventId,
    );
    _salesPoints = await _repository.salesPoints(
      ownerId: ownerId,
      eventId: eventId,
    );
  }
}
