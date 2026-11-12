import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/admin_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/admin/admin_revenue_service.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

class FakeAdminAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>> me() async => {
    'id': 'usr-admin',
    'name': 'Super Admin Test',
    'email': 'admin@event.com',
    'role': 'admin',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createDashboardWidget(AuthProvider authProvider) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const AdminDashboardScreen(),
      ),
    );
  }

  group('AdminDashboardScreen Widget Tests (FR-80 s.d. FR-85)', () {
    testWidgets(
      'Menampilkan metrik lengkap operasional event, pengguna, dan pendapatan',
      (tester) async {
        final authProvider = AuthProvider(FakeAdminAuthService());
        await authProvider.restoreSession();

        await tester.pumpWidget(createDashboardWidget(authProvider));
        await tester.pumpAndSettle();

        // Header greeting
        expect(find.text('Super Admin Dashboard'), findsOneWidget);
        expect(find.textContaining('Super Admin Test'), findsOneWidget);

        // Section 1: Event Operational Metrics (FR-80)
        expect(find.text('Operasional Event Platform'), findsOneWidget);
        expect(find.text('Total Event'), findsOneWidget);
        expect(find.text('Event Mendatang'), findsOneWidget);
        expect(find.text('Menunggu Moderasi'), findsOneWidget);

        // Section 2: Users & Orders (FR-81, FR-82)
        expect(find.text('Pengguna & Transaksi Pesanan'), findsOneWidget);
        expect(find.text('Total Organizer'), findsOneWidget);
        expect(find.text('Total Peserta'), findsOneWidget);
        expect(find.text('Total Order Pesanan'), findsOneWidget);
        expect(find.text('Tiket Diterbitkan'), findsOneWidget);

        // Section 3: Revenue (FR-83, FR-90, FR-93)
        expect(find.text('TOTAL PENDAPATAN PLATFORM'), findsOneWidget);
        expect(
          find.textContaining('Penjualan Tiket Kotor (Gross Sales)'),
          findsOneWidget,
        );
        expect(find.textContaining('Komisi Tiket Platform'), findsOneWidget);
        expect(find.textContaining('Pendapatan Paket Layanan'), findsOneWidget);

        // Section 4: Visual chart (FR-85)
        expect(find.text('Distribusi Status Event Platform'), findsOneWidget);
        expect(
          find.text('Tren Pertumbuhan Penjualan & Pendapatan'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Filter periode memperbarui ringkasan pendapatan platform (FR-84)',
      (tester) async {
        final authProvider = AuthProvider(FakeAdminAuthService());
        await authProvider.restoreSession();

        await tester.pumpWidget(createDashboardWidget(authProvider));
        await tester.pumpAndSettle();

        // Pilih filter periode dropdown
        final dropdown = find.byType(DropdownButton<String>);
        expect(dropdown, findsOneWidget);

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Tap opsi Hari Ini
        await tester.tap(find.text('Hari Ini').last);
        await tester.pumpAndSettle();

        final today = AdminRevenueService.instance.getRevenueSummarySnapshot(
          period: 'today',
        );
        expect(
          find.text(_formatCurrency(today.ticketCommissionRevenue)),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.text(_formatCurrency(today.grossTicketSales)),
          findsAtLeastNWidgets(1),
        );
      },
    );
  });
}

String _formatCurrency(double amount) {
  final digits = amount.toStringAsFixed(0);
  final chars = digits.split('').reversed.toList();
  final parts = <String>[];
  for (var index = 0; index < chars.length; index++) {
    if (index > 0 && index % 3 == 0) parts.add('.');
    parts.add(chars[index]);
  }
  return 'Rp ${parts.reversed.join()}';
}
