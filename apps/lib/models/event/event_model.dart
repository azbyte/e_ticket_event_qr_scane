/// Event model (PRD sections 4.2, 6.1).
///
/// Field names are tentative pending final API contract (PRD section 15).
class EventModel {
  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? category;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? timeZone;
  final String? location;
  final String? onlineUrl;
  final String eventType; // offline, online, hybrid
  final String? contactInfo;

  /// Nama penyelenggara yang ditampilkan ke publik (PRD 5.4 A).
  final String? organizerName;

  /// Informasi yang tampil pada halaman publik (PRD 5.4 E).
  final String? publicInfo;

  /// Field data peserta yang wajib diisi saat registrasi (PRD 5.4 E).
  final List<String> attendeeFields;

  final String status;

  /// Catatan revisi dari Admin/moderator (PRD 5.5.2).
  ///
  /// Hanya ditulis oleh simulasi moderator pada fixture Tahap 0; Owner tidak
  /// dapat mengubah status moderasi maupun catatan reviewer.
  final String? reviewNote;

  /// Waktu pengajuan moderasi terakhir.
  final DateTime? submittedAt;
  final bool isPublic;
  final String? publicUrl;
  final String? registrationQrUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EventModel({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    this.posterUrl,
    this.category,
    required this.startDateTime,
    required this.endDateTime,
    this.timeZone,
    this.location,
    this.onlineUrl,
    required this.eventType,
    this.contactInfo,
    this.organizerName,
    this.publicInfo,
    this.attendeeFields = const <String>[],
    required this.status,
    this.reviewNote,
    this.submittedAt,
    this.isPublic = true,
    this.publicUrl,
    this.registrationQrUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String? ?? '',
      organizerId: json['organizer_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      posterUrl: json['poster_url'] as String?,
      category: json['category'] as String?,
      startDateTime: json['start_date_time'] != null
          ? DateTime.tryParse(json['start_date_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDateTime: json['end_date_time'] != null
          ? DateTime.tryParse(json['end_date_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeZone: json['time_zone'] as String?,
      location: json['location'] as String?,
      onlineUrl: json['online_url'] as String?,
      eventType: json['event_type'] as String? ?? 'offline',
      contactInfo: json['contact_info'] as String?,
      organizerName: json['organizer_name'] as String?,
      publicInfo: json['public_info'] as String?,
      attendeeFields: (json['attendee_fields'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      status: json['status'] as String? ?? 'draft',
      reviewNote: json['review_note'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      isPublic: json['is_public'] as bool? ?? true,
      publicUrl: json['public_url'] as String?,
      registrationQrUrl: json['registration_qr_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizer_id': organizerId,
      'title': title,
      'description': description,
      'poster_url': posterUrl,
      'category': category,
      'start_date_time': startDateTime.toIso8601String(),
      'end_date_time': endDateTime.toIso8601String(),
      'time_zone': timeZone,
      'location': location,
      'online_url': onlineUrl,
      'event_type': eventType,
      'contact_info': contactInfo,
      'organizer_name': organizerName,
      'public_info': publicInfo,
      'attendee_fields': attendeeFields,
      'status': status,
      'review_note': reviewNote,
      'submitted_at': submittedAt?.toIso8601String(),
      'is_public': isPublic,
      'public_url': publicUrl,
      'registration_qr_url': registrationQrUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  EventModel copyWith({
    String? id,
    String? organizerId,
    String? title,
    String? description,
    String? posterUrl,
    String? category,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? timeZone,
    String? location,
    String? onlineUrl,
    String? eventType,
    String? contactInfo,
    String? organizerName,
    String? publicInfo,
    List<String>? attendeeFields,
    String? status,
    String? reviewNote,
    DateTime? submittedAt,
    bool? isPublic,
    String? publicUrl,
    String? registrationQrUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDescription = false,
    bool clearPosterUrl = false,
    bool clearLocation = false,
    bool clearOnlineUrl = false,
    bool clearReviewNote = false,
    bool clearPublicUrl = false,
  }) {
    return EventModel(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      posterUrl: clearPosterUrl ? null : (posterUrl ?? this.posterUrl),
      category: category ?? this.category,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      timeZone: timeZone ?? this.timeZone,
      location: clearLocation ? null : (location ?? this.location),
      onlineUrl: clearOnlineUrl ? null : (onlineUrl ?? this.onlineUrl),
      eventType: eventType ?? this.eventType,
      contactInfo: contactInfo ?? this.contactInfo,
      organizerName: organizerName ?? this.organizerName,
      publicInfo: publicInfo ?? this.publicInfo,
      attendeeFields: attendeeFields ?? this.attendeeFields,
      status: status ?? this.status,
      reviewNote: clearReviewNote ? null : (reviewNote ?? this.reviewNote),
      submittedAt: submittedAt ?? this.submittedAt,
      isPublic: isPublic ?? this.isPublic,
      publicUrl: clearPublicUrl ? null : (publicUrl ?? this.publicUrl),
      registrationQrUrl: registrationQrUrl ?? this.registrationQrUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'EventModel(id: $id, title: $title, status: $status)';
}
