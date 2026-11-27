/// Admin platform tab navigation controller (PRD section 6.1, 7.6).
///
/// Seamless navigation between Admin Overview Dashboard, Event Moderation & Global Events,
/// Account Management, and Support Center.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppTheme.surfaceColor,
      body: IndexedStack(
        index: visibleIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppTheme.secondaryColor,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppTheme.primaryColor,
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppTheme.pureWhite);
            }
            return const IconThemeData(color: AppTheme.ashGray);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppTheme.pureWhite,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: AppTheme.ashGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: visibleIndex,
          backgroundColor: AppTheme.secondaryColor,
          indicatorColor: AppTheme.primaryColor,
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
      ),
    );
  }
}

class _AdminBusinessHubScreen extends StatelessWidget {
  const _AdminBusinessHubScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: const Text('Modul Bisnis Platform'),
          backgroundColor: AppTheme.pureWhite,
          foregroundColor: AppTheme.offBlack,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppTheme.pureWhite,
              elevation: 0,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.subtleGray),
              ),
              child: const Column(
                children: [
                  _BusinessRouteTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Manajemen Paket Layanan',
                    route: AppRoutes.adminPackages,
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
                  _BusinessRouteTile(
                    icon: Icons.card_membership_outlined,
                    title: 'Langganan Organizer',
                    route: AppRoutes.adminSubscriptions,
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
                  _BusinessRouteTile(
                    icon: Icons.monetization_on_outlined,
                    title: 'Transaksi & Pendapatan',
                    route: AppRoutes.adminTransactions,
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
                  _BusinessRouteTile(
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan Platform',
                    route: AppRoutes.adminSettings,
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
                  _BusinessRouteTile(
                    icon: Icons.history_outlined,
                    title: 'Audit Log',
                    route: AppRoutes.adminAuditLog,
                  ),
                  Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
                  _BusinessRouteTile(
                    icon: Icons.person_outline,
                    title: 'Profil Administrator',
                    route: AppRoutes.adminProfile,
                  ),
                ],
              ),
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
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: const TextStyle(color: AppTheme.offBlack, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.slateGray),
        onTap: () => Navigator.pushNamed(context, route),
      );
}
