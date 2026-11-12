/// Support report / trouble ticket model (PRD sections 4.10, 6.8, FR-94 s.d. FR-101).
library;

import 'report_activity_model.dart';

/// Model untuk balasan publik pada laporan kendala (FR-99).
class ReportReplyModel {
  final String id;
  final String reportId;
  final String senderName;
  final String senderRole; // 'Admin Platform' | 'Pelapor' | 'Penyelenggara'
  final String message;
  final DateTime createdAt;

  const ReportReplyModel({
    required this.id,
    required this.reportId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory ReportReplyModel.fromJson(Map<String, dynamic> json) {
    return ReportReplyModel(
      id: json['id'] as String? ?? '',
      reportId: json['report_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Admin Platform',
      senderRole: json['sender_role'] as String? ?? 'Admin Platform',
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Model untuk catatan internal staf/admin (FR-99, FR-101).
///
/// PERINGATAN PRD FR-101: Catatan internal strictly tersembunyi dari pelapor/penyelenggara.
class ReportInternalNoteModel {
  final String id;
  final String reportId;
  final String authorName;
  final String note;
  final DateTime createdAt;

  const ReportInternalNoteModel({
    required this.id,
    required this.reportId,
    required this.authorName,
    required this.note,
    required this.createdAt,
  });

  factory ReportInternalNoteModel.fromJson(Map<String, dynamic> json) {
    return ReportInternalNoteModel(
      id: json['id'] as String? ?? '',
      reportId: json['report_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Admin',
      note: json['note'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'author_name': authorName,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Support report / trouble ticket model (PRD section 4.10, 6.8).
class SupportReportModel {
  final String id;
  final String? userId; // null for guest reporters
  final String? contactEmail;
  final String orderReference; // optional
  final String category;
  final String subject;
  final String description;
  final String status; // open, in_progress, waiting_for_user, resolved, closed
  final String priority; // low, medium, high, urgent (FR-98)
  final String ticketNumber; // human-readable reference e.g. RPT-2026-001
  final String? statusToken; // unguessable token for status page
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? handledBy;
  final List<ReportReplyModel> replies;
  final List<ReportInternalNoteModel> internalNotes;
  final List<ReportActivityModel> activities;

  const SupportReportModel({
    required this.id,
    this.userId,
    this.contactEmail,
    required this.orderReference,
    required this.category,
    this.subject = '',
    required this.description,
    required this.status,
    this.priority = 'medium',
    required this.ticketNumber,
    this.statusToken,
    required this.createdAt,
    this.updatedAt,
    this.handledBy,
    this.replies = const <ReportReplyModel>[],
    this.internalNotes = const <ReportInternalNoteModel>[],
    this.activities = const <ReportActivityModel>[],
  });

  factory SupportReportModel.fromJson(Map<String, dynamic> json) {
    return SupportReportModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      contactEmail: json['contact_email'] as String?,
      orderReference: json['order_reference'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      ticketNumber: json['ticket_number'] as String? ?? '',
      statusToken: json['status_token'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      handledBy: json['handled_by'] as String?,
      replies: (json['replies'] as List?)
              ?.map((e) => ReportReplyModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <ReportReplyModel>[],
      internalNotes: (json['internal_notes'] as List?)
              ?.map((e) => ReportInternalNoteModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <ReportInternalNoteModel>[],
      activities: (json['activities'] as List?)
              ?.map((e) => ReportActivityModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <ReportActivityModel>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'contact_email': contactEmail,
      'order_reference': orderReference,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status,
      'priority': priority,
      'ticket_number': ticketNumber,
      'status_token': statusToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'handled_by': handledBy,
      'replies': replies.map((e) => e.toJson()).toList(),
      'internal_notes': internalNotes.map((e) => e.toJson()).toList(),
      'activities': activities.map((e) => e.toJson()).toList(),
    };
  }

  SupportReportModel copyWith({
    String? id,
    String? userId,
    String? contactEmail,
    String? orderReference,
    String? category,
    String? subject,
    String? description,
    String? status,
    String? priority,
    String? ticketNumber,
    String? statusToken,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? handledBy,
    List<ReportReplyModel>? replies,
    List<ReportInternalNoteModel>? internalNotes,
    List<ReportActivityModel>? activities,
  }) {
    return SupportReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactEmail: contactEmail ?? this.contactEmail,
      orderReference: orderReference ?? this.orderReference,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      statusToken: statusToken ?? this.statusToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      handledBy: handledBy ?? this.handledBy,
      replies: replies ?? this.replies,
      internalNotes: internalNotes ?? this.internalNotes,
      activities: activities ?? this.activities,
    );
  }

  @override
  String toString() =>
      'SupportReportModel(id: $id, ticketNumber: $ticketNumber, status: $status, priority: $priority)';
}
