/// Organizer tab navigation controller (PRD section 7.4).
///
/// Seamless bottom navigation between Organizer Dashboard, Event Management,
/// Attendee monitoring, and Staff delegations.
library;

import 'package:flutter/material.dart';

import '../../../providers/organizer_provider.dart';
import '../screens/attendee_list_screen.dart';
import '../screens/event_management_screen.dart';
import '../screens/organizer_dashboard_screen.dart';
import '../screens/staff_management_screen.dart';

class OrganizerTabController extends StatefulWidget {
  const OrganizerTabController({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<OrganizerTabController> createState() => _OrganizerTabControllerState();
}

class _OrganizerTabControllerState extends State<OrganizerTabController> {
  late int _currentIndex;
  final OrganizerProvider _provider = OrganizerProvider();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OrganizerDashboardScreen(organizerProvider: _provider),
      EventManagementScreen(organizerProvider: _provider),
      const AttendeeListScreen(),
      StaffManagementScreen(organizerProvider: _provider),
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Event Saya',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Peserta',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Staf',
          ),
        ],
      ),
    );
  }
}
