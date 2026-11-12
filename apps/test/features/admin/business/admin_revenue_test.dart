import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_revenue_service.dart';

void main() {
  group('AdminRevenueService & Segregation Tests (FR-89 s.d. FR-93)', () {
    late AdminRevenueService service;

    setUp(() {
      service = AdminRevenueService.instance;
    });

    test('Calculates platform revenue strictly segregated from gross ticket sales (FR-90, FR-93)', () async {
      final summary = await service.getRevenueSummary();

      expect(summary.grossTicketSales, greaterThan(0));
      expect(summary.ticketCommissionRevenue, greaterThan(0));
      expect(summary.packageRevenue, greaterThan(0));

      // Key Financial Rule: totalPlatformRevenue = ticketCommissionRevenue + packageRevenue
      final expectedPlatformRevenue =
          summary.ticketCommissionRevenue + summary.packageRevenue;
      expect(summary.totalPlatformRevenue, equals(expectedPlatformRevenue));

      // Crucial assertion: Gross ticket sales must NOT be counted as platform revenue
      expect(summary.totalPlatformRevenue, lessThan(summary.grossTicketSales));
      expect(summary.totalTicketOrders, greaterThan(0));
      expect(summary.totalPackageInvoices, greaterThan(0));
    });

    test('Ticket transactions preserve snapshot commission rates (FR-91)', () async {
      final trxs = await service.getTicketTransactions();
      expect(trxs.isNotEmpty, isTrue);

      for (final t in trxs) {
        expect(t.grossAmount, greaterThan(0));
        expect(t.commissionRateSnapshot, greaterThan(0));
        expect(t.commissionAmount, equals(t.grossAmount * t.commissionRateSnapshot));
        expect(t.netOrganizerAmount, equals(t.grossAmount - t.commissionAmount));
      }
    });

    test('Package transactions list records paid subscription revenue', () async {
      final pkgTrxs = await service.getPackageTransactions();
      expect(pkgTrxs.isNotEmpty, isTrue);

      final paid = pkgTrxs.where((p) => p.status == 'PAID');
      expect(paid.isNotEmpty, isTrue);
      for (final p in paid) {
        expect(p.amount, greaterThan(0));
        expect(p.invoiceNumber.startsWith('INV-PLAN-'), isTrue);
      }
    });
  });
}

