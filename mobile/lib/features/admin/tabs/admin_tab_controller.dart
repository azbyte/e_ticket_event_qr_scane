/// Admin platform tab navigation controller (PRD section 7.6).
///
/// Seamless navigation between Admin Overview Dashboard, Event Moderation,
/// and Trouble Ticket Resolution Management.
library;

import 'package:flutter/material.dart';

import '../../../providers/organizer_provider.dart';
import '../../../providers/report_provider.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/event_moderation_screen.dart';
import '../screens/report_management_screen.dart';

class AdminTabController extends StatefulWidget {
  const AdminTabController({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<AdminTabController> createState() => _AdminTabControllerState();
}

class _AdminTabControllerState extends State<AdminTabController> {
  late int _currentIndex;
  final OrganizerProvider _orgProvider = OrganizerProvider();
  final ReportProvider _reportProvider = ReportProvider();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(
        organizerProvider: _orgProvider,
        reportProvider: _reportProvider,
      ),
      EventModerationScreen(organizerProvider: _orgProvider),
      ReportManagementScreen(reportProvider: _reportProvider),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
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
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}
