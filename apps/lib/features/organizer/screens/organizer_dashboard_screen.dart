import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../notifications/screens/notification_list_screen.dart';
import 'event_form_screen.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Portal Penyelenggara'),
      leading: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final name = auth.user?.name ?? 'Penyelenggara';
          return IconButton(
            tooltip: 'Profil',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.organizerProfile),
            icon: CircleAvatar(
              radius: 17,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P'),
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
    body: Consumer<AuthProvider>(
      builder: (context, auth, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_available, size: 38),
                  const SizedBox(height: 12),
                  Text(
                    'Halo, ${auth.user?.name ?? 'Penyelenggara'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mulai buat event untuk dibagikan kepada peserta.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const EventFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Event'),
          ),
        ],
      ),
    ),
  );
}
