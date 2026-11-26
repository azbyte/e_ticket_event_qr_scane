/// Layar pengaturan desain tiket untuk satu event (PRD §5).
///
/// Dipisahkan dari tab Tiket agar pemuatan data desain terjadi saat Organizer
/// membuka layar ini, bukan setiap kali detail event dibuka.
library;

import 'package:flutter/material.dart';

import '../../../../models/event/ticket_type_model.dart';
import '../widgets/ticket_design_panel.dart';

class TicketDesignScreen extends StatelessWidget {
  const TicketDesignScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.ticketTypes = const <TicketTypeModel>[],
    this.initialTicketTypeId,
  });

  final String eventId;
  final String eventTitle;
  final List<TicketTypeModel> ticketTypes;

  /// Bila diisi, layar dibuka langsung pada scope kategori tiket tersebut
  /// (dipakai dari form kategori tiket).
  final String? initialTicketTypeId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Desain Tiket')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          eventTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Desain ini dipakai saat tiket peserta diterbitkan (PDF + lampiran '
          'email). Bila tidak ada desain khusus, sistem memakai desain default.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TicketDesignPanel(
          eventId: eventId,
          ticketTypes: ticketTypes,
          initialTicketTypeId: initialTicketTypeId,
        ),
      ],
    ),
  );
}
