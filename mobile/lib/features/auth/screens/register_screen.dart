/// Register screen for organizers (PRD sections 4.1, FR-01).
///
/// Stub fondasi. Admin tidak dapat didaftarkan melalui formulir umum (FR-06).
import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Penyelenggara')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Daftarkan akun penyelenggara untuk membuat dan mengelola event.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Nama lengkap',
                hintText: 'Budi Santoso',
              ),
              validator: InputValidator.required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contoh@email.com',
              ),
              validator: InputValidator.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Kata sandi',
                hintText: '••••••••',
              ),
              obscureText: true,
              validator: InputValidator.password,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: connect to AuthProvider.register after provider added.
              },
              child: const Text('Daftar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: navigate to login screen.
              },
              child: const Text('Sudah punya akun? Masuk'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fitur ini masih dalam tahap fondasi. Admin akses tidak dapat diperoleh '
              'melalui formulir registrasi umum (FR-06).',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
