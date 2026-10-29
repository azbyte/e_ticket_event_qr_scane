/// Ticket selection screen — multiple ticket types (PRD section 4.4).
///
/// Stub fondasi.
import 'package:flutter/material.dart';

class TicketSelectionScreen extends StatelessWidget {
  const TicketSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Kategori Tiket')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Pilih satu atau beberapa kategori tiket.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — integrasi API dan Provider belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
