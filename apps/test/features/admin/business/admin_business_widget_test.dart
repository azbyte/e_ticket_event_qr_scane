import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_profile_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_settings_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/audit_log_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/package_management_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/subscription_management_screen.dart';
import 'package:e_ticket_event_qr_scane/features/admin/screens/transaction_revenue_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

void main() {
  Widget createTestWidget(Widget child) {
    final auth = AuthProvider(AuthService())
      ..setUser(
        const UserModel(
          id: 'usr-admin-01',
          name: 'Super Admin',
          email: 'admin@event.com',
          role: UserRole.admin,
        ),
      );

    return ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Admin Business Screens Widget Tests', () {
    testWidgets('PackageManagementScreen renders package items and filter chips', (tester) async {
      await tester.pumpWidget(createTestWidget(const PackageManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Manajemen Paket Layanan'), findsOneWidget);
      expect(find.text('Semua Paket'), findsOneWidget);
      expect(find.text('Buat Paket Baru'), findsOneWidget);
      expect(find.text('Starter (Gratis)'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
    });

    testWidgets('SubscriptionManagementScreen renders subscriptions and search field', (tester) async {
      await tester.pumpWidget(createTestWidget(const SubscriptionManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Manajemen Langganan Organizer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('PT Event Nusantara'), findsOneWidget);
    });

    testWidgets('TransactionRevenueScreen renders financial segregation summary', (tester) async {
      await tester.pumpWidget(createTestWidget(const TransactionRevenueScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Transaksi & Pendapatan Platform'), findsOneWidget);
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Transaksi Tiket'), findsOneWidget);
      expect(find.text('Pembayaran Paket'), findsOneWidget);
      expect(find.text('Total Pendapatan Bersih Platform'), findsOneWidget);
      expect(find.textContaining('Gross Sales'), findsOneWidget);
    });

    testWidgets('AdminSettingsScreen renders commission and fee form inputs', (tester) async {
      await tester.pumpWidget(createTestWidget(const AdminSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Pengaturan Platform'), findsOneWidget);
      expect(find.text('Simpan Pengaturan'), findsOneWidget);
      expect(find.textContaining('Komisi Tiket'), findsWidgets);
    });

    testWidgets('AuditLogScreen renders audit log records and filter chips', (tester) async {
      await tester.pumpWidget(createTestWidget(const AuditLogScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Audit Log Tindakan Admin'), findsOneWidget);
      expect(find.text('Semua Entitas'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AdminProfileScreen displays administrator info and administrative links', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const AdminProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Profil Administrator'), findsOneWidget);
      expect(find.text('Super Admin'), findsNWidgets(2));
      expect(find.text('admin@event.com'), findsOneWidget);
      expect(find.text('Manajemen Paket Layanan'), findsOneWidget);
      expect(find.text('Keluar dari Akun Admin'), findsOneWidget);
    });
  });
}

