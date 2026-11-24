/// Check-in history screen — audit log & offline sync management (PRD sections 4.5, 7.5 C).
library;

import 'package:flutter/material.dart';

import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';

class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({
    super.key,
    this.checkInProvider,
    this.eventId = '',
  });

  final CheckInProvider? checkInProvider;
  final String eventId;

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  late final CheckInProvider _provider;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await _provider.loadCheckIns(eventId: widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final list = _provider.checkIns.where((c) {
          if (query.isEmpty) return true;
          return c.ticketId.toLowerCase().contains(query) ||
              c.staffName.toLowerCase().contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Riwayat Check-in'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: _loadHistory,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari Tiket / Petugas',
                    hintText: 'Masukkan ID tiket atau nama petugas...',
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

              const Divider(height: 1),

              // History Log List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _provider.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Gagal memuat riwayat: ${_provider.error}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _loadHistory,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : list.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    const Text('Belum ada log check-in.'),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: list.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = list[index];
                                  final timeStr =
                                      '${item.checkedInAt.hour.toString().padLeft(2, '0')}:${item.checkedInAt.minute.toString().padLeft(2, '0')}:${item.checkedInAt.second.toString().padLeft(2, '0')}';

                                  return Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green.shade50,
                                        child: Icon(
                                          Icons.done_all,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      title: Text(
                                        'Tiket ID: ${item.ticketId}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text('Oleh: ${item.staffName} • $timeStr WIB'),
                                      trailing: Chip(
                                        label: const Text(
                                          'Tersinkron',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                          ),
                                        ),
                                        backgroundColor: Colors.green.shade50,
                                        padding: EdgeInsets.zero,
                                      ),
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
}
