/// Banner poster event Organizer.
///
/// Meniru banner kartu pada halaman "Jelajahi Event" (lihat
/// `features/events/widgets/event_card.dart`) agar kartu event milik
/// penyelenggara memiliki tampilan yang sama: poster, chip kategori di kiri
/// atas, dan chip format pelaksanaan di kanan atas.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';

class OrganizerEventPoster extends StatelessWidget {
  const OrganizerEventPoster({
    super.key,
    required this.posterUrl,
    required this.eventType,
    this.category,
    this.height = 140,
  });

  final String? posterUrl;
  final String eventType;
  final String? category;
  final double height;

  bool get _hasPoster => posterUrl != null && posterUrl!.trim().isNotEmpty;

  bool get _hasCategory => category != null && category!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          height: height,
          width: double.infinity,
          color: AppTheme.warmLightGray,
          child: _hasPoster
              ? Image.network(
                  posterUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallback(),
                )
              : _buildFallback(),
        ),
        if (_hasCategory)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_formatIcon(eventType), size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  OrganizerEventFormat.label(eventType).toUpperCase(),
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
    );
  }

  IconData _formatIcon(String type) {
    switch (type) {
      case OrganizerEventFormat.online:
        return Icons.videocam_outlined;
      case OrganizerEventFormat.hybrid:
        return Icons.cell_tower;
      default:
        return Icons.place_outlined;
    }
  }

  Widget _buildFallback() {
    return Container(
      key: const Key('organizer-event-poster-fallback'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[AppTheme.secondaryColor, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.confirmation_number_outlined,
          size: 48,
          color: Colors.white70,
        ),
      ),
    );
  }
}
