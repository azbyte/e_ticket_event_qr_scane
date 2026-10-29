/// Attendee data form screen — registration without mandatory account (PRD sections 2.1, 3.1 #2, 7.2 D).
///
/// Stub fondasi. Formulir data peserta dan email kontak akan diimplementasi
/// setelah OrderService tersedia.
import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';

class AttendeeFormScreen extends StatelessWidget {
  const AttendeeFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Peserta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Isi data peserta yang diperlukan. Peserta tidak wajib membuat akun.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nama lengkap peserta',
                hintText: 'Budi Santoso',
              ),
              validator: InputValidator.required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email untuk pengiriman tiket',
                hintText: 'contoh@email.com',
              ),
              validator: InputValidator.email,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: create order via OrderService.
              },
              child: const Text('Buat Pesanan'),
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
