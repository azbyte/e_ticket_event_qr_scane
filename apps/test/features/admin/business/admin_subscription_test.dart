import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_audit_log_service.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_subscription_service.dart';

void main() {
  group('AdminSubscriptionService Tests (FR-79)', () {
    late AdminSubscriptionService service;
    late AdminAuditLogService auditService;

    setUp(() {
      service = AdminSubscriptionService.instance;
      auditService = AdminAuditLogService.instance;
    });

    test('Retrieves subscriptions with filter options', () async {
      final all = await service.getSubscriptions();
      expect(all.isNotEmpty, isTrue);

      final activeOnly = await service.getSubscriptions(statusFilter: 'ACTIVE');
      for (final s in activeOnly) {
        expect(s.status, equals('ACTIVE'));
      }

      final searchResult = await service.getSubscriptions(searchQuery: 'Nusantara');
      expect(searchResult.isNotEmpty, isTrue);
      expect(searchResult.first.organizerName.contains('Nusantara'), isTrue);
    });

    test('Suspends an active subscription with mandatory reason and logs to audit', () async {
      final ok = await service.suspendSubscription(
        'sub-001',
        reason: 'Verifikasi kepatuhan konten acara',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );

      expect(ok, isTrue);
      final list = await service.getSubscriptions();
      final target = list.firstWhere((s) => s.id == 'sub-001');
      expect(target.isSuspended, isTrue);

      final logs = await auditService.getAuditLogs(actionFilter: 'SUBSCRIPTION_SUSPENDED');
      expect(logs.any((l) => l.entityId == 'sub-001'), isTrue);
    });

    test('Reactivates a suspended subscription', () async {
      final ok = await service.activateSubscription(
        'sub-001',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );

      expect(ok, isTrue);
      final list = await service.getSubscriptions();
      final target = list.firstWhere((s) => s.id == 'sub-001');
      expect(target.isActive, isTrue);
    });

    test('Extends subscription active duration', () async {
      final initialList = await service.getSubscriptions();
      final initialEnd = initialList.firstWhere((s) => s.id == 'sub-001').endDate;

      final ok = await service.extendSubscription(
        'sub-001',
        14,
        reason: 'Kompensasi gangguan teknis',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );

      expect(ok, isTrue);
      final updatedList = await service.getSubscriptions();
      final updatedEnd = updatedList.firstWhere((s) => s.id == 'sub-001').endDate;
      expect(updatedEnd.difference(initialEnd).inDays, equals(14));
    });
  });
}

