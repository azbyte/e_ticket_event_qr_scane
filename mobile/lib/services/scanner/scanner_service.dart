/// QR scanner service (PRD sections 4.5, 7.5).
///
/// Requires package `mobile_scanner` to be added to pubspec.yaml (PRD 8.1).
/// Camera permission must be configured on Android/Web outside frontend/lib/.
class ScannerService {
  ScannerService();

  /// Validates a scanned ticket token against the backend. TODO: real endpoint.
  Future<Map<String, dynamic>> validateTicket(String token) async {
    return ApiService().post('/tickets/validate', body: {'token': token});
  }

  /// Records a check-in. TODO: real endpoint + offline queue handling.
  Future<Map<String, dynamic>> recordCheckIn({
    required String ticketId,
    required String eventId,
    required String staffId,
  }) async {
    return ApiService().post('/check-ins', body: {
      'ticket_id': ticketId,
      'event_id': eventId,
      'staff_id': staffId,
    });
  }
}
