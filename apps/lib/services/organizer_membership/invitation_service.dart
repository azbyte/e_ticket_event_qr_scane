/// Layanan undangan panitia (AC-08, PRD §6.2).
///
/// Membungkus dua endpoint undangan:
///  - `GET /api/invitations/:token` — pratinjau publik (tanpa auth);
///  - `POST /api/invitations/:token/accept` — penerimaan (wajib login, email
///    akun harus cocok dengan email undangan).
library;

import '../api/api_service.dart';

/// Data pratinjau undangan (tanpa PII lengkap; email disamarkan backend).
class InvitationPreview {
  const InvitationPreview({
    required this.status,
    required this.invitedEmail,
    required this.permissions,
    required this.eventId,
    required this.eventTitle,
    required this.eventStatus,
    this.eventDate,
    this.endDateTime,
    this.location,
    this.eventFormat,
    this.onlineUrl,
    this.expiresAt,
  });

  final String status;
  final String invitedEmail;
  final List<String> permissions;
  final String eventId;
  final String eventTitle;
  final String eventStatus;
  final DateTime? eventDate;
  final DateTime? endDateTime;
  final String? location;
  final String? eventFormat;
  final String? onlineUrl;
  final DateTime? expiresAt;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isOnline => (eventFormat ?? '').toUpperCase() == 'ONLINE';

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? const {});
    DateTime? parse(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());
    return InvitationPreview(
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      invitedEmail: (json['invited_email'] ?? '').toString(),
      permissions: (json['permissions'] as List? ?? const [])
          .map((p) => p.toString())
          .toList(),
      eventId: (event['id'] ?? '').toString(),
      eventTitle: (event['title'] ?? 'Event').toString(),
      eventStatus: (event['status'] ?? '').toString(),
      eventDate: parse(event['event_date']),
      endDateTime: parse(event['end_date_time']),
      location: event['location']?.toString(),
      eventFormat: event['event_format']?.toString(),
      onlineUrl: event['online_url']?.toString(),
      expiresAt: parse(json['expires_at']),
    );
  }
}

class InvitationService {
  InvitationService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Pratinjau undangan; tidak memerlukan login.
  Future<InvitationPreview> preview(String token) async {
    final response = await _api.get('/invitations/$token');
    final invitation =
        Map<String, dynamic>.from(response['invitation'] as Map? ?? const {});
    return InvitationPreview.fromJson(invitation);
  }

  /// Menerima undangan. Melempar `AuthException` (401/403) atau
  /// `NetworkException` (404/409/410) sesuai respons backend.
  Future<Map<String, dynamic>> accept(String token) async {
    return _api.post('/invitations/$token/accept');
  }
}
