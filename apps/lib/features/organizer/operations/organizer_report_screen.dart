/// Organizer event reports & financial analytics screen (PRD section 13.3 & FR-70–73).
///
/// Accurately isolates Gross Sales, Platform Commission, Payment Gateway fees,
/// and Organizer Proceeds, with tier breakdown, check-in rate, and export simulation.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';

class OrganizerReportScreen extends StatefulWidget {
  const OrganizerReportScreen({
    super.key,
    required this.eventId,
    this.eventName = 'Tech Innovation Summit 2026',
    required this.contextScope,
  });

  final String eventId;
  final String eventName;
  final OrganizerMembershipContext contextScope;

  @override
  State<OrganizerReportScreen> createState() => _OrganizerReportScreenState();
}

class _OrganizerReportScreenState extends State<OrganizerReportScreen> {
  final OrganizerOperationsRepository _repo =
      OrganizerOperationsRepository.instance;

  String _selectedTierFilter = 'Semua';
  DateTimeRange? _selectedDateRange;

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  void _handleExport() {
    if (!widget.contextScope.hasPermission(
      OrganizerPermission.exportParticipants,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Akses Ditolak: Anda tidak memiliki izin EXPORT_PARTICIPANTS.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final csvData = _repo.exportAttendeesCsv(
        widget.eventId,
        widget.contextScope,
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ekspor Laporan & Peserta Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data operasional event "${widget.eventName}" berhasil dikompilasi ke format CSV (Simulasi Offline).',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade100,
                child: Text(
                  'Pratinjau CSV (${csvData.split("\n").length - 1} baris):\n${csvData.split("\n").take(3).join("\n")}...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Unduh File (Simulasi)'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _selectedDateRange,
      helpText: 'Pilih periode laporan',
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedDateRange = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contextScope.eventId != widget.eventId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan Event')),
        body: const Center(child: Text('Akses ditolak untuk event ini.')),
      );
    }
    final hasReportPermission = widget.contextScope.hasPermission(
      OrganizerPermission.viewReports,
    );

    if (!hasReportPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan Event')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Akses Laporan Ditolak',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Akun staf Anda tidak memiliki izin "${OrganizerPermission.viewReports.code}". Hubungi Penyelenggara untuk meminta hak akses ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final report = _repo.getEventReport(
      widget.eventId,
      ticketType: _selectedTierFilter == 'Semua' ? null : _selectedTierFilter,
      from: _selectedDateRange?.start,
      through: _selectedDateRange == null
          ? null
          : DateTime(
              _selectedDateRange!.end.year,
              _selectedDateRange!.end.month,
              _selectedDateRange!.end.day,
              23,
              59,
              59,
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Analitik Acara'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Ekspor Laporan (CSV)',
            onPressed: _handleExport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              key: const Key('report-date-filter'),
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range),
              label: Text(
                _selectedDateRange == null
                    ? 'Filter tanggal'
                    : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} – ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
              ),
            ),
            // Event Header
            Text(
              widget.eventName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ringkasan data transaksi, kuota tiket, dan persentase check-in.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Key Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Pesanan',
                    value: '${report.totalOrders}',
                    subtitle: 'Transaksi terkonfirmasi',
                    icon: Icons.receipt_long,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Tiket Terbit',
                    value: '${report.totalTicketsSold}',
                    subtitle: 'Total peserta terdaftar',
                    icon: Icons.confirmation_number,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Check-in',
                    value: '${report.totalCheckedIn}',
                    subtitle: 'Peserta hadir fisik',
                    icon: Icons.how_to_reg,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Check-in Rate',
                    value: '${report.checkInRate.toStringAsFixed(1)}%',
                    subtitle: 'Tingkat kehadiran',
                    icon: Icons.pie_chart,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Isolation Card (FR-70–73 requirement)
            const Text(
              'Rincian Keuangan Penjualan Tiket (Transparan)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildFinanceRow(
                      'Gross Sales (Penjualan Kotor Tiket)',
                      _formatCurrency(report.grossSales),
                      isBold: true,
                    ),
                    const Divider(height: 16),
                    _buildFinanceRow(
                      'Komisi Platform E-Ticket',
                      '- ${_formatCurrency(report.platformCommission)}',
                      textColor: Colors.red.shade700,
                    ),
                    const SizedBox(height: 8),
                    _buildFinanceRow(
                      'Biaya Layanan Payment Gateway',
                      '- ${_formatCurrency(report.paymentGatewayFee)}',
                      textColor: Colors.red.shade700,
                    ),
                    const Divider(height: 20),
                    _buildFinanceRow(
                      'Hak Bersih Penyelenggara (Organizer Proceeds)',
                      _formatCurrency(report.organizerProceeds),
                      isBold: true,
                      textColor: Colors.green.shade800,
                      textSize: 15,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Explanatory note about separation of platform package revenue
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: Pendapatan paket langganan platform (${_formatCurrency(report.packageRevenue)}) dipisahkan secara ketat dan bukan bagian dari hasil penjualan tiket acara.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ticket Tier Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distribusi Penjualan per Kategori Tiket',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _selectedTierFilter,
                  isDense: true,
                  underline: const SizedBox(),
                  items: ['Semua', ...report.tierBreakdown.keys]
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k, style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedTierFilter = val);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children:
                      (report.tierBreakdown.entries.where(
                        (e) =>
                            _selectedTierFilter == 'Semua' ||
                            e.key == _selectedTierFilter,
                      )).map((e) {
                        final tierName = e.key;
                        final count = e.value;
                        final pct = report.totalTicketsSold > 0
                            ? (count / report.totalTicketsSold)
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tierName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$count Tiket (${(pct * 100).toStringAsFixed(0)}%)',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(
                                    tierName == 'VIP Pass'
                                        ? Colors.amber.shade700
                                        : tierName == 'Regular Pass'
                                        ? AppTheme.primaryColor
                                        : Colors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Export Actions
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleExport,
                icon: const Icon(Icons.file_download),
                label: const Text('Ekspor Rekap Laporan & Data Peserta ke CSV'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceRow(
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
    double textSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: textSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
