/// Event detail screen (public) — PRD section 7.2 C.
///
/// Stub fondasi. Poster, jadwal, kategori tiket, dan tombol registrasi akan
/// diimplementasi setelah EventProvider dan endpoint /events/:id tersedia.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Event')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Detail event akan ditampilkan di sini.'),
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
