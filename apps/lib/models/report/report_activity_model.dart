/// Activity log for a support report (PRD sections 4.10, 6.8, FR-100).
library;

class ReportActivityModel {
  final String id;
  final String reportId;
  final String? staffId;
  final String? staffName;
  final String action;
  final String? note;
  final DateTime createdAt;

  const ReportActivityModel({
    required this.id,
    required this.reportId,
    this.staffId,
    this.staffName,
    required this.action,
    this.note,
    required this.createdAt,
  });

  factory ReportActivityModel.fromJson(Map<String, dynamic> json) {
    return ReportActivityModel(
      id: json['id'] as String? ?? '',
      reportId: json['report_id'] as String? ?? '',
      staffId: json['staff_id'] as String?,
      staffName: json['staff_name'] as String?,
      action: json['action'] as String? ?? '',
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'staff_id': staffId,
      'staff_name': staffName,
      'action': action,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReportActivityModel copyWith({
    String? id,
    String? reportId,
    String? staffId,
    String? staffName,
    String? action,
    String? note,
    DateTime? createdAt,
  }) {
    return ReportActivityModel(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      action: action ?? this.action,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'ReportActivityModel(id: $id, action: $action, staff: $staffName, time: $createdAt)';
}
