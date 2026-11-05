/// Attendee list screen (organizer) — PRD sections 4.9, 7.4 D.
///
/// Attendee monitoring, search and filter, check-in rate breakdown,
/// and CSV/Excel export triggers.
library;

import 'package:flutter/material.dart';

import '../../../models/event/event_model.dart';
import '../../../services/check_in/check_in_service.dart';

class AttendeeListScreen extends StatefulWidget {
  const AttendeeListScreen({
    super.key,
    this.event,
    this.eventId = 'evt-001',
  });

  final EventModel? event;
  final String eventId;

  @override
  State<AttendeeListScreen> createState() => _AttendeeListScreenState();
}

class _AttendeeListScreenState extends State<AttendeeListScreen> {
  final CheckInService _service = CheckInService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _attendees = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, checked_in, pending

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendees() async {
    setState(() => _isLoading = true);
    final targetId = widget.event?.id ?? widget.eventId;
    final list = await _service.listAttendees(eventId: targetId);
    setState(() {
      _attendees = list;
      _isLoading = false;
    });
  }

  void _exportCsv() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text('Ekspor Data Peserta'),
          ],
        ),
        content: Text(
          'Ekspor ${_attendees.length} data peserta ke format CSV (Comma Separated Values) untuk event "${widget.event?.title ?? 'Tech Innovation Summit 2026'}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File peserta_event_export.csv berhasil dibuat dan diunduh.'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('Unduh CSV'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _attendees.where((a) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      final email = (a['email'] as String? ?? '').toLowerCase();
      final code = (a['ticket_code'] as String? ?? '').toLowerCase();
      final isCheckedIn = a['checked_in'] == true;

      final matchQuery = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          code.contains(query);

      if (!matchQuery) return false;
      if (_filter == 'checked_in') return isCheckedIn;
      if (_filter == 'pending') return !isCheckedIn;
      return true;
    }).toList();

    final checkedInCount = _attendees.where((a) => a['checked_in'] == true).length;
    final totalCount = _attendees.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event?.title != null ? 'Peserta: ${widget.event!.title}' : 'Daftar Peserta Event'),
        actions: [
          IconButton(
            tooltip: 'Ekspor Data CSV',
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendees,
          ),
        ],
      ),
      body: Column(
        children: [
          // Attendance Overview Bar
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total Peserta', '$totalCount', Colors.black87),
                _buildSummaryItem('Sudah Hadir', '$checkedInCount', Colors.green.shade800),
                _buildSummaryItem('Belum Hadir', '${totalCount - checkedInCount}', Colors.orange.shade800),
                _buildSummaryItem(
                  'Tingkat Kehadiran',
                  totalCount > 0 ? '${((checkedInCount / totalCount) * 100).toInt()}%' : '0%',
                  Colors.teal,
                ),
              ],
            ),
          ),

          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Nama, Email, atau Tiket',
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Semua ($totalCount)'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Hadir ($checkedInCount)'),
                      selected: _filter == 'checked_in',
                      onSelected: (_) => setState(() => _filter = 'checked_in'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Belum (${totalCount - checkedInCount})'),
                      selected: _filter == 'pending',
                      onSelected: (_) => setState(() => _filter = 'pending'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List of Attendees
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Tidak ada peserta ditemukan.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isChecked = item['checked_in'] == true;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isChecked ? Colors.green.shade50 : Colors.blueGrey.shade50,
                                child: Icon(
                                  isChecked ? Icons.check_circle : Icons.person,
                                  color: isChecked ? Colors.green.shade700 : Colors.blueGrey.shade700,
                                ),
                              ),
                              title: Text(
                                item['name'] as String? ?? 'Peserta',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${item['ticket_type']} • ${item['ticket_code']}\n${item['email']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(
                                  isChecked ? 'Sudah Check-in' : 'Belum Check-in',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isChecked ? Colors.green.shade800 : Colors.grey.shade800,
                                  ),
                                ),
                                backgroundColor: isChecked ? Colors.green.shade50 : Colors.grey.shade100,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
