import 'package:flutter/material.dart';

import 'registration_screen.dart';

/// Standalone Ticket Selection screen — delegates cleanly to RegistrationScreen.
class TicketSelectionScreen extends StatelessWidget {
  const TicketSelectionScreen({
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
