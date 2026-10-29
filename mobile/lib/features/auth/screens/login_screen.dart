/// Login screen (PRD sections 4.1, 7.2).
///
/// Stub fondasi. Implementasi lengkap + integrasi AuthProvider dilakukan
/// setelah paket `provider` ditambahkan dan kontrak API final (PRD 15).
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/input_validator.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masuk ke akun penyelenggara, staf, atau admin.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
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
                // TODO: connect to AuthProvider.login after provider added.
              },
              child: const Text('Masuk'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: navigate to register screen.
              },
              child: const Text('Belum punya akun? Daftar'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fitur ini masih dalam tahap fondasi. Kode lengkap akan diimplementasi setelah '
              'kontrak API dan paket state management tersedia.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
