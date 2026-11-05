import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../models/event/event_model.dart';
import '../screens/event_detail_screen.dart';

/// Event card widget displaying essential event summary.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final EventModel event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: event.id),
                ),
              );
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster Banner
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                  ),
                  child: event.posterUrl != null && event.posterUrl!.isNotEmpty
                      ? Image.network(
                          event.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildBannerFallback(),
                        )
                      : _buildBannerFallback(),
                ),
                // Category Chip
                if (event.category != null && event.category!.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Event Type Chip (Hybrid/Online/Offline)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          event.eventType == 'online'
                              ? Icons.videocam_outlined
                              : event.eventType == 'hybrid'
                                  ? Icons.cell_tower
                                  : Icons.place_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.eventType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          app_date.DateUtils.formatDateTime(event.startDateTime),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Location row
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.pink),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location ?? (event.eventType == 'online' ? 'Live Online Event' : 'Lokasi diumumkan'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Footer with Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Detail',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.deepPurple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.white70),
      ),
    );
  }
}
