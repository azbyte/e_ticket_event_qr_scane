import 'package:flutter/material.dart';

import '../../../models/payment/payment_model.dart';
import '../../events/screens/event_list_screen.dart';
import '../../tickets/screens/ticket_list_screen.dart';
import 'payment_screen.dart';

/// Payment status screen — PRD sections 3.1 #8, 6.2.
class PaymentStatusScreen extends StatelessWidget {
  const PaymentStatusScreen({
    super.key,
    this.orderId,
    this.isSuccess,
    this.payment,
  });

  final String? orderId;
  final bool? isSuccess;
  final PaymentModel? payment;

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  @override
  Widget build(BuildContext context) {
    final success = isSuccess ?? (payment?.status == 'paid');
    final effectiveOrderId = orderId ?? payment?.orderId ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Transaksi'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon / Circle
              CircleAvatar(
                radius: 46,
                backgroundColor: success ? Colors.green.shade50 : Colors.red.shade50,
                child: Icon(
                  success ? Icons.check_circle : Icons.cancel,
                  color: success ? Colors.green : Colors.red,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                success ? 'Pembayaran Berhasil Dikonfirmasi!' : 'Pembayaran Gagal / Dibatalkan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.black87 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                success
                    ? 'Tiket elektronik (E-Ticket) dengan QR Code unik telah berhasil diterbitkan dan siap digunakan untuk check-in.'
                    : 'Transaksi simulasi tidak berhasil diselesaikan. Anda dapat mencoba lagi atau kembali ke daftar pesanan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),

              // Detail receipt card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRow('ID Pesanan', effectiveOrderId),
                    const Divider(height: 20),
                    _buildRow('Metode Pembayaran', payment?.vaBank ?? 'Virtual Account'),
                    const Divider(height: 20),
                    if (payment?.virtualAccountNumber != null) ...[
                      _buildRow('Nomor VA', payment!.virtualAccountNumber!),
                      const Divider(height: 20),
                    ],
                    _buildRow(
                      'Total Dibayar',
                      payment != null ? _formatCurrency(payment!.amount) : '-',
                      isBold: true,
                    ),
                    const Divider(height: 20),
                    _buildRow(
                      'Status',
                      success ? 'Lunas (PAID)' : 'Gagal (FAILED)',
                      textColor: success ? Colors.green.shade700 : Colors.red,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Action buttons
              if (success) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const TicketListScreen()),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text(
                      'Buka E-Ticket Saya',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EventListScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Kembali ke Jelajahi Event'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(orderId: effectiveOrderId),
                        ),
                      );
                    },
                    child: const Text('Coba Bayar Lagi'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EventListScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text('Kembali ke Beranda Event'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            color: textColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
