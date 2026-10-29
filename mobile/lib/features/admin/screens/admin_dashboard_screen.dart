/// Admin platform dashboard screen (PRD section 7.6 A).
///
/// Global platform metrics, event moderation queue preview,
/// and support trouble report management.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/organizer_provider.dart';
import '../../../providers/report_provider.dart';
import 'event_moderation_screen.dart';
import 'report_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.organizerProvider,
    this.reportProvider,
  });

  final OrganizerProvider? organizerProvider;
  final ReportProvider? reportProvider;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final OrganizerProvider _orgProvider;
  late final ReportProvider _reportProvider;

  @override
  void initState() {
    super.initState();
    _orgProvider = widget.organizerProvider ?? OrganizerProvider();
    _reportProvider = widget.reportProvider ?? ReportProvider();
    _loadData();
  }

  Future<void> _loadData() async {
    await _orgProvider.loadEvents();
    await _reportProvider.loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_orgProvider, _reportProvider]),
      builder: (context, _) {
        final pendingEvents = _orgProvider.events.where(
          (e) => e.status == AppConstants.eventStatusPendingReview,
        ).toList();

        final openReports = _reportProvider.reports.where(
          (r) => r.status == AppConstants.reportStatusOpen || r.status == AppConstants.reportStatusInProgress,
        ).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard Admin Platform'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Admin Welcome Card
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                            child: const Icon(Icons.admin_panel_settings, size: 30, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portal Pengawas Platform',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kontrol Moderasi Acara & Bantuan Pengguna',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Platform KPI Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Perlu Moderasi',
                          value: '${pendingEvents.length}',
                          subtitle: 'Event menunggu persetujuan',
                          icon: Icons.approval,
                          color: pendingEvents.isNotEmpty ? Colors.orange.shade800 : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Laporan Kendala',
                          value: '${openReports.length}',
                          subtitle: 'Tiket belum selesai',
                          icon: Icons.assignment_late_outlined,
                          color: openReports.isNotEmpty ? Colors.red.shade700 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Event Aktif',
                          value: '${_orgProvider.events.where((e) => e.status == AppConstants.eventStatusPublished).length}',
                          subtitle: 'Sedang tayang publik',
                          icon: Icons.event_available,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Total Akun',
                          value: '1.240',
                          subtitle: 'Peserta & penyelenggara',
                          icon: Icons.supervised_user_circle,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Direct Navigation Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Moderasi Event'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventModerationScreen(organizerProvider: _orgProvider),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Kelola Laporan'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportManagementScreen(reportProvider: _reportProvider),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section: Events Awaiting Moderation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Event Menunggu Moderasi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventModerationScreen(organizerProvider: _orgProvider),
                            ),
                          );
                        },
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),

                  if (pendingEvents.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 36),
                              const SizedBox(height: 8),
                              const Text('Semua permohonan event telah diproses.'),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...pendingEvents.take(2).map((event) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.pending_actions, color: Colors.white),
                          ),
                          title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${event.category ?? "Umum"} • Diajukan: ${event.location ?? "Online"}'),
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventModerationScreen(organizerProvider: _orgProvider),
                                ),
                              );
                            },
                            child: const Text('Tinjau'),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Section: Urgent Support Reports
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Laporan Kendala Terbaru',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportManagementScreen(reportProvider: _reportProvider),
                            ),
                          );
                        },
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),

                  if (openReports.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.thumb_up_alt_outlined, color: Colors.teal.shade600, size: 36),
                              const SizedBox(height: 8),
                              const Text('Tidak ada laporan kendala yang tertunda.'),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...openReports.take(2).map((rpt) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rpt.status == AppConstants.reportStatusOpen
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              Icons.report_problem,
                              color: rpt.status == AppConstants.reportStatusOpen
                                  ? Colors.red.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                          title: Text(rpt.ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${rpt.category}: ${rpt.description}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Chip(
                            label: Text(rpt.status, style: const TextStyle(fontSize: 10)),
                            backgroundColor: Colors.grey.shade100,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
