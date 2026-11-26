/// Super Admin Overview Dashboard (PRD sections 6.2, 7.6 A, FR-80 s.d. FR-85).
///
/// Business metrics, event operational counts, revenue vs gross sales distinction,
/// period filters, and visual progress charts.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../features/notifications/screens/notification_list_screen.dart';
import '../../../models/admin/admin_transaction_revenue_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/admin/admin_revenue_service.dart';
import '../../../services/organizer_events/organizer_event_repository_factory.dart';

bool get _isTestEnvironment {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return true;
  }
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Satu titik data tren mingguan dari `GET /api/admin/overview` (`trends`).
class PlatformTrendPoint {
  const PlatformTrendPoint({
    required this.weekStart,
    required this.gross,
    required this.revenue,
    required this.transactions,
  });

  final DateTime? weekStart;
  final double gross;
  final double revenue;
  final int transactions;
}

/// Ringkasan keuangan & operasional konsol Admin.
///
/// Nilai pada mode API berasal dari agregasi PostgreSQL
/// (`GET /api/admin/overview` + `GET /api/revenue/admin/summary`). Tidak ada
/// angka contoh/hardcoded: sebelum data database diterima seluruh metrik
/// bernilai 0 ([PlatformRevenueSummary.empty]).
class PlatformRevenueSummary {
  final AdminRevenueSummary revenue;
  final int totalOrders;
  final int totalTicketsIssued;
  final int totalOrganizers;
  final int totalParticipants;
  final int totalCheckIns;
  final int eventsTotal;
  final int eventsPublished;
  final int eventsPendingReview;
  final int eventsRejected;
  final int eventsDraft;
  final int eventsSuspended;
  final List<PlatformTrendPoint> trends;

  const PlatformRevenueSummary({
    required this.revenue,
    this.totalOrders = 0,
    this.totalTicketsIssued = 0,
    this.totalOrganizers = 0,
    this.totalParticipants = 0,
    this.totalCheckIns = 0,
    this.eventsTotal = 0,
    this.eventsPublished = 0,
    this.eventsPendingReview = 0,
    this.eventsRejected = 0,
    this.eventsDraft = 0,
    this.eventsSuspended = 0,
    this.trends = const [],
  });

  static const AdminRevenueSummary _zeroRevenue = AdminRevenueSummary(
    grossTicketSales: 0,
    ticketCommissionRevenue: 0,
    packageRevenue: 0,
    totalPlatformRevenue: 0,
    totalTicketOrders: 0,
    totalPackageInvoices: 0,
    period: 'all',
  );

  /// Ringkasan kosong untuk mode API sebelum respons database diterima.
  factory PlatformRevenueSummary.empty() =>
      const PlatformRevenueSummary(revenue: _zeroRevenue);

  /// Ringkasan dari data revenue lokal; hanya dipakai mode demo (`MOCK_MODE`)
  /// dan widget test. Jumlah event dihitung dari daftar event yang diberikan.
  factory PlatformRevenueSummary.fromRevenue(
    AdminRevenueSummary revenue, {
    List<Map<String, dynamic>> events = const [],
  }) {
    var pending = 0;
    var published = 0;
    var rejected = 0;
    var draft = 0;
    var suspended = 0;
    for (final event in events) {
      final status = event['status']?.toString().toLowerCase() ?? '';
      if (status == AppConstants.eventStatusPendingReview) {
        pending += 1;
      } else if (status == AppConstants.eventStatusPublished ||
          status == AppConstants.eventStatusApproved) {
        published += 1;
      } else if (status == AppConstants.eventStatusRejected) {
        rejected += 1;
      } else if (status == AppConstants.eventStatusSuspended) {
        suspended += 1;
      } else {
        draft += 1;
      }
    }
    return PlatformRevenueSummary(
      revenue: revenue,
      totalOrders: revenue.totalTicketOrders,
      eventsTotal: events.length,
      eventsPublished: published,
      eventsPendingReview: pending,
      eventsRejected: rejected,
      eventsDraft: draft,
      eventsSuspended: suspended,
    );
  }

  /// Membaca payload `overview` dari `GET /api/admin/overview`.
  ///
  /// Bentuk respons backend (`adminOverviewController`):
  /// `{ events: {total, published, pending_review, ...}, active_organizers,
  ///    total_orders, tickets_sold, total_participants, total_check_ins,
  ///    financials: {gross_amount, commission_amount, service_fee,
  ///                 platform_revenue, organizer_net_amount}, trends: [...] }`.
  factory PlatformRevenueSummary.fromOverview(
    Map<String, dynamic> overview, {
    AdminRevenueSummary? fallbackRevenue,
  }) {
    final financials = _asMap(overview['financials']);
    final events = _asMap(overview['events']);

    final gross = _asDouble(
      financials['gross_amount'],
      fallbackRevenue?.grossTicketSales ?? 0,
    );
    final commission = _asDouble(
      financials['commission_amount'],
      fallbackRevenue?.ticketCommissionRevenue ?? 0,
    );
    final packageRevenue = fallbackRevenue?.packageRevenue ?? 0;
    // `platform_revenue` sudah mencakup komisi + biaya layanan + paket.
    final platformRevenue = financials.containsKey('platform_revenue')
        ? _asDouble(financials['platform_revenue'])
        : commission + packageRevenue;
    final orders = _asInt(
      overview['total_orders'],
      fallbackRevenue?.totalTicketOrders ?? 0,
    );

    final rev = AdminRevenueSummary(
      period: fallbackRevenue?.period ?? 'all',
      grossTicketSales: gross,
      ticketCommissionRevenue: commission,
      packageRevenue: packageRevenue,
      totalPlatformRevenue: platformRevenue,
      totalTicketOrders: orders,
      totalPackageInvoices: fallbackRevenue?.totalPackageInvoices ?? 0,
    );

    final trends = <PlatformTrendPoint>[];
    final rawTrends = overview['trends'];
    if (rawTrends is List) {
      for (final item in rawTrends) {
        final row = _asMap(item);
        if (row.isEmpty) continue;
        trends.add(
          PlatformTrendPoint(
            weekStart: DateTime.tryParse(row['week']?.toString() ?? ''),
            gross: _asDouble(row['gross']),
            revenue: _asDouble(row['revenue']),
            transactions: _asInt(row['transactions']),
          ),
        );
      }
    }

    return PlatformRevenueSummary(
      revenue: rev,
      totalOrders: orders,
      totalTicketsIssued: _asInt(overview['tickets_sold']),
      totalOrganizers: _asInt(overview['active_organizers']),
      totalParticipants: _asInt(overview['total_participants']),
      totalCheckIns: _asInt(overview['total_check_ins']),
      eventsTotal: _asInt(events['total']),
      eventsPublished: _asInt(events['published']),
      eventsPendingReview: _asInt(events['pending_review']),
      eventsRejected: _asInt(events['rejected']),
      eventsDraft: _asInt(events['draft']),
      eventsSuspended: _asInt(events['suspended']),
      trends: trends,
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.eventsLoader,
  });

  final Future<List<Map<String, dynamic>>> Function()? eventsLoader;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedPeriod = '30d'; // today, 7d, 30d, this_month, all
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  late PlatformRevenueSummary _summary;
  bool _summaryLoading = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _summary = PlatformRevenueSummary.empty();
    _reload();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    if (widget.eventsLoader != null) {
      return widget.eventsLoader!();
    }
    // API mode adalah default: event platform dibaca dari GET /api/events
    // (admin-only) melalui repository yang sama dengan layar moderasi. Mock
    // hanya dipakai bila MOCK_MODE=true diminta eksplisit sebagai demo.
    final events = await createOrganizerEventRepository().listPlatformEvents();
    return events.map((event) => event.toJson()).toList(growable: false);
  }

  void _reload() {
    final useLocalSnapshot = AppConfig.mockMode || _isTestEnvironment;
    setState(() {
      _eventsFuture = _loadEvents();
      _summaryError = null;
      if (useLocalSnapshot) {
        // Mode demo/test: angka berasal dari fixture lokal, bukan database.
        _summary = PlatformRevenueSummary.fromRevenue(
          AdminRevenueService.instance.getRevenueSummarySnapshot(
            period: _selectedPeriod,
          ),
        );
        _summaryLoading = false;
      } else {
        // Mode API: jangan tampilkan angka contoh; mulai dari nol sampai
        // agregasi database diterima.
        _summary = PlatformRevenueSummary.empty();
        _summaryLoading = true;
      }
    });
    if (!useLocalSnapshot) {
      _loadOverviewFromApi();
    }
  }

  /// Rentang tanggal untuk filter periode (`GET /api/admin/overview?from&to`).
  Map<String, dynamic>? _periodQuery(String period) {
    final now = DateTime.now();
    DateTime? start;
    switch (period) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
      case '7d':
        start = now.subtract(const Duration(days: 7));
      case '30d':
        start = now.subtract(const Duration(days: 30));
      case 'this_month':
        start = DateTime(now.year, now.month);
      case 'all':
      default:
        start = null;
    }
    if (start == null) return null;
    return {
      'from': start.toUtc().toIso8601String(),
      'to': now.toUtc().toIso8601String(),
    };
  }

  Future<void> _loadOverviewFromApi() async {
    final period = _selectedPeriod;
    try {
      // Hitungan operasional & keuangan platform berasal dari agregasi
      // PostgreSQL pada /admin/overview.
      final response = await ApiClient().get(
        '/admin/overview',
        query: _periodQuery(period),
      );
      final overview = response['overview'];
      if (!mounted || period != _selectedPeriod) return;
      if (overview is! Map<String, dynamic>) {
        setState(() {
          _summaryLoading = false;
          _summaryError = 'Respons /admin/overview tidak valid.';
        });
        return;
      }

      // Rincian tiket vs paket langganan diambil terpisah; kegagalan endpoint
      // ini tidak boleh menghapus angka utama yang sudah valid dari database.
      AdminRevenueSummary? revenue;
      try {
        revenue = await AdminRevenueService.instance.getRevenueSummary(
          period: period,
        );
      } catch (_) {
        revenue = null;
      }
      if (!mounted || period != _selectedPeriod) return;

      setState(() {
        _summary = PlatformRevenueSummary.fromOverview(
          overview,
          fallbackRevenue: revenue,
        );
        _summaryLoading = false;
        _summaryError = null;
      });
    } catch (error) {
      if (!mounted || period != _selectedPeriod) return;
      setState(() {
        _summaryLoading = false;
        _summaryError = 'Gagal memuat ringkasan dari database.';
      });
    }
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final chars = str.split('').reversed.toList();
    final parts = <String>[];
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) parts.add('.');
      parts.add(chars[i]);
    }
    return 'Rp ${parts.reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        leading: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final name = auth.user?.name ?? 'Admin';
            return IconButton(
              tooltip: 'Profil',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.adminProfile),
              icon: CircleAvatar(
                radius: 17,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A'),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationListScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Segarkan Data',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Header
            Consumer<AuthProvider>(
              builder: (context, auth, _) => Card(
                elevation: 0,
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.indigo.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.indigo.shade100,
                        child: const Icon(Icons.admin_panel_settings, size: 32, color: Colors.indigo),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selamat datang, ${auth.user?.name ?? "Administrator"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${auth.user?.email ?? "Administrator"} • Administrator Platform-Wide',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Period Filter Bar (FR-84)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Periode Metrik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('Hari Ini')),
                    DropdownMenuItem(value: '7d', child: Text('7 Hari Terakhir')),
                    DropdownMenuItem(value: '30d', child: Text('30 Hari Terakhir')),
                    DropdownMenuItem(value: 'this_month', child: Text('Bulan Ini')),
                    DropdownMenuItem(value: 'all', child: Text('Semua Waktu')),
                  ],
                  onChanged: (val) {
                    if (val == null || val == _selectedPeriod) return;
                    _selectedPeriod = val;
                    // Muat ulang dari API untuk periode baru. Pada mode
                    // demo/test angka tetap berasal dari snapshot lokal.
                    _reload();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status ringkasan dari database: jangan sembunyikan kegagalan API
            // agar admin tahu angka yang tampil benar-benar berasal dari DB.
            if (_summaryError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_summaryError!} Metrik ditampilkan 0 sampai data database berhasil dimuat.',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                    TextButton(onPressed: _reload, child: const Text('Muat ulang')),
                  ],
                ),
              )
            else if (_summaryLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Memuat ringkasan dari database...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Future Builder for Event Data
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final events = snapshot.data ?? [];
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Gagal memuat data event platform.'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }

                // Categorize events (FR-80)
                final now = DateTime.now();
                int pendingCount = 0;
                int activeCount = 0;
                int upcomingCount = 0;
                int completedCount = 0;
                int rejectedCount = 0;

                for (final evt in events) {
                  final status = evt['status']?.toString().toLowerCase() ?? '';
                  final start = evt['start_date_time'] != null
                      ? DateTime.tryParse(evt['start_date_time'] as String)
                      : null;
                  final end = evt['end_date_time'] != null
                      ? DateTime.tryParse(evt['end_date_time'] as String)
                      : null;

                  if (status == AppConstants.eventStatusPendingReview) {
                    pendingCount++;
                  } else if (status == AppConstants.eventStatusPublished ||
                      status == AppConstants.eventStatusApproved) {
                    if (start != null && end != null) {
                      if (now.isAfter(start) && now.isBefore(end)) {
                        activeCount++;
                      } else if (now.isBefore(start)) {
                        upcomingCount++;
                      } else {
                        completedCount++;
                      }
                    } else {
                      activeCount++;
                    }
                  } else if (status == AppConstants.eventStatusCompleted) {
                    completedCount++;
                  } else if (status == AppConstants.eventStatusRejected ||
                      status == AppConstants.eventStatusSuspended) {
                    rejectedCount++;
                  }
                }

                // Event yang tidak termasuk kategori di atas (mis. draft).
                final otherCount = events.length -
                    pendingCount -
                    activeCount -
                    upcomingCount -
                    completedCount -
                    rejectedCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Review Alert Banner (if any)
                    if (pendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.approval, color: Colors.orange, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$pendingCount Event Menunggu Moderasi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'Penyelenggara menunggu persetujuan agar event dapat tayang.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange.shade100,
                                foregroundColor: Colors.orange.shade900,
                              ),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.adminEventModeration,
                              ),
                              child: const Text('Tinjau'),
                            ),
                          ],
                        ),
                      ),

                    // SECTION 1: METRIK OPERASIONAL EVENT (FR-80)
                    const Text(
                      'Operasional Event Platform',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _StatMetricCard(
                          label: 'Total Event',
                          value: '${events.length}',
                          icon: Icons.event,
                          color: Colors.blue,
                          isLoading: isLoading,
                        ),
                        _StatMetricCard(
                          label: 'Event Aktif (Sedang Berjalan)',
                          value: '$activeCount',
                          icon: Icons.play_circle_outline,
                          color: Colors.green,
                          isLoading: isLoading,
                        ),
                        _StatMetricCard(
                          label: 'Event Mendatang',
                          value: '$upcomingCount',
                          icon: Icons.upcoming_outlined,
                          color: Colors.purple,
                          isLoading: isLoading,
                        ),
                        _StatMetricCard(
                          label: 'Menunggu Moderasi',
                          value: '$pendingCount',
                          icon: Icons.hourglass_top,
                          color: Colors.orange,
                          isLoading: isLoading,
                        ),
                        _StatMetricCard(
                          label: 'Event Selesai',
                          value: '$completedCount',
                          icon: Icons.check_circle_outline,
                          color: Colors.grey,
                          isLoading: isLoading,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // SECTION 2: PENGGUNA & TRANSAKSI (FR-81, FR-82)
                    const Text(
                      'Pengguna & Transaksi Pesanan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _StatMetricCard(
                          label: 'Total Organizer',
                          value: '${_summary.totalOrganizers}',
                          icon: Icons.business,
                          color: Colors.teal,
                        ),
                        _StatMetricCard(
                          label: 'Total Peserta',
                          value: '${_summary.totalParticipants}',
                          icon: Icons.people_outline,
                          color: Colors.indigo,
                        ),
                        _StatMetricCard(
                          label: 'Total Order Pesanan',
                          value: '${_summary.totalOrders}',
                          icon: Icons.shopping_bag_outlined,
                          color: Colors.deepOrange,
                        ),
                        _StatMetricCard(
                          label: 'Tiket Diterbitkan',
                          value: '${_summary.totalTicketsIssued}',
                          icon: Icons.confirmation_number_outlined,
                          color: Colors.cyan,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // SECTION 3: PENDAPATAN & KEUANGAN PLATFORM (FR-83, FR-90, FR-93)
                    const Text(
                      'Keuangan & Pendapatan Platform',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sesuai FR-90: Penjualan tiket kotor dipisahkan secara tegas dari pendapatan riil platform.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Total Platform Revenue Highlight
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL PENDAPATAN PLATFORM',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(
                                        _summary.revenue.totalPlatformRevenue,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 28),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Breakdown Rows (FR-93)
                            _buildRevenueRow(
                              'Penjualan Tiket Kotor (Gross Sales)',
                              _formatCurrency(_summary.revenue.grossTicketSales),
                              isSubtitle: true,
                              note: 'Nilai transaksi keseluruhan peserta',
                            ),
                            const SizedBox(height: 8),
                            _buildRevenueRow(
                              'Komisi Tiket Platform (5% Snapshot)',
                              _formatCurrency(
                                _summary.revenue.ticketCommissionRevenue,
                              ),
                              color: Colors.indigo,
                            ),
                            const SizedBox(height: 8),
                            _buildRevenueRow(
                              'Pendapatan Paket Layanan Organizer',
                              _formatCurrency(_summary.revenue.packageRevenue),
                              color: Colors.teal,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SECTION 4: VISUALISASI PERKEMBANGAN PLATFORM (FR-85)
                    const Text(
                      'Grafik Perkembangan & Distribusi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _buildVisualChartCard(
                      published: activeCount,
                      upcoming: upcomingCount,
                      pending: pendingCount,
                      rejected: rejectedCount,
                      other: otherCount + completedCount,
                    ),

                    const SizedBox(height: 20),

                    // SECTION 5: MODUL UTAMA OPERASIONAL
                    const Text(
                      'Navigasi Modul Operasional',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.manage_accounts)),
                        title: const Text('Pengelolaan akun'),
                        subtitle: const Text('Kelola akun Organizer, Participant, status penangguhan.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.adminAccounts,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.approval)),
                        title: const Text('Moderasi & Semua Event Platform'),
                        subtitle: const Text('Setujui, tolak, minta revisi, atau tangguhkan event.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.adminEventModeration,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.support_agent)),
                        title: const Text('Admin Support Center'),
                        subtitle: const Text('Tangani tiket keluhan, catatan internal, dan balasan.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.adminReports,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueRow(String label, String value, {bool isSubtitle = false, String? note, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSubtitle ? FontWeight.normal : FontWeight.w600,
                  color: isSubtitle ? Colors.grey.shade700 : Colors.black87,
                ),
              ),
              if (note != null)
                Text(note, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Grafik distribusi status & tren penjualan.
  ///
  /// Semua angka berasal dari database: distribusi dihitung dari daftar event
  /// (`GET /api/events`) dan tren mingguan dari `trends` pada
  /// `GET /api/admin/overview`. Tidak ada bar/contoh hardcoded.
  Widget _buildVisualChartCard({
    required int published,
    required int upcoming,
    required int pending,
    required int rejected,
    required int other,
  }) {
    final distributionTotal =
        published + upcoming + pending + rejected + other;
    final trends = _summary.trends.reversed.toList(growable: false);
    final maxGross = trends.isEmpty
        ? 0.0
        : trends
            .map((trend) => trend.gross)
            .reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribusi Status Event Platform',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (distributionTotal == 0)
              Text(
                'Belum ada event pada database.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    if (published > 0)
                      Expanded(
                        flex: published,
                        child: Container(height: 14, color: Colors.green),
                      ),
                    if (upcoming > 0)
                      Expanded(
                        flex: upcoming,
                        child: Container(height: 14, color: Colors.purple),
                      ),
                    if (pending > 0)
                      Expanded(
                        flex: pending,
                        child: Container(height: 14, color: Colors.orange),
                      ),
                    if (rejected > 0)
                      Expanded(
                        flex: rejected,
                        child: Container(height: 14, color: Colors.red),
                      ),
                    if (other > 0)
                      Expanded(
                        flex: other,
                        child: Container(height: 14, color: Colors.blueGrey),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Tayang ($published)', Colors.green),
                _buildLegendItem('Mendatang ($upcoming)', Colors.purple),
                _buildLegendItem('Menunggu Moderasi ($pending)', Colors.orange),
                _buildLegendItem('Ditolak ($rejected)', Colors.red),
                _buildLegendItem('Lainnya ($other)', Colors.blueGrey),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Tren Pertumbuhan Penjualan & Pendapatan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (trends.isEmpty)
              Text(
                'Belum ada transaksi terekam pada database.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trends
                    .map(
                      (trend) => _buildBarCol(
                        trend.weekStart == null
                            ? '-'
                            : '${trend.weekStart!.day}/${trend.weekStart!.month}',
                        maxGross <= 0 ? 0.05 : trend.gross / maxGross,
                        _formatCompactCurrency(trend.gross),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  /// Format singkat untuk label grafik (Rp 1,5 jt / Rp 250 rb).
  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)} M';
    }
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)} jt';
    }
    if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return _formatCurrency(amount);
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildBarCol(String label, double fillPct, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 60 * fillPct,
          decoration: BoxDecoration(
            color: Colors.indigo.shade400,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _StatMetricCard extends StatelessWidget {
  const _StatMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
