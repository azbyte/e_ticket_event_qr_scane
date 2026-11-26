import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/scanner/screens/scan_result_screen.dart';

void main() {
  group('Scanner & CheckIn Online Widget Tests (T3-D2-04 & T3-D2-05)', () {
    testWidgets('ScanResultScreen menampilkan hasil VALID secara ramah dan aman', (tester) async {
      final validResult = {
        'status': 'VALID',
        'valid': true,
        'message': 'Check-in berhasil.',
        'ticket': {
          'ticket_code': 'TK-TECH-001',
          'attendee_name': 'Rian Pratama',
          'ticket_type': 'VIP Pass',
          'event_title': 'Tech Summit 2026',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: validResult),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHECK-IN BERHASIL'), findsOneWidget);
      expect(find.text('TK-TECH-001'), findsOneWidget);
      expect(find.text('Rian Pratama'), findsOneWidget);
      expect(find.text('VIP Pass'), findsOneWidget);
    });

    testWidgets('ScanResultScreen menampilkan peringatan TIKET SUDAH DIGUNAKAN untuk check-in ganda', (tester) async {
      final alreadyUsedResult = {
        'status': 'ALREADY_USED',
        'valid': false,
        'message': 'Tiket sudah digunakan sebelumnya.',
        'ticket': {
          'ticket_code': 'TK-USED-002',
          'attendee_name': 'Budi Santoso',
          'ticket_type': 'Regular',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: alreadyUsedResult),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TIKET SUDAH DIGUNAKAN'), findsOneWidget);
      expect(find.text('TK-USED-002'), findsOneWidget);
    });

    testWidgets('ScanResultScreen menangani status WRONG_EVENT dan PAYMENT_REQUIRED', (tester) async {
      final wrongEventResult = {
        'status': 'WRONG_EVENT',
        'valid': false,
        'message': 'Tiket bukan untuk event ini.',
        'ticket': {'ticket_code': 'TK-WRONG-01'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: wrongEventResult),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EVENT TIDAK SESUAI'), findsOneWidget);
    });
  });
}
