/// Support report / trouble ticket model (PRD section 4.10).
class SupportReportModel {
  final String id;
  final String? userId; // null for guest reporters
  final String? contactEmail;
  final String orderReference; // optional
  final String category;
  final String description;
  final String status; // open, in_progress, waiting_for_user, resolved, closed
  final String ticketNumber; // human-readable reference
  final String? statusToken; // unguessable token for status page
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? handledBy;

  const SupportReportModel({
    required this.id,
    this.userId,
    this.contactEmail,
    required this.orderReference,
    required this.category,
    required this.description,
    required this.status,
    required this.ticketNumber,
    this.statusToken,
    required this.createdAt,
    this.updatedAt,
    this.handledBy,
  });

  factory SupportReportModel.fromJson(Map<String, dynamic> json) {
    return SupportReportModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      contactEmail: json['contact_email'] as String?,
      orderReference: json['order_reference'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      ticketNumber: json['ticket_number'] as String? ?? '',
      statusToken: json['status_token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      handledBy: json['handled_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'contact_email': contactEmail,
      'order_reference': orderReference,
      'category': category,
      'description': description,
      'status': status,
      'ticket_number': ticketNumber,
      'status_token': statusToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'handled_by': handledBy,
    };
  }

  @override
  String toString() =>
      'SupportReportModel(id: $id, ticketNumber: $ticketNumber, status: $status)';
}
