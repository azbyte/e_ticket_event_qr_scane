import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_plans/organizer_plans_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_support/organizer_support_service.dart';
import 'package:e_ticket_event_qr_scane/services/report/report_service.dart';

void main() {
  group('OrganizerPlansService Tests (FR-76–79)', () {
    late OrganizerPlansService service;

    setUp(() {
      service = OrganizerPlansService.instance;
    });

    test('Loads 3-tier organizer plans with quotas', () async {
      final plans = await service.getAvailablePlans();
      expect(plans.length, equals(3));

      final starter = plans.firstWhere((p) => p.id == 'plan-free');
      final pro = plans.firstWhere((p) => p.id == 'plan-pro');
      final enterprise = plans.firstWhere((p) => p.id == 'plan-enterprise');

      expect(starter.priceMonthly, equals(0));
      expect(starter.maxActiveEvents, equals(2));
      expect(pro.maxActiveEvents, equals(10));
      expect(enterprise.maxActiveEvents, equals(999));
    });

    test('Simulates plan upgrade and records transaction history', () async {
      final upgradeOk = await service.changePlan('plan-pro');
      expect(upgradeOk, isTrue);

      final current = await service.getCurrentSubscription();
      expect(current.planId, equals('plan-pro'));
      expect(current.planName, equals('Professional'));

      final txs = await service.getTransactionHistory();
      expect(txs.isNotEmpty, isTrue);
      expect(txs.first.status, equals('success'));
    });

    test('Rejects unknown plans without changing the subscription', () async {
      final before = await service.getCurrentSubscription();

      expect(await service.changePlan('missing-plan'), isFalse);
      expect(await service.getCurrentSubscription(), same(before));
    });
  });

  group('OrganizerSupportService Tests (FR-95, FR-96)', () {
    late OrganizerSupportService supportService;

    setUp(() {
      supportService = OrganizerSupportService.instance;
      ReportService.resetMockData();
    });

    test('Creates complaint in the shared Admin report store', () async {
      final complaint = await supportService.submitComplaint(
        organizerId: 'org-001',
        email: 'organizer@techsummit.id',
        category: 'Moderasi Event',
        subject: 'Permohonan peninjauan kembali banner event',
        description: 'Banner event telah diperbarui sesuai panduan komunitas.',
      );
      final adminReport = await ReportService().getReport(complaint.id);

      expect(complaint.ticketNumber.startsWith('RPT-2026-'), isTrue);
      expect(complaint.statusToken.isNotEmpty, isTrue);
      expect(complaint.status, equals('open'));
      expect(complaint.category, equals('Moderasi Event'));
      expect(adminReport['id'], complaint.id);
      expect(adminReport['ticket_number'], complaint.ticketNumber);
      expect(adminReport['status_token'], complaint.statusToken);
    });

    test('Lists only complaints owned by the requested organizer', () async {
      final complaints = await supportService.listComplaints('org-001');
      expect(complaints.isNotEmpty, isTrue);
      expect(complaints.every((c) => c.organizerId == 'org-001'), isTrue);
      expect(await supportService.listComplaints('org-002'), isEmpty);
    });

    test(
      'Admin replies and status changes appear in the Organizer view',
      () async {
        final before = (await supportService.listComplaints('org-001')).single;
        final reportService = ReportService();

        await reportService.addReply(
          reportId: before.id,
          message: 'Dokumen sudah diverifikasi.',
        );
        await reportService.updateReportStatus(
          reportId: before.id,
          status: 'resolved',
        );
        await reportService.addInternalNote(
          reportId: before.id,
          note: 'Catatan internal admin.',
        );

        final after = (await supportService.listComplaints('org-001')).single;
        expect(after.id, before.id);
        expect(after.status, 'resolved');
        expect(
          after.replies.any(
            (reply) => reply.message == 'Dokumen sudah diverifikasi.',
          ),
          isTrue,
        );
      },
    );

    test('Loads FAQ guidance items', () {
      final faqs = supportService.getFaqs();
      expect(faqs.isNotEmpty, isTrue);
      expect(faqs.any((f) => f.category.contains('Moderasi')), isTrue);
      expect(faqs.any((f) => f.category.contains('Staf')), isTrue);
    });
  });
}
