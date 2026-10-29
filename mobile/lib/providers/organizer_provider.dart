/// Organizer state provider (PRD sections 4.2, 4.8, 4.9).
///
/// State management for organizer dashboard, event management,
/// attendee monitoring, and staff delegation.
library;

import 'package:flutter/foundation.dart';

import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import '../services/organizer/organizer_service.dart';

class OrganizerProvider extends ChangeNotifier {
  OrganizerProvider({OrganizerService? organizerService})
      : _organizerService = organizerService ?? OrganizerService();

  final OrganizerService _organizerService;

  List<EventModel> _events = [];
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _staffList = [];
  List<TicketTypeModel> _ticketTypes = [];
  bool _isLoading = false;
  String? _error;

  List<EventModel> get events => _events;
  Map<String, dynamic>? get stats => _stats;
  List<Map<String, dynamic>> get staffList => _staffList;
  List<TicketTypeModel> get ticketTypes => _ticketTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads dashboard metrics.
  Future<void> loadDashboardStats() async {
    _setLoading(true);
    _error = null;
    try {
      _stats = await _organizerService.getDashboardStats();
      await loadEvents();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Loads all organizer events.
  Future<bool> loadEvents() async {
    _setLoading(true);
    _error = null;
    try {
      _events = await _organizerService.listOrganizerEvents();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Creates a new event.
  Future<EventModel?> createEvent(
    EventModel event, {
    List<TicketTypeModel>? ticketTypes,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final created = await _organizerService.createEvent(event, ticketTypes: ticketTypes);
      await loadEvents();
      return created;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Updates an event.
  Future<bool> updateEvent(EventModel event) async {
    _setLoading(true);
    _error = null;
    try {
      await _organizerService.updateEvent(event);
      await loadEvents();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Deletes an event.
  Future<bool> deleteEvent(String eventId) async {
    _setLoading(true);
    _error = null;
    try {
      final ok = await _organizerService.deleteEvent(eventId);
      if (ok) {
        _events.removeWhere((e) => e.id == eventId);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Loads ticket types for an event.
  Future<void> loadTicketTypes(String eventId) async {
    try {
      _ticketTypes = await _organizerService.getTicketTypes(eventId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Loads staff assigned to an event.
  Future<void> loadStaff(String eventId) async {
    _setLoading(true);
    _error = null;
    try {
      _staffList = await _organizerService.listStaff(eventId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Invites staff member.
  Future<bool> inviteStaff(String eventId, String email, String role) async {
    _setLoading(true);
    _error = null;
    try {
      await _organizerService.inviteStaff(eventId, email, role);
      await loadStaff(eventId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Removes staff member.
  Future<bool> removeStaff(String eventId, String staffId) async {
    _setLoading(true);
    _error = null;
    try {
      final ok = await _organizerService.removeStaff(eventId, staffId);
      if (ok) {
        _staffList.removeWhere((s) => s['id'] == staffId);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
