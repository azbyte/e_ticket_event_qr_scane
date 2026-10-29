/// Event management screen (organizer) — PRD section 7.4 B.
///
/// Lists all organizer events with status filters, moderation tracking,
/// attendee management, and event creation/editing triggers.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/event/event_model.dart';
import '../../../providers/organizer_provider.dart';
import 'attendee_list_screen.dart';
import 'event_form_screen.dart';
import 'staff_management_screen.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({
    super.key,
    this.organizerProvider,
  });

  final OrganizerProvider? organizerProvider;

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late final OrganizerProvider _provider;
  String _filter = 'all'; // all, published, pending_review, draft

  @override
  void initState() {
    super.initState();
    _provider = widget.organizerProvider ?? OrganizerProvider();
    _provider.loadEvents();
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
            title: const Text('Manajemen Event'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: () => _provider.loadEvents(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Buat Event'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventFormScreen(organizerProvider: _provider),
                ),
              );
            },
          ),
          body: Column(
            children: [
              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Semua (${_provider.events.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tayang (Published)'),
                      selected: _filter == AppConstants.eventStatusPublished,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusPublished),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Menunggu Review'),
                      selected: _filter == AppConstants.eventStatusPendingReview,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusPendingReview),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Draf'),
                      selected: _filter == AppConstants.eventStatusDraft,
                      onSelected: (_) => setState(() => _filter = AppConstants.eventStatusDraft),
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
                                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Tidak ada event yang sesuai dengan filter.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: events.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return _buildEventCard(event);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(EventModel event) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${event.category ?? "Umum"} • Tipe: ${event.eventType.toUpperCase()}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(event.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${event.startDateTime.day}/${event.startDateTime.month}/${event.startDateTime.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.place, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location ?? 'Online',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Peserta'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendeeListScreen(event: event),
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Staf'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffManagementScreen(
                          organizerProvider: _provider,
                          eventId: event.id,
                          eventTitle: event.title,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Event',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventFormScreen(
                          organizerProvider: _provider,
                          initialEvent: event,
                        ),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'submit_review') {
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
                        status: AppConstants.eventStatusPendingReview,
                        isPublic: event.isPublic,
                      );
                      await _provider.updateEvent(updated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event diajukan untuk moderasi admin.')),
                        );
                      }
                    } else if (action == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hapus Event?'),
                          content: Text('Apakah Anda yakin ingin menghapus "${event.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _provider.deleteEvent(event.id);
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (event.status == AppConstants.eventStatusDraft)
                      const PopupMenuItem(
                        value: 'submit_review',
                        child: Text('Ajukan ke Moderasi'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus Event', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.eventStatusPublished:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Tayang';
        break;
      case AppConstants.eventStatusPendingReview:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Menunggu Moderasi';
        break;
      case AppConstants.eventStatusDraft:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = 'Draf';
        break;
      case AppConstants.eventStatusRejected:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Ditolak';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
