import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/features/payments/screens/payment_status_screen.dart';
import 'package:e_ticket_event_qr_scane/models/payment/payment_model.dart';

void main() {
  group('Payment & Order Screens Widget Tests (Tahap 1 D3)', () {
    testWidgets('PaymentStatusScreen renders success state and ticket confirmation', (tester) async {
      final successPayment = PaymentModel(
        id: 'pay-001',
        orderId: 'ORD-20261123-001',
        method: 'virtual_account',
        status: 'paid',
        amount: 25000,
        vaBank: 'BCA Virtual Account',
        virtualAccountNumber: '8800112233445566',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentStatusScreen(
            orderId: 'ORD-20261123-001',
            isSuccess: true,
            payment: successPayment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status Transaksi'), findsOneWidget);
      expect(find.text('Pembayaran Berhasil Dikonfirmasi!'), findsOneWidget);
      expect(find.text('ORD-20261123-001'), findsOneWidget);
      expect(find.text('Buka E-Ticket Saya'), findsOneWidget);
    });

    testWidgets('PaymentStatusScreen renders failure state and retry options', (tester) async {
      final failedPayment = PaymentModel(
        id: 'pay-002',
        orderId: 'ORD-20261123-002',
        method: 'virtual_account',
        status: 'failed',
        amount: 15000,
        vaBank: 'Mandiri Virtual Account',
        virtualAccountNumber: '8800998877665544',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentStatusScreen(
            orderId: 'ORD-20261123-002',
            isSuccess: false,
            payment: failedPayment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status Transaksi'), findsOneWidget);
      // Status FAILED kini dibedakan dari EXPIRED/CANCELLED (D1-5 K4).
      expect(find.text('Pembayaran Gagal'), findsOneWidget);
      expect(find.text('Gagal (FAILED)'), findsOneWidget);
      expect(find.text('Coba Bayar Lagi'), findsOneWidget);
    });

    testWidgets('PaymentStatusScreen membedakan status expired tanpa aksi bayar ulang', (
      tester,
    ) async {
      final expiredPayment = PaymentModel(
        id: 'pay-003',
        orderId: 'ORD-20261123-003',
        method: 'virtual_account',
        status: 'expired',
        amount: 15000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentStatusScreen(
            orderId: 'ORD-20261123-003',
            payment: expiredPayment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pembayaran Kedaluwarsa'), findsOneWidget);
      expect(find.text('Kedaluwarsa (EXPIRED)'), findsOneWidget);
      expect(find.text('Coba Bayar Lagi'), findsNothing);
    });
  });
}
