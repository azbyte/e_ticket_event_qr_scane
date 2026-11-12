import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/event_moderation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createModerationWidget() {
    return const MaterialApp(
      home: EventModerationScreen(),
    );
  }

  group('EventModerationScreen Widget Tests (FR-12, FR-16, FR-86)', () {
    setUp(() {
      EventModerationScreen.resetMockEvents();
    });

    testWidgets('Menampilkan filter status dan event yang menunggu review secara default',
        (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      expect(find.text('Moderasi & Event Platform'), findsOneWidget);
      expect(find.text('Menunggu Review'), findsWidgets);
      expect(find.text('Butuh Revisi'), findsOneWidget);
      expect(find.text('Disetujui/Tayang'), findsOneWidget);
      expect(find.text('Ditangguhkan'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Semua Event'), findsOneWidget);

      // Event default pending review (evt-002) tampil
      expect(find.text('Workshop Flutter & Backend Modern'), findsOneWidget);
    });

    testWidgets('Aksi Setujui menyetujui event dan mengubah status',
        (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      // Cari tombol Setujui
      final approveButtons = find.widgetWithText(FilledButton, 'Setujui');
      expect(approveButtons, findsWidgets);

      await tester.tap(approveButtons.first);
      await tester.pumpAndSettle();

      // Dialog konfirmasi setujui
      expect(find.text('Setujui Event?'), findsOneWidget);
      final confirmBtn = find.widgetWithText(FilledButton, 'Setujui & Publikasikan');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // SnackBar muncul
      expect(find.textContaining('telah disetujui & tayang'), findsOneWidget);
    });

    testWidgets('Aksi Minta Revisi wajib mengisi catatan perbaikan',
        (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      final revisionButtons = find.widgetWithText(OutlinedButton, 'Minta Revisi');
      expect(revisionButtons, findsWidgets);

      await tester.tap(revisionButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Minta Revisi Event'), findsOneWidget);
      final submitBtn = find.widgetWithText(FilledButton, 'Kirim Catatan Revisi');

      // Tap tanpa isi
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Catatan revisi wajib diisi.'), findsOneWidget);

      // Isi catatan
      final noteField = find.byType(TextFormField);
      await tester.enterText(noteField, 'Mohon perjelas jadwal pemateri sesi 2.');
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Permintaan revisi dikirim'), findsOneWidget);
    });

    testWidgets('Aksi Tangguhkan pada event yang tayang (FR-88)',
        (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      // Pilih tab Disetujui/Tayang
      await tester.tap(find.text('Disetujui/Tayang'));
      await tester.pumpAndSettle();

      // Event tayang (evt-001) tampil dengan tombol Tangguhkan
      expect(find.text('Tech Innovation Summit 2026'), findsOneWidget);
      final suspendBtn = find.widgetWithText(OutlinedButton, 'Tangguhkan');
      expect(suspendBtn, findsOneWidget);

      await tester.tap(suspendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tangguhkan Event?'), findsOneWidget);

      // Isi alasan penangguhan
      final reasonField = find.byType(TextFormField);
      await tester.enterText(reasonField, 'Investigasi laporan kecurangan kuota tiket.');
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(FilledButton, 'Tangguhkan Event');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('telah ditangguhkan'), findsOneWidget);
    });

    testWidgets('Detail event menampilkan dialog/sheet informasi lengkap',
        (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      final detailButtons = find.widgetWithText(TextButton, 'Detail');
      expect(detailButtons, findsWidgets);

      await tester.tap(detailButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Deskripsi Acara:'), findsOneWidget);
      expect(find.text('Jadwal & Lokasi:'), findsOneWidget);
      expect(find.text('Tutup Detail'), findsOneWidget);

      await tester.tap(find.text('Tutup Detail'));
      await tester.pumpAndSettle();
    });
  });
}
