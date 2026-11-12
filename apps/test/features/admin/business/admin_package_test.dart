import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/models/admin/admin_package_model.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_audit_log_service.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_package_service.dart';

void main() {
  group('AdminPackageService Tests (FR-74, FR-75, FR-76)', () {
    late AdminPackageService packageService;
    late AdminAuditLogService auditService;

    setUp(() {
      packageService = AdminPackageService.instance;
      auditService = AdminAuditLogService.instance;
    });

    test('Loads pre-seeded packages including free and paid tiers', () async {
      final list = await packageService.getPackages();
      expect(list.length, greaterThanOrEqualTo(3));

      final free = list.firstWhere((p) => p.isFree);
      expect(free.priceMonthly, equals(0));
      expect(free.maxActiveEvents, equals(2));

      final pro = list.firstWhere((p) => p.name.contains('Professional'));
      expect(pro.priceMonthly, greaterThan(0));
      expect(pro.hasExportAttendees, isTrue);
    });

    test('Creates new package and appends action to audit log', () async {
      final newPkg = AdminPackageModel(
        id: 'pkg-test-custom',
        name: 'Paket Komunitas Khusus',
        description: 'Paket custom uji coba sistem',
        priceMonthly: 150000,
        priceYearly: 1500000,
        status: 'active',
        isFree: false,
        maxActiveEvents: 4,
        maxTicketsPerEvent: 800,
        maxStaffPerEvent: 6,
        hasAdvancedReports: true,
        hasExportAttendees: true,
        hasCustomBranding: false,
        hasAnalytics: false,
        createdAt: DateTime.now(),
      );

      final created = await packageService.createPackage(
        newPkg,
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );

      expect(created.id, equals('pkg-test-custom'));
      final all = await packageService.getPackages();
      expect(all.any((p) => p.id == 'pkg-test-custom'), isTrue);

      final logs = await auditService.getAuditLogs(actionFilter: 'PACKAGE_CREATED');
      expect(logs.any((l) => l.entityId == 'pkg-test-custom'), isTrue);
    });

    test('Updates existing package and logs changes', () async {
      final all = await packageService.getPackages();
      final target = all.firstWhere((p) => p.id == 'pkg-pro');
      final updated = target.copyWith(name: 'Professional Updated');

      await packageService.updatePackage(
        updated,
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
        reason: 'Penyesuaian nama paket',
      );

      final reloaded = await packageService.getPackages();
      final pro = reloaded.firstWhere((p) => p.id == 'pkg-pro');
      expect(pro.name, equals('Professional Updated'));
    });

    test('Toggles package active and inactive status', () async {
      final initial = await packageService.getPackages();
      final target = initial.firstWhere((p) => p.id == 'pkg-pro');
      final initialStatus = target.status;

      await packageService.togglePackageStatus(
        'pkg-pro',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );

      final updated = await packageService.getPackages();
      final updatedPkg = updated.firstWhere((p) => p.id == 'pkg-pro');
      expect(updatedPkg.status, isNot(equals(initialStatus)));

      // Toggle back
      await packageService.togglePackageStatus(
        'pkg-pro',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
      );
    });

    test('Archives package without deleting historical records', () async {
      final success = await packageService.archivePackage(
        'pkg-test-custom',
        actorId: 'usr-admin-test',
        actorName: 'Test Admin',
        reason: 'Paket promosi telah berakhir',
      );

      expect(success, isTrue);
      final list = await packageService.getPackages(statusFilter: 'archived');
      expect(list.any((p) => p.id == 'pkg-test-custom'), isTrue);
    });
  });
}

