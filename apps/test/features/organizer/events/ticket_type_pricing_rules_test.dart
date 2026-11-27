import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/organizer/events/screens/organizer_ticket_type_form_screen.dart';
import 'package:e_ticket_event_qr_scane/models/event/ticket_type_model.dart';
import 'package:e_ticket_event_qr_scane/providers/event_provider.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';

void main() {
  const freeType = TicketTypeModel(
    id: 'tt-free-1',
    eventId: 'evt-1002',
    name: 'Reguler Gratis',
    price: 0,
    quota: 100,
    sold: 5,
    held: 0,
  );

  const paidType = TicketTypeModel(
    id: 'tt-paid-1',
    eventId: 'evt-1001',
    name: 'Reguler Berbayar',
    price: 150000,
    quota: 100,
    sold: 10,
    held: 2,
  );

  EventProvider buildProvider() {
    return EventProvider(
      repository: MockOrganizerEventRepository(latency: Duration.zero),
      ownerId: OrganizerEventFixtures.demoOwnerId,
    );
  }

  testWidgets('event gratis mengisi awal harga 0 dan menampilkan banner mode gratis', (
    tester,
  ) async {
    final provider = buildProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: OrganizerTicketTypeFormScreen(
          provider: provider,
          eventId: 'evt-1002',
          existingTypes: const <TicketTypeModel>[freeType],
        ),
      ),
    );

    final priceField = tester.widget<TextFormField>(
      find.byKey(const Key('ticket-price-field')),
    );
    expect(priceField.controller?.text, '0');
    expect(
      find.text(
        'Event ini bertipe Gratis (Rp 0). Kategori baru tidak boleh berbayar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('menolak input harga dengan pemisah ribuan seperti 50.000', (
    tester,
  ) async {
    final provider = buildProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: OrganizerTicketTypeFormScreen(
          provider: provider,
          eventId: 'evt-1001',
          existingTypes: const <TicketTypeModel>[paidType],
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('ticket-name-field')),
      'VIP Tambahan',
    );
    await tester.enterText(
      find.byKey(const Key('ticket-price-field')),
      '50.000',
    );
    await tester.enterText(
      find.byKey(const Key('ticket-quota-field')),
      '20',
    );

    final saveButton = find.byKey(const Key('ticket-save-button'));
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Masukkan angka harga tanpa pemisah ribuan titik (contoh: 50000).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mode edit mengunci field harga agar konsisten dengan backend', (
    tester,
  ) async {
    final provider = buildProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: OrganizerTicketTypeFormScreen(
          provider: provider,
          eventId: 'evt-1001',
          initial: paidType,
          existingTypes: const <TicketTypeModel>[paidType],
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('ticket-price-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.readOnly, isTrue);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.text('Harga kategori tiket dikunci setelah dibuat.'),
      findsOneWidget,
    );
  });
}
