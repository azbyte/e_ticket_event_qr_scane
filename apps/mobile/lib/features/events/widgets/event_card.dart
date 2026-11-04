/// Event card widget used in event list screens (PRD section 7.2 B).
///
/// Stub fondasi.
import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event),
        title: const Text('Nama Event'),
        subtitle: const Text('Tanggal & lokasi'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: navigate to event detail screen.
        },
      ),
    );
  }
}
