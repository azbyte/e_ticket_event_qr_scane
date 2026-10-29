/// QR scanner service (PRD sections 4.5, 7.5).
///
/// Validates scanned ticket QR codes, checks for duplicate check-ins,
/// and records check-in records online or to the local offline queue.
library;

import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../check_in/check_in_service.dart';

class ScannerService {
  ScannerService({CheckInService? checkInService})
      : _checkInService = checkInService ?? CheckInService();

  final CheckInService _checkInService;
  final ApiService _api = ApiService();

  // Mock tickets database for validation
  static final Map<String, Map<String, dynamic>> _mockTickets = {
    'TK-TECH-001': {
      'id': 'tkt-001',
      'token': 'TK-TECH-001',
      'event_id': 'evt-001',
      'event_title': 'Tech Innovation Summit 2026',
      'attendee_name': 'Ahmad Fauzi',
      'attendee_email': 'ahmad.fauzi@example.com',
      'ticket_type': 'VIP Pass',
      'status': 'checked_in', // Already used
      'checked_in_at': '2026-10-30T09:15:00Z',
      'checked_in_by': 'Budi Santoso',
    },
    'TK-TECH-002': {
      'id': 'tkt-002',
      'token': 'TK-TECH-002',
      'event_id': 'evt-001',
      'event_title': 'Tech Innovation Summit 2026',
      'attendee_name': 'Dewi Lestari',
      'attendee_email': 'dewi.lestari@example.com',
      'ticket_type': 'Regular Pass',
      'status': 'checked_in', // Already used
      'checked_in_at': '2026-10-30T09:40:00Z',
      'checked_in_by': 'Budi Santoso',
    },
    'TK-TECH-003': {
      'id': 'tkt-003',
      'token': 'TK-TECH-003',
      'event_id': 'evt-001',
      'event_title': 'Tech Innovation Summit 2026',
      'attendee_name': 'Rian Pratama',
      'attendee_email': 'rian.pratama@example.com',
      'ticket_type': 'Regular Pass',
      'status': 'valid',
      'checked_in_at': null,
      'checked_in_by': null,
    },
    'TK-TECH-004': {
      'id': 'tkt-004',
      'token': 'TK-TECH-004',
      'event_id': 'evt-001',
      'event_title': 'Tech Innovation Summit 2026',
      'attendee_name': 'Siti Nurhaliza',
      'attendee_email': 'siti.nurhaliza@example.com',
      'ticket_type': 'VIP Pass',
      'status': 'valid',
      'checked_in_at': null,
      'checked_in_by': null,
    },
    'TK-TECH-005': {
      'id': 'tkt-005',
      'token': 'TK-TECH-005',
      'event_id': 'evt-001',
      'event_title': 'Tech Innovation Summit 2026',
      'attendee_name': 'Eko Prasetyo',
      'attendee_email': 'eko.prasetyo@example.com',
      'ticket_type': 'Early Bird',
      'status': 'valid',
      'checked_in_at': null,
      'checked_in_by': null,
    },
  };

  /// Validates a scanned ticket token against the database.
  Future<Map<String, dynamic>> validateTicket(String token) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final cleanToken = token.trim().toUpperCase();

      // Check simulated edge cases
      if (cleanToken.contains('INVALID') || cleanToken == 'INV-999') {
        return {
          'valid': false,
          'status': 'invalid',
          'message': 'Tiket tidak ditemukan atau kode QR tidak valid.',
          'ticket': null,
        };
      }

      if (cleanToken.contains('USED') || cleanToken == 'TK-USED-999') {
        return {
          'valid': false,
          'status': 'already_checked_in',
          'message': 'Peringatan: Tiket ini sudah pernah digunakan untuk check-in.',
          'ticket': {
            'token': cleanToken,
            'attendee_name': 'Bambang Sudirman',
            'ticket_type': 'VIP Pass',
            'event_title': 'Tech Innovation Summit 2026',
            'checked_in_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
            'checked_in_by': 'Staf Ahmad',
          },
        };
      }

      final ticket = _mockTickets[cleanToken];
      if (ticket == null) {
        // Allow any generic valid token pattern for flexible testing
        if (cleanToken.startsWith('TK-') || cleanToken.startsWith('TEST-')) {
          return {
            'valid': true,
            'status': 'valid',
            'message': 'Tiket valid dan dapat digunakan untuk check-in.',
            'ticket': {
              'id': 'tkt-dynamic-${DateTime.now().millisecondsSinceEpoch}',
              'token': cleanToken,
              'event_id': 'evt-001',
              'event_title': 'Tech Innovation Summit 2026',
              'attendee_name': 'Peserta Simulasi',
              'attendee_email': 'peserta@example.com',
              'ticket_type': 'Standard Ticket',
              'status': 'valid',
            },
          };
        }

        return {
          'valid': false,
          'status': 'invalid',
          'message': 'Tiket tidak terdaftar dalam sistem.',
          'ticket': null,
        };
      }

      if (ticket['status'] == 'checked_in') {
        return {
          'valid': false,
          'status': 'already_checked_in',
          'message': 'Tiket sudah digunakan untuk check-in sebelumnya.',
          'ticket': ticket,
        };
      }

      return {
        'valid': true,
        'status': 'valid',
        'message': 'Tiket valid. Siap untuk check-in.',
        'ticket': ticket,
      };
    }

    return _api.post('/tickets/validate', body: {'token': token});
  }

  /// Records check-in after successful scan.
  Future<Map<String, dynamic>> recordCheckIn({
    required String ticketId,
    required String eventId,
    required String staffId,
    String staffName = 'Staf Event',
    bool isOffline = false,
  }) async {
    if (AppConfig.mockMode) {
      // Mark as checked in in local mock tickets table
      for (final key in _mockTickets.keys) {
        if (_mockTickets[key]!['id'] == ticketId || _mockTickets[key]!['token'] == ticketId) {
          _mockTickets[key]!['status'] = 'checked_in';
          _mockTickets[key]!['checked_in_at'] = DateTime.now().toIso8601String();
          _mockTickets[key]!['checked_in_by'] = staffName;
          break;
        }
      }

      return _checkInService.recordCheckIn(
        ticketId: ticketId,
        eventId: eventId,
        staffId: staffId,
        staffName: staffName,
        isOffline: isOffline,
      );
    }

    return _api.post('/check-ins', body: {
      'ticket_id': ticketId,
      'event_id': eventId,
      'staff_id': staffId,
    });
  }
}
