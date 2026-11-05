import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/organizer/events/screens/organizer_event_detail_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/event_form_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/event_management_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';

const String ownerId = OrganizerEventFixtures.demoOwnerId;

MockOrganizerEventRepository buildRepository() =>
    MockOrganizerEventRepository(latency: Duration.zero);

Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: child,
    );

void main() {
  testWidgets('daftar menampilkan event milik Owner beserta status', (
    tester,
  ) async {
    final repository = buildRepository();
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: repository,
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle(const Duration(milliseconds: 2000));

    expect(find.text('Event Saya'), findsOneWidget);
    expect(find.text('Jakarta Music Fest 2026'), findsOneWidget);
    expect(find.text('Webinar Produk Digital 2026'), findsOneWidget);
    expect(find.text('Event Milik Owner Lain'), findsNothing);
    expect(find.text('Dipublikasikan'), findsOneWidget);
    expect(find.text('Menunggu moderasi'), findsOneWidget);
  });

  testWidgets('filter draft hanya menampilkan draft', (tester) async {
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: buildRepository(),
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap chip "Draft" di bar filter (yang pertama)
    await tester.tap(find.text('Draft').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Lari Komunitas 5K'), findsOneWidget);
    expect(find.text('Jakarta Music Fest 2026'), findsNothing);
  });

  testWidgets('pencarian tanpa hasil menampilkan state empty', (tester) async {
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: buildRepository(),
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('event-search-field')),
      'zzz-tidak-ada',
    );
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada event yang cocok'), findsOneWidget);
  });

  testWidgets('owner tanpa event melihat empty state dengan aksi buat', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: MockOrganizerEventRepository.empty(),
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada event'), findsOneWidget);
    expect(find.byKey(const Key('event-create-fab')), findsOneWidget);
  });

  testWidgets('kegagalan muat menampilkan error dan dapat dicoba lagi', (
    tester,
  ) async {
    final repository = buildRepository()..setFailure(value: true);
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: repository,
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat data'), findsOneWidget);

    repository.setFailure(value: false);
    await tester.pump();
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Jakarta Music Fest 2026'), findsOneWidget);
  });

  testWidgets('repository kosong menunjukkan empty state (bukan shared)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(EventManagementScreen(
      repository: MockOrganizerEventRepository.empty(),
      ownerId: ownerId,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada event'), findsOneWidget);
  });

  testWidgets('detail event menampilkan ringkasan dan kategori tiket', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(OrganizerEventDetailScreen(
      eventId: 'evt-1001',
      ownerId: ownerId,
      repository: buildRepository(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Jakarta Music Fest 2026'), findsOneWidget);
    expect(find.text('Tiket terjual'), findsOneWidget);
    expect(find.text('Peserta terdaftar'), findsOneWidget);

    await tester.tap(find.text('Tiket'));
    await tester.pumpAndSettle();

    expect(find.text('Reguler'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Terjual 320'), findsOneWidget);
    expect(find.text('Tertahan 15'), findsOneWidget);
  });

  testWidgets('detail event milik owner lain menampilkan akses ditolak', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(OrganizerEventDetailScreen(
      eventId: 'evt-9001',
      ownerId: ownerId,
      repository: buildRepository(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Akses ditolak'), findsOneWidget);
    expect(find.text('Event Milik Owner Lain'), findsNothing);
  });

  testWidgets('form edit menyimpan perubahan judul sebagai draft', (
    tester,
  ) async {
    final repository = buildRepository();
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EventFormScreen(
                  eventId: 'evt-1004',
                  repository: repository,
                  ownerId: ownerId,
                ),
              ),
            ),
            child: const Text('Buka form'),
          ),
        ),
      ),
    )));

    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Lari Komunitas 10K',
    );
    await tester.tap(find.byKey(const Key('event-save-draft-button')));
    await tester.pumpAndSettle();

    final updated = await repository.getEvent(
      ownerId: ownerId,
      eventId: 'evt-1004',
    );
    expect(updated.title, 'Lari Komunitas 10K');
    expect(updated.status, OrganizerEventStatus.draft);
  });

  // __APPEND_SCREENS__
}
