/// Administrative audit log service (PRD Section 6.11, FR-104, FR-105, FR-106).
library;

import 'package:flutter/widgets.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../models/admin/admin_audit_log_model.dart';

bool get _isTestEnvironment {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return true;
  }
}

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
      details:
          'Menyetujui event "Tech Innovation Summit 2026" untuk tayang publik.',
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
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      try {
        final query = <String, String>{};
        if (actionFilter != null &&
            actionFilter.isNotEmpty &&
            actionFilter != 'ALL') {
          query['action'] = actionFilter;
        }
        if (entityFilter != null &&
            entityFilter.isNotEmpty &&
            entityFilter != 'ALL') {
          query['entity_type'] = entityFilter;
        }
        if (startDate != null) {
          query['from'] = startDate.toIso8601String();
        }
        if (endDate != null) {
          query['to'] = endDate.toIso8601String();
        }

        final res = await ApiClient.instance.get(
          '/admin/audit-logs',
          query: query,
        );
        final list = (res['logs'] as List<dynamic>? ?? []);
        var entries = list
            .map(
              (item) =>
                  AdminAuditLogEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList();

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.toLowerCase().trim();
          entries = entries.where((e) {
            return e.actorName.toLowerCase().contains(q) ||
                e.action.toLowerCase().contains(q) ||
                e.entityId.toLowerCase().contains(q) ||
                (e.details?.toLowerCase().contains(q) ?? false) ||
                (e.reason?.toLowerCase().contains(q) ?? false);
          }).toList();
        }
        return entries;
      } catch (e) {
        rethrow;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    List<AdminAuditLogEntry> result = List.from(_auditLogs);

    if (actionFilter != null &&
        actionFilter.isNotEmpty &&
        actionFilter != 'ALL') {
      result = result.where((e) => e.action.contains(actionFilter)).toList();
    }

    if (entityFilter != null &&
        entityFilter.isNotEmpty &&
        entityFilter != 'ALL') {
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
  ///
  /// Pada mode API audit log platform ditulis oleh backend ke tabel
  /// `audit_logs` (mis. `moderate_event`, `PUT /admin/accounts/:id/status`,
  /// `PUT /admin/settings/:key`). Menyisipkan entri lokal di sini hanya akan
  /// menampilkan log yang tidak pernah tersimpan di database, sehingga pada
  /// mode API metode ini tidak melakukan apa pun.
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
    if (!AppConfig.mockMode && !_isTestEnvironment) return;

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
