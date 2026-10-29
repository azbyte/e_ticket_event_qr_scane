/// Event moderation screen (admin) — PRD section 7.6 B.
///
/// Stub fondasi. Detail event, informasi penyelenggara, dan tombol setujui/
/// tolak/minta revisi akan diimplementasi setelah backend moderasi event tersedia.
import 'package:flutter/material.dart';

class EventModerationScreen extends StatelessWidget {
  const EventModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderasi Event')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.approval, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar event menunggu moderasi akan ditampilkan di sini.'),
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
