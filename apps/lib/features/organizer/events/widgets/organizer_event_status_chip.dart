/// Chip status event Organizer (warna konsisten dengan [AppTheme]).
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/organizer_events/organizer_event_contract.dart';

class OrganizerEventStatusChip extends StatelessWidget {
  const OrganizerEventStatusChip({super.key, required this.status});

  final String status;

  /// Warna status agar Owner dapat membedakan tahap moderasi sekilas.
  static Color colorFor(String status) {
    switch (status) {
      case OrganizerEventStatus.published:
      case OrganizerEventStatus.approved:
        return AppTheme.successColor;
      case OrganizerEventStatus.pendingReview:
        return AppTheme.warningColor;
      case OrganizerEventStatus.revisionRequested:
        return AppTheme.secondaryColor;
      case OrganizerEventStatus.rejected:
      case OrganizerEventStatus.cancelled:
        return AppTheme.errorColor;
      case OrganizerEventStatus.completed:
        return AppTheme.primaryColor;
      case OrganizerEventStatus.suspended:
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublished = status == OrganizerEventStatus.published ||
        status == OrganizerEventStatus.approved;

    final bg = isPublished ? const Color(0xFFE8F5EE) : colorFor(status).withValues(alpha: 0.12);
    final border = isPublished ? const Color(0xFF2E8B57) : colorFor(status).withValues(alpha: 0.5);
    final textColor = isPublished ? const Color(0xFF2E8B57) : colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        OrganizerEventStatus.label(status),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
