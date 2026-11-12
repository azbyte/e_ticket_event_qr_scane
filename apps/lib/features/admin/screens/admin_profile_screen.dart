/// Admin profile screen (/admin/profile) for Platform Admin (PRD Section 6.1, FR-80).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(
        title: const Text('Profil Administrator'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          final name = user?.name ?? 'Super Admin';
          final email = user?.email ?? 'admin@event.com';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'A',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Administrator Platform (Hak Akses Penuh)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Account Details Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Nama Lengkap'),
                        subtitle: Text(name),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Alamat Email'),
                        subtitle: Text(email),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.security_outlined),
                        title: Text('Tingkat Otoritas'),
                        subtitle: Text('Full Administrative Access (Super Admin)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Administrative Shortcuts
              Text(
                'Menu Administrasi Bisnis & Pengaturan:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                      title: const Text('Manajemen Paket Layanan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.adminPackages),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.card_membership_outlined, color: Colors.purple),
                      title: const Text('Langganan Organizer'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminSubscriptions,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.monetization_on_outlined, color: Colors.green),
                      title: const Text('Transaksi & Pendapatan Platform'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminTransactions,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, color: Colors.orange),
                      title: const Text('Pengaturan Komisi & Platform'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.adminSettings,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history_outlined, color: Colors.indigo),
                      title: const Text('Audit Log Tindakan Admin'),
                      trailing: const Icon(Icons.chevron_right),
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
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Akun Admin'),
                onPressed: () => _logout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

