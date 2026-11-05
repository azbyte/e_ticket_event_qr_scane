/// Organizer operational repository (PRD sections 2, 4.5, 4.7, 4.9, 13.3 & PEMBAGIAN_TUGAS_2).
///
/// In-memory single-source-of-truth for event-scoped attendee operations,
/// assisted registration, mock scanning, reporting metrics, and offline sync.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'event_activity_service.dart';
import 'organizer_permission.dart';

class OrganizerAttendee {
  const OrganizerAttendee({
    required this.id,
    required this.eventId,
    required this.name,
    required this.email,
    required this.phone,
    required this.ticketType,
    required this.ticketCode,
    required this.orderId,
    required this.registrationMethod, // 'SELF_SERVICE' or 'ASSISTED'
    required this.orderStatus, // 'confirmed', 'pending', 'cancelled'
    required this.paymentStatus, // 'paid', 'pending', 'cancelled'
    required this.ticketStatus, // 'valid', 'checked_in', 'cancelled'
    required this.checkedIn,
    this.checkedInAt,
    this.checkedInBy,
    this.assistedBy,
    required this.createdAt,
    this.isOfflinePending = false,
  });

  final String id;
  final String eventId;
  final String name;
  final String email;
  final String phone;
  final String ticketType;
  final String ticketCode;
  final String orderId;
  final String registrationMethod;
  final String orderStatus;
  final String paymentStatus;
  final String ticketStatus;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final String? assistedBy;
  final DateTime createdAt;
  final bool isOfflinePending;

  /// Masks email to protect sensitive participant data (e.g., ah***@example.com).
  String get maskedEmail {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final namePart = parts[0];
    if (namePart.length <= 2) return '$namePart***@${parts[1]}';
    return '${namePart.substring(0, 2)}***@${parts[1]}';
  }

  /// Masks phone number for data minimization (e.g., 0812****7890).
  String get maskedPhone {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 4)}';
  }

  OrganizerAttendee copyWith({
    bool? checkedIn,
    DateTime? checkedInAt,
    String? checkedInBy,
    String? ticketStatus,
    bool? isOfflinePending,
  }) {
    return OrganizerAttendee(
      id: id,
      eventId: eventId,
      name: name,
      email: email,
      phone: phone,
      ticketType: ticketType,
      ticketCode: ticketCode,
      orderId: orderId,
      registrationMethod: registrationMethod,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      ticketStatus: ticketStatus ?? this.ticketStatus,
      checkedIn: checkedIn ?? this.checkedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedInBy: checkedInBy ?? this.checkedInBy,
      assistedBy: assistedBy,
      createdAt: createdAt,
      isOfflinePending: isOfflinePending ?? this.isOfflinePending,
    );
  }
}

class AssistedRegistrationResult {
  const AssistedRegistrationResult({
    required this.isSuccess,
    required this.message,
    this.orderId,
    this.orderReference,
    this.totalAmount,
    this.vaBank,
    this.vaNumber,
    this.vaExpiry,
    this.createdAttendees = const [],
  });

  final bool isSuccess;
  final String message;
  final String? orderId;
  final String? orderReference;
  final double? totalAmount;
  final String? vaBank;
  final String? vaNumber;
  final DateTime? vaExpiry;
  final List<OrganizerAttendee> createdAttendees;
}

class ScanCheckInResult {
  const ScanCheckInResult({
    required this.status,
    required this.message,
    required this.isSuccess,
    this.attendee,
    this.isOfflineQueued = false,
    this.isConflict = false,
  });

  final String status; // 'VALID', 'ALREADY_CHECKED_IN', 'INVALID_CODE', 'WRONG_EVENT', 'CANCELLED', 'OFFLINE_QUEUED'
  final String message;
  final bool isSuccess;
  final OrganizerAttendee? attendee;
  final bool isOfflineQueued;
  final bool isConflict;
}

class OrganizerReportMetrics {
  const OrganizerReportMetrics({
    required this.eventId,
    required this.totalOrders,
    required this.totalTicketsSold,
    required this.totalCheckedIn,
    required this.checkInRate,
    required this.grossSales,
    required this.platformCommission,
    required this.paymentGatewayFee,
    required this.organizerProceeds,
    required this.packageRevenue,
    required this.tierBreakdown,
  });

  final String eventId;
  final int totalOrders;
  final int totalTicketsSold;
  final int totalCheckedIn;
  final double checkInRate; // 0.0 - 100.0 %
  final double grossSales;
  final double platformCommission;
  final double paymentGatewayFee;
  final double
  organizerProceeds; // grossSales - platformCommission - paymentGatewayFee
  final double packageRevenue; // platform internal revenue (isolated)
  final Map<String, int> tierBreakdown;
}

class OrganizerOperationsRepository extends ChangeNotifier {
  OrganizerOperationsRepository._internal() {
    _initMockAttendees();
  }

  static final OrganizerOperationsRepository instance =
      OrganizerOperationsRepository._internal();

  final List<OrganizerAttendee> _attendees = [];
  final List<OrganizerAttendee> _offlineQueue = [];
  bool _offlineModeEnabled = false;

  bool get isOfflineModeEnabled => _offlineModeEnabled;
  List<OrganizerAttendee> get offlineQueue => List.unmodifiable(_offlineQueue);

  void toggleOfflineMode(bool enabled) {
    _offlineModeEnabled = enabled;
    notifyListeners();
  }

  void _initMockAttendees() {
    _attendees.clear();
    _offlineQueue.clear();
    final now = DateTime.now();
    _attendees.addAll([
      OrganizerAttendee(
        id: 'att-001',
        eventId: 'evt-001',
        name: 'Ahmad Fauzi',
        email: 'ahmad.fauzi@example.com',
        phone: '081234567890',
        ticketType: 'VIP Pass',
        ticketCode: 'TK-TECH-001',
        orderId: 'ORD-202610-001',
        registrationMethod: 'SELF_SERVICE',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'checked_in',
        checkedIn: true,
        checkedInAt: now.subtract(const Duration(minutes: 45)),
        checkedInBy: 'Budi Santoso (Staf)',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      OrganizerAttendee(
        id: 'att-002',
        eventId: 'evt-001',
        name: 'Dewi Lestari',
        email: 'dewi.lestari@example.com',
        phone: '081298765432',
        ticketType: 'Regular Pass',
        ticketCode: 'TK-TECH-002',
        orderId: 'ORD-202610-002',
        registrationMethod: 'SELF_SERVICE',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'checked_in',
        checkedIn: true,
        checkedInAt: now.subtract(const Duration(minutes: 20)),
        checkedInBy: 'Budi Santoso (Staf)',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      OrganizerAttendee(
        id: 'att-003',
        eventId: 'evt-001',
        name: 'Rian Pratama',
        email: 'rian.pratama@example.com',
        phone: '081311223344',
        ticketType: 'Regular Pass',
        ticketCode: 'TK-TECH-003',
        orderId: 'ORD-202610-003',
        registrationMethod: 'SELF_SERVICE',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'valid',
        checkedIn: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      OrganizerAttendee(
        id: 'att-004',
        eventId: 'evt-001',
        name: 'Siti Nurhaliza',
        email: 'siti.nurhaliza@example.com',
        phone: '081555667788',
        ticketType: 'VIP Pass',
        ticketCode: 'TK-TECH-004',
        orderId: 'ORD-202610-004',
        registrationMethod: 'ASSISTED',
        assistedBy: 'Penyelenggara Tech',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'valid',
        checkedIn: false,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      OrganizerAttendee(
        id: 'att-005',
        eventId: 'evt-001',
        name: 'Eko Prasetyo',
        email: 'eko.prasetyo@example.com',
        phone: '081777889900',
        ticketType: 'Early Bird',
        ticketCode: 'TK-TECH-005',
        orderId: 'ORD-202610-005',
        registrationMethod: 'ASSISTED',
        assistedBy: 'Budi Santoso (Staf)',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'valid',
        checkedIn: false,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      OrganizerAttendee(
        id: 'att-006',
        eventId: 'evt-001',
        name: 'Hendra Gunawan',
        email: 'hendra.gunawan@example.com',
        phone: '081999001122',
        ticketType: 'Regular Pass',
        ticketCode: 'TK-TECH-006',
        orderId: 'ORD-202610-006',
        registrationMethod: 'SELF_SERVICE',
        orderStatus: 'cancelled',
        paymentStatus: 'cancelled',
        ticketStatus: 'cancelled',
        checkedIn: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  /// Restores deterministic in-memory fixtures for isolated prototype tests.
  @visibleForTesting
  void resetMockData() {
    _offlineModeEnabled = false;
    _initMockAttendees();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // ATTENDEE QUERY & FILTERING
  // ---------------------------------------------------------------------------

  List<OrganizerAttendee> getAttendeesForEvent(
    String eventId, {
    String search = '',
    String filterStatus = 'all', // 'all', 'checked_in', 'pending', 'cancelled'
    String filterMethod = 'all', // 'all', 'SELF_SERVICE', 'ASSISTED'
    String filterTicketType = 'all',
    String filterPaymentStatus = 'all',
  }) {
    final query = search.trim().toLowerCase();

    return _attendees.where((a) {
      if (a.eventId != eventId) return false;

      // Status filter
      if (filterStatus == 'checked_in' && !a.checkedIn) return false;
      if (filterStatus == 'pending' &&
          (a.checkedIn || a.ticketStatus == 'cancelled'))
        return false;
      if (filterStatus == 'cancelled' && a.ticketStatus != 'cancelled')
        return false;

      // Method filter
      if (filterMethod != 'all' && a.registrationMethod != filterMethod)
        return false;

      // Ticket tier filter
      if (filterTicketType != 'all' && a.ticketType != filterTicketType)
        return false;
      if (filterPaymentStatus != 'all' &&
          a.paymentStatus != filterPaymentStatus)
        return false;

      // Search query filter
      if (query.isNotEmpty) {
        final match =
            a.name.toLowerCase().contains(query) ||
            a.email.toLowerCase().contains(query) ||
            a.phone.contains(query) ||
            a.ticketCode.toLowerCase().contains(query) ||
            a.orderId.toLowerCase().contains(query);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // ASSISTED REGISTRATION (FR-30–35)
  // ---------------------------------------------------------------------------

  AssistedRegistrationResult createAssistedRegistration({
    required String eventId,
    OrganizerMembershipContext? context,
    required String ordererName,
    required String ordererEmail,
    required String ordererPhone,
    required String ticketType,
    required double unitPrice,
    required List<Map<String, String>>
    attendeeDetails, // [{name, email, phone}]
    required String actorId,
    required String actorName,
  }) {
    if (context != null &&
        (context.eventId != eventId ||
            !context.hasPermission(OrganizerPermission.assistRegistration))) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message: 'Akses ditolak untuk registrasi dibantu pada event ini.',
      );
    }
    if (unitPrice < 0 || ticketType.trim().isEmpty) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message: 'Kategori tiket dan harga yang valid wajib dipilih.',
      );
    }
    // 1. Validation
    if (ordererName.trim().isEmpty || ordererEmail.trim().isEmpty) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message: 'Nama dan email pemesan wajib diisi.',
      );
    }
    if (!ordererEmail.contains('@')) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message: 'Format email pemesan tidak valid.',
      );
    }
    if (attendeeDetails.isEmpty) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message: 'Minimal satu data peserta harus disertakan.',
      );
    }
    if (attendeeDetails.length > 5) {
      return const AssistedRegistrationResult(
        isSuccess: false,
        message:
            'Batas maksimal registrasi dibantu adalah 5 tiket per pesanan.',
      );
    }

    // Check duplicate attendee emails in the same submission
    final emails = <String>{};
    for (final att in attendeeDetails) {
      if ((att['name'] ?? '').trim().isEmpty) {
        return const AssistedRegistrationResult(
          isSuccess: false,
          message: 'Nama setiap peserta wajib diisi.',
        );
      }
      final email = (att['email'] ?? '').trim().toLowerCase();
      if (email.isEmpty || !email.contains('@')) {
        return const AssistedRegistrationResult(
          isSuccess: false,
          message: 'Seluruh peserta harus memiliki email yang valid.',
        );
      }
      if (emails.contains(email)) {
        return AssistedRegistrationResult(
          isSuccess: false,
          message:
              'Duplikasi email ditemukan: $email tidak boleh didaftarkan ganda dalam pesanan yang sama.',
        );
      }
      emails.add(email);
    }

    final orderId =
        'ORD-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${100 + _attendees.length}';
    final totalAmount =
        (unitPrice * attendeeDetails.length) + (unitPrice > 0 ? 4500 : 0);
    final randomSuffix = Random().nextInt(89999) + 10000;
    final vaNumber = '88001$randomSuffix';
    final vaExpiry = DateTime.now().add(const Duration(hours: 24));

    final newAttendees = <OrganizerAttendee>[];
    var seq = 1;

    for (final att in attendeeDetails) {
      final code =
          'TK-AST-${DateTime.now().millisecondsSinceEpoch % 100000}-$seq';
      final attendee = OrganizerAttendee(
        id: 'att-${DateTime.now().millisecondsSinceEpoch}-$seq',
        eventId: eventId,
        name: att['name']!.trim(),
        email: att['email']!.trim(),
        phone: att['phone']?.trim() ?? ordererPhone.trim(),
        ticketType: ticketType,
        ticketCode: code,
        orderId: orderId,
        registrationMethod: 'ASSISTED',
        assistedBy: actorName,
        orderStatus: 'pending',
        paymentStatus: 'pending', // Do NOT force mark paid!
        ticketStatus: 'valid',
        checkedIn: false,
        createdAt: DateTime.now(),
      );
      newAttendees.add(attendee);
      seq++;
    }

    _attendees.addAll(newAttendees);

    // Log to Event Activity Stream
    EventActivityLogger.instance.log(
      eventId: eventId,
      actorId: actorId,
      actorName: actorName,
      action: 'ASSISTED_REGISTRATION',
      summary:
          '$actorName membuat pesanan dibantu $orderId (${newAttendees.length} tiket $ticketType).',
      metadata: {
        'order_id': orderId,
        'count': newAttendees.length,
        'total': totalAmount,
      },
    );

    notifyListeners();

    return AssistedRegistrationResult(
      isSuccess: true,
      message:
          'Registrasi dibantu berhasil dibuat dengan metode Virtual Account.',
      orderId: orderId,
      orderReference: orderId,
      totalAmount: totalAmount,
      vaBank: 'BCA Virtual Account (Demo)',
      vaNumber: vaNumber,
      vaExpiry: vaExpiry,
      createdAttendees: newAttendees,
    );
  }

  // ---------------------------------------------------------------------------
  // SCANNER & CHECK-IN (FR-50–59)
  // ---------------------------------------------------------------------------

  ScanCheckInResult validateAndCheckIn({
    required String eventId,
    required String ticketCode,
    required OrganizerMembershipContext context,
    bool autoCommitCheckIn = true,
  }) {
    if (context.eventId != eventId) {
      return const ScanCheckInResult(
        status: 'DENIED',
        message: 'Akses ditolak: keanggotaan tidak berlaku untuk event ini.',
        isSuccess: false,
      );
    }
    if (!context.hasPermission(OrganizerPermission.scanTicket)) {
      return const ScanCheckInResult(
        status: 'DENIED',
        message: 'Akses ditolak: Anda tidak memiliki izin SCAN_TICKET.',
        isSuccess: false,
      );
    }
    if (context.hasPermission(OrganizerPermission.checkInTicket) &&
        !context.hasPermission(OrganizerPermission.scanTicket)) {
      return const ScanCheckInResult(
        status: 'DENIED',
        message: 'Akses ditolak: izin scan tiket diperlukan.',
        isSuccess: false,
      );
    }

    final cleanCode = ticketCode.trim().toUpperCase();

    // Simulated edge cases
    if (cleanCode.contains('INVALID') || cleanCode == 'INV-999') {
      EventActivityLogger.instance.log(
        eventId: eventId,
        actorId: context.userId,
        actorName: context.userName,
        action: 'CHECK_IN_FAILED',
        summary: 'Percobaan scan token invalid: "$cleanCode".',
      );
      return const ScanCheckInResult(
        status: 'INVALID_CODE',
        message: 'Kode QR tiket tidak ditemukan dalam basis data sistem.',
        isSuccess: false,
      );
    }

    if (cleanCode.contains('CANCELLED') || cleanCode == 'TK-TECH-006') {
      return const ScanCheckInResult(
        status: 'CANCELLED',
        message: 'Tiket ini telah dibatalkan karena pesanan dibatalkan/refund.',
        isSuccess: false,
      );
    }

    if (cleanCode.startsWith('TK-WRONG') || cleanCode.startsWith('TK-MUSIC')) {
      return const ScanCheckInResult(
        status: 'WRONG_EVENT',
        message: 'Tiket ini terdaftar untuk acara lain (bukan event ini).',
        isSuccess: false,
      );
    }

    // Lookup attendee in repository
    final matchIndex = _attendees.indexWhere(
      (a) => a.ticketCode.toUpperCase() == cleanCode && a.eventId == eventId,
    );

    if (matchIndex == -1) {
      return const ScanCheckInResult(
        status: 'INVALID_CODE',
        message: 'Tiket tidak ditemukan pada event yang sedang dikelola.',
        isSuccess: false,
      );
    }

    final attendee = _attendees[matchIndex];

    if (attendee.checkedIn) {
      return ScanCheckInResult(
        status: 'ALREADY_CHECKED_IN',
        message:
            'Peringatan: Tiket ${attendee.ticketCode} sudah pernah digunakan check-in oleh ${attendee.checkedInBy ?? "staf"} pada ${attendee.checkedInAt?.hour}:${attendee.checkedInAt?.minute.toString().padLeft(2, '0')} WIB.',
        isSuccess: false,
        attendee: attendee,
      );
    }

    // If check-in execution is requested
    if (autoCommitCheckIn) {
      if (!context.hasPermission(OrganizerPermission.checkInTicket)) {
        return ScanCheckInResult(
          status: 'VALID_SCAN_ONLY',
          message: 'Tiket Valid, tetapi Anda hanya memiliki izin memindai (tidak berhak konfirmasi check-in).',
          isSuccess: true,
          attendee: attendee,
        );
      }

      // Offline mode handling
      if (_offlineModeEnabled) {
        final offlineAttendee = attendee.copyWith(
          checkedIn: true,
          checkedInAt: DateTime.now(),
          checkedInBy: '${context.userName} (Offline)',
          ticketStatus: 'checked_in',
          isOfflinePending: true,
        );
        _attendees[matchIndex] = offlineAttendee;
        _offlineQueue.add(offlineAttendee);

        EventActivityLogger.instance.log(
          eventId: eventId,
          actorId: context.userId,
          actorName: context.userName,
          action: 'CHECK_IN_OFFLINE',
          summary:
              'Check-in offline tersimpan lokal untuk ${attendee.name} (${attendee.ticketCode}).',
        );

        notifyListeners();

        return ScanCheckInResult(
          status: 'OFFLINE_QUEUED',
          message: 'Mode offline aktif: Check-in disimpan di antrean lokal (belum diverifikasi server).',
          isSuccess: true,
          attendee: offlineAttendee,
          isOfflineQueued: true,
        );
      }

      // Online check-in execution
      final updatedAttendee = attendee.copyWith(
        checkedIn: true,
        checkedInAt: DateTime.now(),
        checkedInBy: context.userName,
        ticketStatus: 'checked_in',
      );
      _attendees[matchIndex] = updatedAttendee;

      EventActivityLogger.instance.log(
        eventId: eventId,
        actorId: context.userId,
        actorName: context.userName,
        action: 'CHECK_IN_SUCCESS',
        summary:
            'Check-in berhasil untuk ${attendee.name} (${attendee.ticketCode} - ${attendee.ticketType}).',
      );

      notifyListeners();

      return ScanCheckInResult(
        status: 'VALID',
        message: 'Check-in berhasil! Selamat datang, ${attendee.name}.',
        isSuccess: true,
        attendee: updatedAttendee,
      );
    }

    return ScanCheckInResult(
      status: 'VALID',
      message: 'Tiket valid dan siap untuk di-check-in.',
      isSuccess: true,
      attendee: attendee,
    );
  }

  /// Syncs offline queue check-in items with simulated conflict detection.
  Map<String, dynamic> syncOfflineQueue(String eventId) {
    var syncedCount = 0;
    var conflictCount = 0;

    for (final item in List.from(_offlineQueue)) {
      if (item.eventId != eventId) continue;
      if (item.ticketCode.contains('CONFLICT')) {
        conflictCount++;
      } else {
        syncedCount++;
        _offlineQueue.remove(item);
      }
    }

    notifyListeners();

    return {
      'synced': syncedCount,
      'conflicts': conflictCount,
      'remaining': _offlineQueue.length,
      'message':
          'Sinkronisasi selesai: $syncedCount berhasil disinkronkan, $conflictCount konflik data check-in.',
    };
  }

  // ---------------------------------------------------------------------------
  // REPORTING & METRICS (FR-70–73)
  // ---------------------------------------------------------------------------

  OrganizerReportMetrics getEventReport(
    String eventId, {
    String? ticketType,
    DateTime? from,
    DateTime? through,
  }) {
    final eventAttendees = _attendees.where((a) {
      if (a.eventId != eventId) return false;
      if (ticketType != null && a.ticketType != ticketType) return false;
      if (from != null && a.createdAt.isBefore(from)) return false;
      if (through != null && a.createdAt.isAfter(through)) return false;
      return true;
    }).toList();
    final validOrPaid = eventAttendees
        .where((a) => a.paymentStatus == 'paid')
        .toList();

    final totalOrders = {for (final a in validOrPaid) a.orderId}.length;
    final totalTickets = validOrPaid.length;
    final totalCheckedIn = validOrPaid.where((a) => a.checkedIn).length;
    final checkInRate = totalTickets > 0
        ? (totalCheckedIn / totalTickets) * 100
        : 0.0;

    // Approximate financial metrics based on tier
    double gross = 0;
    final tiers = <String, int>{};

    for (final a in validOrPaid) {
      tiers[a.ticketType] = (tiers[a.ticketType] ?? 0) + 1;
      if (a.ticketType == 'VIP Pass') {
        gross += 750000;
      } else if (a.ticketType == 'Early Bird') {
        gross += 250000;
      } else {
        gross += 350000;
      }
    }

    final platformCommission = gross * 0.05; // 5% fee
    final gatewayFee = totalOrders * 4500.0;
    final proceeds = gross - platformCommission - gatewayFee;

    return OrganizerReportMetrics(
      eventId: eventId,
      totalOrders: totalOrders,
      totalTicketsSold: totalTickets,
      totalCheckedIn: totalCheckedIn,
      checkInRate: checkInRate,
      grossSales: gross,
      platformCommission: platformCommission,
      paymentGatewayFee: gatewayFee,
      organizerProceeds: proceeds > 0 ? proceeds : 0,
      packageRevenue: 500000.0, // Platform internal subscription plan
      tierBreakdown: tiers,
    );
  }

  String exportAttendeesCsv(
    String eventId,
    OrganizerMembershipContext context,
  ) {
    if (context.eventId != eventId) {
      throw Exception(
        'Akses ditolak: keanggotaan tidak berlaku untuk event ini.',
      );
    }
    if (!context.hasPermission(OrganizerPermission.exportParticipants)) {
      throw Exception(
        'Akses ditolak: Anda tidak memiliki izin EXPORT_PARTICIPANTS.',
      );
    }

    final attendees = getAttendeesForEvent(eventId);
    final buffer = StringBuffer();
    buffer.writeln(
      'ID,Nama,Email,No_HP,Kategori_Tiket,Kode_Tiket,No_Pesanan,Metode,Status_Tiket,CheckIn,Waktu_CheckIn',
    );

    for (final a in attendees) {
      buffer.writeln(
        '${a.id},"${a.name}","${a.maskedEmail}","${a.maskedPhone}","${a.ticketType}","${a.ticketCode}","${a.orderId}","${a.registrationMethod}","${a.ticketStatus}",${a.checkedIn ? "YA" : "TIDAK"},"${a.checkedInAt?.toIso8601String() ?? "-"}"',
      );
    }

    EventActivityLogger.instance.log(
      eventId: eventId,
      actorId: context.userId,
      actorName: context.userName,
      action: 'EXPORT_ATTENDEES',
      summary:
          '${context.userName} mengekspor ${attendees.length} data peserta ke CSV.',
    );

    return buffer.toString();
  }
}
