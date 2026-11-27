/// Attendee list & operations screen (organizer) — PRD sections 4.9, 7.4 D, 13.3 & PEMBAGIAN_TUGAS_2.
///
/// Attendee monitoring, search and filter, check-in rate breakdown,
/// sensitive data minimization, permission enforcement, and operational hub.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../models/event/event_model.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../operations/organizer_activity_log_screen.dart';
import '../operations/organizer_attendee_detail_screen.dart';
import '../operations/organizer_report_screen.dart';
import '../operations/organizer_scanner_screen.dart';

class AttendeeListScreen extends StatefulWidget {
  const AttendeeListScreen({
    super.key,
    this.event,
    this.eventId,
    this.initialMembershipContext,
  });

  final EventModel? event;
  final String? eventId;
  final OrganizerMembershipContext? initialMembershipContext;

  @override
  State<AttendeeListScreen> createState() => _AttendeeListScreenState();
}

class _AttendeeListScreenState extends State<AttendeeListScreen> {
  final OrganizerOperationsRepository _repo =
      OrganizerOperationsRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  late OrganizerMembershipContext _currentContext;
  bool _isLoading = false;
  String? _errorMessage;

  String _filterStatus = 'all'; // all, checked_in, pending, cancelled
  String _filterMethod = 'all'; // all, SELF_SERVICE, ASSISTED
  String _filterTicket = 'all'; // all, VIP Pass, Regular Pass, Early Bird

  @override
  void initState() {
    super.initState();
    final targetId = widget.event?.id ??
        widget.eventId ??
        widget.initialMembershipContext?.eventId ??
        (AppConfig.mockMode ? 'evt-1001' : '');
    _currentContext =
        widget.initialMembershipContext ??
        OrganizerMembershipContext.owner(
          userId: 'usr-org-001',
          userName: 'Penyelenggara Tech (Owner)',
          eventId: targetId,
        );
    if (!AppConfig.mockMode && targetId.isNotEmpty && _canViewParticipants) {
      _loadAttendees();
    }
  }

  Future<void> _loadAttendees() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repo.refreshAttendeesFromApi(_targetEventId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _targetEventId =>
      widget.event?.id ??
      widget.eventId ??
      widget.initialMembershipContext?.eventId ??
      (AppConfig.mockMode ? 'evt-1001' : '');
  String get _targetEventTitle =>
      widget.event?.title ??
      (widget.eventId != null && widget.eventId!.isNotEmpty
          ? 'Event #${widget.eventId}'
          : (AppConfig.mockMode ? 'Tech Innovation Summit 2026' : 'Acara'));
  bool get _canViewParticipants =>
      _currentContext.hasPermission(OrganizerPermission.viewParticipants);

  Future<void> _exportCsv() async {
    if (!_currentContext.hasPermission(
      OrganizerPermission.exportParticipants,
    )) {
      _showAccessDeniedDialog('EXPORT_PARTICIPANTS');
      return;
    }

    if (_targetEventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Acara tidak valid untuk ekspor.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Mengunduh CSV dari server...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final csvContent = await _repo.exportAttendeesCsvFromApi(
        _targetEventId,
        _currentContext,
      );
      if (mounted) Navigator.pop(context); // close progress dialog

      final lines = csvContent.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      final lineCount = lines.length > 1 ? lines.length - 1 : 0;
      final previewLines = lines.take(5).join('\n');

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_done, color: Colors.teal),
              SizedBox(width: 8),
              Text('Ekspor CSV Server'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ekspor $lineCount peserta acara "$_targetEventTitle" berhasil diambil dari server.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  previewLines.isNotEmpty ? '$previewLines\n...' : 'File CSV kosong.',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAEA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Kepatuhan PRD: Formula injection dicegah di server; data sensitif dilindungi.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Salin CSV'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csvContent));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Isi CSV berhasil disalin ke clipboard!'),
                    ),
                  );
                }
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // close progress dialog
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor CSV: $e'),
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
    if (!_currentContext.hasPermission(OrganizerPermission.viewScanHistory)) {
      _showAccessDeniedDialog('VIEW_SCAN_HISTORY');
      return;
    }

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
        final allEventAttendees = _repo.getAttendeesForEvent(_targetEventId);
        final filteredAttendees = _repo.getAttendeesForEvent(
          _targetEventId,
          search: _searchController.text,
          filterStatus: _filterStatus,
          filterMethod: _filterMethod,
          filterTicketType: _filterTicket,
        );

        final totalCount = allEventAttendees.length;
        final checkedInCount = allEventAttendees
            .where((a) => a.checkedIn)
            .length;
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
              if (_currentContext.hasPermission(
                OrganizerPermission.exportParticipants,
              ))
                IconButton(
                  tooltip: 'Ekspor CSV Peserta',
                  icon: const Icon(Icons.download),
                  onPressed: _exportCsv,
                ),
              if (_currentContext.hasPermission(
                OrganizerPermission.viewScanHistory,
              ))
                IconButton(
                  tooltip: 'Riwayat Log Aktivitas',
                  icon: const Icon(Icons.history),
                  onPressed: _openActivityLog,
                ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              if (_errorMessage != null)
                MaterialBanner(
                  content: Text('Gagal memuat peserta: $_errorMessage'),
                  leading: const Icon(Icons.warning, color: Colors.amber),
                  actions: [
                    TextButton(
                      onPressed: _loadAttendees,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              // Role/Context switcher bar (for prototype demonstration)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulasi Peran: ${_currentContext.userName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
                      // Tombol Registrasi Dibantu (non-MVP) disembunyikan dari navigasi
                      ActionChip(
                        avatar: const Icon(
                          Icons.qr_code_scanner,
                          size: 18,
                          color: Color(0xFF2E8B57),
                        ),
                        label: const Text('Pemindai QR / Check-in'),
                        onPressed: _openScanner,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.analytics_outlined,
                          size: 18,
                          color: Color(0xFFC94426),
                        ),
                        label: const Text('Laporan & Finansial'),
                        onPressed: _openReport,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.history,
                          size: 18,
                          color: Colors.brown,
                        ),
                        label: const Text('Log Aktivitas'),
                        onPressed: _openActivityLog,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              if (_canViewParticipants) ...[
                // Attendance Metrics Overview Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Peserta',
                        '$totalCount',
                        Colors.black87,
                      ),
                      _buildSummaryItem(
                        'Hadir',
                        '$checkedInCount',
                        Colors.green.shade800,
                      ),
                      _buildSummaryItem(
                        'Belum Hadir',
                        '$pendingCount',
                        Colors.orange.shade800,
                      ),
                      _buildSummaryItem(
                        'Kehadiran',
                        '$attendanceRate%',
                        Colors.teal,
                      ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua Status'),
                        selected: _filterStatus == 'all',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Hadir'),
                        selected: _filterStatus == 'checked_in',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'checked_in'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Belum Hadir'),
                        selected: _filterStatus == 'pending',
                        onSelected: (_) =>
                            setState(() => _filterStatus = 'pending'),
                      ),
                      const SizedBox(width: 12),
                      const Text('|', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Metode: Semua'),
                        selected: _filterMethod == 'all',
                        onSelected: (_) =>
                            setState(() => _filterMethod = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Self-Service'),
                        selected: _filterMethod == 'SELF_SERVICE',
                        onSelected: (_) =>
                            setState(() => _filterMethod = 'SELF_SERVICE'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Dibantu (Staff)'),
                        selected: _filterMethod == 'ASSISTED',
                        onSelected: (_) =>
                            setState(() => _filterMethod = 'ASSISTED'),
                      ),
                      const SizedBox(width: 12),
                      const Text('|', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Tiket: Semua'),
                        selected: _filterTicket == 'all',
                        onSelected: (_) =>
                            setState(() => _filterTicket = 'all'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('VIP Pass'),
                        selected: _filterTicket == 'VIP Pass',
                        onSelected: (_) =>
                            setState(() => _filterTicket = 'VIP Pass'),
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Regular Pass'),
                        selected: _filterTicket == 'Regular Pass',
                        onSelected: (_) =>
                            setState(() => _filterTicket = 'Regular Pass'),
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
                              Icon(
                                Icons.person_search,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
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
                            final isAssisted =
                                item.registrationMethod == 'ASSISTED';

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isChecked
                                      ? const Color(0xFFE8F5EE)
                                      : const Color(0xFFEAEAEA),
                                  child: Icon(
                                    isChecked
                                        ? Icons.check_circle
                                        : (isAssisted
                                              ? Icons.support_agent
                                              : Icons.person),
                                    color: isChecked
                                        ? const Color(0xFF2E8B57)
                                        : const Color(0xFFC94426),
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
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                          Icon(
                                            Icons.cloud_queue,
                                            size: 12,
                                            color: Colors.orange.shade800,
                                          ),
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
                                      builder: (_) =>
                                          OrganizerAttendeeDetailScreen(
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
              ] else
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_off_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Akses daftar peserta tidak tersedia untuk peran ini.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Peran: ${_currentContext.userName}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
