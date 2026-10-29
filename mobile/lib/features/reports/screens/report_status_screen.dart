/// Report status check screen (attendee & guest) — PRD section 4.10 FR-72.
///
/// Public status tracking for trouble reports using human-readable ticket numbers
/// or secure tokens with progress milestone timeline.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/report/support_report_model.dart';
import '../../../services/report/report_service.dart';

class ReportStatusScreen extends StatefulWidget {
  const ReportStatusScreen({
    super.key,
    this.ticketNumber,
  });

  final String? ticketNumber;

  @override
  State<ReportStatusScreen> createState() => _ReportStatusScreenState();
}

class _ReportStatusScreenState extends State<ReportStatusScreen> {
  final ReportService _service = ReportService();
  late final TextEditingController _searchController;
  SupportReportModel? _report;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.ticketNumber ?? 'RPT-2026-001');
    _lookupReport(_searchController.text.trim());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _lookupReport(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.getReport(query);
      setState(() {
        _report = SupportReportModel.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Laporan dengan nomor atau token "$query" tidak ditemukan.';
        _report = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lacak Status Laporan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar for Ticket Number
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Nomor Tiket Laporan',
                      hintText: 'Cth: RPT-2026-001',
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onSubmitted: _lookupReport,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: () => _lookupReport(_searchController.text.trim()),
                  child: const Text('Cari'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_report != null) ...[
              // Milestone Tracker Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _report!.ticketNumber,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          _buildStatusBadge(_report!.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kategori: ${_report!.category}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const Divider(height: 24),
                      // Stepper / Timeline
                      _buildTimelineStep(
                        title: 'Laporan Diterima',
                        subtitle: 'Tiket berhasil didaftarkan ke sistem antrean.',
                        isCompleted: true,
                      ),
                      _buildTimelineStep(
                        title: 'Sedang Ditinjau Tim Support',
                        subtitle: 'Petugas sedang memvalidasi data dan konfirmasi sistem.',
                        isCompleted: _report!.status == AppConstants.reportStatusInProgress ||
                            _report!.status == AppConstants.reportStatusResolved ||
                            _report!.status == AppConstants.reportStatusClosed,
                      ),
                      _buildTimelineStep(
                        title: 'Solusi Diberikan & Selesai',
                        subtitle: 'Masalah berhasil diselesaikan oleh admin platform.',
                        isCompleted: _report!.status == AppConstants.reportStatusResolved ||
                            _report!.status == AppConstants.reportStatusClosed,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Detail Details Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rincian Kendala yang Dilaporkan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _report!.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_report!.orderReference.isNotEmpty)
                        Text(
                          'No. Referensi Pesanan: ${_report!.orderReference}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        'Email Pelapor: ${_report!.contactEmail ?? "-"}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (_report!.handledBy != null)
                        Text(
                          'Ditangani Oleh: ${_report!.handledBy}',
                          style: const TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: isCompleted ? Colors.green : Colors.grey.shade300,
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: 14,
                color: Colors.white,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCompleted ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.reportStatusOpen:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Open';
        break;
      case AppConstants.reportStatusInProgress:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'In Progress';
        break;
      case AppConstants.reportStatusResolved:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Resolved';
        break;
      case AppConstants.reportStatusClosed:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'Closed';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
