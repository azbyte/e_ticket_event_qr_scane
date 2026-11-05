/// Report management screen (admin) — PRD sections 4.10, 7.6 C.
///
/// Administrative trouble ticket management, resolution tracking,
/// category filtering, and user reply dispatch.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/report/support_report_model.dart';
import '../../../providers/report_provider.dart';

class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({
    super.key,
    this.reportProvider,
  });

  final ReportProvider? reportProvider;

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  late final ReportProvider _provider;
  String _statusFilter = 'all'; // all, open, in_progress, resolved, closed

  @override
  void initState() {
    super.initState();
    _provider = widget.reportProvider ?? ReportProvider();
    _provider.loadReports();
  }

  void _showResolutionDialog(SupportReportModel report) {
    String selectedStatus = report.status;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Colors.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tindak Lanjut ${report.ticketNumber}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategori: ${report.category}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text('Email: ${report.contactEmail ?? "Tanpa Email"}', style: const TextStyle(fontSize: 12)),
                if (report.orderReference.isNotEmpty)
                  Text('Ref Pesanan: ${report.orderReference}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.description,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status Penyelesaian *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: AppConstants.reportStatusOpen, child: Text('Open (Baru)')),
                    DropdownMenuItem(value: AppConstants.reportStatusInProgress, child: Text('In Progress (Diproses)')),
                    DropdownMenuItem(value: AppConstants.reportStatusResolved, child: Text('Resolved (Selesai)')),
                    DropdownMenuItem(value: AppConstants.reportStatusClosed, child: Text('Closed (Ditutup)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Tanggapan / Catatan Admin',
                    hintText: 'Tuliskan tindakan pemecahan masalah untuk peserta...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await _provider.updateStatus(
                  reportId: report.id,
                  status: selectedStatus,
                  note: noteController.text.trim(),
                );
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status laporan ${report.ticketNumber} berhasil diperbarui.'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final reports = _provider.reports.where((r) {
          if (_statusFilter == 'all') return true;
          return r.status == _statusFilter;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manajemen Laporan Kendala'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadReports(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Semua (${_provider.reports.length})'),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Open'),
                      selected: _statusFilter == AppConstants.reportStatusOpen,
                      onSelected: (_) => setState(() => _statusFilter = AppConstants.reportStatusOpen),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('In Progress'),
                      selected: _statusFilter == AppConstants.reportStatusInProgress,
                      onSelected: (_) => setState(() => _statusFilter = AppConstants.reportStatusInProgress),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Resolved'),
                      selected: _statusFilter == AppConstants.reportStatusResolved,
                      onSelected: (_) => setState(() => _statusFilter = AppConstants.reportStatusResolved),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Closed'),
                      selected: _statusFilter == AppConstants.reportStatusClosed,
                      onSelected: (_) => setState(() => _statusFilter = AppConstants.reportStatusClosed),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Reports List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : reports.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.done_all, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Tidak ada laporan kendala dengan status ini.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: reports.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = reports[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.ticketNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          _buildStatusBadge(item.status),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Kategori: ${item.category} • Email: ${item.contactEmail ?? "-"}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.description,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Waktu: ${item.createdAt.day}/${item.createdAt.month} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: () => _showResolutionDialog(item),
                                            child: const Text('Tindak Lanjut'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
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
