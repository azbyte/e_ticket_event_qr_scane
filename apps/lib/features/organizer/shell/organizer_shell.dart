/// Kerangka halaman Organizer (FR-66).
///
/// Menyediakan AppBar ringkas (judul halaman + ikon notifikasi) serta navigasi
/// utama yang konsisten:
/// - Mobile: [NavigationBar] dengan tepat tiga tujuan (Dashboard, Scan QR,
///   Profil).
/// - Web/desktop: sidebar dengan tiga tujuan yang sama.
///
/// Drawer (ikon hamburger) dan avatar profil pada AppBar tidak disediakan agar
/// header tetap ringkas dan tidak ada dua pintu masuk menuju halaman yang sama.
/// Halaman turunan (Event Saya, detail event, Tim & Staf, Paket, Bantuan)
/// dibuka dari halaman yang relevan sehingga bottom navigation tidak muncul dan
/// pengguna kembali melalui tombol kembali pada AppBar.
library;

import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../services/organizer_notifications/organizer_notifications_service.dart';
import '../../notifications/screens/notification_list_screen.dart';

/// Satu tujuan navigasi utama Organizer.
class _OrganizerDestination {
  const _OrganizerDestination({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class OrganizerShell extends StatelessWidget {
  const OrganizerShell({
    super.key,
    required this.currentRoute,
    required this.child,
    this.title = 'Dashboard',
    this.actions,
    this.floatingActionButton,
  });

  final String currentRoute;
  final Widget child;
  final String title;

  /// Aksi tambahan AppBar, ditampilkan sebelum ikon notifikasi.
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Tepat tiga menu utama. Fitur lain (Event Saya, Tim & Staf, Paket,
  /// Bantuan) dibuka dari halaman yang relevan, bukan dari bottom navigation.
  static const List<_OrganizerDestination> _destinations =
      <_OrganizerDestination>[
        _OrganizerDestination(
          route: AppRoutes.organizerDashboard,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
        ),
        _OrganizerDestination(
          route: AppRoutes.organizerScan,
          icon: Icons.qr_code_scanner_outlined,
          selectedIcon: Icons.qr_code_scanner,
          label: 'Scan QR',
        ),
        _OrganizerDestination(
          route: AppRoutes.organizerProfile,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profil',
        ),
      ];

  static const double _desktopBreakpoint = 900;

  /// Indeks tab aktif; `null` bila halaman ini bukan salah satu tab utama.
  int? get _selectedIndex {
    final index = _destinations.indexWhere(
      (destination) => destination.route == currentRoute,
    );
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
    final selectedIndex = _selectedIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF181818),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF181818)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: Color(0xFFE2E2E2),
          ),
        ),
        actions: <Widget>[
          ...?actions,
          _buildNotificationAction(context),
          const SizedBox(width: 4),
        ],
      ),
      body: Row(
        children: <Widget>[
          if (isDesktop) _buildSidebar(context, selectedIndex),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isDesktop || selectedIndex == null
          ? null
          : _buildBottomNav(context, selectedIndex),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNotificationAction(BuildContext context) {
    final unreadCount = OrganizerNotificationService.instance.unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifikasi',
          icon: const Icon(Icons.notifications_outlined, color: Color(0xFF181818)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationListScreen(),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE03E3E),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, int selectedIndex) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: const Color(0xFFC94426),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFFFFFF));
          }
          return const IconThemeData(color: Color(0xFFA8A8A8));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: Color(0xFFA8A8A8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: const Color(0xFFC94426),
        onDestinationSelected: (index) =>
            _openDestination(context, _destinations[index].route),
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, int? selectedIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Container(
        width: 248,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Portal Penyelenggara',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < _destinations.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildSidebarItem(
                    context,
                    _destinations[index],
                    selectedIndex == index,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    _OrganizerDestination destination,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
      leading: Icon(
        isSelected ? destination.selectedIcon : destination.icon,
        color: isSelected ? colorScheme.primary : Colors.black54,
      ),
      title: Text(
        destination.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? colorScheme.primary : Colors.black87,
        ),
      ),
      onTap: () => _openDestination(context, destination.route),
    );
  }

  /// Berpindah tab tanpa menumpuk halaman pada stack navigasi.
  void _openDestination(BuildContext context, String route) {
    if (route == currentRoute) return;
    Navigator.pushReplacementNamed(context, route);
  }
}
