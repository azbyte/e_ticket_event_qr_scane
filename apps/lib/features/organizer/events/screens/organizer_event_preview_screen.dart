/// Pratinjau halaman publik event khusus Organizer (read-only).
///
/// Screen publik `features/events/screens/event_detail_screen.dart` milik area
/// Participant tidak diubah; adapter ini hanya menampilkan data fixture yang
/// sama dalam konteks Organizer dan tidak mengklaim publikasi server.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as core;
import '../../../../models/event/event_model.dart';
import '../../../../models/event/ticket_type_model.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';
import '../widgets/organizer_feedback_view.dart';
import '../widgets/organizer_summary_widgets.dart';

class OrganizerEventPreviewScreen extends StatelessWidget {
  const OrganizerEventPreviewScreen({
    super.key,
    required this.event,
    this.ticketTypes = const <TicketTypeModel>[],
  });

  final EventModel event;
  final List<TicketTypeModel> ticketTypes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau Halaman Publik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const OrganizerInfoBanner(
            message: 'Pratinjau lokal dari fixture. Halaman ini belum tayang di '
                'server dan tombol registrasi tidak memproses apa pun.',
            color: AppTheme.warningColor,
            icon: Icons.remove_red_eye_outlined,
          ),
          const SizedBox(height: 12),
          _buildPoster(context),
          const SizedBox(height: 16),
          Text(
            event.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            event.organizerName ?? 'Penyelenggara',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _buildRow(
            Icons.schedule,
            '${core.DateUtils.formatDateTime(event.startDateTime)} - '
            '${core.DateUtils.formatDateTime(event.endDateTime)}',
          ),
          _buildRow(Icons.public, OrganizerTimeZones.label(event.timeZone)),
          if (event.needsPhysicalLocation)
            _buildRow(Icons.place_outlined, event.location ?? '-'),
          if (event.needsOnlineUrl)
            _buildRow(Icons.videocam_outlined, event.onlineUrl ?? '-'),
          _buildRow(Icons.category_outlined, event.formatLabel),
          if (event.contactInfo != null)
            _buildRow(Icons.contacts_outlined, event.contactInfo!),
          const SizedBox(height: 16),
          const Text(
            'Deskripsi',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(event.description ?? '-'),
          const SizedBox(height: 16),
          if (event.publicInfo != null && event.publicInfo!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.publicInfo!,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Kategori tiket',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (ticketTypes.isEmpty)
            const Text(
              'Belum ada kategori tiket yang ditampilkan.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            for (final type in ticketTypes) _buildTicketRow(type),
          const SizedBox(height: 24),
          const FilledButton(
            onPressed: null,
            child: Text('Registrasi (tidak tersedia di pratinjau)'),
          ),

        ],
      ),
    );
  }

  Widget _buildPoster(BuildContext context) {
    // Poster tidak diunduh dari jaringan agar alur Organizer bebas request HTTP.
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.primaryColor.withValues(alpha: 0.85),
            AppTheme.secondaryColor.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.image_outlined, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                event.posterUrl == null
                    ? 'Poster belum diunggah'
                    : 'Poster: ${event.posterUrl}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.black45),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13.5)),
            ),
          ],
        ),
      );

  Widget _buildTicketRow(TicketTypeModel type) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    type.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    type.isActive
                        ? 'Sisa kuota ${type.remainingQuota}'
                        : 'Sedang tidak dijual',
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(
              OrganizerFormatters.rupiah(type.price),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
