import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:e_ticket_event_qr_scane/features/staff/screens/staff_dashboard_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

class _NoopAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

void main() {
  group('StaffDashboardScreen Widget Tests (T3-D2-03)', () {
    testWidgets('Staff dashboard menampilkan identitas staf dan empty state jika tidak ada penugasan', (tester) async {
      final authProvider = AuthProvider(_NoopAuthService())
        ..setUser(
          const UserModel(
            id: 'usr-stf-999',
            email: 'staf.resmi@example.com',
            name: 'Staf Lapangan Resmi',
            role: UserRole.staff,
          ),
        );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: const MaterialApp(
            home: StaffDashboardScreen(
              assignedEvents: [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Staf Lapangan Resmi'), findsOneWidget);
      expect(find.text('Belum ada penugasan event aktif'), findsOneWidget);
    });
  });
}
