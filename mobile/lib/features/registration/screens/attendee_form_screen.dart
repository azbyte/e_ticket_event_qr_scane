import 'package:flutter/material.dart';

import 'registration_screen.dart';

/// Standalone Attendee Form screen — delegates cleanly to RegistrationScreen.
class AttendeeFormScreen extends StatelessWidget {
  const AttendeeFormScreen({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    final routeArg = ModalRoute.of(context)?.settings.arguments as String?;
    return RegistrationScreen(eventId: eventId ?? routeArg ?? 'evt-001');
  }
}
