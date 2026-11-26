/// Profil dan pengaturan akun Organizer (tab "Profil").
///
/// Selain data akun, halaman ini menjadi rumah fitur pendukung yang tidak
/// memiliki menu sendiri pada bottom navigation: Paket & Langganan serta Pusat
/// Bantuan. Pengelolaan Tim & Staf tetap berada pada konteks event (detail
/// event) karena membutuhkan event yang dipilih.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                    backgroundColor: const Color(0xFFC94426),
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFFFFF),
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
                    color: const Color(0xFF181818),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 10),
                Center(child: _buildRoleChip(context, roleLabel)),
                const SizedBox(height: 28),
                _buildSectionTitle(context, 'Informasi Akun'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  color: const Color(0xFFFFFFFF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E2E2), width: 1),
                  ),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: Color(0xFFC94426)),
                        title: const Text('Nama', style: TextStyle(color: Color(0xFF181818), fontWeight: FontWeight.w600)),
                        subtitle: Text(name, style: const TextStyle(color: Color(0xFF7A7A7A))),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E2)),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, color: Color(0xFFC94426)),
                        title: const Text('Email', style: TextStyle(color: Color(0xFF181818), fontWeight: FontWeight.w600)),
                        subtitle: Text(email, style: const TextStyle(color: Color(0xFF7A7A7A))),
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E2)),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined, color: Color(0xFFC94426)),
                        title: const Text('Peran', style: TextStyle(color: Color(0xFF181818), fontWeight: FontWeight.w600)),
                        subtitle: Text(roleLabel, style: const TextStyle(color: Color(0xFF7A7A7A))),
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
                  color: const Color(0xFFFFFFFF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E2E2), width: 1),
                  ),
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
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E2)),
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
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E2)),
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
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: const Color(0xFFE03E3E),
                    side: const BorderSide(
                      color: Color(0xFFE03E3E),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, size: 18, color: Color(0xFFE03E3E)),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFE03E3E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: const Color(0xFF181818),
      ),
    );
  }

  Widget _buildRoleChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFC94426),
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
      leading: Icon(icon, color: const Color(0xFFC94426)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF181818),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF7A7A7A)),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF7A7A7A)),
      onTap: onTap,
    );
  }
}
