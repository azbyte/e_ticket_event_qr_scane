/// Event state provider (PRD sections 4.2, 4.4).
import 'package:flutter/foundation.dart';

import '../models/event/event_model.dart';
import '../models/event/ticket_type_model.dart';
import '../services/event/event_service.dart';
import '../services/ticket/ticket_type_service.dart';

class EventProvider extends ChangeNotifier {
  EventProvider([EventService? eventService, TicketTypeService? ticketTypeService])
      : _eventService = eventService ?? EventService(),
        _ticketTypeService = ticketTypeService ?? TicketTypeService();

  static final EventProvider instance = EventProvider();

  final EventService _eventService;
  final TicketTypeService _ticketTypeService;

  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  List<TicketTypeModel> _ticketTypes = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'Semua';

  List<EventModel> get events => _events;
  EventModel? get selectedEvent => _selectedEvent;
  List<TicketTypeModel> get ticketTypes => _ticketTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<bool> loadEvents({Map<String, dynamic>? query, String? search, String? category}) async {
    _setLoading(true);
    _error = null;
    try {
      final combinedQuery = <String, dynamic>{
        if (query != null) ...query,
        if (search != null && search.isNotEmpty) 'q': search,
        if (category != null && category.isNotEmpty && category != 'Semua') 'category': category,
      };

      final list = await _eventService.listEvents(query: combinedQuery);
      _events = list.map((e) => EventModel.fromJson(e)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _eventService.getEvent(eventId);
      _selectedEvent = EventModel.fromJson(data);
      await loadTicketTypes(eventId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadTicketTypes(String eventId) async {
    try {
      _ticketTypes = await _ticketTypeService.getTicketTypesByEventId(eventId);
      notifyListeners();
      return true;
    } catch (e) {
      // If error occurs, keep ticketTypes empty but don't break whole screen
      _ticketTypes = [];
      return false;
    }
  }

  void clearSelectedEvent() {
    _selectedEvent = null;
    _ticketTypes = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
