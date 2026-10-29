/// Ticket list screen (attendee ticket history) — PRD section 3.1 #11.
///
/// Stub fondasi. Riwayat tiket untuk peserta yang memiliki akun akan
/// diimplementasi setelah TicketProvider tersedia.
import 'package:flutter/material.dart';

class TicketListScreen extends StatelessWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tiket Saya')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_num, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar tiket akan ditampilkan di sini.'),
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
