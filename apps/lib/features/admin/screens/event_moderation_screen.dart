/// Event moderation screen (admin) — PRD section 7.6 B.
///
/// Workflow for approving, rejecting, or requesting revisions on submitted
/// events before public publishing.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/event/event_model.dart';
import '../../../providers/organizer_provider.dart';

class EventModerationScreen extends StatefulWidget {
  const EventModerationScreen({
    super.key,
    this.organizerProvider,
  });

  final OrganizerProvider? organizerProvider;

  @override
  State<EventModerationScreen> createState() => _EventModerationScreenState();
}

class _EventModerationScreenState extends State<EventModerationScreen> {
  late final OrganizerProvider _provider;
  String _filter = AppConstants.eventStatusPendingReview; // pending_review, revision_required, published, rejected, all

  @override
  void initState() {
    super.initState();
    _provider = widget.organizerProvider ?? OrganizerProvider();
    _provider.loadEvents();
  }

  void _showApproveDialog(EventModel event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Setujui Event?'),
          ],
        ),
        content: Text(
          'Apakah Anda menyetujui penayangan publik untuk event "${event.title}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = EventModel(
                id: event.id,
                organizerId: event.organizerId,
                title: event.title,
                description: event.description,
                category: event.category,
                posterUrl: event.posterUrl,
                startDateTime: event.startDateTime,
                endDateTime: event.endDateTime,
                location: event.location,
                eventType: event.eventType,
                contactInfo: event.contactInfo,
                status: AppConstants.eventStatusPublished,
                isPublic: true,
              );
              await _provider.updateEvent(updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Event "${event.title}" telah disetujui & tayang publik.'),
                    backgroundColor: Colors.green.shade800,
                  ),
                );
              }
            },
            child: const Text('Setujui & Publikasikan'),
          ),
        ],
      ),
    );
  }

  void _showRevisionDialog(EventModel event) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Colors.orange),
            SizedBox(width: 8),
            Text('Minta Revisi Event'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tuliskan catatan perbaikan yang wajib dipenuhi oleh penyelenggara:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan Revisi *',
                hintText: 'Cth: Mohon perjelas batas kuota tiket dan alamat gedung...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final updated = EventModel(
                id: event.id,
                organizerId: event.organizerId,
                title: event.title,
                description: event.description,
                category: event.category,
                posterUrl: event.posterUrl,
                startDateTime: event.startDateTime,
                endDateTime: event.endDateTime,
                location: event.location,
                eventType: event.eventType,
                contactInfo: event.contactInfo,
                status: AppConstants.eventStatusRevisionRequired,
                isPublic: false,
              );
              await _provider.updateEvent(updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Permintaan revisi dikirim ke penyelenggara "${event.title}".'),
                    backgroundColor: Colors.orange.shade900,
                  ),
                );
              }
            },
            child: const Text('Kirim Catatan Revisi'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(EventModel event) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Tolak Event'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tuliskan alasan penolakan event "${event.title}":',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan *',
                hintText: 'Cth: Melanggar ketentuan konten platform / indikasi penipuan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final updated = EventModel(
                id: event.id,
                organizerId: event.organizerId,
                title: event.title,
                description: event.description,
                category: event.category,
                posterUrl: event.posterUrl,
                startDateTime: event.startDateTime,
                endDateTime: event.endDateTime,
                location: event.location,
                eventType: event.eventType,
                contactInfo: event.contactInfo,
                status: AppConstants.eventStatusRejected,
                isPublic: false,
              );
              await _provider.updateEvent(updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Event "${event.title}" telah ditolak.'),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            child: const Text('Tolak Permohonan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final events = _provider.events.where((e) {
          if (_filter == 'all') return true;
          return e.status == _filter;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Moderasi Event Acara'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadEvents(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Menunggu Review'),
                      selected: _filter == AppConstants.eventStatusPendingReview,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusPendingReview),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Butuh Revisi'),
                      selected: _filter == AppConstants.eventStatusRevisionRequired,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusRevisionRequired),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Disetujui'),
                      selected: _filter == AppConstants.eventStatusPublished,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusPublished),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Ditolak'),
                      selected: _filter == AppConstants.eventStatusRejected,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusRejected),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Events List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fact_check, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Tidak ada permohonan event pada kategori ini.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: events.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = events[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          _buildBadge(item.status),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Kategori: ${item.category ?? "Umum"} • Format: ${item.eventType.toUpperCase()}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.description ?? 'Tidak ada deskripsi acara.',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.location ?? 'Online',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      // Moderation Actions
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                            ),
                                            onPressed: () => _showRejectDialog(item),
                                            child: const Text('Tolak'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.orange.shade900,
                                              side: BorderSide(color: Colors.orange.shade700),
                                            ),
                                            onPressed: () => _showRevisionDialog(item),
                                            child: const Text('Minta Revisi'),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                            onPressed: () => _showApproveDialog(item),
                                            child: const Text('Setujui'),
                                          ),
                                        ],
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

  Widget _buildBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.eventStatusPublished:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Disetujui';
        break;
      case AppConstants.eventStatusPendingReview:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Menunggu Review';
        break;
      case AppConstants.eventStatusRevisionRequired:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Butuh Revisi';
        break;
      case AppConstants.eventStatusRejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Ditolak';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
