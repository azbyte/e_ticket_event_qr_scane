import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/theme/app_theme.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/events/widgets/organizer_event_card.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';

final EventModel _publishedEvent = EventModel(
  id: 'evt-1001',
  organizerId: 'org-001',
  title: 'Tech Innovation Summit 2026',
  posterUrl: 'https://demo.eticket.local/posters/music-fest.png',
  category: 'Teknologi',
  startDateTime: DateTime(2026, 12, 20, 19),
  endDateTime: DateTime(2026, 12, 20, 23),
  location: 'Grand Ballroom Hotel Indonesia',
  eventType: OrganizerEventFormat.offline,
  status: OrganizerEventStatus.published,
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: ListView(children: <Widget>[child]),
  ),
);

void main() {
  testWidgets('kartu event Organizer tampil seperti kartu Jelajahi Event', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OrganizerEventCard(
          event: _publishedEvent,
          ticketsSold: 320,
          participants: 280,
        ),
      ),
    );
    await tester.pump();

    // Poster tampil di bagian atas kartu (fallback gradien dipakai bila
    // jaringan tidak tersedia, misalnya pada widget test).
    expect(find.byType(Image), findsOneWidget);

    // Chip kategori dan format mengikuti kartu Jelajahi Event.
    expect(find.text('Teknologi'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);

    // Informasi khusus Organizer tetap tersedia.
    expect(find.text('Tech Innovation Summit 2026'), findsOneWidget);
    expect(find.text('Grand Ballroom Hotel Indonesia'), findsOneWidget);
    expect(find.text('Dipublikasikan'), findsOneWidget);
    expect(find.text('Terjual 320'), findsOneWidget);
    expect(find.text('Peserta 280'), findsOneWidget);
    expect(find.text('Tayang di halaman publik'), findsOneWidget);
    expect(find.text('Kelola Event'), findsOneWidget);
  });

  testWidgets('kartu event draft tanpa poster memakai fallback gradien', (
    tester,
  ) async {
    final draft = EventModel(
      id: 'evt-1004',
      organizerId: 'org-001',
      title: 'Lari Komunitas 5K',
      category: 'Olahraga',
      startDateTime: DateTime(2027, 2, 7, 6),
      endDateTime: DateTime(2027, 2, 7, 9),
      location: 'Lapangan Banteng, Jakarta',
      eventType: OrganizerEventFormat.offline,
      status: OrganizerEventStatus.draft,
    );

    await tester.pumpWidget(_wrap(OrganizerEventCard(event: draft)));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const Key('organizer-event-poster-fallback')),
      findsOneWidget,
    );
    expect(find.text('Olahraga'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Belum tayang di halaman publik'), findsOneWidget);
  });
}
