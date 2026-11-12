/// Super Admin Overview Dashboard (PRD sections 6.2, 7.6 A, FR-80 s.d. FR-85).
///
/// Business metrics, event operational counts, revenue vs gross sales distinction,
/// period filters, and visual progress charts.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../features/notifications/screens/notification_list_screen.dart';
import '../../../models/admin/admin_transaction_revenue_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/admin/admin_revenue_service.dart';
import '../../../services/organizer_events/mock_organizer_event_repository.dart';

/// DTO Ringkasan Keuangan Platform sesuai Kontrak Integrasi Developer 3.
class PlatformRevenueSummary {
  final AdminRevenueSummary revenue;
  final int totalOrders;
  final int totalTicketsIssued;
  final int totalOrganizers;
  final int totalParticipants;

  const PlatformRevenueSummary({
    required this.revenue,
    required this.totalOrders,
    required this.totalTicketsIssued,
    required this.totalOrganizers,
    required this.totalParticipants,
  });

  factory PlatformRevenueSummary.forPeriod(
    String period,
    AdminRevenueSummary revenue,
  ) {
    final counts = switch (period) {
      'today' => (5, 78, 5, 65),
      '7d' => (8, 395, 8, 320),
      '30d' || 'this_month' => (14, 1650, 14, 1240),
      _ => (24, 3820, 24, 2950),
    };
    return PlatformRevenueSummary(
      revenue: revenue,
      totalOrders: revenue.totalTicketOrders,
      totalTicketsIssued: counts.$2,
      totalOrganizers: counts.$3,
      totalParticipants: counts.$4,
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    if (widget.eventsLoader != null) {
      return widget.eventsLoader!();
    }
    final events = await MockOrganizerEventRepository.shared()
        .listPlatformEvents();
    return events.map((event) => event.toJson()).toList(growable: false);
  }

  void _reload() {
    setState(() {
      _eventsFuture = _loadEvents();
      _summary = PlatformRevenueSummary.forPeriod(
        _selectedPeriod,
        AdminRevenueService.instance.getRevenueSummarySnapshot(
          period: _selectedPeriod,
        ),
      );
    });
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
                              '${auth.user?.email ?? "admin@event.com"} • Administrator Platform-Wide',
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
                    if (val != null) {
                      setState(() {
                        _selectedPeriod = val;
                        _summary = PlatformRevenueSummary.forPeriod(
                          val,
                          AdminRevenueService.instance
                              .getRevenueSummarySnapshot(period: val),
                        );
                      });
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                  }
                }

                // If demo has no active yet, assign realistic defaults for UI demo
                if (activeCount == 0 && events.isNotEmpty) activeCount = 1;
                if (upcomingCount == 0 && events.isNotEmpty) upcomingCount = events.length - activeCount;

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
                    _buildVisualChartCard(),

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

  Widget _buildVisualChartCard() {
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
            // Multi-segment progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(flex: 55, child: Container(height: 14, color: Colors.green)),
                  Expanded(flex: 25, child: Container(height: 14, color: Colors.purple)),
                  Expanded(flex: 15, child: Container(height: 14, color: Colors.orange)),
                  Expanded(flex: 5, child: Container(height: 14, color: Colors.red)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Tayang/Disetujui (55%)', Colors.green),
                _buildLegendItem('Mendatang (25%)', Colors.purple),
                _buildLegendItem('Review (15%)', Colors.orange),
                _buildLegendItem('Ditolak (5%)', Colors.red),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'Tren Pertumbuhan Penjualan & Pendapatan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Simulated chart bars
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarCol('Mg 1', 0.4, 'Rp 1.5jt'),
                _buildBarCol('Mg 2', 0.65, 'Rp 2.8jt'),
                _buildBarCol('Mg 3', 0.5, 'Rp 2.1jt'),
                _buildBarCol('Mg 4', 0.85, 'Rp 3.9jt'),
                _buildBarCol('Mg 5', 1.0, 'Rp 4.7jt'),
              ],
            ),
          ],
        ),
      ),
    );
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
