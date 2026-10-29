import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import '../../models/order/order_item_model.dart';
import '../../models/order/order_model.dart';
import '../../models/payment/payment_model.dart';
import '../../models/ticket/ticket_model.dart';

/// In-memory mock data repository for Attendee flow.
///
/// Ensures end-to-end coherence between Event, Order, Payment, and Ticket issuance
/// during development and offline demo mode.
class MockAttendeeRepository {
  MockAttendeeRepository._();
  static final MockAttendeeRepository instance = MockAttendeeRepository._();

  // ---------------------------------------------------------------------------
  // Mock Events
  // ---------------------------------------------------------------------------
  final List<EventModel> _events = [
    EventModel(
      id: 'evt-001',
      organizerId: 'org-001',
      title: 'Tech Inovasi Summit 2026',
      description:
          'Konferensi teknologi terbesar di Indonesia yang menghadirkan praktisi AI, Web3, Cloud Computing, dan Mobile Engineering. Dilengkapi sesi keynote dari pakar global, panel diskusi industri, dan networking lounge.',
      posterUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80',
      category: 'Teknologi',
      startDateTime: DateTime(2026, 11, 15, 9, 0),
      endDateTime: DateTime(2026, 11, 16, 17, 30),
      timeZone: 'WIB',
      location: 'Jakarta Convention Center (JCC) Senayan, Jakarta Pusat',
      onlineUrl: 'https://stream.techinovasi2026.id',
      eventType: 'hybrid',
      contactInfo: 'support@techinovasi2026.id | +62 812-3456-7890',
      status: AppConstants.eventStatusPublished,
      isPublic: true,
      publicUrl: 'https://event.techinovasi2026.id',
      registrationQrUrl: 'https://api.qrserver.com/v1/create-qr-code/?data=evt-001',
      createdAt: DateTime(2026, 10, 1),
    ),
    EventModel(
      id: 'evt-002',
      organizerId: 'org-002',
      title: 'Festival Musik Nusantara 2026',
      description:
          'Perayaan harmoni musik tanah air menyatukan deretan musisi indie, folk, pop, dan orkestra tradisional. Menghadirkan 3 panggung terbuka, instalasi seni cahaya spektakuler, serta ragam kuliner khas nusantara.',
      posterUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
      category: 'Musik',
      startDateTime: DateTime(2026, 12, 5, 14, 0),
      endDateTime: DateTime(2026, 12, 5, 23, 30),
      timeZone: 'WIB',
      location: 'Stadion Madya Gelora Bung Karno, Senayan, Jakarta',
      eventType: 'offline',
      contactInfo: 'halo@festivalmusiknusantara.id | +62 821-9876-5432',
      status: AppConstants.eventStatusPublished,
      isPublic: true,
      publicUrl: 'https://festivalmusiknusantara.id',
      createdAt: DateTime(2026, 10, 5),
    ),
    EventModel(
      id: 'evt-003',
      organizerId: 'org-001',
      title: 'Workshop UI/UX & Design System',
      description:
          'Pelatihan intensif 1 hari membangun antarmuka mobile & web modern berstandar industri dengan Figma tokens, prototyping interaktif, dan usability testing.',
      posterUrl: 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=800&q=80',
      category: 'Workshop',
      startDateTime: DateTime(2026, 11, 20, 10, 0),
      endDateTime: DateTime(2026, 11, 20, 16, 0),
      timeZone: 'WIB',
      location: 'D.Lab Co-Working Space, Menteng, Jakarta Pusat',
      eventType: 'offline',
      contactInfo: 'workshop@digitalacademy.id',
      status: AppConstants.eventStatusPublished,
      isPublic: true,
      publicUrl: 'https://digitalacademy.id/workshops/uiux',
      createdAt: DateTime(2026, 10, 10),
    ),
    EventModel(
      id: 'evt-004',
      organizerId: 'org-003',
      title: 'Seminar Nasional AI & Karir Digital',
      description:
          'Membongkar masa depan automasi kecerdasan buatan, peluang karir global bagi talenta muda Indonesia, dan panduan praktis adopsi generative AI di tempat kerja.',
      posterUrl: 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&q=80',
      category: 'Seminar',
      startDateTime: DateTime(2026, 11, 28, 13, 0),
      endDateTime: DateTime(2026, 11, 28, 16, 30),
      timeZone: 'WIB',
      onlineUrl: 'https://meet.google.com/live-seminar-ai-2026',
      eventType: 'online',
      contactInfo: 'seminar@kampusdigital.ac.id',
      status: AppConstants.eventStatusPublished,
      isPublic: true,
      publicUrl: 'https://seminar.kampusdigital.ac.id',
      createdAt: DateTime(2026, 10, 15),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Mock Ticket Types per Event
  // ---------------------------------------------------------------------------
  final List<TicketTypeModel> _ticketTypes = [
    // Event 1 - Tech Inovasi Summit
    const TicketTypeModel(
      id: 'tt-001-reg',
      eventId: 'evt-001',
      name: 'Regular Pass',
      description: 'Akses seminar utama 2 hari, seminar kit resmi, dan makan siang.',
      price: 150000,
      quota: 500,
      sold: 120,
    ),
    const TicketTypeModel(
      id: 'tt-001-vip',
      eventId: 'evt-001',
      name: 'VIP All-Access',
      description: 'Akses kursi baris depan, VIP Lounge, workshop privat, dan Gala Dinner.',
      price: 450000,
      quota: 100,
      sold: 75,
    ),
    const TicketTypeModel(
      id: 'tt-001-onl',
      eventId: 'evt-001',
      name: 'Online Streaming Pass',
      description: 'Siaran langsung HD 2 hari, akses rekaman, dan sertifikat digital.',
      price: 50000,
      quota: 1000,
      sold: 210,
    ),

    // Event 2 - Festival Musik Nusantara
    const TicketTypeModel(
      id: 'tt-002-ebd',
      eventId: 'evt-002',
      name: 'Early Bird (Habis)',
      description: 'Harga spesial pembeli pertama.',
      price: 175000,
      quota: 300,
      sold: 300,
    ),
    const TicketTypeModel(
      id: 'tt-002-reg',
      eventId: 'evt-002',
      name: 'Festival Regular',
      description: 'Akses seluruh panggung dan area bazaar musik nusantara.',
      price: 250000,
      quota: 1500,
      sold: 820,
    ),
    const TicketTypeModel(
      id: 'tt-002-vip',
      eventId: 'evt-002',
      name: 'VIP Experience',
      description: 'Jalur masuk khusus, platform tonton VIP, dan official t-shirt.',
      price: 600000,
      quota: 200,
      sold: 150,
    ),

    // Event 3 - Workshop UI/UX
    const TicketTypeModel(
      id: 'tt-003-stu',
      eventId: 'evt-003',
      name: 'Student Pass',
      description: 'Harga bersubsidi untuk mahasiswa aktif (wajib tunjukkan KTM).',
      price: 150000,
      quota: 20,
      sold: 14,
    ),
    const TicketTypeModel(
      id: 'tt-003-pro',
      eventId: 'evt-003',
      name: 'Professional Pass',
      description: 'Termasuk file asset Figma berlisensi komersial dan review portfolio.',
      price: 350000,
      quota: 40,
      sold: 26,
    ),

    // Event 4 - Seminar AI
    const TicketTypeModel(
      id: 'tt-004-fre',
      eventId: 'evt-004',
      name: 'Tiket Masuk Gratis',
      description: 'Akses sesi webinar interaktif dan tanya jawab.',
      price: 0,
      quota: 500,
      sold: 340,
    ),
    const TicketTypeModel(
      id: 'tt-004-cer',
      eventId: 'evt-004',
      name: 'Akses + E-Sertifikat Resmi',
      description: 'Akses webinar, ringkasan materi pembicara, dan e-sertifikat terverifikasi.',
      price: 50000,
      quota: 300,
      sold: 95,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Mock Orders
  // ---------------------------------------------------------------------------
  final List<OrderModel> _orders = [
    OrderModel(
      id: 'ORD-20261020-001',
      userId: 'usr-attendee-01',
      eventId: 'evt-001',
      eventTitle: 'Tech Inovasi Summit 2026',
      status: AppConstants.orderStatusPaid,
      totalAmount: 300000,
      serviceFee: 5000,
      grandTotal: 305000,
      items: const [
        OrderItemModel(
          id: 'item-001',
          orderId: 'ORD-20261020-001',
          ticketTypeId: 'tt-001-reg',
          ticketTypeName: 'Regular Pass',
          quantity: 2,
          unitPrice: 150000,
          subtotal: 300000,
        ),
      ],
      paymentReference: 'VA-BCA-88092812345678',
      createdAt: DateTime(2026, 10, 20, 14, 20),
      updatedAt: DateTime(2026, 10, 20, 14, 35),
    ),
    OrderModel(
      id: 'ORD-20261028-002',
      userId: 'usr-attendee-01',
      eventId: 'evt-002',
      eventTitle: 'Festival Musik Nusantara 2026',
      status: AppConstants.orderStatusPendingPayment,
      totalAmount: 250000,
      serviceFee: 5000,
      grandTotal: 255000,
      items: const [
        OrderItemModel(
          id: 'item-002',
          orderId: 'ORD-20261028-002',
          ticketTypeId: 'tt-002-reg',
          ticketTypeName: 'Festival Regular',
          quantity: 1,
          unitPrice: 250000,
          subtotal: 250000,
        ),
      ],
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      paymentReference: 'VA-MANDIRI-8931238472910',
      createdAt: DateTime(2026, 10, 28, 10, 15),
      updatedAt: DateTime(2026, 10, 28, 10, 15),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Mock Payments
  // ---------------------------------------------------------------------------
  final Map<String, Map<String, String>> _orderAttendeeInfo = {};
  final Map<String, PaymentModel> _payments = {
    'ORD-20261020-001': PaymentModel(
      id: 'pay-001',
      orderId: 'ORD-20261020-001',
      method: 'virtual_account',
      status: AppConstants.paymentStatusPaid,
      amount: 305000,
      virtualAccountNumber: '88092812345678',
      vaBank: 'BCA Virtual Account',
      paidAt: DateTime(2026, 10, 20, 14, 35),
      notes: 'Pembayaran terverifikasi otomatis (Simulasi)',
    ),
    'ORD-20261028-002': PaymentModel(
      id: 'pay-002',
      orderId: 'ORD-20261028-002',
      method: 'virtual_account',
      status: AppConstants.paymentStatusPending,
      amount: 255000,
      virtualAccountNumber: '8931238472910',
      vaBank: 'Mandiri Virtual Account',
      expiredAt: DateTime.now().add(const Duration(hours: 24)),
      notes: 'Selesaikan pembayaran sebelum batas waktu berakhir.',
    ),
  };

  // ---------------------------------------------------------------------------
  // Mock Issued Tickets
  // ---------------------------------------------------------------------------
  final List<TicketModel> _tickets = [
    TicketModel(
      id: 'tkt-001-a',
      orderId: 'ORD-20261020-001',
      eventId: 'evt-001',
      ticketTypeId: 'tt-001-reg',
      attendeeName: 'Ahmad Rizky Pratama',
      attendeeEmail: 'ahmad.rizky@example.com',
      token: 'TIS2026-REG-98A1B2C3',
      status: AppConstants.ticketStatusValid,
      qrCodeData: 'TIS2026-REG-98A1B2C3',
      issuedAt: DateTime(2026, 10, 20, 14, 35),
    ),
    TicketModel(
      id: 'tkt-001-b',
      orderId: 'ORD-20261020-001',
      eventId: 'evt-001',
      ticketTypeId: 'tt-001-reg',
      attendeeName: 'Budi Santoso',
      attendeeEmail: 'budi.santoso@example.com',
      token: 'TIS2026-REG-47D5E6F7',
      status: AppConstants.ticketStatusCheckedIn,
      qrCodeData: 'TIS2026-REG-47D5E6F7',
      issuedAt: DateTime(2026, 10, 20, 14, 35),
      checkedInAt: DateTime(2026, 11, 15, 9, 15),
      checkedInByStaffId: 'staff-01',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Event Methods
  // ---------------------------------------------------------------------------
  List<EventModel> getEvents({String? query, String? category}) {
    return _events.where((e) {
      if (category != null && category.isNotEmpty && category != 'Semua') {
        if (e.category?.toLowerCase() != category.toLowerCase()) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase();
        final matchesTitle = e.title.toLowerCase().contains(q);
        final matchesDesc = e.description?.toLowerCase().contains(q) ?? false;
        final matchesLoc = e.location?.toLowerCase().contains(q) ?? false;
        return matchesTitle || matchesDesc || matchesLoc;
      }
      return true;
    }).toList();
  }

  EventModel getEventById(String eventId) {
    try {
      return _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      throw NotFoundException('Event dengan ID $eventId tidak ditemukan.');
    }
  }

  // ---------------------------------------------------------------------------
  // Ticket Type Methods
  // ---------------------------------------------------------------------------
  List<TicketTypeModel> getTicketTypesByEventId(String eventId) {
    return _ticketTypes.where((tt) => tt.eventId == eventId).toList();
  }

  TicketTypeModel getTicketTypeById(String ticketTypeId) {
    try {
      return _ticketTypes.firstWhere((tt) => tt.id == ticketTypeId);
    } catch (_) {
      throw NotFoundException('Kategori tiket dengan ID $ticketTypeId tidak ditemukan.');
    }
  }

  // ---------------------------------------------------------------------------
  // Order Methods
  // ---------------------------------------------------------------------------
  List<OrderModel> getOrders({String? query}) {
    final list = List<OrderModel>.from(_orders);
    list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return list;
  }

  OrderModel getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      throw NotFoundException('Pesanan dengan ID $orderId tidak ditemukan.');
    }
  }

  OrderModel createOrder({
    required String eventId,
    required String attendeeName,
    required String attendeeEmail,
    String? attendeePhone,
    required Map<String, int> selectedTicketQuantities, // ticketTypeId -> quantity
  }) {
    final event = getEventById(eventId);
    final orderId = 'ORD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${Random().nextInt(9000) + 1000}';

    final orderItems = <OrderItemModel>[];
    double totalAmount = 0;

    for (final entry in selectedTicketQuantities.entries) {
      if (entry.value <= 0) continue;
      final ticketType = getTicketTypeById(entry.key);

      if (ticketType.availableQuota < entry.value) {
        throw ValidationException('Kuota untuk kategori "${ticketType.name}" tidak mencukupi.');
      }

      final subtotal = ticketType.price * entry.value;
      totalAmount += subtotal;

      orderItems.add(
        OrderItemModel(
          id: 'item-${Random().nextInt(90000) + 10000}',
          orderId: orderId,
          ticketTypeId: ticketType.id,
          ticketTypeName: ticketType.name,
          quantity: entry.value,
          unitPrice: ticketType.price,
          subtotal: subtotal,
        ),
      );
    }

    if (orderItems.isEmpty) {
      throw ValidationException('Silakan pilih minimal 1 tiket untuk melanjutkan.');
    }

    // Free event has no service fee; paid event has 5000 IDR service fee
    final serviceFee = totalAmount > 0 ? 5000.0 : 0.0;
    final grandTotal = totalAmount + serviceFee;

    // Generate simulated Virtual Account number
    final vaNumber = '8809${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

    final newOrder = OrderModel(
      id: orderId,
      userId: 'guest-${attendeeEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      eventId: event.id,
      eventTitle: event.title,
      status: grandTotal == 0 ? AppConstants.orderStatusPaid : AppConstants.orderStatusPendingPayment,
      totalAmount: totalAmount,
      serviceFee: serviceFee,
      grandTotal: grandTotal,
      items: orderItems,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      paymentReference: 'VA-BCA-$vaNumber',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _orders.insert(0, newOrder);

    // Create payment entry
    final payment = PaymentModel(
      id: 'pay-${Random().nextInt(90000) + 10000}',
      orderId: orderId,
      method: 'virtual_account',
      status: grandTotal == 0 ? AppConstants.paymentStatusPaid : AppConstants.paymentStatusPending,
      amount: grandTotal,
      virtualAccountNumber: vaNumber,
      vaBank: 'BCA Virtual Account',
      paidAt: grandTotal == 0 ? DateTime.now() : null,
      expiredAt: DateTime.now().add(const Duration(hours: 24)),
      notes: grandTotal == 0 ? 'Pendaftaran event gratis terverifikasi otomatis.' : 'Selesaikan pembayaran via transfer ke Virtual Account.',
    );
    _payments[orderId] = payment;
    _orderAttendeeInfo[orderId] = {'name': attendeeName, 'email': attendeeEmail};

    // If order was free, issue tickets immediately!
    if (grandTotal == 0) {
      _issueTicketsForOrder(newOrder, attendeeName, attendeeEmail);
    }

    return newOrder;
  }

  // ---------------------------------------------------------------------------
  // Payment Methods
  // ---------------------------------------------------------------------------
  PaymentModel getPaymentByOrderId(String orderId) {
    final payment = _payments[orderId];
    if (payment != null) return payment;

    // If not found, build default from order
    final order = getOrderById(orderId);
    final fallbackPayment = PaymentModel(
      id: 'pay-${Random().nextInt(90000) + 10000}',
      orderId: orderId,
      method: 'virtual_account',
      status: order.isPaid ? AppConstants.paymentStatusPaid : AppConstants.paymentStatusPending,
      amount: order.grandTotal,
      virtualAccountNumber: '88092812345678',
      vaBank: 'BCA Virtual Account',
      paidAt: order.isPaid ? (order.updatedAt ?? DateTime.now()) : null,
      expiredAt: order.expiresAt,
    );
    _payments[orderId] = fallbackPayment;
    return fallbackPayment;
  }

  PaymentModel simulatePayment({
    required String orderId,
    required String virtualAccountNumber,
    bool simulateSuccess = true,
  }) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex == -1) {
      throw NotFoundException('Pesanan dengan ID $orderId tidak ditemukan.');
    }

    final order = _orders[orderIndex];

    if (!simulateSuccess) {
      final failedPayment = PaymentModel(
        id: 'pay-${Random().nextInt(90000) + 10000}',
        orderId: orderId,
        method: 'virtual_account',
        status: AppConstants.paymentStatusFailed,
        amount: order.grandTotal,
        virtualAccountNumber: virtualAccountNumber,
        vaBank: 'BCA Virtual Account',
        notes: 'Simulasi pembayaran gagal atau dibatalkan pengguna.',
      );
      _payments[orderId] = failedPayment;
      return failedPayment;
    }

    // Success simulation
    final now = DateTime.now();
    final updatedOrder = OrderModel(
      id: order.id,
      userId: order.userId,
      eventId: order.eventId,
      eventTitle: order.eventTitle,
      status: AppConstants.orderStatusPaid,
      totalAmount: order.totalAmount,
      serviceFee: order.serviceFee,
      grandTotal: order.grandTotal,
      items: order.items,
      expiresAt: order.expiresAt,
      paymentReference: order.paymentReference,
      createdAt: order.createdAt,
      updatedAt: now,
    );
    _orders[orderIndex] = updatedOrder;

    final paidPayment = PaymentModel(
      id: 'pay-${Random().nextInt(90000) + 10000}',
      orderId: orderId,
      method: 'virtual_account',
      status: AppConstants.paymentStatusPaid,
      amount: order.grandTotal,
      virtualAccountNumber: virtualAccountNumber,
      vaBank: 'BCA Virtual Account',
      paidAt: now,
      notes: 'Pembayaran simulasi berhasil diverifikasi.',
    );
    _payments[orderId] = paidPayment;

    // Issue tickets for order items
    final attendee = _orderAttendeeInfo[orderId] ?? {'name': 'Peserta Terdaftar', 'email': 'peserta@example.com'};
    _issueTicketsForOrder(updatedOrder, attendee['name']!, attendee['email']!);

    return paidPayment;
  }

  void _issueTicketsForOrder(OrderModel order, String attendeeName, String attendeeEmail) {
    for (final item in order.items) {
      for (int i = 0; i < item.quantity; i++) {
        final token = 'TKT-${order.eventId.toUpperCase().replaceAll('-', '')}-${Random().nextInt(900000) + 100000}';
        final ticket = TicketModel(
          id: 'tkt-${Random().nextInt(900000) + 100000}',
          orderId: order.id,
          eventId: order.eventId,
          ticketTypeId: item.ticketTypeId,
          attendeeName: attendeeName,
          attendeeEmail: attendeeEmail,
          token: token,
          status: AppConstants.ticketStatusValid,
          qrCodeData: token,
          issuedAt: DateTime.now(),
        );
        _tickets.insert(0, ticket);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Ticket Methods
  // ---------------------------------------------------------------------------
  List<TicketModel> getTickets({String? query}) {
    final list = List<TicketModel>.from(_tickets);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      return list.where((t) =>
          t.attendeeName.toLowerCase().contains(q) ||
          t.token.toLowerCase().contains(q) ||
          t.orderId.toLowerCase().contains(q) ||
          t.eventId.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  TicketModel getTicketById(String ticketId) {
    try {
      return _tickets.firstWhere((t) => t.id == ticketId);
    } catch (_) {
      throw NotFoundException('Tiket dengan ID $ticketId tidak ditemukan.');
    }
  }
}
