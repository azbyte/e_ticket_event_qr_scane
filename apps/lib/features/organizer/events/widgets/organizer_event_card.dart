/// Kartu event pada halaman "Event Saya" (PRD 5.3).
///
/// Menampilkan nama, tanggal, status, tiket terjual, peserta, dan status
/// moderasi. Aksi yang tersedia mengikuti status event (PRD 5.3 + 5.4 aturan).
library;

import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart' as core;
import '../../../../models/event/event_model.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';
import 'organizer_event_status_chip.dart';

class OrganizerEventCard extends StatelessWidget {
  const OrganizerEventCard({
    super.key,
    required this.event,
    this.ticketsSold,
    this.participants,
    this.onOpen,
    this.onEdit,
    this.onSubmitForReview,
    this.onPreview,
    this.onCopyLink,
    this.onDelete,
    this.onSimulateModeration,
  });

  final EventModel event;
  final int? ticketsSold;
  final int? participants;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onSubmitForReview;
  final VoidCallback? onPreview;
  final VoidCallback? onCopyLink;
  final VoidCallback? onDelete;
  final VoidCallback? onSimulateModeration;

  @override
  Widget build(BuildContext context) {
    final location = event.needsPhysicalLocation
        ? (event.location ?? 'Lokasi belum diisi')
        : (event.onlineUrl ?? 'Tautan online belum diisi');
    final statusColor = OrganizerEventStatusChip.colorFor(event.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('organizer-event-card-${event.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Icon(Icons.event, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${core.DateUtils.formatDateTime(event.startDateTime)}'
                          ' • ${event.formatLabel}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActions(context),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  OrganizerEventStatusChip(status: event.status),
                  _MetaChip(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Terjual ${ticketsSold ?? 0}',
                  ),
                  _MetaChip(
                    icon: Icons.people_outline,
                    label: 'Peserta ${participants ?? 0}',
                  ),
                  if (event.category != null)
                    _MetaChip(icon: Icons.label_outline, label: event.category!),
                ],
              ),
              if (event.reviewNote != null &&
                  (event.isRevisionRequested || event.isRejected)) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Catatan moderator: ${event.reviewNote}',
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final entries = <PopupMenuEntry<String>>[];
    if (event.canBeEdited && onEdit != null) {
      entries.add(
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit event')),
      );
    }
    if (event.canSubmitForReview && onSubmitForReview != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'submit',
          child: Text('Ajukan moderasi'),
        ),
      );
    }
    if (event.canResubmit && onSubmitForReview != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'submit',
          child: Text('Ajukan ulang moderasi'),
        ),
      );
    }
    if (event.isPublishedLike && onCopyLink != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'copy',
          child: Text('Salin tautan publik'),
        ),
      );
    }
    if (onPreview != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'preview',
          child: Text('Pratinjau halaman publik'),
        ),
      );
    }
    if (event.isPendingReview && onSimulateModeration != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'simulate',
          child: Text('Simulasi keputusan moderator'),
        ),
      );
    }
    if (event.canBeDeleted && onDelete != null) {
      entries.add(
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Hapus draft'),
        ),
      );
    }

    if (entries.isEmpty) {
      return const SizedBox(width: 8);
    }

    return PopupMenuButton<String>(
      tooltip: 'Aksi event',
      onSelected: (action) {
        switch (action) {
          case 'edit':
            onEdit?.call();
          case 'submit':
            onSubmitForReview?.call();
          case 'copy':
            onCopyLink?.call();
          case 'preview':
            onPreview?.call();
          case 'simulate':
            onSimulateModeration?.call();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => entries,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: Colors.black54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
        ),
      );
}
