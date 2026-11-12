import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/features/admin/screens/account_management_screen.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

class FakeAdminAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>> me() async => {
        'id': 'usr-admin',
        'name': 'Super Admin',
        'email': 'admin@event.com',
        'role': 'admin',
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createAccountWidget(AuthProvider authProvider) {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const AccountManagementScreen(),
      ),
    );
  }

  group('AccountManagementScreen Widget Tests (FR-87, FR-88)', () {
    testWidgets('Menampilkan tab Semua Akun, Organizer, dan Participant',
        (tester) async {
      final auth = AuthProvider(FakeAdminAuthService());
      await auth.restoreSession();

      await tester.pumpWidget(createAccountWidget(auth));
      await tester.pumpAndSettle();

      expect(find.text('Pengelolaan Akun Platform'), findsOneWidget);
      expect(find.text('Semua Akun'), findsOneWidget);
      expect(find.text('Organizer'), findsOneWidget);
      expect(find.text('Participant'), findsOneWidget);

      // Pastikan ada akun organizer di tab default
      expect(find.text('Organizer Event Nusantara'), findsOneWidget);

      // Beralih ke tab Participant
      await tester.tap(find.text('Participant'));
      await tester.pumpAndSettle();
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('Pencarian akun menyaring data berdasarkan kata kunci',
        (tester) async {
      final auth = AuthProvider(FakeAdminAuthService());
      await auth.restoreSession();

      await tester.pumpWidget(createAccountWidget(auth));
      await tester.pumpAndSettle();

      // Ketik pencarian "Dewi"
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Dewi');
      await tester.pumpAndSettle();

      expect(find.text('Dewi Lestari'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsNothing);
    });

    testWidgets('Penangguhan akun wajib mengisi alasan (FR-88)',
        (tester) async {
      final auth = AuthProvider(FakeAdminAuthService());
      await auth.restoreSession();

      await tester.pumpWidget(createAccountWidget(auth));
      await tester.pumpAndSettle();

      // Cari tombol Tangguhkan untuk akun aktif yang bukan diri sendiri
      final suspendButtons = find.widgetWithText(OutlinedButton, 'Tangguhkan');
      expect(suspendButtons, findsWidgets);

      // Tap tombol tangguhkan pertama
      await tester.tap(suspendButtons.first);
      await tester.pumpAndSettle();

      // Dialog penangguhan muncul
      expect(find.textContaining('Alasan Penangguhan Akun *'), findsOneWidget);

      // Coba klik konfirmasi tanpa alasan
      final confirmBtn = find.widgetWithText(FilledButton, 'Tangguhkan Akun');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Validasi error tampil
      expect(find.text('Alasan penangguhan wajib diisi.'), findsOneWidget);

      // Isi alasan yang valid
      final reasonField = find.byType(TextFormField);
      await tester.enterText(reasonField, 'Pelanggaran syarat ketentuan penjualan tiket.');
      await tester.pumpAndSettle();

      // Konfirmasi penangguhan
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // SnackBar konfirmasi tampil
      expect(find.textContaining('berhasil ditangguhkan'), findsOneWidget);
    });
  });
}
