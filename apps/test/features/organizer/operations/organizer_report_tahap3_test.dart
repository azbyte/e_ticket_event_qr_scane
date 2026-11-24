import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_operations_repository.dart';

void main() {
  setUp(() {
    OrganizerOperationsRepository.instance.resetMockData();
  });

  group('T3-D3-04 — Organizer Report & Financial Isolation Tahap 3 Tests', () {
    test('Laporan event menghitung proceeds dengan memisahkan komisi dan biaya gateway', () {
      final repo = OrganizerOperationsRepository.instance;
      final report = repo.getEventReport('evt-1001');

      expect(report.eventId, equals('evt-1001'));
      expect(report.grossSales, greaterThan(0));
      expect(report.platformCommission, equals(report.grossSales * 0.05));
      expect(report.organizerProceeds, equals(report.grossSales - report.platformCommission - report.paymentGatewayFee));
      expect(report.checkInRate, greaterThanOrEqualTo(0.0));
      expect(report.checkInRate, lessThanOrEqualTo(100.0));
    });

    test('Laporan mengisolasi pendapatan langganan platform internal dari proceeds organizer', () {
      final repo = OrganizerOperationsRepository.instance;
      final report = repo.getEventReport('evt-1001');

      expect(report.packageRevenue, equals(500000.0));
    });
  });
}
