/// Admin profile screen (/admin/profile) for Platform Admin (PRD Section 6.1, FR-80).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Profil Administrator'),
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.offBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          final name = user?.name ?? 'Super Admin';
          final email = user?.email ?? 'Email belum tersedia';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.pureWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.offBlack,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Administrator Platform (Hak Akses Penuh)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.slateGray, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Account Details Card
              Card(
                elevation: 0,
                color: AppTheme.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.subtleGray),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
                        title: const Text('Nama Lengkap', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                        subtitle: Text(name, style: const TextStyle(color: AppTheme.slateGray)),
                      ),
                      const Divider(height: 1, color: AppTheme.subtleGray),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                        title: const Text('Alamat Email', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                        subtitle: Text(email, style: const TextStyle(color: AppTheme.slateGray)),
                      ),
                      const Divider(height: 1, color: AppTheme.subtleGray),
                      const ListTile(
                        leading: Icon(Icons.security_outlined, color: AppTheme.primaryColor),
                        title: Text('Tingkat Otoritas', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                        subtitle: Text('Full Administrative Access (Super Admin)', style: TextStyle(color: AppTheme.slateGray)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Administrative Shortcuts
              Text(
                'Menu Administrasi Bisnis & Pengaturan:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.offBlack,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: AppTheme.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.subtleGray),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor),
                      title: const Text('Manajemen Paket Layanan', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.adminPackages),
                    ),
                    const Divider(height: 1, color: AppTheme.subtleGray),
                    ListTile(
                      leading: const Icon(Icons.card_membership_outlined, color: AppTheme.primaryColor),
                      title: const Text('Langganan Organizer', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminSubscriptions,
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.subtleGray),
                    ListTile(
                      leading: const Icon(Icons.monetization_on_outlined, color: AppTheme.successColor),
                      title: const Text('Transaksi & Pendapatan Platform', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminTransactions,
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.subtleGray),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, color: AppTheme.warningColor),
                      title: const Text('Pengaturan Komisi & Platform', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminSettings,
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.subtleGray),
                    ListTile(
                      leading: const Icon(Icons.history_outlined, color: AppTheme.secondaryColor),
                      title: const Text('Audit Log Tindakan Admin', style: TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminAuditLog,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.pureWhite,
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                label: const Text('Keluar dari Akun Admin', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                onPressed: () => _logout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

