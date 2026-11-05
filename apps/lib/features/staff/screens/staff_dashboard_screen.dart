/// Staff dashboard screen — assigned events and check-in station (PRD sections 2.3, 7.5 A).

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/check_in_provider.dart';
import '../../../services/organizer_membership/organizer_membership_service.dart';
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

            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final displayName = auth.user?.name ?? widget.staffName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Staf Event'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang penugasan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaffAssignments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStaffAssignments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header Card
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
                                    displayName,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Penugasan Staf Event (Event-Level Membership)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withValues(alpha: 0.8),
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

                    // Empty state when staff has no active assignments
                    if (_assignedEvents.isEmpty) ...[
                      Card(
                        elevation: 0,
                        color: Colors.amber.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.amber.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 48, color: Colors.amber.shade800),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Penugasan Event Aktif',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Anda belum ditugaskan pada event aktif apapun. Silakan hubungi Penyelenggara (Organizer) untuk menerima undangan dan izin staf.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Assigned Event Selector Card
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
                                    'Pilih Event yang Ditugaskan',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<EventMemberModel>(
                                isExpanded: true,
                                initialValue: _selectedAssignment,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: _assignedEvents.map((member) {
                                  return DropdownMenuItem<EventMemberModel>(
                                    value: member,
                                    child: Text(
                                      member.eventTitle,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedAssignment = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Izin Anda pada Event ini:',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (_selectedAssignment?.permissions ?? {}).map((perm) {
                                  return Chip(
                                    avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    label: Text(perm.label, style: const TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Connection Mode & Offline Queue Control
                      Card(
                        color: _isOfflineMode ? Colors.orange.shade50 : Colors.teal.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isOfflineMode ? Colors.orange.shade300 : Colors.teal.shade300,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                _isOfflineMode ? Icons.wifi_off : Icons.wifi,
                                color: _isOfflineMode ? Colors.orange.shade800 : Colors.teal.shade800,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isOfflineMode ? 'Mode Offline Aktif (Simulasi)' : 'Mode Online Aktif',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isOfflineMode ? Colors.orange.shade900 : Colors.teal.shade900,
                                      ),
                                    ),
                                    Text(
                                      _isOfflineMode
                                          ? 'Pemindaian disimpan ke antrean lokal'
                                          : 'Verifikasi pemindaian langsung ke server',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isOfflineMode ? Colors.orange.shade800 : Colors.teal.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isOfflineMode,
                                activeThumbColor: Colors.orange.shade800,
                                onChanged: (val) => setState(() => _isOfflineMode = val),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Primary Action: QR Scanner Button (Gated by scanTicket)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: _hasPermission(OrganizerPermission.scanTicket)
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 28),
                        label: Text(
                          _hasPermission(OrganizerPermission.scanTicket)
                              ? 'Buka Pemindai QR Tiket'
                              : 'Pemindai QR (Izin Terbatas)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (!_hasPermission(OrganizerPermission.scanTicket)) {
                            _showPermissionDenied('Pindai QR Tiket');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ScannerScreen()),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Quick Action Menu Grid (Gated)
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
                                if (!_hasPermission(OrganizerPermission.checkInTicket)) {
                                  _showPermissionDenied('Konfirmasi Check-in');
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
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
                              label: const Text('Riwayat Scan'),
                              onPressed: () {
                                if (!_hasPermission(OrganizerPermission.viewScanHistory)) {
                                  _showPermissionDenied('Melihat Riwayat Scan');
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CheckInHistoryScreen()),
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
                          if (!_hasPermission(OrganizerPermission.viewReports)) {
                            _showPermissionDenied('Melihat Laporan Kendala');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportListScreen()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
