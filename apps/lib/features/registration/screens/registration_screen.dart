/// Registration screen — choose ticket types & quantity (PRD sections 3.1 #5,#6, 4.4, 7.2 D).
///
/// Stub fondasi. Pilihan kategori dan jumlah tiket akan diimplementasi
/// setelah TicketTypeProvider dan endpoint tiket tersedia.
import 'package:flutter/material.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesan Tiket')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Pilih kategori dan jumlah tiket.'),
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
