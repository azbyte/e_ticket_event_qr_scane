import 'package:flutter/material.dart';

import '../../features/admin/tabs/admin_tab_controller.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/events/screens/event_list_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notifications/screens/notification_list_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/organizer/tabs/organizer_tab_controller.dart';
import '../../features/reports/screens/report_form_screen.dart';
import '../../features/staff/screens/staff_dashboard_screen.dart';
import '../../features/tickets/screens/ticket_list_screen.dart';
import '../theme/app_theme.dart';

/// Navigation Drawer providing access to all 4 platform roles and core features.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.pureWhite,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.primaryColor, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                ),
                SizedBox(height: 10),
                Text(
                  'E-Ticket QR Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Platform Manajemen & Tiket Acara',
                  style: TextStyle(color: AppTheme.ashGray, fontSize: 12.5),
                ),
              ],
            ),
          ),

          // PESERTA SECTION
          _buildSectionHeader('PESERTA / ATTENDEE'),
          ListTile(
            leading: const Icon(Icons.home_outlined, color: AppTheme.primaryColor),
            title: const Text('Beranda'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined, color: AppTheme.primaryColor),
            title: const Text('Jelajahi Event'),
            onTap: () => _navigateTo(context, const EventListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryColor),
            title: const Text('Tiket Saya'),
            onTap: () => _navigateTo(context, const TicketListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: AppTheme.primaryColor),
            title: const Text('Riwayat Pesanan'),
            onTap: () => _navigateTo(context, const OrderListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline, color: AppTheme.primaryColor),
            title: const Text('Lapor Kendala'),
            onTap: () => _navigateTo(context, const ReportFormScreen()),
          ),

          const Divider(color: AppTheme.subtleGray),

          // PENYELENGGARA SECTION
          _buildSectionHeader('PENYELENGGARA / ORGANIZER'),
          ListTile(
            leading: const Icon(Icons.business_center_outlined, color: AppTheme.primaryColor),
            title: const Text('Portal Penyelenggara'),
            subtitle: const Text('Dashboard, Event, Peserta & Staf'),
            onTap: () => _navigateTo(context, const OrganizerTabController()),
          ),

          const Divider(color: AppTheme.subtleGray),

          // STAF CHECK-IN SECTION
          _buildSectionHeader('STAF EVENT / CHECK-IN'),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppTheme.successColor),
            title: const Text('Portal Staf & Scanner'),
            subtitle: const Text('Scan QR & Riwayat Check-In'),
            onTap: () => _navigateTo(context, const StaffDashboardScreen()),
          ),

          const Divider(color: AppTheme.subtleGray),

          // ADMIN SECTION
          _buildSectionHeader('ADMINISTRATOR PLATFORM'),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.secondaryColor),
            title: const Text('Portal Admin'),
            subtitle: const Text('Moderasi Event & Laporan Kendala'),
            onTap: () => _navigateTo(context, const AdminTabController()),
          ),

          const Divider(color: AppTheme.subtleGray),

          // AKUN & NOTIFIKASI
          _buildSectionHeader('AKUN & NOTIFIKASI'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: AppTheme.slateGray),
            title: const Text('Notifikasi'),
            onTap: () => _navigateTo(context, const NotificationListScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.login, color: AppTheme.slateGray),
            title: const Text('Masuk (Login)'),
            onTap: () => _navigateTo(context, const LoginScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_outlined, color: AppTheme.slateGray),
            title: const Text('Daftar Akun Baru'),
            onTap: () => _navigateTo(context, const RegisterScreen()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

