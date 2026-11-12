/// Admin transactions and platform revenue service (PRD Section 6.7, FR-89 s.d. FR-93).
library;

import '../../models/admin/admin_transaction_revenue_model.dart';

class AdminRevenueService {
  AdminRevenueService._internal();
  static final AdminRevenueService instance = AdminRevenueService._internal();
  factory AdminRevenueService() => instance;

  // Mock ticket transactions
  final List<AdminTicketTransactionModel> _ticketTransactions = [
    AdminTicketTransactionModel(
      id: 'trx-tkt-001',
      orderId: 'ord-1001',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      customerName: 'Ahmad Fauzi',
      grossAmount: 750000.0,
      commissionRateSnapshot: 0.05,
      commissionAmount: 37500.0,
      netOrganizerAmount: 712500.0,
      paymentMethod: 'BCA Virtual Account (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    AdminTicketTransactionModel(
      id: 'trx-tkt-002',
      orderId: 'ord-1002',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      customerName: 'Rina Wijaya',
      grossAmount: 1500000.0,
      commissionRateSnapshot: 0.05,
      commissionAmount: 75000.0,
      netOrganizerAmount: 1425000.0,
      paymentMethod: 'QRIS (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    AdminTicketTransactionModel(
      id: 'trx-tkt-003',
      orderId: 'ord-1003',
      eventId: 'evt-002',
      eventTitle: 'Workshop Flutter & Backend Modern',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      customerName: 'Budi Santoso',
      grossAmount: 350000.0,
      commissionRateSnapshot: 0.05,
      commissionAmount: 17500.0,
      netOrganizerAmount: 332500.0,
      paymentMethod: 'Mandiri Virtual Account (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AdminTicketTransactionModel(
      id: 'trx-tkt-004',
      orderId: 'ord-1004',
      eventId: 'evt-003',
      eventTitle: 'Konser Musik Akustik Senja',
      organizerId: 'org-003',
      organizerName: 'Festival Musik Kreatif',
      customerName: 'Dewi Lestari',
      grossAmount: 500000.0,
      commissionRateSnapshot: 0.05,
      commissionAmount: 25000.0,
      netOrganizerAmount: 475000.0,
      paymentMethod: 'GoPay (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AdminTicketTransactionModel(
      id: 'trx-tkt-005',
      orderId: 'ord-1005',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      customerName: 'Indra Gunawan',
      grossAmount: 250000.0,
      commissionRateSnapshot: 0.05,
      commissionAmount: 12500.0,
      netOrganizerAmount: 237500.0,
      paymentMethod: 'BNI Virtual Account (Demo)',
      status: 'PENDING',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  // Mock subscription package payment transactions
  final List<AdminPackageTransactionModel> _packageTransactions = [
    AdminPackageTransactionModel(
      id: 'trx-pkg-001',
      invoiceNumber: 'INV-PLAN-2026-001',
      subscriptionId: 'sub-001',
      organizerId: 'org-001',
      organizerName: 'PT Event Nusantara',
      planId: 'pkg-pro',
      planName: 'Professional Plan (1 Bulan)',
      amount: 299000.0,
      paymentMethod: 'BCA Virtual Account (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    AdminPackageTransactionModel(
      id: 'trx-pkg-002',
      invoiceNumber: 'INV-PLAN-2026-002',
      subscriptionId: 'sub-003',
      organizerId: 'org-003',
      organizerName: 'Festival Musik Kreatif',
      planId: 'pkg-enterprise',
      planName: 'Enterprise Plan (1 Bulan)',
      amount: 999000.0,
      paymentMethod: 'Mandiri Bill Payment (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    AdminPackageTransactionModel(
      id: 'trx-pkg-003',
      invoiceNumber: 'INV-PLAN-2026-003',
      subscriptionId: 'sub-004',
      organizerId: 'org-004',
      organizerName: 'EO Cahaya Mandiri',
      planId: 'pkg-pro',
      planName: 'Professional Plan (1 Bulan)',
      amount: 299000.0,
      paymentMethod: 'BNI Virtual Account (Demo)',
      status: 'PAID',
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
  ];

  /// Calculates aggregated revenue summary for platform monitoring (FR-89 s.d. FR-93).
  Future<AdminRevenueSummary> getRevenueSummary({String period = 'all'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // Filter paid ticket transactions
    final paidTickets = _ticketTransactions.where((t) => t.status == 'PAID').toList();
    final grossTicketSales = paidTickets.fold<double>(0.0, (acc, t) => acc + t.grossAmount);
    final ticketCommission = paidTickets.fold<double>(0.0, (acc, t) => acc + t.commissionAmount);

    // Filter paid package transactions
    final paidPackages = _packageTransactions.where((p) => p.status == 'PAID').toList();
    final packageRevenue = paidPackages.fold<double>(0.0, (acc, p) => acc + p.amount);

    final totalPlatformRevenue = ticketCommission + packageRevenue;

    return AdminRevenueSummary(
      grossTicketSales: grossTicketSales,
      ticketCommissionRevenue: ticketCommission,
      packageRevenue: packageRevenue,
      totalPlatformRevenue: totalPlatformRevenue,
      totalTicketOrders: paidTickets.length,
      totalPackageInvoices: paidPackages.length,
      period: period,
    );
  }

  /// Lists ticket transactions.
  Future<List<AdminTicketTransactionModel>> getTicketTransactions({
    String? statusFilter,
    String? searchQuery,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminTicketTransactionModel> list = List.from(_ticketTransactions);

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      list = list.where((t) => t.status == statusFilter).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((t) {
        return t.orderId.toLowerCase().contains(q) ||
            t.eventTitle.toLowerCase().contains(q) ||
            t.customerName.toLowerCase().contains(q) ||
            t.organizerName.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Lists subscription package payment transactions.
  Future<List<AdminPackageTransactionModel>> getPackageTransactions({
    String? statusFilter,
    String? searchQuery,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminPackageTransactionModel> list = List.from(_packageTransactions);

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      list = list.where((p) => p.status == statusFilter).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((p) {
        return p.invoiceNumber.toLowerCase().contains(q) ||
            p.organizerName.toLowerCase().contains(q) ||
            p.planName.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

