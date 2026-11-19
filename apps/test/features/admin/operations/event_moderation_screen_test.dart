import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/event_moderation_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrganizerEventRepository repository;

  Widget createModerationWidget() =>
      MaterialApp(home: EventModerationScreen(repository: repository));

  group('EventModerationScreen Widget Tests (FR-12, FR-16, FR-86)', () {
    setUp(() {
      EventModerationScreen.resetMockEvents();
      repository = MockOrganizerEventRepository(latency: Duration.zero);
    });

    testWidgets(
      'Menampilkan filter status dan event yang menunggu review secara default',
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

        // Event default pending review (evt-1002) tampil dari store Organizer.
        expect(find.text('Webinar Produk Digital 2026'), findsOneWidget);
      },
    );

    testWidgets('Admin memantau event pending tanpa approval manual', (
      tester,
    ) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      expect(find.text('Webinar Produk Digital 2026'), findsOneWidget);
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Minta Revisi'), findsNothing);
    });

    testWidgets('Admin tidak meminta revisi secara manual', (tester) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      expect(find.text('Butuh Revisi'), findsOneWidget);
      await tester.tap(find.text('Butuh Revisi'));
      await tester.pumpAndSettle();

      expect(find.text('Minta Revisi'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('Aksi Tangguhkan pada event yang tayang (FR-88)', (
      tester,
    ) async {
      await tester.pumpWidget(createModerationWidget());
      await tester.pumpAndSettle();

      // Pilih tab Disetujui/Tayang
      await tester.tap(find.text('Disetujui/Tayang'));
      await tester.pumpAndSettle();

      // Event tayang (evt-1001) tampil dengan tombol Tangguhkan
      expect(find.text('Tech Innovation Summit 2026'), findsOneWidget);
      final suspendBtn = find.widgetWithText(OutlinedButton, 'Tangguhkan');
      expect(suspendBtn, findsWidgets);

      await tester.tap(suspendBtn.first);
      await tester.pumpAndSettle();

      expect(find.text('Tangguhkan Event?'), findsOneWidget);

      // Isi alasan penangguhan
      final reasonField = find.byType(TextFormField);
      await tester.enterText(
        reasonField,
        'Investigasi laporan kecurangan kuota tiket.',
      );
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(FilledButton, 'Tangguhkan Event');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('telah ditangguhkan'), findsOneWidget);
    });

    testWidgets('Detail event menampilkan dialog/sheet informasi lengkap', (
      tester,
    ) async {
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
