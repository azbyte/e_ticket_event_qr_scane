import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/constants/app_constants.dart';
import 'package:e_ticket_event_qr_scane/models/report/support_report_model.dart';
import 'package:e_ticket_event_qr_scane/providers/report_provider.dart';
import 'package:e_ticket_event_qr_scane/services/report/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportService & ReportProvider Tests (FR-94 s.d. FR-101)', () {
    late ReportService service;
    late ReportProvider provider;

    setUp(() {
      ReportService.resetMockData();
      service = ReportService();
      provider = ReportProvider(reportService: service);
    });

    test('Memuat daftar laporan awal termasuk tiket bersama rpt-001 dan cmp-001', () async {
      final reports = await service.listReports();
      expect(reports.isNotEmpty, isTrue);

      final ids = reports.map((r) => r['id']).toList();
      expect(ids.contains('rpt-001'), isTrue);
      expect(ids.contains('cmp-001'), isTrue); // Sesuai keselarasan dengan keluhan Organizer
    });

    test('Filter laporan berdasarkan status, kategori, prioritas, dan pencarian', () async {
      // Filter status Open
      final openReports = await service.listReports(query: {'status': AppConstants.reportStatusOpen});
      expect(openReports.every((r) => r['status'] == AppConstants.reportStatusOpen), isTrue);

      // Filter kategori PAYMENT
      final paymentReports = await service.listReports(query: {'category': 'PAYMENT'});
      expect(paymentReports.every((r) => r['category'] == 'PAYMENT'), isTrue);

      // Filter prioritas urgent
      final urgentReports = await service.listReports(query: {'priority': 'urgent'});
      expect(urgentReports.every((r) => r['priority'] == 'urgent'), isTrue);

      // Pencarian kata kunci
      final searchResult = await service.listReports(query: {'search': 'Dewi'});
      expect(searchResult.isNotEmpty, isTrue);
      expect(searchResult.first['contact_email'], contains('dewi'));
    });

    test('Memperbarui status dan prioritas laporan dengan riwayat aktivitas', () async {
      // Perbarui status
      final updateResult = await service.updateReportStatus(
        reportId: 'rpt-003',
        status: AppConstants.reportStatusInProgress,
        note: 'Staf sedang memverifikasi identitas',
        handledBy: 'Admin Testing',
      );
      expect(updateResult['status'], AppConstants.reportStatusInProgress);

      // Periksa detail
      final reportData = await service.getReport('rpt-003');
      final report = SupportReportModel.fromJson(reportData);
      expect(report.status, AppConstants.reportStatusInProgress);
      expect(report.activities.isNotEmpty, isTrue);
      expect(report.activities.first.action, 'Status Diubah');

      // Perbarui prioritas
      final prioResult = await service.updateReportPriority(
        reportId: 'rpt-003',
        priority: 'urgent',
        handledBy: 'Admin Testing',
      );
      expect(prioResult['priority'], 'urgent');
    });

    test('Menambahkan balasan publik dan catatan internal rahasia (FR-99, FR-101)', () async {
      // Tambah balasan
      await service.addReply(
        reportId: 'rpt-001',
        message: 'Pembayaran Anda telah diverifikasi oleh tim finance.',
        senderName: 'Admin Platform',
        senderRole: 'Admin Platform',
      );

      // Tambah catatan internal
      await service.addInternalNote(
        reportId: 'rpt-001',
        note: 'Dokumen mutasi rekening disimpan di folder vault.',
        authorName: 'Admin Security',
      );

      final updatedData = await service.getReport('rpt-001');
      final updated = SupportReportModel.fromJson(updatedData);

      expect(updated.replies.any((r) => r.message.contains('diverifikasi')), isTrue);
      expect(updated.internalNotes.any((n) => n.note.contains('folder vault')), isTrue);
      expect(updated.activities.any((a) => a.action == 'Catatan Internal Ditambahkan'), isTrue);
    });

    test('ReportProvider mengelola state reaktif dengan benar', () async {
      expect(provider.reports.isEmpty, isTrue);

      final loaded = await provider.loadReports();
      expect(loaded, isTrue);
      expect(provider.reports.isNotEmpty, isTrue);

      // Ambil single report
      final singleLoaded = await provider.loadReport('rpt-002');
      expect(singleLoaded, isTrue);
      expect(provider.selectedReport?.id, 'rpt-002');

      // Update status via provider
      final statusOk = await provider.updateStatus(
        reportId: 'rpt-002',
        status: AppConstants.reportStatusClosed,
      );
      expect(statusOk, isTrue);
      expect(provider.reports.firstWhere((r) => r.id == 'rpt-002').status, AppConstants.reportStatusClosed);

      // Kirim balasan via provider
      final replyOk = await provider.addReply(
        reportId: 'rpt-002',
        message: 'Tiket berhasil ditutup.',
      );
      expect(replyOk, isTrue);

      // Tambah catatan internal via provider
      final noteOk = await provider.addInternalNote(
        reportId: 'rpt-002',
        note: 'Kasus selesai tanpa kendala.',
      );
      expect(noteOk, isTrue);
    });
  });
}

