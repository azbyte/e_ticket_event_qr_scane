import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';

/// Halaman penerimaan undangan panitia (`/invite/:token`) — D1-1.
///
/// D1 hanya memiliki route + gerbang login: route ini WAJIB melewati guard
/// autentikasi sehingga guest diarahkan ke login lalu kembali ke halaman ini.
/// Form penerimaan (kecocokan email, accept, redirect ke scanner) disediakan
/// Developer 2 pada `features/staff/screens/accept_invitation_screen.dart`;
/// halaman ini menjadi placeholder navigasi sampai screen tersebut tersedia.
class InvitationEntryScreen extends StatelessWidget {
  const InvitationEntryScreen({super.key, required this.token});

  final String token;

  void _openStaffWorkspace(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.staffDashboard, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Undangan Panitia')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Undangan Panitia Event',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Anda sudah masuk. Undangan hanya dapat diterima oleh akun '
                  'dengan email yang diundang. Halaman penerimaan lengkap '
                  'disediakan modul Staf Event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Token undangan',
                        style: TextStyle(fontSize: 11.5, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        token,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('invitation-open-staff-button'),
                  onPressed: () => _openStaffWorkspace(context),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Buka Workspace Staf'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
