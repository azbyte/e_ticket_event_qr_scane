/// Admin transactions and platform revenue service (PRD Section 6.7, FR-89 s.d. FR-93).
library;

import 'package:flutter/widgets.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../models/admin/admin_transaction_revenue_model.dart';

bool get _isTestEnvironment {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return true;
  }
}

class AdminRevenueService {
  AdminRevenueService._internal();
  static final AdminRevenueService instance = AdminRevenueService._internal();
  factory AdminRevenueService() => instance;

  // Mock ticket transactions
  final List<AdminTicketTransactionModel> _ticketTransactions = [
    AdminTicketTransactionModel(
      id: 'trx-tkt-001',
      orderId: 'ord-1001',
      eventId: 'evt-1001',
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
      eventId: 'evt-1001',
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
      eventId: 'evt-1001',
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
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final query = <String, String>{};
      final start = _periodStart(period, DateTime.now());
      if (start != null) {
        query['from'] = start.toIso8601String();
        query['to'] = DateTime.now().toIso8601String();
      }
      final res = await ApiClient.instance.get(
        '/revenue/admin/summary',
        query: query.isEmpty ? null : query,
      );
      final summary = res['summary'] as Map<String, dynamic>? ?? {};
      final bySource = (res['by_source'] as List<dynamic>? ?? []);
      double pkgRev = 0.0;
      int pkgInvoices = 0;
      for (final s in bySource) {
        if (s is Map<String, dynamic> && s['source'] == 'SUBSCRIPTION') {
          pkgRev = (s['platform_revenue'] as num? ?? 0).toDouble();
          pkgInvoices = (s['transaction_count'] as num? ?? 0).toInt();
        }
      }
      final gross = (summary['gross_amount'] as num? ?? 0).toDouble();
      final commission = (summary['commission_amount'] as num? ?? 0).toDouble();
      final platformRev = (summary['platform_revenue'] as num? ?? (commission + pkgRev)).toDouble();
      final totalOrders = (summary['transaction_count'] as num? ?? 0).toInt() - pkgInvoices;

      return AdminRevenueSummary(
        grossTicketSales: gross,
        ticketCommissionRevenue: commission,
        packageRevenue: pkgRev,
        totalPlatformRevenue: platformRev,
        totalTicketOrders: totalOrders > 0 ? totalOrders : 0,
        totalPackageInvoices: pkgInvoices,
        period: period,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return getRevenueSummarySnapshot(period: period);
  }

  /// Synchronous local snapshot used by dashboard widgets that render mock data.
  AdminRevenueSummary getRevenueSummarySnapshot({String period = 'all'}) {
    final cutoff = _periodStart(period, DateTime.now());
    bool isIncluded(DateTime date) => cutoff == null || !date.isBefore(cutoff);
    final periodTickets = _ticketTransactions
        .where((transaction) => isIncluded(transaction.createdAt))
        .toList(growable: false);
    final paidTickets = periodTickets
        .where((transaction) => transaction.status == 'PAID')
        .toList(growable: false);
    final grossTicketSales = paidTickets.fold<double>(
      0.0,
      (acc, t) => acc + t.grossAmount,
    );
    final ticketCommission = paidTickets.fold<double>(
      0.0,
      (acc, t) => acc + t.commissionAmount,
    );

    final paidPackages = _packageTransactions
        .where((transaction) => transaction.status == 'PAID')
        .where((transaction) => isIncluded(transaction.createdAt))
        .toList(growable: false);
    final packageRevenue = paidPackages.fold<double>(
      0.0,
      (acc, p) => acc + p.amount,
    );

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

  DateTime? _periodStart(String period, DateTime now) {
    switch (period) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case '7d':
      case 'this_week':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case 'this_month':
        return DateTime(now.year, now.month);
      case 'this_year':
        return DateTime(now.year);
      case 'all':
      default:
        return null;
    }
  }

  /// Lists ticket transactions.
  Future<List<AdminTicketTransactionModel>> getTicketTransactions({
    String? statusFilter,
    String? searchQuery,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final res = await ApiClient.instance.get('/revenue/admin/transactions');
      final list = (res['transactions'] as List<dynamic>? ?? []);
      final parsed = <AdminTicketTransactionModel>[];
      for (final item in list) {
        if (item is Map<String, dynamic> && item['order_payment_id'] != null) {
          final gross = (item['gross_amount'] as num? ?? 0).toDouble();
          final commission = (item['commission_amount'] as num? ?? 0).toDouble();
          final net = (item['organizer_net_amount'] as num? ?? (gross - commission)).toDouble();
          parsed.add(
            AdminTicketTransactionModel(
              id: item['id']?.toString() ?? '',
              orderId: item['order_number']?.toString() ?? item['order_payment_id']?.toString() ?? '-',
              eventId: item['event_id']?.toString() ?? '',
              eventTitle: item['event_title']?.toString() ?? 'Event',
              organizerId: item['organizer_id']?.toString() ?? '',
              organizerName: item['organizer_name']?.toString() ?? 'Penyelenggara',
              customerName: item['customer_name']?.toString() ?? item['user_id']?.toString() ?? 'Peserta',
              grossAmount: gross,
              commissionRateSnapshot: gross > 0 ? commission / gross : 0.05,
              commissionAmount: commission,
              netOrganizerAmount: net,
              paymentMethod: item['payment_method']?.toString() ?? 'Virtual Account',
              status: (item['status'] ?? 'PAID').toString().toUpperCase(),
              createdAt: item['created_at'] != null
                  ? (DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now())
                  : DateTime.now(),
            ),
          );
        }
      }
      var filtered = parsed;
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        filtered = filtered.where((t) => t.status == statusFilter).toList();
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        filtered = filtered.where((t) {
          return t.orderId.toLowerCase().contains(q) ||
              t.eventTitle.toLowerCase().contains(q) ||
              t.customerName.toLowerCase().contains(q) ||
              t.organizerName.toLowerCase().contains(q);
        }).toList();
      }
      return filtered;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminTicketTransactionModel> list = List.from(_ticketTransactions);

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'ALL') {
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
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final res = await ApiClient.instance.get('/revenue/admin/transactions');
      final list = (res['transactions'] as List<dynamic>? ?? []);
      final parsed = <AdminPackageTransactionModel>[];
      for (final item in list) {
        if (item is Map<String, dynamic> && item['subscription_payment_id'] != null) {
          parsed.add(
            AdminPackageTransactionModel(
              id: item['id']?.toString() ?? '',
              invoiceNumber: item['invoice_number']?.toString() ?? 'INV-${item['id']}',
              subscriptionId: item['subscription_id']?.toString() ?? item['subscription_payment_id']?.toString() ?? '-',
              organizerId: item['organizer_id']?.toString() ?? '',
              organizerName: item['organizer_name']?.toString() ?? 'Penyelenggara',
              planId: item['plan_id']?.toString() ?? '',
              planName: item['plan_name']?.toString() ?? 'Paket Langganan',
              amount: (item['gross_amount'] as num? ?? 0).toDouble(),
              paymentMethod: item['payment_method']?.toString() ?? 'Virtual Account',
              status: (item['status'] ?? 'PAID').toString().toUpperCase(),
              createdAt: item['created_at'] != null
                  ? (DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now())
                  : DateTime.now(),
            ),
          );
        }
      }
      var filtered = parsed;
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        filtered = filtered.where((p) => p.status == statusFilter).toList();
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        filtered = filtered.where((p) {
          return p.invoiceNumber.toLowerCase().contains(q) ||
              p.organizerName.toLowerCase().contains(q) ||
              p.planName.toLowerCase().contains(q);
        }).toList();
      }
      return filtered;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    List<AdminPackageTransactionModel> list = List.from(_packageTransactions);

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'ALL') {
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
