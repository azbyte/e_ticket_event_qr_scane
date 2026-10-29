/// Organizer dashboard screen (PRD sections 4.9, 7.4 A).
///
/// Overview metrics, ticket sales performance, quick event management,
/// attendee check-in rate, and staff delegation controls.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/organizer_provider.dart';
import 'attendee_list_screen.dart';
import 'event_form_screen.dart';
import 'event_management_screen.dart';
import 'staff_management_screen.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({
    super.key,
    this.organizerProvider,
  });

  final OrganizerProvider? organizerProvider;

  @override
  State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  late final OrganizerProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.organizerProvider ?? OrganizerProvider();
    _loadData();
  }

  Future<void> _loadData() async {
    await _provider.loadDashboardStats();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final stats = _provider.stats ?? {
          'total_events': 3,
          'total_tickets_sold': 235,
          'total_revenue': 58500000,
          'check_in_rate': 0.76,
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard Penyelenggara'),
            actions: [
              IconButton(
                tooltip: 'Muat Ulang',
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
                  // Greeting Card
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.business_center, size: 28, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PT Event Nusantara Jaya',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Penyelenggara Terverifikasi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
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

                  // KPI 2x2 Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Total Event',
                          value: '${stats['total_events'] ?? 0}',
                          icon: Icons.event,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Tiket Terjual',
                          value: '${stats['total_tickets_sold'] ?? 0}',
                          icon: Icons.confirmation_number_outlined,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Total Pendapatan',
                          value: 'Rp ${((stats['total_revenue'] as num? ?? 0) / 1000000).toStringAsFixed(1)} Jt',
                          icon: Icons.payments_outlined,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Kehadiran (Check-in)',
                          value: '${(((stats['check_in_rate'] as num? ?? 0) * 100).toInt())}%',
                          icon: Icons.how_to_reg,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Action Buttons
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Buat Event Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(organizerProvider: _provider),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Kelola Event'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventManagementScreen(organizerProvider: _provider),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.group_outlined),
                          label: const Text('Daftar Peserta'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AttendeeListScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Manajemen Staf & Panitia'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffManagementScreen(organizerProvider: _provider),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Recent Events Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Event Saya',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventManagementScreen(organizerProvider: _provider),
                            ),
                          );
                        },
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),

                  if (_provider.events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Belum ada event yang dibuat.')),
                    )
                  else
                    ..._provider.events.take(3).map((event) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${event.category ?? "Umum"} • ${event.location ?? "Online"}'),
                              const SizedBox(height: 4),
                              Text(
                                '${event.startDateTime.day}/${event.startDateTime.month}/${event.startDateTime.year}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: _buildStatusChip(event.status),
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

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
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
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.eventStatusPublished:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Tayang';
        break;
      case AppConstants.eventStatusPendingReview:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Moderasi';
        break;
      case AppConstants.eventStatusDraft:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'Draf';
        break;
      case AppConstants.eventStatusRejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Ditolak';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = status;
    }

    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
    );
  }
}
