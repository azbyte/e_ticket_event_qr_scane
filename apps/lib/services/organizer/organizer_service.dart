/// Organizer service (PRD sections 4.2, 4.8, 4.9).
///
/// Handles event creation, ticket category configuration, attendee lists,
/// and staff invitation/management for event organizers.
library;

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import '../api/api_service.dart';

class OrganizerService {
  OrganizerService();

  final ApiService _api = ApiService();

  // Mock list of events managed by organizer
  static final List<EventModel> _mockEvents = [
    EventModel(
      id: 'evt-001',
      organizerId: 'org-001',
      title: 'Tech Innovation Summit 2026',
      description: 'Konferensi teknologi terbesar tahun 2026 yang menghadirkan pembicara pakar AI, Cloud, dan Cybersecurity.',
      category: 'Teknologi',
      posterUrl: null,
      startDateTime: DateTime.now().add(const Duration(days: 14)),
      endDateTime: DateTime.now().add(const Duration(days: 15)),
      location: 'Grand Ballroom Hotel Indonesia Kempinski, Jakarta',
      eventType: 'hybrid',
      contactInfo: 'organizer@techsummit.id',
      status: AppConstants.eventStatusPublished,
      isPublic: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    EventModel(
      id: 'evt-002',
      organizerId: 'org-001',
      title: 'Workshop Flutter & Backend Modern',
      description: 'Pelatihan intensif 2 hari membangun arsitektur aplikasi mobile enterprise skala besar.',
      category: 'Edukasi',
      posterUrl: null,
      startDateTime: DateTime.now().add(const Duration(days: 21)),
      endDateTime: DateTime.now().add(const Duration(days: 22)),
      location: 'Auditorium Fasilkom UI, Depok',
      eventType: 'offline',
      contactInfo: 'workshop@devcommunity.id',
      status: AppConstants.eventStatusPendingReview,
      isPublic: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    EventModel(
      id: 'evt-003',
      organizerId: 'org-001',
      title: 'Festival Musik Indie Nusantara',
      description: 'Pentas seni dan pertunjukan musik musisi independen dari berbagai penjuru tanah air.',
      category: 'Seni & Musik',
      posterUrl: null,
      startDateTime: DateTime.now().add(const Duration(days: 35)),
      endDateTime: DateTime.now().add(const Duration(days: 36)),
      location: 'Gelora Bung Karno Park, Jakarta',
      eventType: 'offline',
      contactInfo: 'contact@indiefest.id',
      status: AppConstants.eventStatusDraft,
      isPublic: false,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  // Mock ticket types per event
  static final List<TicketTypeModel> _mockTicketTypes = [
    TicketTypeModel(
      id: 'tt-001',
      eventId: 'evt-001',
      name: 'VIP Pass (All Access)',
      description: 'Akses panggung utama, workshop, dan networking dinner.',
      price: 750000,
      quota: 50,
      sold: 45,
    ),
    TicketTypeModel(
      id: 'tt-002',
      eventId: 'evt-001',
      name: 'Regular Conference Pass',
      description: 'Akses panggung utama dan pameran teknologi.',
      price: 350000,
      quota: 200,
      sold: 160,
    ),
    TicketTypeModel(
      id: 'tt-003',
      eventId: 'evt-002',
      name: 'Student Workshop Pass',
      description: 'Khusus mahasiswa aktif dengan kartu tanda mahasiswa.',
      price: 150000,
      quota: 60,
      sold: 30,
    ),
  ];

  // Mock staff list per event
  static final List<Map<String, dynamic>> _mockStaffList = [
    {
      'id': 'stf-001',
      'name': 'Budi Santoso',
      'email': 'budi.santoso@eventcrew.id',
      'event_id': 'evt-001',
      'role': 'QR Scanner Staff',
      'assigned_at': '2026-10-25T10:00:00Z',
      'status': 'active',
    },
    {
      'id': 'stf-002',
      'name': 'Siti Rahma',
      'email': 'siti.rahma@eventcrew.id',
      'event_id': 'evt-001',
      'role': 'Registration Desk',
      'assigned_at': '2026-10-26T11:30:00Z',
      'status': 'active',
    },
  ];

  /// Fetches organizer KPI dashboard metrics.
  Future<Map<String, dynamic>> getDashboardStats() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return {
        'total_events': _mockEvents.length,
        'published_events': _mockEvents.where((e) => e.status == AppConstants.eventStatusPublished).length,
        'pending_events': _mockEvents.where((e) => e.status == AppConstants.eventStatusPendingReview).length,
        'total_tickets_sold': 235,
        'total_revenue': 58500000,
        'check_in_rate': 0.76,
      };
    }
    return _api.get('/organizer/stats');
  }

  /// Lists all events created by organizer.
  Future<List<EventModel>> listOrganizerEvents() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return List<EventModel>.from(_mockEvents);
    }
    final res = await _api.get('/organizer/events');
    final data = res['data'] as List? ?? [];
    return data.map((json) => EventModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Creates a new event with ticket types.
  Future<EventModel> createEvent(EventModel event, {List<TicketTypeModel>? ticketTypes}) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final newEvent = EventModel(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        organizerId: event.organizerId.isEmpty ? 'org-001' : event.organizerId,
        title: event.title,
        description: event.description,
        category: event.category ?? 'Umum',
        posterUrl: event.posterUrl,
        startDateTime: event.startDateTime,
        endDateTime: event.endDateTime,
        location: event.location,
        eventType: event.eventType,
        contactInfo: event.contactInfo,
        status: event.status.isEmpty ? AppConstants.eventStatusDraft : event.status,
        isPublic: event.isPublic,
        createdAt: DateTime.now(),
      );
      _mockEvents.insert(0, newEvent);

      if (ticketTypes != null) {
        for (final tt in ticketTypes) {
          _mockTicketTypes.add(TicketTypeModel(
            id: 'tt-${DateTime.now().millisecondsSinceEpoch}-${tt.name}',
            eventId: newEvent.id,
            name: tt.name,
            description: tt.description,
            price: tt.price,
            quota: tt.quota,
            sold: 0,
          ));
        }
      }
      return newEvent;
    }

    final res = await _api.post('/organizer/events', body: {
      'event': event.toJson(),
      'ticket_types': ticketTypes?.map((t) => t.toJson()).toList(),
    });
    return EventModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Updates existing event.
  Future<EventModel> updateEvent(EventModel event) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final idx = _mockEvents.indexWhere((e) => e.id == event.id);
      if (idx != -1) {
        _mockEvents[idx] = event;
      }
      return event;
    }
    final res = await _api.put('/organizer/events/${event.id}', body: event.toJson());
    return EventModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Deletes or cancels an event.
  Future<bool> deleteEvent(String eventId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _mockEvents.removeWhere((e) => e.id == eventId);
      return true;
    }
    await _api.delete('/organizer/events/$eventId');
    return true;
  }

  /// Lists ticket categories for an event.
  Future<List<TicketTypeModel>> getTicketTypes(String eventId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _mockTicketTypes.where((t) => t.eventId == eventId).toList();
    }
    final res = await _api.get('/events/$eventId/ticket-types');
    final data = res['data'] as List? ?? [];
    return data.map((json) => TicketTypeModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Lists staff assigned to an event.
  Future<List<Map<String, dynamic>>> listStaff(String eventId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _mockStaffList.where((s) => s['event_id'] == eventId || eventId.isEmpty).toList();
    }
    final res = await _api.get('/events/$eventId/staff');
    final data = res['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Invites a new staff member to an event.
  Future<Map<String, dynamic>> inviteStaff(String eventId, String email, String role) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final newStaff = {
        'id': 'stf-${DateTime.now().millisecondsSinceEpoch}',
        'name': email.split('@').first.replaceAll('.', ' ').toUpperCase(),
        'email': email,
        'event_id': eventId,
        'role': role,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'active',
      };
      _mockStaffList.add(newStaff);
      return newStaff;
    }
    final res = await _api.post('/events/$eventId/staff', body: {
      'email': email,
      'role': role,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Revokes staff access from an event.
  Future<bool> removeStaff(String eventId, String staffId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _mockStaffList.removeWhere((s) => s['id'] == staffId);
      return true;
    }
    await _api.delete('/events/$eventId/staff/$staffId');
    return true;
  }
}
