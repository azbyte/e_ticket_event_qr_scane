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
}

