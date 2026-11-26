/// Profil dan pengaturan akun Organizer (tab "Profil").
///
/// Selain data akun, halaman ini menjadi rumah fitur pendukung yang tidak
/// memiliki menu sendiri pada bottom navigation: Paket & Langganan serta Pusat
/// Bantuan. Pengelolaan Tim & Staf tetap berada pada konteks event (detail
/// event) karena membutuhkan event yang dipilih.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../shell/organizer_content_frame.dart';
import '../shell/organizer_shell.dart';

class OrganizerProfileScreen extends StatelessWidget {
  const OrganizerProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrganizerShell(
      currentRoute: AppRoutes.organizerProfile,
      title: 'Profil',
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          final name = user?.name ?? 'Pengguna';
          final email = user?.email ?? '-';
          final roleLabel = user?.role.label ?? 'Penyelenggara';
          final theme = Theme.of(context);
          final initial = name.trim().isEmpty
              ? 'P'
              : name.trim()[0].toUpperCase();

          return OrganizerContentFrame(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: <Widget>[
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Center(child: _buildRoleChip(context, roleLabel)),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Informasi Akun'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Nama'),
                        subtitle: Text(name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(email),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Peran'),
                        subtitle: Text(roleLabel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(context, 'Pengaturan & Bantuan'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      _buildMenuTile(
                        context,
                        icon: Icons.edit_outlined,
                        title: 'Edit Profil',
                        subtitle: 'Ubah nama yang tampil pada akun',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.profileEdit),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.stars_outlined,
                        title: 'Paket & Langganan',
                        subtitle: 'Lihat paket aktif dan riwayat transaksi',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.organizerPlans,
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.help_outline,
                        title: 'Pusat Bantuan & Laporan',
                        subtitle: 'FAQ dan laporan kendala penyelenggara',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.organizerSupport,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(
                      color: AppTheme.errorColor.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
    );
  }

  Widget _buildRoleChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
