/// Attendee list screen (organizer) — PRD sections 4.9, 7.4 D.
///
/// Stub fondasi. Daftar peserta, pencarian, filter, dan ekspor ke CSV/Excel
/// (backend dependent) akan diimplementasi setelah CheckInService/OrderService tersedia.
import 'package:flutter/material.dart';

class AttendeeListScreen extends StatelessWidget {
  const AttendeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Peserta')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar peserta dan status check-in akan ditampilkan di sini.'),
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
