/// Support report form screen (attendee) — PRD sections 4.10, 7.2 G.
///
/// Stub fondasi. Kategori laporan, email kontak, nomor referensi pesanan,
/// dan deskripsi kendala akan diimplementasi setelah ReportService tersedia.
import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';

class ReportFormScreen extends StatelessWidget {
  const ReportFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan Kendala')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Berikan informasi minimum agar tim dapat menindaklanjuti.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email kontak',
                hintText: 'contoh@email.com',
              ),
              validator: InputValidator.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nomor referensi pesanan (jika ada)',
                hintText: 'Ord-12345',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Deskripsi kendala',
                hintText: 'Contoh: pembayaran belum terkonfirmasi',
              ),
              maxLines: 4,
              validator: InputValidator.required,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: create report via ReportService.
              },
              child: const Text('Kirim Laporan'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stub fondasi — integrasi API belum tersedia.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
