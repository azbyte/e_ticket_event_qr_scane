/// Ticket model (PRD sections 4.6, 6.3).
class TicketModel {
  final String id;
  final String orderId;
  final String eventId;
  final String ticketTypeId;
  final String attendeeName;
  final String? attendeeEmail;
  final String token; // unique, hard-to-guess token
  final String status; // valid, checked_in, cancelled, revoked
  final String? qrCodeData;
  final DateTime? issuedAt;
  final DateTime? checkedInAt;
  final String? checkedInByStaffId;

  const TicketModel({
    required this.id,
    required this.orderId,
    required this.eventId,
    required this.ticketTypeId,
    required this.attendeeName,
    this.attendeeEmail,
    required this.token,
    required this.status,
    this.qrCodeData,
    this.issuedAt,
    this.checkedInAt,
    this.checkedInByStaffId,
  });

  bool get isValid => status == 'valid';
  bool get isCheckedIn => status == 'checked_in';

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      ticketTypeId: json['ticket_type_id'] as String? ?? '',
      attendeeName: json['attendee_name'] as String? ?? '',
      attendeeEmail: json['attendee_email'] as String?,
      token: json['token'] as String? ?? '',
      status: json['status'] as String? ?? 'valid',
      qrCodeData: json['qr_code_data'] as String?,
      issuedAt: json['issued_at'] != null
          ? DateTime.tryParse(json['issued_at'] as String)
          : null,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'] as String)
          : null,
      checkedInByStaffId: json['checked_in_by_staff_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'event_id': eventId,
      'ticket_type_id': ticketTypeId,
      'attendee_name': attendeeName,
      'attendee_email': attendeeEmail,
      'token': token,
      'status': status,
      'qr_code_data': qrCodeData,
      'issued_at': issuedAt?.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_in_by_staff_id': checkedInByStaffId,
    };
  }

  @override
  String toString() => 'TicketModel(id: $id, token: $token, status: $status)';
}
