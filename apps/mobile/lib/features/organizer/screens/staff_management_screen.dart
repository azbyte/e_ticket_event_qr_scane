/// Staff management screen (organizer) — PRD sections 4.8, 7.4 E.
///
/// Stub fondasi. Undangan staf, status undangan, dan pencabutan akses akan
/// diimplementasi setelah backend undangan staf tersedia (PRD 13 #7).
import 'package:flutter/material.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Staf')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar dan undangan staf event akan ditampilkan di sini.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — integrasi API belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
