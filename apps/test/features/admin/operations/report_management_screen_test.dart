import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/report_management_screen.dart';
import 'package:e_ticket_event_qr_scane/providers/report_provider.dart';
import 'package:e_ticket_event_qr_scane/services/report/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createReportManagementWidget(ReportProvider provider) {
    return MaterialApp(
      home: ReportManagementScreen(reportProvider: provider),
    );
  }

  group('ReportManagementScreen Widget Tests (FR-97 s.d. FR-101)', () {
    late ReportProvider provider;

    setUp(() {
      ReportService.resetMockData();
      provider = ReportProvider();
    });

    testWidgets('Menampilkan daftar tiket kendala, badge prioritas, dan nomor tiket',
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

    testWidgets('Pencarian tiket menyaring laporan berdasarkan nomor tiket atau subjek',
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

    testWidgets('Membuka modal detail, mengirim balasan publik, dan catatan internal (FR-99, FR-101)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createReportManagementWidget(provider));
      await tester.pumpAndSettle();

      // Tap tombol detail tiket pertama
      final detailButtons = find.widgetWithText(FilledButton, 'Detail & Tindak Lanjut');
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
      final replyInput = find.widgetWithText(TextField, 'Tulis balasan publik ke pelapor...');
      expect(replyInput, findsOneWidget);

      const replyText = 'Halo, kami telah memverifikasi mutasi bank Anda.';
      await tester.enterText(replyInput, replyText);
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(provider.reports.first.replies.any((r) => r.message == replyText), isTrue);
      expect(find.text(replyText), findsOneWidget);

      // 2. Beralih ke tab Internal Notes (FR-101)
      await tester.tap(find.textContaining('Internal Notes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('STRICTLY PRIVAT untuk admin'), findsOneWidget);

      final noteInput = find.widgetWithText(TextField, 'Tambah catatan internal admin...');
      expect(noteInput, findsOneWidget);

      const noteText = 'Verifikasi audit log selesai dengan kode TRX-991.';
      await tester.enterText(noteInput, noteText);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(provider.reports.first.internalNotes.any((n) => n.note == noteText), isTrue);
      expect(find.text(noteText), findsOneWidget);

      // 3. Beralih ke tab Riwayat (FR-100)
      await tester.tap(find.textContaining('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Balasan Terkirim'), findsWidgets);
      expect(find.textContaining('Catatan Internal Ditambahkan'), findsWidgets);
    });
  });
}
