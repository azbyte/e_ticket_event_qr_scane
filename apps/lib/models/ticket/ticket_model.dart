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

  /// Nama event asli dari database (bukan UUID/placeholder).
  final String eventTitle;

  /// Nama kategori tiket (mis. "Reguler", "VIP").
  final String? ticketTypeName;

  /// ID publik tiket yang dicetak pada e-ticket (mis. `ETK-7K4P9Q`). Tiket lama
  /// dapat masih memakai kode panjang `TKT-<uuid>` sampai dirapikan backend.
  final String? ticketCode;

  /// Jadwal & lokasi event untuk ditampilkan pada tiket.
  final DateTime? eventDate;
  final String? eventLocation;
  final String? eventOnlineUrl;

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
    this.eventTitle = '',
    this.ticketTypeName,
    this.ticketCode,
    this.eventDate,
    this.eventLocation,
    this.eventOnlineUrl,
  });

  bool get isValid => status == 'valid' || status == 'active';
  bool get isCheckedIn => status == 'checked_in' || status == 'used';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isRevoked => status == 'revoked';

  /// Label event untuk UI; jatuh ke placeholder netral bila data kosong.
  String get displayEventTitle =>
      eventTitle.trim().isEmpty ? 'Nama event tidak tersedia' : eventTitle;

  /// Label kategori tiket; jatuh ke '-' bila tidak tersedia.
  String get displayTicketType {
    final name = ticketTypeName?.trim() ?? '';
    return name.isEmpty ? '-' : name;
  }

  /// Lokasi tampilan: lokasi fisik, lalu URL online, lalu '-'.
  String get displayLocation {
    final location = eventLocation?.trim() ?? '';
    if (location.isNotEmpty) return location;
    final online = eventOnlineUrl?.trim() ?? '';
    return online.isEmpty ? '-' : online;
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final events = json['events'];
    final eventMap = events is Map ? Map<String, dynamic>.from(events) : null;
    final eventDateRaw = json['event_date'] ?? eventMap?['event_date'];
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
      eventTitle:
          (json['event_title'] ?? eventMap?['title'])?.toString() ?? '',
      ticketTypeName: json['ticket_type_name']?.toString(),
      ticketCode: json['ticket_code']?.toString(),
      eventDate: eventDateRaw is String
          ? DateTime.tryParse(eventDateRaw)
          : null,
      eventLocation: (json['event_location'] ?? eventMap?['location'])
          ?.toString(),
      eventOnlineUrl: (json['event_online_url'] ?? eventMap?['online_url'])
          ?.toString(),
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
      'event_title': eventTitle,
      'ticket_type_name': ticketTypeName,
      'ticket_code': ticketCode,
      'event_date': eventDate?.toIso8601String(),
      'event_location': eventLocation,
      'event_online_url': eventOnlineUrl,
    };
  }

  @override
  String toString() => 'TicketModel(id: $id, token: $token, status: $status)';
}
