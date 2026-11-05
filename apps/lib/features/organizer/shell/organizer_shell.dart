/// Responsive Organizer Shell layout (FR-66).
///
/// Provides top bar, responsive sidebar navigation (for Web / Desktop)
/// and bottom navigation (for Mobile), with notification badges and profile menus.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_notifications/organizer_notifications_service.dart';

class OrganizerShell extends StatelessWidget {
  const OrganizerShell({
    super.key,
    required this.currentRoute,
    required this.child,
    this.title = 'Portal Penyelenggara',
    this.actions,
    this.floatingActionButton,
  });

  final String currentRoute;
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final notifService = OrganizerNotificationService.instance;
    final unreadCount = notifService.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 1,
        actions: [
          ...?actions,
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifikasi Penyelenggara',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notificationList),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final name = auth.user?.name ?? 'Penyelenggara';
              return IconButton(
                tooltip: 'Profil Saya',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.organizerProfile),
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(context),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(context),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Consumer<AuthProvider>(
              builder: (context, auth, _) => UserAccountsDrawerHeader(
                accountName: Text(auth.user?.name ?? 'PT Event Nusantara'),
                accountEmail: Text(auth.user?.email ?? 'organizer@platform.id'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (auth.user?.name ?? 'P')[0].toUpperCase(),
                    style: TextStyle(fontSize: 24, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            _buildDrawerTile(context, Icons.dashboard_outlined, 'Dashboard', AppRoutes.organizerDashboard),
            _buildDrawerTile(context, Icons.event_note_outlined, 'Event Saya', AppRoutes.organizerEvents),
            _buildDrawerTile(context, Icons.people_outline, 'Manajemen Tim & Staf', AppRoutes.organizerTeam),
            _buildDrawerTile(context, Icons.card_membership_outlined, 'Paket & Langganan', AppRoutes.organizerPlans),
            _buildDrawerTile(context, Icons.help_outline, 'Pusat Bantuan & Laporan', AppRoutes.organizerSupport),
            const Divider(),
            _buildDrawerTile(context, Icons.person_outline, 'Profil Penyelenggara', AppRoutes.organizerProfile),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar (Logout)', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final navigator = Navigator.of(context);
                await context.read<AuthProvider>().logout();
                navigator.pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildSidebarItem(context, Icons.dashboard_outlined, 'Dashboard', AppRoutes.organizerDashboard),
          _buildSidebarItem(context, Icons.event_note_outlined, 'Event Saya', AppRoutes.organizerEvents),
          _buildSidebarItem(context, Icons.people_outline, 'Manajemen Tim', AppRoutes.organizerTeam),
          _buildSidebarItem(context, Icons.card_membership_outlined, 'Paket Langganan', AppRoutes.organizerPlans),
          _buildSidebarItem(context, Icons.help_outline, 'Pusat Bantuan', AppRoutes.organizerSupport),
          const Divider(),
          _buildSidebarItem(context, Icons.person_outline, 'Profil Akun', AppRoutes.organizerProfile),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final navigator = Navigator.of(context);
              await context.read<AuthProvider>().logout();
              navigator.pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
        leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
          ),
        ),
        onTap: () {
          if (!isSelected) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    int getIndex() {
      if (currentRoute == AppRoutes.organizerDashboard) return 0;
      if (currentRoute == AppRoutes.organizerEvents) return 1;
      if (currentRoute == AppRoutes.organizerTeam) return 2;
      if (currentRoute == AppRoutes.organizerPlans) return 3;
      if (currentRoute == AppRoutes.organizerSupport) return 4;
      return 0;
    }

    return NavigationBar(
      selectedIndex: getIndex(),
      onDestinationSelected: (idx) {
        switch (idx) {
          case 0:
            if (currentRoute != AppRoutes.organizerDashboard) {
              Navigator.pushReplacementNamed(context, AppRoutes.organizerDashboard);
            }
            break;
          case 1:
            if (currentRoute != AppRoutes.organizerEvents) {
              Navigator.pushReplacementNamed(context, AppRoutes.organizerEvents);
            }
            break;
          case 2:
            if (currentRoute != AppRoutes.organizerTeam) {
              Navigator.pushReplacementNamed(context, AppRoutes.organizerTeam);
            }
            break;
          case 3:
            if (currentRoute != AppRoutes.organizerPlans) {
              Navigator.pushReplacementNamed(context, AppRoutes.organizerPlans);
            }
            break;
          case 4:
            if (currentRoute != AppRoutes.organizerSupport) {
              Navigator.pushReplacementNamed(context, AppRoutes.organizerSupport);
            }
            break;
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Event'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Tim'),
        NavigationDestination(icon: Icon(Icons.card_membership_outlined), selectedIcon: Icon(Icons.card_membership), label: 'Paket'),
        NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: 'Bantuan'),
      ],
    );
  }
}
