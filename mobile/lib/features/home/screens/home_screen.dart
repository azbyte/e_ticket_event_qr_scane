/// Home screen — public landing page (PRD sections 7.2 A).
///
/// Stub fondasi. Daftar event pilihan dan pencarian akan diimplementasi
/// setelah EventProvider dan endpoint /events tersedia.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppTheme.primaryColor.toString())),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Beranda E-Ticket Event QR Scanner'),
            SizedBox(height: 8),
            Text(
              'Halaman publik — daftar event pilihan akan ditampilkan di sini.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
