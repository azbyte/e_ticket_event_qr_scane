/// Staff dashboard screen — assigned events and check-in station (PRD sections 2.3, 7.5 A).
library;

import 'package:flutter/material.dart';

import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';
import '../../check_in/screens/check_in_history_screen.dart';
import '../../check_in/screens/check_in_screen.dart';
import '../../reports/screens/report_list_screen.dart';
import '../../scanner/screens/scanner_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({
    super.key,
    this.checkInProvider,
    this.staffName = 'Budi Santoso',
    this.assignedEventTitle = 'Tech Innovation Summit 2026',
    this.eventId = 'evt-001',
  });

  final CheckInProvider? checkInProvider;
  final String staffName;
  final String assignedEventTitle;
  final String eventId;

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  late final CheckInProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
    _loadData();
  }

  Future<void> _loadData() async {
    await _provider.loadCheckIns(eventId: widget.eventId);
    await _provider.loadAttendees(eventId: widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final totalCheckIns = _provider.checkIns.length;
        final totalAttendees = _provider.attendees.length;
        final offlineQueueCount = _provider.pendingOfflineCount;
        final isOffline = _provider.isOfflineMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard Staf Event'),
            actions: [
              IconButton(
                tooltip: 'Muat ulang data',
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
                  // Greeting & Profile Header
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
                            child: const Icon(Icons.badge, size: 30, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.staffName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Peran: Staf Verifikator QR Code',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

                  // Assigned Event Banner
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_available, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Event yang Ditugaskan',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.assignedEventTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Grand Ballroom Hotel Indonesia, Jakarta',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Connection Mode & Offline Queue Control
                  Card(
                    color: isOffline ? Colors.orange.shade50 : Colors.teal.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isOffline ? Colors.orange.shade300 : Colors.teal.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isOffline ? Icons.wifi_off : Icons.wifi,
                            color: isOffline ? Colors.orange.shade800 : Colors.teal.shade800,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOffline ? 'Mode Offline Aktif' : 'Mode Online Aktif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOffline ? Colors.orange.shade900 : Colors.teal.shade900,
                                  ),
                                ),
                                Text(
                                  isOffline
                                      ? 'Check-in disimpan ke antrean lokal'
                                      : 'Verifikasi langsung ke server backend',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOffline ? Colors.orange.shade800 : Colors.teal.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isOffline,
                            activeColor: Colors.orange.shade800,
                            onChanged: (val) {
                              _provider.toggleOfflineMode(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: 'Sudah Check-in',
                          value: '$totalCheckIns',
                          subtitle: 'dari $totalAttendees peserta',
                          icon: Icons.how_to_reg,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: 'Antrean Offline',
                          value: '$offlineQueueCount',
                          subtitle: offlineQueueCount > 0 ? 'Perlu disinkronkan' : 'Semua tersinkron',
                          icon: Icons.cloud_queue,
                          color: offlineQueueCount > 0 ? Colors.orange : Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Primary Action: QR Scanner Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Text(
                      'Buka Pemindai QR Tiket',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScannerScreen(checkInProvider: _provider),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Quick Action Menu Grid
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Check-in Manual'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckInScreen(checkInProvider: _provider),
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
                          icon: const Icon(Icons.history),
                          label: const Text('Riwayat Check-in'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckInHistoryScreen(checkInProvider: _provider),
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
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Laporan Kendala Peserta'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportListScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Recent Check-in Logs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aktivitas Check-in Terkini',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckInHistoryScreen(checkInProvider: _provider),
                            ),
                          );
                        },
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),

                  if (_provider.checkIns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Belum ada riwayat check-in untuk event ini.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._provider.checkIns.take(3).map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.synced ? Colors.green.shade100 : Colors.orange.shade100,
                            child: Icon(
                              item.synced ? Icons.check : Icons.access_time,
                              color: item.synced ? Colors.green.shade800 : Colors.orange.shade800,
                            ),
                          ),
                          title: Text('Tiket: ${item.ticketId}'),
                          subtitle: Text('Dicatat oleh: ${item.staffName}'),
                          trailing: Chip(
                            label: Text(
                              item.synced ? 'Tersinkron' : 'Offline',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: item.synced ? Colors.green.shade50 : Colors.orange.shade50,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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

  Widget _buildStatCard(
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
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
