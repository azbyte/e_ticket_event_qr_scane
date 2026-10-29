import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/core/constants/app_constants.dart';
import 'package:e_ticket_event_qr_scane/features/events/widgets/event_card.dart';
import 'package:e_ticket_event_qr_scane/features/tickets/widgets/qr_ticket_display.dart';
import 'package:e_ticket_event_qr_scane/models/event/event_model.dart';
import 'package:e_ticket_event_qr_scane/providers/event_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/order_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/payment_provider.dart';
import 'package:e_ticket_event_qr_scane/providers/ticket_provider.dart';
import 'package:e_ticket_event_qr_scane/services/event/event_service.dart';
import 'package:e_ticket_event_qr_scane/services/order/order_service.dart';
import 'package:e_ticket_event_qr_scane/services/payment/payment_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_service.dart';
import 'package:e_ticket_event_qr_scane/services/ticket/ticket_type_service.dart';

void main() {
  group('Developer 2 - Repository & Service Unit Tests', () {
    late EventService eventService;
    late TicketTypeService ticketTypeService;
    late OrderService orderService;
    late PaymentService paymentService;
    late TicketService ticketService;

    setUp(() {
      eventService = EventService();
      ticketTypeService = TicketTypeService();
      orderService = OrderService();
      paymentService = PaymentService();
      ticketService = TicketService();
    });

    test('Daftar event menampilkan minimal 3 event dummy', () async {
      final events = await eventService.listEvents();
      expect(events.length, greaterThanOrEqualTo(3));

      final first = events.first;
      expect(first['title'], isNotEmpty);
      expect(first['start_date_time'], isNotNull);
      expect(first['category'], isNotNull);
    });

    test('Filter event berdasarkan kategori dan pencarian kata kunci', () async {
      final techEvents = await eventService.listEvents(query: {'category': 'Teknologi'});
      expect(techEvents.every((e) => e['category'] == 'Teknologi'), isTrue);

      final musicEvents = await eventService.listEvents(query: {'q': 'Musik'});
      expect(musicEvents.isNotEmpty, isTrue);
    });

    test('Mengambil detail event dan jenis tiket terkait', () async {
      final event = await eventService.getEvent('evt-001');
      expect(event['id'], 'evt-001');
      expect(event['title'], 'Tech Inovasi Summit 2026');

      final ticketTypes = await ticketTypeService.getTicketTypesByEventId('evt-001');
      expect(ticketTypes.isNotEmpty, isTrue);
      expect(ticketTypes.first.price, greaterThanOrEqualTo(0));
      expect(ticketTypes.first.quota, greaterThan(0));
    });

    test('Alur lengkap pemesanan, simulasi pembayaran, hingga penerbitan tiket', () async {
      // 1. Buat pesanan baru
      final orderPayload = {
        'event_id': 'evt-001',
        'attendee_name': 'Rizky Developer 2',
        'attendee_email': 'rizky@test.com',
        'items': {'tt-001-reg': 2},
      };

      final orderData = await orderService.createOrder(orderPayload);
      final orderId = orderData['id'] as String;
      expect(orderId, isNotEmpty);
      expect(orderData['status'], AppConstants.orderStatusPendingPayment);
      expect(orderData['grand_total'], greaterThan(0));

      // 2. Simulasikan pembayaran berhasil
      final paymentResult = await paymentService.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: '88092812345678',
        simulateSuccess: true,
      );

      expect(paymentResult['status'], AppConstants.paymentStatusPaid);

      // 3. Verifikasi order terupdate menjadi paid
      final updatedOrder = await orderService.getOrder(orderId);
      expect(updatedOrder['status'], AppConstants.orderStatusPaid);

      // 4. Verifikasi tiket diterbitkan dengan QR token unik
      final tickets = await ticketService.listTickets();
      final issuedTickets = tickets.where((t) => t['order_id'] == orderId).toList();
      expect(issuedTickets.length, 2);

      final firstTicket = issuedTickets.first;
      expect(firstTicket['attendee_name'], 'Rizky Developer 2');
      expect(firstTicket['token'], isNotEmpty);
      expect(firstTicket['status'], AppConstants.ticketStatusValid);
      expect(firstTicket['qr_code_data'], firstTicket['token']);
    });
  });

  group('Developer 2 - Provider State Management Tests', () {
    test('EventProvider memuat daftar event dan kategori tiket', () async {
      final provider = EventProvider(EventService(), TicketTypeService());
      expect(provider.events.isEmpty, isTrue);

      final success = await provider.loadEvents();
      expect(success, isTrue);
      expect(provider.events.length, greaterThanOrEqualTo(3));

      final loadDetailSuccess = await provider.loadEvent('evt-001');
      expect(loadDetailSuccess, isTrue);
      expect(provider.selectedEvent, isNotNull);
      expect(provider.selectedEvent?.id, 'evt-001');
      expect(provider.ticketTypes.isNotEmpty, isTrue);
    });

    test('OrderProvider membuat pesanan dan menyimpan state selectedOrder', () async {
      final provider = OrderProvider(OrderService());
      final newOrder = await provider.createOrder(
        eventId: 'evt-002',
        attendeeName: 'Peserta Uji',
        attendeeEmail: 'peserta.uji@example.com',
        selectedTicketQuantities: {'tt-002-reg': 1},
      );

      expect(newOrder, isNotNull);
      expect(provider.selectedOrder?.id, newOrder?.id);
      expect(provider.orders.contains(newOrder), isTrue);
    });

    test('PaymentProvider melakukan simulasi dan mengubah status isPaid', () async {
      final paymentProvider = PaymentProvider(PaymentService());
      final success = await paymentProvider.simulatePayment(
        orderId: 'ORD-20261028-002',
        virtualAccountNumber: '8931238472910',
        simulateSuccess: true,
      );

      expect(success, isTrue);
      expect(paymentProvider.isPaid, isTrue);
      expect(paymentProvider.isPending, isFalse);
    });

    test('TicketProvider memuat daftar tiket milik peserta', () async {
      final ticketProvider = TicketProvider(TicketService());
      final success = await ticketProvider.loadTickets();

      expect(success, isTrue);
      expect(ticketProvider.tickets.isNotEmpty, isTrue);

      final ticketId = ticketProvider.tickets.first.id;
      final loadSingleSuccess = await ticketProvider.loadTicket(ticketId);
      expect(loadSingleSuccess, isTrue);
      expect(ticketProvider.selectedTicket?.id, ticketId);
    });
  });

  group('Developer 2 - Widget & UI Tests', () {
    testWidgets('QrTicketDisplay menampilkan token unik dan teks kepatuhan FR-36', (tester) async {
      const token = 'TKT-TEST-TOKEN-12345';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrTicketDisplay(ticketData: token),
          ),
        ),
      );

      expect(find.text(token), findsOneWidget);
      expect(find.text('KODE TIKET UNIK'), findsOneWidget);
      expect(find.text('Terverifikasi & Aman (FR-36 compliant)'), findsOneWidget);
    });

    testWidgets('EventCard menampilkan judul event, kategori, dan tombol navigasi', (tester) async {
      final event = EventModel(
        id: 'evt-test-999',
        organizerId: 'org-test',
        title: 'Festival Musik Indie Test',
        category: 'Musik',
        startDateTime: DateTime(2026, 11, 25, 19, 0),
        endDateTime: DateTime(2026, 11, 25, 23, 0),
        eventType: 'offline',
        location: 'Senayan Park Jakarta',
        status: AppConstants.eventStatusPublished,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(event: event),
          ),
        ),
      );

      expect(find.text('Festival Musik Indie Test'), findsOneWidget);
      expect(find.text('Musik'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Senayan Park Jakarta'), findsOneWidget);
      expect(find.text('Lihat Detail'), findsOneWidget);
    });
  });
}
