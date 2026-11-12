/// Event moderation and global event management screen (admin) — PRD sections 6.3, 7.6 B, FR-12, FR-16, FR-86.
///
/// Complete moderation workflow (approve, request revision, reject, suspend),
/// global event monitoring, detail inspection, and review notes tracking.
library;

import 'package:flutter/material.dart';

import '../../../models/event/event_model.dart';
import '../../../services/admin/admin_audit_log_service.dart';
import '../../../services/organizer_events/organizer_event_contract.dart';
import '../../../services/organizer_events/organizer_event_repository.dart';
import '../../../services/organizer_events/mock_organizer_event_repository.dart';

class EventModerationScreen extends StatefulWidget {
  const EventModerationScreen({
    super.key,
    this.repository,
  });

  final OrganizerEventRepository? repository;

  /// Reset mock events ke kondisi default awal (berguna untuk testing).
  static void resetMockEvents() {
    MockOrganizerEventRepository.resetShared();
  }

  @override
  State<EventModerationScreen> createState() => _EventModerationScreenState();
}

class _EventModerationScreenState extends State<EventModerationScreen> {
  late final OrganizerEventRepository _repository;
  List<EventModel> _events = const <EventModel>[];
  bool _isLoading = true;
  String? _loadError;
  String _filter = OrganizerEventStatus.pendingReview;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? MockOrganizerEventRepository.shared();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final events = await _repository.listPlatformEvents();
      if (mounted) setState(() => _events = events);
    } on Exception catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEventState(
    EventModel event, {
    required String status,
    required String action,
    required String successMessage,
    String? note,
  }) async {
    try {
      await _repository.simulatePlatformModeration(
        eventId: event.id,
        status: status,
        note: note,
      );
      await AdminAuditLogService.instance.logAction(
        actorId: 'admin@event.com',
        actorName: 'Super Admin',
        action: action,
        entityType: 'EVENT',
        entityId: event.id,
        reason: note,
        details: 'Keputusan simulasi untuk event "${event.title}".',
        metadata: {'title': event.title, 'status': status},
      );
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perubahan event gagal disimpan: $error')),
        );
      }
    }
  }

  void _showApproveDialog(EventModel event) {
    showDialog<void>(
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
          'Apakah Anda menyetujui penayangan publik untuk event "${event.title}"?\n\n'
          'Status akan diubah menjadi Disetujui/Dipublikasikan dan dapat dipesan peserta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateEventState(
                event,
                status: OrganizerEventStatus.approved,
                action: 'EVENT_APPROVED',
                successMessage:
                    'Event "${event.title}" telah disetujui & tayang.',
              );
            },
            child: const Text('Setujui & Publikasikan'),
          ),
        ],
      ),
    );
  }

  void _showRevisionDialog(EventModel event) {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Colors.orange),
            SizedBox(width: 8),
            Text('Minta Revisi Event'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tuliskan catatan perbaikan yang wajib dipenuhi oleh penyelenggara event "${event.title}":',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan Revisi *',
                  hintText: 'Cth: Mohon perjelas batas kuota tiket dan alamat gedung...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Catatan revisi wajib diisi.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _updateEventState(
                event,
                status: OrganizerEventStatus.revisionRequested,
                action: 'EVENT_REVISION_REQUESTED',
                successMessage:
                    'Permintaan revisi dikirim ke penyelenggara "${event.title}".',
                note: noteController.text.trim(),
              );
            },
            child: const Text('Kirim Catatan Revisi'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(EventModel event) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Tolak Permohonan Event'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tuliskan alasan penolakan event "${event.title}":',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penolakan *',
                  hintText: 'Cth: Melanggar ketentuan konten platform / indikasi penipuan',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alasan penolakan wajib diisi.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _updateEventState(
                event,
                status: OrganizerEventStatus.rejected,
                action: 'EVENT_REJECTED',
                successMessage: 'Event "${event.title}" telah ditolak.',
                note: reasonController.text.trim(),
              );
            },
            child: const Text('Tolak Permohonan'),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(EventModel event) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Tangguhkan Event?'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesuai FR-88, penangguhan event WAJIB mencatat alasan penangguhan ke AuditLog:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penangguhan Event *',
                  hintText: 'Cth: Terjadi kendala keamanan tempat / investigasi kecurangan tiket...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alasan penangguhan wajib diisi.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _updateEventState(
                event,
                status: OrganizerEventStatus.suspended,
                action: 'EVENT_SUSPENDED',
                successMessage:
                    'Event "${event.title}" telah ditangguhkan.',
                note: reasonController.text.trim(),
              );
            },
            child: const Text('Tangguhkan Event'),
          ),
        ],
      ),
    );
  }

  void _showReactivateDialog(EventModel event) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.green),
            SizedBox(width: 8),
            Text('Buka Penangguhan?'),
          ],
        ),
        content: Text(
          'Pulihkan penayangan untuk event "${event.title}"?\n'
          'Status akan dikembalikan ke Disetujui/Tayang.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateEventState(
                event,
                status: OrganizerEventStatus.approved,
                action: 'EVENT_REACTIVATED',
                successMessage:
                    'Penangguhan event "${event.title}" berhasil dibuka.',
              );
            },
            child: const Text('Buka Penangguhan'),
          ),
        ],
      ),
    );
  }

  void _showDetailModal(EventModel event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  _buildBadge(event.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Penyelenggara: ${event.organizerName ?? event.organizerId}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
              Text(
                'Kontak: ${event.contactInfo ?? "-"}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              const Text('Deskripsi Acara:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(event.description ?? 'Tidak ada deskripsi acara.'),
              const SizedBox(height: 16),
              const Text('Jadwal & Lokasi:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Mulai: ${event.startDateTime.day}/${event.startDateTime.month}/${event.startDateTime.year} ${event.startDateTime.hour}:${event.startDateTime.minute.toString().padLeft(2, '0')}'),
              Text('Selesai: ${event.endDateTime.day}/${event.endDateTime.month}/${event.endDateTime.year} ${event.endDateTime.hour}:${event.endDateTime.minute.toString().padLeft(2, '0')}'),
              Text('Format: ${event.eventType.toUpperCase()}'),
              Text('Lokasi: ${event.location ?? "Online"}'),
              if (event.publicUrl != null) ...[
                const SizedBox(height: 8),
                Text('URL Publik: ${event.publicUrl}', style: const TextStyle(color: Colors.blue, fontSize: 12)),
              ],
              if (event.reviewNote != null && event.reviewNote!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan Review / Penangguhan Terakhir:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(event.reviewNote!, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup Detail'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = _events;

    final query = _searchController.text.trim().toLowerCase();
    final events = allEvents.where((e) {
      // Filter status
      bool matchStatus;
      if (_filter == 'all') {
        matchStatus = true;
      } else if (_filter == OrganizerEventStatus.published) {
        matchStatus = e.status == OrganizerEventStatus.published || e.status == OrganizerEventStatus.approved;
      } else {
        matchStatus = e.status == _filter;
      }

      if (!matchStatus) return false;

      // Filter search
      if (query.isNotEmpty) {
        return e.title.toLowerCase().contains(query) ||
            (e.category?.toLowerCase().contains(query) ?? false) ||
            (e.organizerName?.toLowerCase().contains(query) ?? false) ||
            (e.location?.toLowerCase().contains(query) ?? false);
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderasi & Event Platform'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari judul event, kategori, penyelenggara...',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filter Chips (FR-86, FR-12)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Menunggu Review'),
                  selected: _filter == OrganizerEventStatus.pendingReview,
                  onSelected: (_) => setState(() => _filter = OrganizerEventStatus.pendingReview),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Butuh Revisi'),
                  selected: _filter == OrganizerEventStatus.revisionRequested,
                  onSelected: (_) => setState(() => _filter = OrganizerEventStatus.revisionRequested),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Disetujui/Tayang'),
                  selected: _filter == OrganizerEventStatus.published,
                  onSelected: (_) => setState(() => _filter = OrganizerEventStatus.published),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Ditangguhkan'),
                  selected: _filter == OrganizerEventStatus.suspended,
                  onSelected: (_) => setState(() => _filter = OrganizerEventStatus.suspended),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Ditolak'),
                  selected: _filter == OrganizerEventStatus.rejected,
                  onSelected: (_) => setState(() => _filter = OrganizerEventStatus.rejected),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Semua Event'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Events List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Gagal memuat event.'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadEvents,
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      )
                    : events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
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
                      return _buildEventCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventModel item) {
    final isPending = item.status == OrganizerEventStatus.pendingReview;
    final isSuspended = item.status == OrganizerEventStatus.suspended;
    final isPublished = item.status == OrganizerEventStatus.published || item.status == OrganizerEventStatus.approved;

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
              'Kategori: ${item.category ?? "Umum"} • Format: ${item.eventType.toUpperCase()} • Penyelenggara: ${item.organizerName ?? item.organizerId}',
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
                    item.location ?? 'Online Event',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),

            // Review Note Box
            if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'Catatan Review/Alasan: "${item.reviewNote}"',
                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                ),
              ),
            ],

            const Divider(height: 24),

            // Moderation Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Detail'),
                  onPressed: () => _showDetailModal(item),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (isPending) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _showRejectDialog(item),
                        child: const Text('Tolak'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade900,
                          side: BorderSide(color: Colors.orange.shade700),
                        ),
                        onPressed: () => _showRevisionDialog(item),
                        child: const Text('Minta Revisi'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _showApproveDialog(item),
                        child: const Text('Setujui'),
                      ),
                    ] else if (isPublished) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _showSuspendDialog(item),
                        child: const Text('Tangguhkan'),
                      ),
                    ] else if (isSuspended) ...[
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green.shade800,
                        ),
                        onPressed: () => _showReactivateDialog(item),
                        child: const Text('Buka Penangguhan'),
                      ),
                    ] else if (item.status == OrganizerEventStatus.revisionRequested) ...[
                      OutlinedButton(
                        onPressed: () => _showRevisionDialog(item),
                        child: const Text('Ubah Catatan'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _showApproveDialog(item),
                        child: const Text('Setujui'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color bg;
    Color fg;
    String label = OrganizerEventStatus.label(status);

    switch (status) {
      case OrganizerEventStatus.published:
      case OrganizerEventStatus.approved:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case OrganizerEventStatus.pendingReview:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        break;
      case OrganizerEventStatus.revisionRequested:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case OrganizerEventStatus.rejected:
      case OrganizerEventStatus.suspended:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
