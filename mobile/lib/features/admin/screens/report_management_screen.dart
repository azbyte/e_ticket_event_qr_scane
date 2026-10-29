/// Report management screen (admin) — PRD sections 4.10, 7.6 C.
///
/// Stub fondasi. Admin melihat, mencari, memfilter laporan dan mengubah
/// status laporan (Open, In Progress, Waiting for User, Resolved, Closed).
import 'package:flutter/material.dart';

class ReportManagementScreen extends StatelessWidget {
  const ReportManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Laporan')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Manajemen laporan kendala akan ditampilkan di sini.'),
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
