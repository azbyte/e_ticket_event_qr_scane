/// Staff & team management screen adapter for Organizer (PRD sections 2.3, 4.8, FR-60–65).
///
/// Connects event-specific staff and team management to the full-featured TeamManagementScreen
/// while maintaining backward compatibility with legacy router arguments and tab controller.
library;

import 'package:flutter/material.dart';

import '../membership/team_management_screen.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({
    super.key,
    this.eventId = 'evt-001',
    this.eventName = 'Tech Innovation Summit 2026',
    this.organizerProvider,
  });

  final String eventId;
  final String eventName;
  final dynamic organizerProvider;

  @override
  Widget build(BuildContext context) {
    return TeamManagementScreen(
      eventId: eventId,
      eventTitle: eventName,
    );
  }
}
