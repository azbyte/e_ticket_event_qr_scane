import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/constants/app_constants.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/report_management_screen.dart';
import 'package:e_ticket_event_qr_scane/models/report/report_activity_model.dart';
import 'package:e_ticket_event_qr_scane/models/report/support_report_model.dart';
import 'package:e_ticket_event_qr_scane/providers/report_provider.dart';
import 'package:e_ticket_event_qr_scane/services/report/report_service.dart';

class FakeReportService extends ReportService {
  List<SupportReportModel> _items = _seed();

  static List<SupportReportModel> _seed() => [
        SupportReportModel(
          id: 'rpt-001',
          userId: 'usr-part-002',
          contactEmail: 'dewi.lestari@example.com',
          orderReference: 'ORD-2026-9901',
          category: 'PAYMENT',
          subject: 'Kendala verifikasi pembayaran QRIS tiket festival',
          description:
              'Saya sudah mentransfer nominal tiket via QRIS simulasi namun status pembayaran belum berubah menjadi Paid.',
          status: AppConstants.reportStatusInProgress,
          priority: 'high',
          ticketNumber: 'RPT-2026-001',
          statusToken: 'st-token-dewi-9901',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
          handledBy: 'Admin Platform',
          replies: [
            ReportReplyModel(
              id: 'rep-001-1',
              reportId: 'rpt-001',
              senderName: 'Dewi Lestari',
              senderRole: 'Pelapor',
              message:
                  'Bukti transfer QRIS nomor ref 9988221 sudah berhasil terpotong dari saldo.',
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            ),
          ],
          internalNotes: const [],
          activities: [
            ReportActivityModel(
              id: 'act-001-1',
              reportId: 'rpt-001',
              action: 'Laporan Dibuat',
              note: 'Laporan dibuat dari formulir bantuan',
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            ),
          ],
        ),
        SupportReportModel(
          id: 'rpt-002',
          userId: 'usr-part-001',
          contactEmail: 'budi.santoso@example.com',
          orderReference: 'ORD-2026-9902',
          category: 'TICKET',
          subject: 'Tiket tidak muncul di menu Tiket Saya setelah sukses bayar',
          description:
              'Status pesanan sudah Paid tapi tab tiket masih kosong. Mohon bantuan sinkronisasi.',
          status: AppConstants.reportStatusResolved,
          priority: 'medium',
          ticketNumber: 'RPT-2026-002',
          statusToken: 'st-token-budi-9902',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
          handledBy: 'Admin Platform',
          replies: const [],
          internalNotes: const [],
          activities: const [],
        ),
        SupportReportModel(
          id: 'cmp-001',
          userId: 'org-001',
          contactEmail: 'organizer@techsummit.id',
          orderReference: '',
          category: 'EVENT',
          subject:
              'Permohonan percepatan review event Tech Innovation Summit',
          description:
              'Event kami telah diajukan 2 hari lalu namun status masih pending review.',
          status: AppConstants.reportStatusInProgress,
          priority: 'urgent',
          ticketNumber: 'RPT-ORG-2026-001',
          statusToken: 'tok-org-alpha-991',
          createdAt: DateTime.now().subtract(const Duration(hours: 24)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
          handledBy: 'Admin Platform',
          replies: const [],
          internalNotes: const [],
          activities: const [],
        ),
      ];

  void reset() {
    _items = _seed();
  }

  @override
  Future<List<Map<String, dynamic>>> listReports({
    Map<String, dynamic>? query,
  }) async {
    var list = List<SupportReportModel>.from(_items);
    final status = query?['status'] as String?;
    if (status != null && status.isNotEmpty && status != 'all') {
      list = list
          .where((r) => r.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    final category = query?['category'] as String?;
    if (category != null && category.isNotEmpty && category != 'all') {
      list = list
          .where((r) => r.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    final priority = query?['priority'] as String?;
    if (priority != null && priority.isNotEmpty && priority != 'all') {
      list = list
          .where((r) => r.priority.toLowerCase() == priority.toLowerCase())
          .toList();
    }
    final search = query?['search'] as String?;
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      list = list.where((r) {
        return r.ticketNumber.toLowerCase().contains(term) ||
            r.description.toLowerCase().contains(term) ||
            r.subject.toLowerCase().contains(term) ||
            (r.contactEmail?.toLowerCase().contains(term) ?? false) ||
            r.orderReference.toLowerCase().contains(term);
      }).toList();
    }
    return list.map((r) => r.toJson()).toList();
  }

  @override
  Future<Map<String, dynamic>> getReport(String reportId) async {
    final report = _items.firstWhere(
      (r) =>
          r.id == reportId ||
          r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
      orElse: () => _items.first,
    );
    return report.toJson();
  }

  @override
  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? note,
    String handledBy = 'Admin Platform',
  }) async {
    final idx = _items.indexWhere(
      (r) =>
          r.id == reportId ||
          r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
    );
    if (idx != -1) {
      final existing = _items[idx];
      final now = DateTime.now();
      final newAct = ReportActivityModel(
        id: 'act-${now.millisecondsSinceEpoch}',
        reportId: existing.id,
        staffName: handledBy,
        action: 'Status Diubah',
        note: note ?? 'Status diubah ke $status oleh $handledBy',
        createdAt: now,
      );
      final updated = existing.copyWith(
        status: status,
        updatedAt: now,
        handledBy: handledBy,
        activities: [newAct, ...existing.activities],
      );
      _items[idx] = updated;
      return updated.toJson();
    }
    return {'success': false};
  }

  @override
  Future<Map<String, dynamic>> addReply({
    required String reportId,
    required String message,
    String senderName = 'Admin Platform',
    String senderRole = 'Admin Platform',
  }) async {
    final idx = _items.indexWhere(
      (r) =>
          r.id == reportId ||
          r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
    );
    if (idx != -1) {
      final existing = _items[idx];
      final now = DateTime.now();
      final newReply = ReportReplyModel(
        id: 'rep-${now.millisecondsSinceEpoch}',
        reportId: existing.id,
        senderName: senderName,
        senderRole: senderRole,
        message: message,
        createdAt: now,
      );
      final newAct = ReportActivityModel(
        id: 'act-${now.millisecondsSinceEpoch}',
        reportId: existing.id,
        staffName: senderName,
        action: 'Balasan Terkirim',
        note: 'Balasan publik dikirim kepada pelapor',
        createdAt: now,
      );
      final updated = existing.copyWith(
        updatedAt: now,
        handledBy: senderName,
        replies: [...existing.replies, newReply],
        activities: [newAct, ...existing.activities],
      );
      _items[idx] = updated;
      return updated.toJson();
    }
    return {'success': false};
  }

  @override
  Future<Map<String, dynamic>> addInternalNote({
    required String reportId,
    required String note,
    String authorName = 'Admin Platform',
  }) async {
    final idx = _items.indexWhere(
      (r) =>
          r.id == reportId ||
          r.ticketNumber.toUpperCase() == reportId.toUpperCase(),
    );
    if (idx != -1) {
      final existing = _items[idx];
      final now = DateTime.now();
      final newNote = ReportInternalNoteModel(
        id: 'not-${now.millisecondsSinceEpoch}',
        reportId: existing.id,
        authorName: authorName,
        note: note,
        createdAt: now,
      );
      final newAct = ReportActivityModel(
        id: 'act-${now.millisecondsSinceEpoch}',
        reportId: existing.id,
        staffName: authorName,
        action: 'Catatan Internal Ditambahkan',
        note: 'Catatan internal baru dicatat (khusus admin)',
        createdAt: now,
      );
      final updated = existing.copyWith(
        updatedAt: now,
        internalNotes: [...existing.internalNotes, newNote],
        activities: [newAct, ...existing.activities],
      );
      _items[idx] = updated;
      return updated.toJson();
    }
    return {'success': false};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createReportManagementWidget(ReportProvider provider) {
    return MaterialApp(
      home: ReportManagementScreen(reportProvider: provider),
    );
  }

  group('ReportManagementScreen Widget Tests (FR-97 s.d. FR-101)', () {
    late FakeReportService fakeService;
    late ReportProvider provider;

    setUp(() {
      fakeService = FakeReportService();
      provider = ReportProvider(reportService: fakeService);
    });

    testWidgets(
        'Menampilkan daftar tiket kendala, badge prioritas, dan nomor tiket',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createReportManagementWidget(provider));
      await tester.pumpAndSettle();

      expect(find.text('Admin Support Center'), findsOneWidget);
      expect(find.text('RPT-2026-001'), findsOneWidget);
      expect(find.text('RPT-2026-002'), findsOneWidget);
      expect(find.text('RPT-ORG-2026-001'), findsOneWidget);

      // Badge prioritas
      expect(find.text('HIGH'), findsWidgets);
      expect(find.text('URGENT'), findsWidgets);
    });

    testWidgets(
        'Pencarian tiket menyaring laporan berdasarkan nomor tiket atau subjek',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createReportManagementWidget(provider));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'RPT-2026-002');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Memastikan kartu tiket RPT-2026-002 muncul dan RPT-2026-001 tersaring keluar
      expect(find.widgetWithText(Card, 'RPT-2026-002'), findsOneWidget);
      expect(find.text('RPT-2026-001'), findsNothing);
    });

    testWidgets(
        'Membuka modal detail, mengirim balasan publik, dan catatan internal (FR-99, FR-101)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createReportManagementWidget(provider));
      await tester.pumpAndSettle();

      // Tap tombol detail tiket pertama
      final detailButtons =
          find.widgetWithText(FilledButton, 'Detail & Tindak Lanjut');
      expect(detailButtons, findsWidgets);

      await tester.tap(detailButtons.first);
      await tester.pumpAndSettle();

      // Verifikasi header detail sheet
      expect(find.text('Token Status: st-token-dewi-9901'), findsOneWidget);

      // Verifikasi 3 tab: Percakapan, Internal Notes, Riwayat
      expect(find.textContaining('Percakapan'), findsOneWidget);
      expect(find.textContaining('Internal Notes'), findsOneWidget);
      expect(find.textContaining('Riwayat'), findsOneWidget);

      // 1. Kirim balasan publik
      final replyInput =
          find.widgetWithText(TextField, 'Tulis balasan publik ke pelapor...');
      expect(replyInput, findsOneWidget);

      const replyText = 'Halo, kami telah memverifikasi mutasi bank Anda.';
      await tester.enterText(replyInput, replyText);
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(
          provider.reports.first.replies.any((r) => r.message == replyText),
          isTrue);
      expect(find.text(replyText), findsOneWidget);

      // 2. Beralih ke tab Internal Notes (FR-101)
      await tester.tap(find.textContaining('Internal Notes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('STRICTLY PRIVAT untuk admin'), findsOneWidget);

      final noteInput =
          find.widgetWithText(TextField, 'Tambah catatan internal admin...');
      expect(noteInput, findsOneWidget);

      const noteText = 'Verifikasi audit log selesai dengan kode TRX-991.';
      await tester.enterText(noteInput, noteText);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(
          provider.reports.first.internalNotes
              .any((n) => n.note == noteText),
          isTrue);
      expect(find.text(noteText), findsOneWidget);

      // 3. Beralih ke tab Riwayat (FR-100)
      await tester.tap(find.textContaining('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Balasan Terkirim'), findsWidgets);
      expect(find.textContaining('Catatan Internal Ditambahkan'), findsWidgets);
    });
  });
}
