/// Attendee list & operations screen (organizer) — PRD sections 4.9, 7.4 D, 13.3 & PEMBAGIAN_TUGAS_2.
///
/// Attendee monitoring, search and filter, check-in rate breakdown,
/// sensitive data minimization, permission enforcement, and operational hub.
library;

import 'package:flutter/material.dart';

import '../../../models/event/event_model.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../operations/assisted_registration_screen.dart';
import '../operations/organizer_activity_log_screen.dart';
import '../operations/organizer_attendee_detail_screen.dart';
import '../operations/organizer_report_screen.dart';
import '../operations/organizer_scanner_screen.dart';

class AttendeeListScreen extends StatefulWidget {
  const AttendeeListScreen({
    super.key,
    this.event,
    this.eventId = 'evt-001',
    this.initialMembershipContext,
  });

  final EventModel? event;
  final String eventId;
  final OrganizerMembershipContext? initialMembershipContext;

  @override
  State<AttendeeListScreen> createState() => _AttendeeListScreenState();
}

class _AttendeeListScreenState extends State<AttendeeListScreen> {
  final OrganizerOperationsRepository _repo =
      OrganizerOperationsRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  late OrganizerMembershipContext _currentContext;

  String _filterStatus = 'all'; // all, checked_in, pending, cancelled
  String _filterMethod = 'all'; // all, SELF_SERVICE, ASSISTED
  String _filterTicket = 'all'; // all, VIP Pass, Regular Pass, Early Bird

  @override
  void initState() {
    super.initState();
    final targetId = widget.event?.id ?? widget.eventId;
    _currentContext = widget.initialMembershipContext ??
        OrganizerMembershipContext.owner(
          userId: 'usr-org-001',
          userName: 'Penyelenggara Tech (Owner)',
          eventId: targetId,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _targetEventId => widget.event?.id ?? widget.eventId;
  String get _targetEventTitle =>
      widget.event?.title ?? 'Tech Innovation Summit 2026';

  void _exportCsv() {
    if (!_currentContext.hasPermission(OrganizerPermission.exportParticipants)) {
      _showAccessDeniedDialog('EXPORT_PARTICIPANTS');
      return;
    }

    try {
      final csvContent =
          _repo.exportAttendeesCsv(_targetEventId, _currentContext);
      final lineCount = csvContent.split('\n').length - 2;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_done, color: Colors.teal),
              SizedBox(width: 8),
              Text('Simulasi Ekspor CSV'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ekspor $lineCount peserta acara "$_targetEventTitle" berhasil dibuat (simulasi offline-first).',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Catatan Kepatuhan PRD: Seluruh data email & no. telepon peserta telah disamarkan (masked) untuk perlindungan data pribadi.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showAccessDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.gpp_bad, color: Colors.red, size: 48),
        title: const Text('Akses Ditolak'),
        content: Text(
          'Akun Anda (${_currentContext.userName} - ${_currentContext.isOwner ? "Owner" : "Staf"}) tidak memiliki izin $permissionName untuk acara ini.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _openAssistedRegistration() {
    if (!_currentContext.hasPermission(OrganizerPermission.assistRegistration)) {
      _showAccessDeniedDialog('ASSIST_REGISTRATION');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssistedRegistrationScreen(
          eventId: _targetEventId,
          eventName: _targetEventTitle,
          contextScope: _currentContext,
        ),
      ),
    );
  }

  void _openScanner() {
    if (!_currentContext.hasPermission(OrganizerPermission.scanTicket)) {
      _showAccessDeniedDialog('SCAN_TICKET');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerScannerScreen(
          eventId: _targetEventId,
          eventName: _targetEventTitle,
          contextScope: _currentContext,
        ),
      ),
    );
  }

  void _openReport() {
    if (!_currentContext.hasPermission(OrganizerPermission.viewReports)) {
      _showAccessDeniedDialog('VIEW_REPORTS');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerReportScreen(
          eventId: _targetEventId,
          eventName: _targetEventTitle,
          contextScope: _currentContext,
        ),
      ),
    );
  }

  void _openActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerActivityLogScreen(
          eventId: _targetEventId,
          eventTitle: _targetEventTitle,
        ),
      ),
    );
  }

  void _switchContext(String mode) {
    setState(() {
      if (mode == 'owner') {
        _currentContext = OrganizerMembershipContext.owner(
          userId: 'usr-org-001',
          userName: 'Penyelenggara Tech (Owner)',
          eventId: _targetEventId,
        );
      } else if (mode == 'staff_full') {
        _currentContext = OrganizerMembershipContext.staff(
          userId: 'usr-stf-001',
          userName: 'Budi Santoso (Staf Operasional)',
          eventId: _targetEventId,
          permissions: {
            OrganizerPermission.viewEvent,
            OrganizerPermission.viewParticipants,
            OrganizerPermission.assistRegistration,
            OrganizerPermission.viewOrders,
            OrganizerPermission.scanTicket,
            OrganizerPermission.checkInTicket,
            OrganizerPermission.viewScanHistory,
          },
        );
      } else if (mode == 'staff_gate') {
        _currentContext = OrganizerMembershipContext.staff(
          userId: 'usr-stf-002',
          userName: 'Siti Rahma (Staf Pintu Masuk)',
          eventId: _targetEventId,
          permissions: {
            OrganizerPermission.viewEvent,
            OrganizerPermission.scanTicket,
            OrganizerPermission.checkInTicket,
            OrganizerPermission.viewScanHistory,
          },
        );
      } else if (mode == 'staff_restricted') {
        _currentContext = OrganizerMembershipContext.staff(
          userId: 'usr-stf-003',
          userName: 'Doni (Staf Read-Only)',
          eventId: _targetEventId,
          permissions: {
            OrganizerPermission.viewEvent,
            OrganizerPermission.viewParticipants,
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final allEventAttendees =
            _repo.getAttendeesForEvent(_targetEventId);
        final filteredAttendees = _repo.getAttendeesForEvent(
          _targetEventId,
          search: _searchController.text,
          filterStatus: _filterStatus,
          filterMethod: _filterMethod,
          filterTicketType: _filterTicket,
        );

        final totalCount = allEventAttendees.length;
        final checkedInCount =
            allEventAttendees.where((a) => a.checkedIn).length;
        final pendingCount = totalCount - checkedInCount;
        final attendanceRate = totalCount > 0
            ? ((checkedInCount / totalCount) * 100).toInt()
            : 0;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peserta & Operasional Acara',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  _targetEventTitle,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Simulasi Ekspor CSV',
                icon: const Icon(Icons.download),
                onPressed: _exportCsv,
              ),
              IconButton(
                tooltip: 'Riwayat Log Aktivitas',
                icon: const Icon(Icons.history),
                onPressed: _openActivityLog,
              ),
            ],
          ),
          body: Column(
            children: [
              // Role/Context switcher bar (for prototype demonstration)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulasi Peran: ${_currentContext.userName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.tune, size: 20),
                      tooltip: 'Ganti Hak Akses Uji',
                      onSelected: _switchContext,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'owner',
                          child: Text('Owner (Penyelenggara Penuh)'),
                        ),
                        const PopupMenuItem(
                          value: 'staff_full',
                          child: Text('Staf Lengkap (Scan + Registrasi)'),
                        ),
                        const PopupMenuItem(
                          value: 'staff_gate',
                          child: Text('Staf Pintu Masuk (Hanya Scan/Check-in)'),
                        ),
                        const PopupMenuItem(
                          value: 'staff_restricted',
                          child: Text('Staf Terbatas (Hanya Lihat Peserta)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Operational Quick Action Hub
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.app_registration, size: 18, color: Colors.indigo),
                        label: const Text('Registrasi Dibantu'),
                        onPressed: _openAssistedRegistration,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.teal),
                        label: const Text('Pemindai QR / Check-in'),
                        onPressed: _openScanner,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.analytics_outlined, size: 18, color: Colors.purple),
                        label: const Text('Laporan & Finansial'),
                        onPressed: _openReport,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.history, size: 18, color: Colors.brown),
                        label: const Text('Log Aktivitas'),
                        onPressed: _openActivityLog,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Attendance Metrics Overview Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Peserta', '$totalCount', Colors.black87),
                    _buildSummaryItem('Hadir', '$checkedInCount', Colors.green.shade800),
                    _buildSummaryItem('Belum Hadir', '$pendingCount', Colors.orange.shade800),
                    _buildSummaryItem('Kehadiran', '$attendanceRate%', Colors.teal),
                  ],
                ),
              ),

              // Search & Multi-Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Nama, Email, No. HP, atau Kode Tiket',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Semua Status'),
                      selected: _filterStatus == 'all',
                      onSelected: (_) => setState(() => _filterStatus = 'all'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Hadir'),
                      selected: _filterStatus == 'checked_in',
                      onSelected: (_) => setState(() => _filterStatus = 'checked_in'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Belum Hadir'),
                      selected: _filterStatus == 'pending',
                      onSelected: (_) => setState(() => _filterStatus = 'pending'),
                    ),
                    const SizedBox(width: 12),
                    const Text('|', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Metode: Semua'),
                      selected: _filterMethod == 'all',
                      onSelected: (_) => setState(() => _filterMethod = 'all'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Self-Service'),
                      selected: _filterMethod == 'SELF_SERVICE',
                      onSelected: (_) => setState(() => _filterMethod = 'SELF_SERVICE'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Dibantu (Staff)'),
                      selected: _filterMethod == 'ASSISTED',
                      onSelected: (_) => setState(() => _filterMethod = 'ASSISTED'),
                    ),
                    const SizedBox(width: 12),
                    const Text('|', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Tiket: Semua'),
                      selected: _filterTicket == 'all',
                      onSelected: (_) => setState(() => _filterTicket = 'all'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('VIP Pass'),
                      selected: _filterTicket == 'VIP Pass',
                      onSelected: (_) => setState(() => _filterTicket = 'VIP Pass'),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Regular Pass'),
                      selected: _filterTicket == 'Regular Pass',
                      onSelected: (_) => setState(() => _filterTicket = 'Regular Pass'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Attendees List
              Expanded(
                child: filteredAttendees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada peserta yang cocok dengan kriteria filter.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredAttendees.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filteredAttendees[index];
                          final isChecked = item.checkedIn;
                          final isAssisted = item.registrationMethod == 'ASSISTED';

                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isChecked
                                    ? Colors.green.shade50
                                    : Colors.blueGrey.shade50,
                                child: Icon(
                                  isChecked
                                      ? Icons.check_circle
                                      : (isAssisted
                                          ? Icons.support_agent
                                          : Icons.person),
                                  color: isChecked
                                      ? Colors.green.shade700
                                      : Colors.blueGrey.shade700,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (isAssisted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'DIBANTU',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.ticketType} • ${item.ticketCode}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.maskedEmail} • ${item.maskedPhone}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (item.isOfflinePending) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.cloud_queue,
                                            size: 12, color: Colors.orange.shade800),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Menunggu Sinkronisasi Offline',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      isChecked ? 'Hadir' : 'Belum Hadir',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isChecked
                                            ? Colors.green.shade800
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                    backgroundColor: isChecked
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrganizerAttendeeDetailScreen(
                                      attendee: item,
                                      contextScope: _currentContext,
                                    ),
                                  ),
                                );
                              },
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
