/// Administrative audit log model (PRD Section 6.11, FR-104, FR-105, FR-106).
library;

class AdminAuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String actorId;
  final String actorName;
  final String actorRole; // e.g. 'ADMIN'
  final String action; // e.g. 'ACCOUNT_SUSPENDED', 'EVENT_MODERATION', 'PACKAGE_UPDATED', etc.
  final String entityType; // e.g. 'USER', 'EVENT', 'PACKAGE', 'SUBSCRIPTION', 'SETTINGS'
  final String entityId;
  final String? reason;
  final String? details;
  final Map<String, dynamic>? metadata;

  const AdminAuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.reason,
    this.details,
    this.metadata,
  });

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogEntry(
      id: json['id']?.toString() ?? '',
      timestamp: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      actorId: json['actor_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'System',
      actorRole: json['actor_role']?.toString() ?? 'ADMIN',
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      reason: json['reason']?.toString(),
      details: json['details']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}
