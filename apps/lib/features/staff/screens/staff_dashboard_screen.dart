/// Staff dashboard screen — assigned events and check-in station (PRD sections 2.3, 7.5 A).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/check_in_provider.dart';
import '../../../services/organizer_membership/organizer_membership_service.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../../check_in/screens/check_in_history_screen.dart';
import '../../check_in/screens/check_in_screen.dart';
import '../../reports/screens/report_list_screen.dart';
import '../../scanner/screens/scanner_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({
    super.key,
    this.checkInProvider,
    this.staffName,
    this.assignedEventTitle,
    this.eventId,
    this.assignedEvents,
  });

  final CheckInProvider? checkInProvider;
  final String? staffName;
  final String? assignedEventTitle;
  final String? eventId;
  final List<EventMemberModel>? assignedEvents;

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final OrganizerMembershipService _membershipService =
      OrganizerMembershipService.instance;
  List<EventMemberModel> _assignedEvents = [];
  EventMemberModel? _selectedAssignment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.assignedEvents != null) {
      _assignedEvents = List.from(widget.assignedEvents!);
      _isLoading = false;
      if (widget.eventId != null && widget.eventId!.isNotEmpty) {
        for (final assignment in _assignedEvents) {
          if (assignment.eventId == widget.eventId) {
            _selectedAssignment = assignment;
            break;
          }
        }
      }
      _selectedAssignment ??=
          _assignedEvents.isEmpty ? null : _assignedEvents.first;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadStaffAssignments();
      });
    }
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
      if (widget.eventId != null && widget.eventId!.isNotEmpty) {
        for (final assignment in assignments) {
          if (assignment.eventId == widget.eventId) {
            selected = assignment;
            break;
          }
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
    final displayName = auth.user?.name ?? widget.staffName ?? 'Staf Event';

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.offBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
        ),
        title: const Text('Dashboard Staf Event'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang penugasan',
            icon: const Icon(Icons.refresh, color: AppTheme.offBlack),
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
                      color: AppTheme.pureWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: AppTheme.errorColor),
                        title: Text(_error!, style: const TextStyle(color: AppTheme.offBlack)),
                        trailing: TextButton(
                          onPressed: _loadStaffAssignments,
                          child: const Text('Coba lagi'),
                        ),
                      ),
                    ),
                  Card(
                    color: AppTheme.pureWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.subtleGray),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(Icons.badge, color: AppTheme.pureWhite),
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.offBlack,
                        ),
                      ),
                      subtitle: const Text(
                        'Penugasan Staf Event',
                        style: TextStyle(color: AppTheme.slateGray),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_assignedEvents.isEmpty)
                    Card(
                      color: AppTheme.pureWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.subtleGray),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, size: 48, color: AppTheme.slateGray),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada penugasan event aktif',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.offBlack,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Hubungi penyelenggara untuk menerima undangan.',
                              style: TextStyle(color: AppTheme.slateGray),
                              textAlign: TextAlign.center,
                            ),
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
                    FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Buka Pemindai QR Tiket'),
                      onPressed: _hasPermission(OrganizerPermission.scanTicket)
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ScannerScreen(
                                    eventId:
                                        _selectedAssignment!.eventId,
                                  ),
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
                                      builder: (_) => CheckInScreen(
                                        eventId:
                                            _selectedAssignment!.eventId,
                                      ),
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
                                      builder: (_) => CheckInHistoryScreen(
                                        eventId:
                                            _selectedAssignment!.eventId,
                                      ),
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