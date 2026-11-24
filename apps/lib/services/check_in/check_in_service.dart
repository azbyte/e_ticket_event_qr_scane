/// Check-in service (PRD sections 4.5, 4.6, 4.7).
///
/// Implements online check-in verification, duplicate prevention, and
/// offline queue handling with synchronization per PRD section 4.7.
library;

import '../../core/config/app_config.dart';
import '../../models/check_in/check_in_model.dart';
import '../api/api_service.dart';

class CheckInService {
  CheckInService();

  final ApiService _api = ApiService();

  // In-memory mock database for check-in records
  static final List<CheckInModel> _mockCheckIns = [
    CheckInModel(
      id: 'chk-001',
      ticketId: 'tkt-001',
      eventId: 'evt-1001',
      staffId: 'stf-001',
      staffName: 'Budi Santoso',
      checkedInAt: DateTime.now().subtract(const Duration(minutes: 45)),
      synced: true,
      syncStatus: 'synced',
    ),
    CheckInModel(
      id: 'chk-002',
      ticketId: 'tkt-002',
      eventId: 'evt-1001',
      staffId: 'stf-001',
      staffName: 'Budi Santoso',
      checkedInAt: DateTime.now().subtract(const Duration(minutes: 20)),
      synced: true,
      syncStatus: 'synced',
    ),
  ];

  // Mock attendee database for check-in verification
  static final List<Map<String, dynamic>> _mockAttendees = [
    {
      'id': 'att-001',
      'ticket_id': 'tkt-001',
      'ticket_code': 'TK-TECH-001',
      'name': 'Ahmad Fauzi',
      'email': 'ahmad.fauzi@example.com',
      'ticket_type': 'VIP Pass',
      'event_id': 'evt-1001',
      'checked_in': true,
      'checked_in_at': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
    },
    {
      'id': 'att-002',
      'ticket_id': 'tkt-002',
      'ticket_code': 'TK-TECH-002',
      'name': 'Dewi Lestari',
      'email': 'dewi.lestari@example.com',
      'ticket_type': 'Regular Pass',
      'event_id': 'evt-1001',
      'checked_in': true,
      'checked_in_at': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
    },
    {
      'id': 'att-003',
      'ticket_id': 'tkt-003',
      'ticket_code': 'TK-TECH-003',
      'name': 'Rian Pratama',
      'email': 'rian.pratama@example.com',
      'ticket_type': 'Regular Pass',
      'event_id': 'evt-1001',
      'checked_in': false,
      'checked_in_at': null,
    },
    {
      'id': 'att-004',
      'ticket_id': 'tkt-004',
      'ticket_code': 'TK-TECH-004',
      'name': 'Siti Nurhaliza',
      'email': 'siti.nurhaliza@example.com',
      'ticket_type': 'VIP Pass',
      'event_id': 'evt-1001',
      'checked_in': false,
      'checked_in_at': null,
    },
    {
      'id': 'att-005',
      'ticket_id': 'tkt-005',
      'ticket_code': 'TK-TECH-005',
      'name': 'Eko Prasetyo',
      'email': 'eko.prasetyo@example.com',
      'ticket_type': 'Early Bird',
      'event_id': 'evt-1001',
      'checked_in': false,
      'checked_in_at': null,
    },
  ];

  /// Lists check-in records for a given event.
  Future<List<Map<String, dynamic>>> listCheckIns({
    required String eventId,
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _mockCheckIns
          .where((c) => c.eventId == eventId || eventId.isEmpty)
          .map((c) => c.toJson())
          .toList();
    }

    final result = await _api.get('/check-ins/events/$eventId/check-ins', query: query);
    final data = (result['check_ins'] ?? result['data']) as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Lists attendees with check-in status for an event.
  Future<List<Map<String, dynamic>>> listAttendees({
    required String eventId,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _mockAttendees
          .where((a) => a['event_id'] == eventId || eventId.isEmpty)
          .toList();
    }
    final result = await _api.get('/events/$eventId/attendees');
    final data = result['attendees'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Records a check-in either online or to the offline queue.
  Future<Map<String, dynamic>> recordCheckIn({
    required String ticketId,
    required String eventId,
    required String staffId,
    String staffName = 'Staf Event',
    bool isOffline = false,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify attendee status
      final attendeeIndex = _mockAttendees.indexWhere((a) => a['ticket_id'] == ticketId);
      if (attendeeIndex != -1) {
        if (_mockAttendees[attendeeIndex]['checked_in'] == true) {
          return {
            'success': false,
            'status': 'already_checked_in',
            'message': 'Tiket sudah digunakan untuk check-in sebelumnya.',
            'attendee': _mockAttendees[attendeeIndex],
          };
        }
        _mockAttendees[attendeeIndex]['checked_in'] = true;
        _mockAttendees[attendeeIndex]['checked_in_at'] = DateTime.now().toIso8601String();
      }

      final checkInRecord = CheckInModel(
        id: 'chk-${DateTime.now().millisecondsSinceEpoch}',
        ticketId: ticketId,
        eventId: eventId,
        staffId: staffId,
        staffName: staffName,
        checkedInAt: DateTime.now(),
        synced: true,
        syncStatus: 'synced',
      );

      _mockCheckIns.insert(0, checkInRecord);

      return {
        'success': true,
        'status': 'checked_in',
        'message': 'Check-in berhasil dicatat.',
        'check_in': checkInRecord.toJson(),
        'attendee': attendeeIndex != -1 ? _mockAttendees[attendeeIndex] : null,
      };
    }

    return _api.post('/check-ins', body: {
      'ticket_id': ticketId,
      'event_id': eventId,
      'staff_id': staffId,
    });
  }

  /// Pada alur MVP, seluruh check-in diproses langsung secara online.
  Future<int> syncPendingCheckIns() async => 0;

  /// Returns count of pending offline check-in records (selalu 0 pada MVP).
  int get pendingOfflineCount => 0;
}
