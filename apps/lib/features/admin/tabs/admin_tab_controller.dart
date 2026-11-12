/// Admin platform tab navigation controller (PRD section 6.1, 7.6).
///
/// Seamless navigation between Admin Overview Dashboard, Event Moderation & Global Events,
/// Account Management, and Support Center.
library;

import 'package:flutter/material.dart';

import '../../../providers/organizer_provider.dart';
import '../../../providers/report_provider.dart';
import '../screens/account_management_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/event_moderation_screen.dart';
import '../screens/report_management_screen.dart';

class AdminTabController extends StatefulWidget {
  const AdminTabController({
    super.key,
    this.initialIndex = 0,
    this.organizerProvider,
    this.reportProvider,
    this.customScreens,
  });

  final int initialIndex;
  final OrganizerProvider? organizerProvider;
  final ReportProvider? reportProvider;
  final List<Widget>? customScreens;

  @override
  State<AdminTabController> createState() => _AdminTabControllerState();
}

class _AdminTabControllerState extends State<AdminTabController> {
  late int _currentIndex;
  late final OrganizerProvider _orgProvider;
  late final ReportProvider _reportProvider;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _orgProvider = widget.organizerProvider ?? OrganizerProvider();
    _reportProvider = widget.reportProvider ?? ReportProvider();
  }

  @override
  Widget build(BuildContext context) {
    final defaultScreens = <Widget>[
      const AdminDashboardScreen(),
      EventModerationScreen(organizerProvider: _orgProvider),
      const AccountManagementScreen(),
      ReportManagementScreen(reportProvider: _reportProvider),
    ];

    final screens = widget.customScreens ?? defaultScreens;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex < screens.length ? _currentIndex : 0,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex < 4 ? _currentIndex : 0,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
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
        ],
      ),
    );
  }
}
