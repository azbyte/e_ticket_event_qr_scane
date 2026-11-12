/// Administrative audit log service (PRD Section 6.11, FR-104, FR-105, FR-106).
library;

import '../../models/admin/admin_audit_log_model.dart';

class AdminAuditLogService {
  AdminAuditLogService._internal();
  static final AdminAuditLogService instance = AdminAuditLogService._internal();
  factory AdminAuditLogService() => instance;

  final List<AdminAuditLogEntry> _auditLogs = [
    AdminAuditLogEntry(
      id: 'aud-001',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      actorRole: 'ADMIN',
      action: 'EVENT_APPROVED',
      entityType: 'EVENT',
      entityId: 'evt-1001',
      details: 'Menyetujui event "Tech Innovation Summit 2026" untuk tayang publik.',
      metadata: {'eventTitle': 'Tech Innovation Summit 2026'},
    ),
    AdminAuditLogEntry(
      id: 'aud-002',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      actorRole: 'ADMIN',
      action: 'ACCOUNT_SUSPENDED',
      entityType: 'USER',
      entityId: 'usr-org-bad',
      reason: 'Terindikasi melakukan duplikasi tiket dan pelanggaran hak cipta poster.',
      details: 'Menonaktifkan akun organizer nakal@fakeevent.com.',
      metadata: {'userEmail': 'nakal@fakeevent.com'},
    ),
    AdminAuditLogEntry(
      id: 'aud-003',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      actorRole: 'ADMIN',
      action: 'SETTINGS_FEE_CHANGED',
      entityType: 'SETTINGS',
      entityId: 'cfg-fee-01',
      reason: 'Penyesuaian promosi awal tahun untuk mendukung komunitas lokal.',
      details: 'Mengubah persentase komisi tiket dari 7% menjadi 5%.',
      metadata: {'oldRate': 7.0, 'newRate': 5.0},
    ),
    AdminAuditLogEntry(
      id: 'aud-004',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      actorRole: 'ADMIN',
      action: 'PACKAGE_UPDATED',
      entityType: 'PACKAGE',
      entityId: 'pkg-pro',
      details: 'Menambah kuota tiket maksimal paket Pro menjadi 2.000 tiket.',
      metadata: {'packageName': 'Professional Plan'},
    ),
    AdminAuditLogEntry(
      id: 'aud-005',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      actorRole: 'ADMIN',
      action: 'SUBSCRIPTION_EXTENDED',
      entityType: 'SUBSCRIPTION',
      entityId: 'sub-001',
      reason: 'Kompensasi kendala teknis gateway pembayaran.',
      details: 'Perpanjangan masa aktif langganan selama 7 hari.',
      metadata: {'organizer': 'PT Event Nusantara'},
    ),
  ];

  /// Retrieves audit log entries with optional filters (append-only view).
  Future<List<AdminAuditLogEntry>> getAuditLogs({
    String? actionFilter,
    String? entityFilter,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminAuditLogEntry> result = List.from(_auditLogs);

    if (actionFilter != null && actionFilter.isNotEmpty && actionFilter != 'ALL') {
      result = result.where((e) => e.action.contains(actionFilter)).toList();
    }

    if (entityFilter != null && entityFilter.isNotEmpty && entityFilter != 'ALL') {
      result = result.where((e) => e.entityType == entityFilter).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((e) {
        return e.actorName.toLowerCase().contains(q) ||
            e.action.toLowerCase().contains(q) ||
            e.entityId.toLowerCase().contains(q) ||
            (e.details?.toLowerCase().contains(q) ?? false) ||
            (e.reason?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (startDate != null) {
      result = result.where((e) => e.timestamp.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      result = result.where((e) => e.timestamp.isBefore(endDate)).toList();
    }

    // Sort newest first
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  /// Appends a new administrative audit log record (FR-104, FR-105).
  Future<void> logAction({
    required String actorId,
    required String actorName,
    String actorRole = 'ADMIN',
    required String action,
    required String entityType,
    required String entityId,
    String? reason,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = AdminAuditLogEntry(
      id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      action: action,
      entityType: entityType,
      entityId: entityId,
      reason: reason,
      details: details,
      metadata: metadata,
    );
    _auditLogs.insert(0, entry);
  }
}

