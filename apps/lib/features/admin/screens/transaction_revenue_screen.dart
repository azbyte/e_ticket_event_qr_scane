/// Platform transaction and revenue monitoring screen (PRD Section 6.7, FR-89 s.d. FR-93).
library;

import 'package:flutter/material.dart';

import '../../../models/admin/admin_transaction_revenue_model.dart';
import '../../../services/admin/admin_revenue_service.dart';

class TransactionRevenueScreen extends StatefulWidget {
  const TransactionRevenueScreen({super.key});

  @override
  State<TransactionRevenueScreen> createState() => _TransactionRevenueScreenState();
}

class _TransactionRevenueScreenState extends State<TransactionRevenueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminRevenueService _revenueService = AdminRevenueService.instance;

  AdminRevenueSummary? _summary;
  List<AdminTicketTransactionModel> _ticketTrxs = [];
  List<AdminPackageTransactionModel> _packageTrxs = [];
  bool _isLoading = true;
  String _selectedPeriod = 'all';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _revenueService.getRevenueSummary(period: _selectedPeriod);
      final tickets = await _revenueService.getTicketTransactions(
        searchQuery: _searchCtrl.text.trim(),
      );
      final packages = await _revenueService.getPackageTransactions(
        searchQuery: _searchCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _ticketTrxs = tickets;
          _packageTrxs = packages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRp(double val) {
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi & Pendapatan Platform'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Pendapatan'),
            Tab(icon: Icon(Icons.confirmation_number_outlined), text: 'Transaksi Tiket'),
            Tab(icon: Icon(Icons.receipt_outlined), text: 'Pembayaran Paket'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRevenueSummaryTab(),
                _buildTicketTransactionsTab(),
                _buildPackageTransactionsTab(),
              ],
            ),
    );
  }

  // TAB 1: REVENUE SUMMARY (FR-90, FR-93)
  Widget _buildRevenueSummaryTab() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Selector
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.indigo),
                  const SizedBox(width: 10),
                  const Text('Periode Analisis:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _selectedPeriod,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Semua Waktu')),
                      DropdownMenuItem(value: 'today', child: Text('Hari Ini')),
                      DropdownMenuItem(value: 'this_week', child: Text('Minggu Ini')),
                      DropdownMenuItem(value: 'this_month', child: Text('Bulan Ini')),
                      DropdownMenuItem(value: 'this_year', child: Text('Tahun Ini')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPeriod = val);
                        _loadAllData();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Total Platform Revenue Main Banner (FR-90)
          Card(
            color: Colors.indigo.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pendapatan Bersih Platform',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Komisi + Paket', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatRp(s.totalPlatformRevenue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Akumulasi dari ${s.totalTicketOrders} order tiket berbayar dan ${s.totalPackageInvoices} faktur langganan organizer.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Segregated Metric Grid (FR-90, FR-93)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Komisi Tiket Platform',
                  subtitle: '5% snapshot per order',
                  amount: _formatRp(s.ticketCommissionRevenue),
                  color: Colors.teal,
                  icon: Icons.percent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Pendapatan Paket Layanan',
                  subtitle: 'Langganan bulanan/tahunan',
                  amount: _formatRp(s.packageRevenue),
                  color: Colors.blue,
                  icon: Icons.card_membership,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gross Ticket Sales (Segregated & explicitly identified as organizer gross)
          Card(
            elevation: 1,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    child: Icon(Icons.account_balance_wallet, color: Colors.amber.shade900),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Penjualan Kotor Tiket (Gross Sales)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRp(s.grossTicketSales),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hak bersih Organizer setelah dikurangi komisi platform. Gross sales BUKAN pendapatan platform.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 12, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // TAB 2: TICKET TRANSACTIONS (FR-89, FR-91)
  Widget _buildTicketTransactionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari order, event, pembeli, organizer...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onSubmitted: (_) => _loadAllData(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _ticketTrxs.isEmpty
              ? const Center(child: Text('Tidak ada riwayat transaksi tiket.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ticketTrxs.length,
                  itemBuilder: (context, index) {
                    final t = _ticketTrxs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order: ${t.orderId}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                _buildTrxBadge(t.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.eventTitle,
                              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Penyelenggara: ${t.organizerName} • Pembeli: ${t.customerName}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Gross Penjualan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(_formatRp(t.grossAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Komisi Platform (${(t.commissionRateSnapshot * 100).toInt()}%)', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                                    Text(_formatRp(t.commissionAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Bersih Organizer', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(_formatRp(t.netOrganizerAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${t.paymentMethod} • ${_formatDate(t.createdAt)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: PACKAGE SUBSCRIPTION TRANSACTIONS (FR-89, FR-93)
  Widget _buildPackageTransactionsTab() {
    return Column(
      children: [
        Expanded(
          child: _packageTrxs.isEmpty
              ? const Center(child: Text('Tidak ada riwayat pembayaran paket.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _packageTrxs.length,
                  itemBuilder: (context, index) {
                    final p = _packageTrxs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.receipt_long, color: Colors.white),
                        ),
                        title: Text(p.planName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p.invoiceNumber}\n${p.organizerName}\n${p.paymentMethod} • ${_formatDate(p.createdAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatRp(p.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            _buildTrxBadge(p.status),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrxBadge(String status) {
    Color bg = Colors.green.shade50;
    Color fg = Colors.green.shade800;

    if (status == 'PENDING') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    } else if (status == 'REFUNDED' || status == 'FAILED') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

