/// Support report list screen (attendee & general) — PRD sections 4.10, 7.6 C.
///
/// Browse submitted support tickets, check resolution progress,
/// and launch new trouble reports.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/report_provider.dart';
import 'report_form_screen.dart';
import 'report_status_screen.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({
    super.key,
    this.reportProvider,
  });

  final ReportProvider? reportProvider;

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  late final ReportProvider _provider;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _provider = widget.reportProvider ?? ReportProvider();
    _provider.loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final reports = _provider.reports.where((r) {
          if (_filter == 'all') return true;
          return r.status == _filter;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Laporan Kendala Saya'),
            actions: [
              IconButton(
                tooltip: 'Lacak Status Tiket',
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportStatusScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadReports(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Buat Laporan'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportFormScreen(reportProvider: _provider),
                ),
              );
            },
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
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Open'),
                      selected: _filter == AppConstants.reportStatusOpen,
                      onSelected: (_) => setState(() => _filter = AppConstants.reportStatusOpen),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('In Progress'),
                      selected: _filter == AppConstants.reportStatusInProgress,
                      onSelected: (_) => setState(() => _filter = AppConstants.reportStatusInProgress),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Resolved'),
                      selected: _filter == AppConstants.reportStatusResolved,
                      onSelected: (_) => setState(() => _filter = AppConstants.reportStatusResolved),
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
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Belum ada laporan kendala pada kategori ini.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: reports.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = reports[index];
                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReportStatusScreen(ticketNumber: item.ticketNumber),
                                      ),
                                    );
                                  },
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
                                            _buildBadge(item.status),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Kategori: ${item.category}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const Divider(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Diajukan: ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            const Row(
                                              children: [
                                                Text('Lacak Status', style: TextStyle(fontSize: 12, color: Colors.indigo)),
                                                Icon(Icons.chevron_right, size: 16, color: Colors.indigo),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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

  Widget _buildBadge(String status) {
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
