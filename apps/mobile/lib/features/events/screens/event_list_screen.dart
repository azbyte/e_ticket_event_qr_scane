/// Event list screen (public) — PRD sections 7.2 B, 3.1 #3.
///
/// Stub fondasi. Kartu event, pencarian, dan filter kategori akan
/// diimplementasi setelah EventProvider dan endpoint /events tersedia.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Event')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Daftar event akan ditampilkan di sini.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — integrasi EventProvider dan API belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
