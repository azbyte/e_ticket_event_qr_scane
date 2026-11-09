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

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final OrganizerMembershipService _membershipService =
      OrganizerMembershipService.instance;
  List<EventMemberModel> _assignedEvents = [];
  EventMemberModel? _selectedAssignment;
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaffAssignments();
  }

  Future<void> _loadStaffAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      final assignments = user == null
          ? <EventMemberModel>[]
          : await _membershipService.getAssignedActiveEvents(
              user.id ?? user.email,
            );
      if (!mounted) return;
      EventMemberModel? selected;
      for (final assignment in assignments) {
        if (assignment.eventId == widget.eventId) {
          selected = assignment;
          break;
        }
      }
      setState(() {
        _assignedEvents = assignments;
        _selectedAssignment = selected ??
            (assignments.isEmpty ? null : assignments.first);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Penugasan gagal dimuat. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasPermission(OrganizerPermission permission) =>
      _selectedAssignment?.hasPermission(permission) ?? false;

  void _showPermissionDenied(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Anda tidak memiliki izin untuk $action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final displayName = auth.user?.name ?? widget.staffName;
    final checkInProvider = widget.checkInProvider;

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
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(_error!),
                        trailing: TextButton(
                          onPressed: _loadStaffAssignments,
                          child: const Text('Coba lagi'),
                        ),
                      ),
                    ),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.badge)),
                      title: Text(displayName),
                      subtitle: const Text('Penugasan Staf Event'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_assignedEvents.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, size: 48),
                            SizedBox(height: 12),
                            Text('Belum ada penugasan event aktif'),
                            Text('Hubungi penyelenggara untuk menerima undangan.'),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pilih Event yang Ditugaskan'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<EventMemberModel>(
                              isExpanded: true,
                              initialValue: _selectedAssignment,
                              items: _assignedEvents
                                  .map(
                                    (member) => DropdownMenuItem(
                                      value: member,
                                      child: Text(
                                        member.eventTitle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _selectedAssignment = value,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Izin Anda pada event ini:'),
                            Wrap(
                              spacing: 6,
                              children: (_selectedAssignment?.permissions ?? {})
                                  .map((permission) => Chip(
                                        label: Text(permission.label),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        title: Text(
                          _isOfflineMode
                              ? 'Mode offline (simulasi)'
                              : 'Mode online (simulasi)',
                        ),
                        subtitle: const Text(
                          'Status check-in demo tidak diverifikasi oleh server.',
                        ),
                        value: _isOfflineMode,
                        onChanged: (value) {
                          setState(() => _isOfflineMode = value);
                          checkInProvider?.toggleOfflineMode(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Buka Pemindai QR Tiket'),
                      onPressed: _hasPermission(OrganizerPermission.scanTicket)
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const ScannerScreen(),
                                ),
                              )
                          : () => _showPermissionDenied('memindai tiket'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Check-in Manual'),
                          onPressed: _hasPermission(
                            OrganizerPermission.checkInTicket,
                          )
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CheckInScreen(),
                                    ),
                                  )
                              : () => _showPermissionDenied(
                                    'mengonfirmasi check-in',
                                  ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('Riwayat Scan'),
                          onPressed: _hasPermission(
                            OrganizerPermission.viewScanHistory,
                          )
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const CheckInHistoryScreen(),
                                    ),
                                  )
                              : () => _showPermissionDenied(
                                    'melihat riwayat scan',
                                  ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.report_problem_outlined),
                          label: const Text('Laporan Kendala'),
                          onPressed: _hasPermission(
                            OrganizerPermission.viewReports,
                          )
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ReportListScreen(),
                                    ),
                                  )
                              : () => _showPermissionDenied(
                                    'melihat laporan',
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}