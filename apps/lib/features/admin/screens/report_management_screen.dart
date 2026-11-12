/// Report management screen (admin) — PRD sections 4.10, 6.8, FR-97 s.d. FR-101.
///
/// Admin Support Center: ticket listing, search, category & priority filtering,
/// status transitions, public replies, internal notes, and activity audit trails.
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

  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _priorityFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = widget.reportProvider ?? ReportProvider();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _provider.loadReports(query: {
      'status': _statusFilter,
      'category': _categoryFilter,
      'priority': _priorityFilter,
      'search': _searchController.text.trim(),
    });
  }

  void _showReportDetailModal(SupportReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReportDetailSheet(
        report: report,
        provider: _provider,
        onChanged: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final reports = _provider.reports;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Support Center'),
            actions: [
              IconButton(
                tooltip: 'Segarkan Laporan',
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari no tiket, subjek, deskripsi, email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onSubmitted: (_) => _loadData(),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    // Status Filter
                    DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Status: Semua')),
                        DropdownMenuItem(value: AppConstants.reportStatusOpen, child: Text('Status: Open')),
                        DropdownMenuItem(value: AppConstants.reportStatusInProgress, child: Text('Status: In Progress')),
                        DropdownMenuItem(value: AppConstants.reportStatusWaitingForUser, child: Text('Status: Menunggu User')),
                        DropdownMenuItem(value: AppConstants.reportStatusResolved, child: Text('Status: Resolved')),
                        DropdownMenuItem(value: AppConstants.reportStatusClosed, child: Text('Status: Closed')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _statusFilter = val);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    // Priority Filter
                    DropdownButton<String>(
                      value: _priorityFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Prioritas: Semua')),
                        DropdownMenuItem(value: 'urgent', child: Text('Prioritas: Urgent')),
                        DropdownMenuItem(value: 'high', child: Text('Prioritas: High')),
                        DropdownMenuItem(value: 'medium', child: Text('Prioritas: Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Prioritas: Low')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _priorityFilter = val);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    // Category Filter
                    DropdownButton<String>(
                      value: _categoryFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Kategori: Semua')),
                        DropdownMenuItem(value: 'PAYMENT', child: Text('Pembayaran')),
                        DropdownMenuItem(value: 'E_TICKET', child: Text('E-Tiket & QR')),
                        DropdownMenuItem(value: 'REGISTRATION', child: Text('Pendaftaran')),
                        DropdownMenuItem(value: 'EVENT', child: Text('Event & Moderasi')),
                        DropdownMenuItem(value: 'SCANNER', child: Text('Scanner Gate')),
                        DropdownMenuItem(value: 'ACCOUNT', child: Text('Akun Pengguna')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _categoryFilter = val);
                          _loadData();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Reports List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _provider.error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 8),
                                Text('Gagal memuat laporan: ${_provider.error}'),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                        : reports.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('Tidak ada laporan kendala sesuai kriteria.'),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: reports.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = reports[index];
                                  return _buildReportCard(item);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportCard(SupportReportModel item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showReportDetailModal(item),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        item.ticketNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityBadge(item.priority),
                    ],
                  ),
                  _buildStatusBadge(item.status),
                ],
              ),
              const SizedBox(height: 8),
              if (item.subject.isNotEmpty)
                Text(
                  item.subject,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.category,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Email: ${item.contactEmail ?? "Tanpa Akun"}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dibuat: ${item.createdAt.day}/${item.createdAt.month} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _showReportDetailModal(item),
                    child: const Text('Detail & Tindak Lanjut'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    String label = priority.toUpperCase();

    switch (priority.toLowerCase()) {
      case 'urgent':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'high':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'medium':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'low':
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
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
      case AppConstants.reportStatusWaitingForUser:
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = 'Menunggu User';
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

/// Sheet detail komprehensif untuk resolusi tiket kendala Admin.
class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({
    required this.report,
    required this.provider,
    required this.onChanged,
  });

  final SupportReportModel report;
  final ReportProvider provider;
  final VoidCallback onChanged;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _currentStatus;
  late String _currentPriority;
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _internalNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentStatus = widget.report.status;
    _currentPriority = widget.report.priority;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _currentStatus = newStatus);
    await widget.provider.updateStatus(
      reportId: widget.report.id,
      status: newStatus,
      handledBy: 'Admin Platform',
    );
    widget.onChanged();
  }

  Future<void> _updatePriority(String newPriority) async {
    setState(() => _currentPriority = newPriority);
    await widget.provider.updatePriority(
      reportId: widget.report.id,
      priority: newPriority,
      handledBy: 'Admin Platform',
    );
    widget.onChanged();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();
    await widget.provider.addReply(
      reportId: widget.report.id,
      message: text,
      senderName: 'Admin Platform',
      senderRole: 'Admin Platform',
    );
    widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _sendInternalNote() async {
    final text = _internalNoteController.text.trim();
    if (text.isEmpty) return;
    _internalNoteController.clear();
    await widget.provider.addInternalNote(
      reportId: widget.report.id,
      note: text,
      authorName: 'Admin Platform',
    );
    widget.onChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final currentReport = widget.provider.reports.firstWhere(
          (r) => r.id == widget.report.id,
          orElse: () => widget.report,
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Modal Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentReport.ticketNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Token Status: ${currentReport.statusToken ?? "-"}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Status & Priority Quick Change
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currentStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: AppConstants.reportStatusOpen, child: Text('Open', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: AppConstants.reportStatusInProgress, child: Text('In Progress', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: AppConstants.reportStatusWaitingForUser, child: Text('Menunggu User', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: AppConstants.reportStatusResolved, child: Text('Resolved', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: AppConstants.reportStatusClosed, child: Text('Closed', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) _updateStatus(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currentPriority,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Prioritas',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'urgent', child: Text('Urgent', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'high', child: Text('High', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'medium', child: Text('Medium', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'low', child: Text('Low', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) _updatePriority(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Percakapan (${currentReport.replies.length})'),
                    Tab(text: 'Internal Notes (${currentReport.internalNotes.length})'),
                    Tab(text: 'Riwayat (${currentReport.activities.length})'),
                  ],
                ),

                // Tab View Body
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Percakapan Publik
                      _buildRepliesTab(currentReport),

                      // Tab 2: Catatan Internal (Strictly Admin Only)
                      _buildInternalNotesTab(currentReport),

                      // Tab 3: Riwayat Aktivitas
                      _buildActivitiesTab(currentReport),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRepliesTab(SupportReportModel report) {
    return Column(
      children: [
        // Original Problem Box
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masalah: ${report.subject.isNotEmpty ? report.subject : report.category}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(report.description, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                'Oleh: ${report.contactEmail ?? "Tamu"} • Ref: ${report.orderReference.isNotEmpty ? report.orderReference : "-"}',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
              ),
            ],
          ),
        ),

        // Replies List
        Expanded(
          child: report.replies.isEmpty
              ? const Center(child: Text('Belum ada balasan kepada pelapor.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: report.replies.length,
                  itemBuilder: (context, index) {
                    final rep = report.replies[index];
                    final isAdmin = rep.senderRole == 'Admin Platform';
                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.indigo.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAdmin ? Colors.indigo.shade200 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${rep.senderName} (${rep.senderRole})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAdmin ? Colors.indigo.shade900 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(rep.message, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '${rep.createdAt.hour.toString().padLeft(2, '0')}:${rep.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Reply Input
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: const InputDecoration(
                    hintText: 'Tulis balasan publik ke pelapor...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sendReply,
                child: const Text('Kirim'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInternalNotesTab(SupportReportModel report) {
    return Column(
      children: [
        // Warning Banner (FR-101 compliance)
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catatan internal ini STRICTLY PRIVAT untuk admin dan tidak dapat diakses oleh pelapor/penyelenggara (FR-101).',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),

        // Notes List
        Expanded(
          child: report.internalNotes.isEmpty
              ? const Center(child: Text('Belum ada catatan internal.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: report.internalNotes.length,
                  itemBuilder: (context, index) {
                    final note = report.internalNotes[index];
                    return Card(
                      color: Colors.yellow.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.amber.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  note.authorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  '${note.createdAt.day}/${note.createdAt.month} ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(note.note, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Internal Note Input
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _internalNoteController,
                  decoration: const InputDecoration(
                    hintText: 'Tambah catatan internal admin...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _sendInternalNote,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab(SupportReportModel report) {
    if (report.activities.isEmpty) {
      return const Center(child: Text('Belum ada riwayat aktivitas.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: report.activities.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final act = report.activities[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 14,
              child: Icon(Icons.history, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.action,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (act.note != null && act.note!.isNotEmpty)
                    Text(
                      act.note!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${act.staffName ?? "Sistem"} • ${act.createdAt.day}/${act.createdAt.month} ${act.createdAt.hour.toString().padLeft(2, '0')}:${act.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
