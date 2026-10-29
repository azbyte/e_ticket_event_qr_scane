/// Event form screen (PRD sections 4.2, 7.4 C).
///
/// Stub fondasi. Informasi dasar, jadwal, lokasi, poster, kategori tiket,
/// kuota, dan periode penjualan akan diimplementasi setelah EventService
/// dan TicketTypeService tersedia.
import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';

class EventFormScreen extends StatelessWidget {
  const EventFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat / Edit Event')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Isi informasi event dan ajukan untuk moderasi.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nama event',
                hintText: 'Konferensi Teknologi 2026',
              ),
              validator: InputValidator.required,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: save draft / submit for review via EventService.
              },
              child: const Text('Simpan Draf / Ajukan Moderasi'),
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
