/// Kompatibilitas navigasi Organizer (PRD section 7.4).
///
/// Sebelumnya kelas ini membuat bottom navigation kedua (Dashboard, Event,
/// Peserta, Staf) yang tumpang tindih dengan [OrganizerShell]. Sekarang seluruh
/// pintu masuk Organizer memakai [OrganizerDashboardScreen] agar hanya ada satu
/// sistem navigasi dengan tiga menu utama (Dashboard, Scan QR, Profil).
library;

import 'package:flutter/material.dart';

import '../screens/organizer_dashboard_screen.dart';

class OrganizerTabController extends StatelessWidget {
  const OrganizerTabController({super.key, this.initialIndex = 0});

  /// Dipertahankan agar pemanggil lama tetap kompatibel. Navigasi kini
  /// dikelola oleh [OrganizerShell], sehingga nilai ini tidak lagi dipakai.
  final int initialIndex;

  @override
  Widget build(BuildContext context) => const OrganizerDashboardScreen();
}
