/// Report status check screen (attendee) — PRD section 4.10 FR-72.
///
/// Stub fondasi. Pemeriksaan status laporan melalui tautan bertoken acak
/// akan diimplementasi setelah backend tautan status final.
import 'package:flutter/material.dart';

class ReportStatusScreen extends StatelessWidget {
  const ReportStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status Laporan')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Pemeriksaan status laporan akan ditampilkan di sini.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — mekanisme tautan status bertoken belum final.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
