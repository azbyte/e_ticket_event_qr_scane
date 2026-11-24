import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/tickets/screens/ticket_detail_screen.dart';
import 'package:e_ticket_event_qr_scane/features/tickets/widgets/qr_ticket_display.dart';
import 'package:e_ticket_event_qr_scane/models/ticket/ticket_model.dart';

void main() {
  group('TicketDetailScreen Widget Tests (T3-D2-02)', () {
    testWidgets('Tiket aktif menampilkan QR code asli QrTicketDisplay', (tester) async {
      final activeTicket = TicketModel(
        id: 'tkt-test-active',
        orderId: 'ord-test-01',
        eventId: 'evt-test-01',
        ticketTypeId: 'VIP',
        attendeeName: 'Budi Test',
        attendeeEmail: 'budi@example.com',
        token: 'TOKEN-ACTIVE-SECRET-12345678',
        status: 'valid',
        issuedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TicketDetailScreen(
            ticketId: activeTicket.id,
            ticket: activeTicket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VALID / SIAP CHECK-IN'), findsOneWidget);
      expect(find.byType(QrTicketDisplay), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-image')), findsOneWidget);
      expect(find.text('TOKEN-ACTIVE-SECRET-12345678'), findsOneWidget);
    });

    testWidgets('Tiket pending menampilkan info Menunggu Pembayaran dan menyembunyikan QR code', (tester) async {
      final pendingTicket = TicketModel(
        id: 'tkt-test-pending',
        orderId: 'ord-test-02',
        eventId: 'evt-test-01',
        ticketTypeId: 'Regular',
        attendeeName: 'Siti Pending',
        token: '',
        status: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TicketDetailScreen(
            ticketId: pendingTicket.id,
            ticket: pendingTicket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BELUM DIBAYAR'), findsOneWidget);
      expect(find.text('Menunggu Pembayaran'), findsOneWidget);
      expect(find.byType(QrTicketDisplay), findsNothing);
      expect(find.byKey(const Key('ticket-qr-image')), findsNothing);
    });

    testWidgets('Tiket cancelled menampilkan info Tiket Dibatalkan dan menyembunyikan QR code', (tester) async {
      final cancelledTicket = TicketModel(
        id: 'tkt-test-cancelled',
        orderId: 'ord-test-03',
        eventId: 'evt-test-01',
        ticketTypeId: 'Regular',
        attendeeName: 'Andi Batal',
        token: 'CANCELLED-TOKEN',
        status: 'cancelled',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TicketDetailScreen(
            ticketId: cancelledTicket.id,
            ticket: cancelledTicket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DIBATALKAN'), findsOneWidget);
      expect(find.text('Tiket Dibatalkan'), findsOneWidget);
      expect(find.byType(QrTicketDisplay), findsNothing);
    });

    testWidgets('Responsif pada layar 360 px tanpa overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeTicket = TicketModel(
        id: 'tkt-test-360',
        orderId: 'ord-test-360',
        eventId: 'evt-test-360',
        ticketTypeId: 'VIP Pass Exclusive',
        attendeeName: 'Ahmad Fauzi bin Abdullah',
        attendeeEmail: 'ahmad.fauzi@longdomainexample.co.id',
        token: 'TOKEN-360-TEST-LONG-ALPHANUMERIC-VALUE',
        status: 'valid',
        issuedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TicketDetailScreen(
            ticketId: activeTicket.id,
            ticket: activeTicket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VALID / SIAP CHECK-IN'), findsOneWidget);
    });
  });
}
