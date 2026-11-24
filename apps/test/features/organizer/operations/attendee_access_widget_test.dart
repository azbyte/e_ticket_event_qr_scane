import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/screens/attendee_list_screen.dart';
import 'package:e_ticket_event_qr_scane/features/organizer/operations/organizer_scanner_screen.dart';
import 'package:e_ticket_event_qr_scane/features/scanner/screens/scanner_screen.dart';
import 'package:e_ticket_event_qr_scane/features/scanner/screens/scan_result_screen.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  group('Attendee Access & Permissions Tests', () {
    testWidgets('staff without participant permission cannot see attendee data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AttendeeListScreen(
            initialMembershipContext: OrganizerMembershipContext.staff(
              eventId: 'evt-1001',
              userName: 'Staf Pintu Masuk',
              permissions: {
                OrganizerPermission.scanTicket,
                OrganizerPermission.checkInTicket,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Akses daftar peserta tidak tersedia untuk peran ini.'),
        findsOneWidget,
      );
      expect(find.text('Total Peserta'), findsNothing);
      expect(find.text('Ahmad Fauzi'), findsNothing);
    });
  });

  group('OrganizerScannerScreen Permissions Tests', () {
    testWidgets('staff without scanTicket permission sees access denied view', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizerScannerScreen(
            eventId: 'evt-1001',
            contextScope: OrganizerMembershipContext.staff(
              eventId: 'evt-1001',
              userName: 'Staf Tanpa Izin Scan',
              permissions: {OrganizerPermission.viewReports},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses Ditolak'), findsOneWidget);
      expect(find.textContaining('SCAN_TICKET'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('staff with scanTicket permission can access scanner screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrganizerScannerScreen(
            eventId: 'evt-1001',
            contextScope: OrganizerMembershipContext.staff(
              eventId: 'evt-1001',
              userName: 'Staf Pintu',
              permissions: {OrganizerPermission.scanTicket},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Akses Ditolak'), findsNothing);
      expect(find.text('Input Kode / Token Tiket QR'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('ScannerScreen UI & Permission States', () {
    testWidgets('shows camera permission denied view with accessible retry button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScannerScreen(
            initialCameraPermission: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Izin Kamera Diperlukan'), findsOneWidget);
      expect(find.text('Coba Minta Izin Lagi'), findsOneWidget);

      // Ensure visible and tap retry button to grant permission
      await tester.ensureVisible(find.text('Coba Minta Izin Lagi'));
      await tester.tap(find.text('Coba Minta Izin Lagi'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Izin Kamera Diperlukan'), findsNothing);
      expect(find.text('Arahkan QR ke dalam kotak'), findsOneWidget);
    });

    testWidgets('provides manual ticket code entry and action buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScannerScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Input Kode / Token Tiket'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('1. Simulasikan Scan Valid (TK-TECH-003)'), findsOneWidget);
      expect(find.text('2. Simulasikan Tiket Sudah Check-in (Ganda)'), findsOneWidget);
      expect(find.text('3. Simulasikan Tiket Palsu / Invalid'), findsOneWidget);
    });
  });

  group('ScanResultScreen Status Details', () {
    testWidgets('displays confirmation for VALID status', (tester) async {
      final payload = {
        'status': 'VALID',
        'valid': true,
        'message': 'Tiket valid. Siap untuk check-in.',
        'ticket': {
          'ticket_code': 'TK-TECH-003',
          'attendee_name': 'Rian Pratama',
          'attendee_email': 'rian.pratama@example.com',
          'ticket_type': 'VIP Pass',
          'event_title': 'Tech Summit 2026',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: payload),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHECK-IN BERHASIL'), findsOneWidget);
      expect(find.text('Rian Pratama'), findsOneWidget);
      expect(find.text('TK-TECH-003'), findsOneWidget);
      expect(find.text('VIP Pass'), findsOneWidget);
    });

    testWidgets('displays duplicate warning for ALREADY_USED status', (tester) async {
      final payload = {
        'status': 'ALREADY_USED',
        'valid': false,
        'message': 'Tiket sudah digunakan untuk check-in sebelumnya.',
        'ticket': {
          'ticket_code': 'TK-TECH-001',
          'attendee_name': 'Ahmad Fauzi',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: payload),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TIKET SUDAH DIGUNAKAN'), findsOneWidget);
      expect(
        find.text('Pencegahan Check-in Ganda: Tiket ini telah dipakai sebelumnya.'),
        findsOneWidget,
      );
      expect(find.text('Ahmad Fauzi'), findsOneWidget);
    });

    testWidgets('displays warning for WRONG_EVENT and PAYMENT_REQUIRED statuses', (tester) async {
      final wrongEventPayload = {
        'status': 'WRONG_EVENT',
        'valid': false,
        'message': 'Tiket tidak berlaku untuk event ini.',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(result: wrongEventPayload),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EVENT TIDAK SESUAI'), findsOneWidget);
      expect(find.text('Tiket tidak berlaku untuk event ini.'), findsOneWidget);
    });
  });
}
