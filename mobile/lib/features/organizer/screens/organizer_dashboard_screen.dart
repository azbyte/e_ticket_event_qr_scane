/// Organizer dashboard screen (PRD sections 4.9, 7.4 A).
///
/// Stub fondasi. Ringkasan event, tiket terjual, pesanan menunggu pembayaran,
/// dan total check-in akan diimplementasi setelah OrganizerProvider/API tersedia.
import 'package:flutter/material.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Penyelenggara')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Dashboard penyelenggara akan ditampilkan di sini.'),
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
