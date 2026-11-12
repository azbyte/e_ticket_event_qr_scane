/// Admin platform tab navigation controller (PRD section 6.1, 7.6).
///
/// Seamless navigation between Admin Overview Dashboard, Event Moderation & Global Events,
/// Account Management, and Support Center.
library;

import 'package:flutter/material.dart';

import '../../../providers/report_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_events/organizer_event_repository.dart';
import '../screens/account_management_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/event_moderation_screen.dart';
import '../screens/report_management_screen.dart';

class AdminTabController extends StatefulWidget {
  const AdminTabController({
    super.key,
    this.initialIndex = 0,
    this.eventRepository,
    this.reportProvider,
    this.customScreens,
  });

  final int initialIndex;
  final OrganizerEventRepository? eventRepository;
  final ReportProvider? reportProvider;
  final List<Widget>? customScreens;

  @override
  State<AdminTabController> createState() => _AdminTabControllerState();
}

class _AdminTabControllerState extends State<AdminTabController> {
  late int _currentIndex;
  late final ReportProvider _reportProvider;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _reportProvider = widget.reportProvider ?? ReportProvider();
  }

  @override
  Widget build(BuildContext context) {
    final defaultScreens = <Widget>[
      const AdminDashboardScreen(),
      EventModerationScreen(repository: widget.eventRepository),
      const AccountManagementScreen(),
      ReportManagementScreen(reportProvider: _reportProvider),
      const _AdminBusinessHubScreen(),
    ];

    final screens = widget.customScreens ?? defaultScreens;
    final visibleIndex = _currentIndex < screens.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: visibleIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: visibleIndex,
        onDestinationSelected: (idx) {
          if (idx < screens.length) setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval),
            label: 'Moderasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Akun',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_center_outlined),
            selectedIcon: Icon(Icons.business_center),
            label: 'Bisnis',
          ),
        ].take(screens.length).toList(),
      ),
    );
  }
}

class _AdminBusinessHubScreen extends StatelessWidget {
  const _AdminBusinessHubScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Modul Bisnis Platform')),
        body: ListView(
          children: [
            _BusinessRouteTile(
              icon: Icons.inventory_2_outlined,
              title: 'Manajemen Paket Layanan',
              route: AppRoutes.adminPackages,
            ),
            _BusinessRouteTile(
              icon: Icons.card_membership_outlined,
              title: 'Langganan Organizer',
              route: AppRoutes.adminSubscriptions,
            ),
            _BusinessRouteTile(
              icon: Icons.monetization_on_outlined,
              title: 'Transaksi & Pendapatan',
              route: AppRoutes.adminTransactions,
            ),
            _BusinessRouteTile(
              icon: Icons.settings_outlined,
              title: 'Pengaturan Platform',
              route: AppRoutes.adminSettings,
            ),
            _BusinessRouteTile(
              icon: Icons.history_outlined,
              title: 'Audit Log',
              route: AppRoutes.adminAuditLog,
            ),
            _BusinessRouteTile(
              icon: Icons.person_outline,
              title: 'Profil Administrator',
              route: AppRoutes.adminProfile,
            ),
          ],
        ),
      );
}

class _BusinessRouteTile extends StatelessWidget {
  const _BusinessRouteTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      );
}
