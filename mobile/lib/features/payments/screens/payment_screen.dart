/// Payment screen — simulated Virtual Account (PRD sections 4.7, 7.2 E).
///
/// Stub fondasi. Nomor VA simulasi, total, dan batas waktu pembayaran akan
/// diimplementasi setelah PaymentProvider dan endpoint pembayaran tersedia.
import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Simulasi pembayaran Virtual Account.'),
            SizedBox(height: 8),
            Text(
              'Stub fondasi — integrasi API belum tersedia. Payment gateway sungguhan ditunda (PRD 3.2).',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
