/// Ticket detail screen — e-ticket with QR code (PRD sections 4.6, 7.2 F).
///
/// Stub fondasi. Data peserta, kategori, QR code individual, dan status
/// tiket akan diimplementasi setelah qr_flutter dan TicketProvider tersedia.
import 'package:flutter/material.dart';

class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Ticket')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Halaman e-ticket dengan QR Code.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — paket qr_flutter dan integrasi API belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
