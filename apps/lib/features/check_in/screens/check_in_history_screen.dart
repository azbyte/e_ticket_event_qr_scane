/// Check-in history screen — audit log & offline sync management (PRD sections 4.5, 7.5 C).
library;

import 'package:flutter/material.dart';

import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';

class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({
    super.key,
    this.checkInProvider,
    this.eventId = 'evt-001',
  });

  final CheckInProvider? checkInProvider;
  final String eventId;

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  late final CheckInProvider _provider;
  String _filter = 'all'; // all, synced, pending

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _provider.loadCheckIns(eventId: widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final pendingCount = _provider.pendingOfflineCount;
        final list = _provider.checkIns.where((c) {
          if (_filter == 'synced') return c.synced;
          if (_filter == 'pending') return !c.synced;
          return true;
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
              // Offline Sync Alert Banner (if any offline pending)
              if (pendingCount > 0)
                Container(
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingCount Check-in Offline Tersimpan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            Text(
                              'Data belum dikirim ke database backend.',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade100,
                          foregroundColor: Colors.orange.shade900,
                        ),
                        onPressed: () async {
                          final count = await _provider.syncPendingCheckIns(eventId: widget.eventId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$count data check-in berhasil disinkronkan ke server.'),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          }
                        },
                        child: const Text('Sinkronkan'),
                      ),
                    ],
                  ),
                ),

              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Semua (${_provider.checkIns.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tersinkron'),
                      selected: _filter == 'synced',
                      onSelected: (_) => setState(() => _filter = 'synced'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Offline ($pendingCount)'),
                      selected: _filter == 'pending',
                      onSelected: (_) => setState(() => _filter = 'pending'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // History Log List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
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
                                    backgroundColor: item.synced ? Colors.green.shade50 : Colors.orange.shade50,
                                    child: Icon(
                                      item.synced ? Icons.done_all : Icons.cloud_queue,
                                      color: item.synced ? Colors.green.shade700 : Colors.orange.shade800,
                                    ),
                                  ),
                                  title: Text(
                                    'Tiket ID: ${item.ticketId}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text('Oleh: ${item.staffName} • $timeStr WIB'),
                                  trailing: Chip(
                                    label: Text(
                                      item.synced ? 'Tersinkron' : 'Pending',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: item.synced ? Colors.green.shade800 : Colors.orange.shade900,
                                      ),
                                    ),
                                    backgroundColor: item.synced ? Colors.green.shade50 : Colors.orange.shade50,
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
