import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/notifications/screens/notification_list_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/event/event_service.dart';
import '../screens/account_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _events = EventService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _events.platformEvents();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Super Admin'),
      leading: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final name = auth.user?.name ?? 'Admin';
          return IconButton(
            tooltip: 'Profil',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminProfile),
            icon: CircleAvatar(
              radius: 17,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A'),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationListScreen(),
            ),
          ),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, size: 40),
                title: Text('Selamat datang, ${auth.user?.name ?? 'Admin'}'),
                subtitle: Text(
                  '${auth.user?.email ?? ''}\nAdministrator platform-wide',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: const Text('Event platform'),
                    subtitle: Text('Gagal memuat event: ${snapshot.error}'),
                  ),
                );
              }
              final events = snapshot.data ?? [];
              final organizers = events
                  .map((event) => event['created_by'])
                  .where((id) => id != null)
                  .toSet()
                  .length;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total event',
                          value: '${events.length}',
                          icon: Icons.event,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Penyelenggara aktif',
                          value: '$organizers',
                          icon: Icons.groups,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Seluruh event platform',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  ...events.map(
                    (event) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(event['title']?.toString() ?? 'Event'),
                        subtitle: Text(
                          '${event['location'] ?? ''} · ${event['event_date'] ?? ''}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Belum ada event.'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Pengelolaan akun'),
              subtitle: const Text(
                'Lihat akun platform dan aktifkan/nonaktifkan akun.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountManagementScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
