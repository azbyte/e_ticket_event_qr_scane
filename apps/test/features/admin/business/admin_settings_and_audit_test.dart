import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_audit_log_service.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_settings_service.dart';

void main() {
  group('AdminSettingsService & Fee Audit Tests (FR-102, FR-103)', () {
    late AdminSettingsService settingsService;
    late AdminAuditLogService auditService;

    setUp(() {
      settingsService = AdminSettingsService.instance;
      auditService = AdminAuditLogService.instance;
    });

    test('Retrieves initial platform settings and fee history', () async {
      final s = await settingsService.getSettings();
      expect(s.platformName.isNotEmpty, isTrue);
      expect(s.ticketCommissionRate, equals(5.0));

      final history = await settingsService.getFeeHistory();
      expect(history.isNotEmpty, isTrue);
    });

    test('Updating commission records fee change history and triggers audit log (FR-103)', () async {
      final current = await settingsService.getSettings();
      final updated = current.copyWith(ticketCommissionRate: 6.0);

      final ok = await settingsService.updateSettings(
        updated,
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
        reason: 'Penyesuaian kuartal Q3',
      );

      expect(ok, isTrue);
      final reloaded = await settingsService.getSettings();
      expect(reloaded.ticketCommissionRate, equals(6.0));

      final history = await settingsService.getFeeHistory();
      expect(history.first.newCommissionRate, equals(6.0));
      expect(history.first.reason, equals('Penyesuaian kuartal Q3'));

      final auditLogs = await auditService.getAuditLogs(actionFilter: 'SETTINGS_FEE_CHANGED');
      expect(auditLogs.any((l) => l.reason == 'Penyesuaian kuartal Q3'), isTrue);

      // Restore
      await settingsService.updateSettings(
        current,
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
        reason: 'Reset ke default',
      );
    });
  });

  group('AdminAuditLogService Tests (FR-104, FR-105, FR-106)', () {
    late AdminAuditLogService auditService;

    setUp(() {
      auditService = AdminAuditLogService.instance;
    });

    test('Audit log is append-only and supports multi-filter querying (FR-106)', () async {
      await auditService.logAction(
        actorId: 'usr-admin-01',
        actorName: 'Super Admin',
        action: 'EVENT_APPROVED',
        entityType: 'EVENT',
        entityId: 'evt-test-custom',
        details: 'Event uji coba disetujui',
      );

      final all = await auditService.getAuditLogs();
      expect(all.any((l) => l.entityId == 'evt-test-custom'), isTrue);

      final eventOnly = await auditService.getAuditLogs(entityFilter: 'EVENT');
      for (final l in eventOnly) {
        expect(l.entityType, equals('EVENT'));
      }

      final searchResult = await auditService.getAuditLogs(searchQuery: 'evt-test-custom');
      expect(searchResult.isNotEmpty, isTrue);
      expect(searchResult.first.entityId, equals('evt-test-custom'));
    });
  });
}

