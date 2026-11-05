/// Access denied screen (PRD Section 2.3, 7.3).
///
/// Displayed when an organizer or staff member attempts to open an unauthorized
/// direct route without leaking sensitive business or event information.
library;

import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({
    super.key,
    this.message = 'Anda tidak memiliki hak akses untuk membuka halaman ini.',
    this.redirectRoute,
    this.reason,
    this.returnRoute,
  });

  final String message;
  final String? redirectRoute;
  final String? reason;
  final String? returnRoute;

  String get effectiveMessage => reason ?? message;
  String? get effectiveReturnRoute => returnRoute ?? redirectRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akses Dibatasi'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Akses Ditolak',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                effectiveMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pastikan Anda masuk dengan akun yang memiliki hak akses dan telah diundang ke event ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke Halaman Utama'),
                onPressed: () {
                  final target = effectiveReturnRoute ?? AppRoutes.home;
                  Navigator.pushNamedAndRemoveUntil(context, target, (_) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
