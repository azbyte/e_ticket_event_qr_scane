/// Check-in attendee list and manual check-in station (PRD sections 4.5, 4.7).
library;

import 'package:flutter/material.dart';

import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    this.checkInProvider,
    this.eventId = 'evt-001',
    this.staffId = 'stf-001',
    this.staffName = 'Budi Santoso',
  });

  final CheckInProvider? checkInProvider;
  final String eventId;
  final String staffId;
  final String staffName;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  late final CheckInProvider _provider;
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all'; // all, pending, checked_in

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
    _loadAttendees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendees() async {
    await _provider.loadAttendees(eventId: widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final query = _searchController.text.trim().toLowerCase();
        final filteredList = _provider.attendees.where((att) {
          final name = (att['name'] as String? ?? '').toLowerCase();
          final email = (att['email'] as String? ?? '').toLowerCase();
          final ticketCode = (att['ticket_code'] as String? ?? '').toLowerCase();
          final isCheckedIn = att['checked_in'] == true;

          final matchesQuery = query.isEmpty ||
              name.contains(query) ||
              email.contains(query) ||
              ticketCode.contains(query);

          if (!matchesQuery) return false;

          if (_filter == 'checked_in') return isCheckedIn;
          if (_filter == 'pending') return !isCheckedIn;
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Check-in Peserta'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: _loadAttendees,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Cari Peserta / Kode Tiket',
                        hintText: 'Nama, email, atau TK-TECH-...',
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
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Semua Peserta'),
                            selected: _filter == 'all',
                            onSelected: (val) => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Belum Check-in'),
                            selected: _filter == 'pending',
                            onSelected: (val) => setState(() => _filter = 'pending'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Sudah Check-in'),
                            selected: _filter == 'checked_in',
                            onSelected: (val) => setState(() => _filter = 'checked_in'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Attendee List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Tidak ada peserta yang cocok dengan filter.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: filteredList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final attendee = filteredList[index];
                              final isCheckedIn = attendee['checked_in'] == true;
                              final ticketCode = attendee['ticket_code'] as String? ?? '-';
                              final ticketId = attendee['ticket_id'] as String? ?? '';
                              final name = attendee['name'] as String? ?? 'Peserta';
                              final email = attendee['email'] as String? ?? '-';
                              final ticketType = attendee['ticket_type'] as String? ?? 'Tiket Reguler';

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isCheckedIn
                                            ? Colors.green.shade100
                                            : Colors.blue.shade100,
                                        child: Icon(
                                          isCheckedIn ? Icons.check : Icons.person_outline,
                                          color: isCheckedIn ? Colors.green.shade800 : Colors.blue.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            Text(
                                              '$ticketType • $ticketCode',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                            Text(
                                              email,
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCheckedIn)
                                        Chip(
                                          avatar: const Icon(Icons.check, size: 14, color: Colors.green),
                                          label: const Text('Hadir', style: TextStyle(fontSize: 12, color: Colors.green)),
                                          backgroundColor: Colors.green.shade50,
                                        )
                                      else
                                        FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onPressed: () async {
                                            final ok = await _provider.manualCheckIn(
                                              ticketId,
                                              eventId: widget.eventId,
                                              staffId: widget.staffId,
                                              staffName: widget.staffName,
                                            );
                                            if (context.mounted && ok) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Check-in manual berhasil: $name')),
                                              );
                                            }
                                          },
                                          child: const Text('Check-in'),
                                        ),
                                    ],
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
