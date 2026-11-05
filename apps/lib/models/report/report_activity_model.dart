/// Activity log for a support report (PRD section 4.10).
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
}
