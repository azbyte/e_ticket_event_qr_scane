/// QR scanner screen (PRD sections 4.5, 7.5 B).
///
/// Stub fondasi. Tampilan kamera, panduan pemindaian, dan indikator
/// online/offline akan diimplementasi setelah paket `mobile_scanner` ditambahkan
/// dan izin kamera dikonfigurasi di platform (di luar frontend/lib/).
import 'package:flutter/material.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pemindai QR Tiket')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Layar pemindaian QR akan ditampilkan di sini.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — paket mobile_scanner dan izin kamera belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
