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
  final String status;
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
    required this.status,
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
      status: json['status'] as String? ?? 'draft',
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
      'status': status,
      'is_public': isPublic,
      'public_url': publicUrl,
      'registration_qr_url': registrationQrUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'EventModel(id: $id, title: $title, status: $status)';
}
