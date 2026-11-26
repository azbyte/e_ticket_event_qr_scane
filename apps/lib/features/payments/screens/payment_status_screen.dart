import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/payment/email_delivery_model.dart';
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
    this.emailDelivery = const EmailDeliverySummary(),
  });

  final String? orderId;
  final bool? isSuccess;
  final PaymentModel? payment;

  /// Status pengiriman email e-ticket yang sebenarnya dari backend.
  final EmailDeliverySummary emailDelivery;

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  @override
  Widget build(BuildContext context) {
    final status = payment?.status;
    final success = isSuccess ?? (status == AppConstants.paymentStatusPaid);
    final effectiveOrderId = orderId ?? payment?.orderId ?? '-';
    final isExpired = status == AppConstants.paymentStatusExpired;
    final isCancelled = status == AppConstants.paymentStatusCancelled;
    final canRetry = !success && !isExpired && !isCancelled;
    final statusLabel = switch (status) {
      AppConstants.paymentStatusPaid => 'Lunas (PAID)',
      AppConstants.paymentStatusPending => 'Menunggu pembayaran (PENDING)',
      AppConstants.paymentStatusExpired => 'Kedaluwarsa (EXPIRED)',
      AppConstants.paymentStatusCancelled => 'Dibatalkan (CANCELLED)',
      AppConstants.paymentStatusFailed => 'Gagal (FAILED)',
      _ => success ? 'Lunas (PAID)' : 'Gagal (FAILED)',
    };
    final title = success
        ? 'Pembayaran Berhasil Dikonfirmasi!'
        : isExpired
        ? 'Pembayaran Kedaluwarsa'
        : isCancelled
        ? 'Pembayaran Dibatalkan'
        : 'Pembayaran Gagal';
    final description = success
        ? 'Tiket elektronik (E-Ticket) dengan QR Code unik telah berhasil '
              'diterbitkan dan siap digunakan untuk check-in.'
        : isExpired
        ? 'Batas waktu pembayaran sudah lewat sehingga tiket tidak diterbitkan. '
              'Silakan buat pesanan baru dari halaman event.'
        : isCancelled
        ? 'Pesanan ini dibatalkan sehingga tiket tidak diterbitkan.'
        : 'Transaksi simulasi tidak berhasil diselesaikan. Anda dapat mencoba '
              'lagi selama pesanan belum kedaluwarsa.';
    // Status email hanya ditampilkan bila tiket sudah terbit, dan isinya
    // mengikuti keadaan sebenarnya (bukan asumsi "berhasil").
    final showEmailStatus = success && emailDelivery.results.isNotEmpty;
    final emailDelivered = emailDelivery.delivered;

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
                backgroundColor: success
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Icon(
                  success ? Icons.check_circle : Icons.cancel,
                  color: success ? Colors.green : Colors.red,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.black87 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.grey.shade600,
                ),
              ),
              if (showEmailStatus) ...[
                const SizedBox(height: 16),
                Container(
                  key: const Key('payment-email-status'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: emailDelivered
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: emailDelivered
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        emailDelivered ? Icons.mark_email_read : Icons.mail_outline,
                        color: emailDelivered
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          emailDelivery.message,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: emailDelivered
                                ? Colors.green.shade800
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    _buildRow(
                      'Metode Pembayaran',
                      payment?.vaBank ?? 'Virtual Account',
                    ),
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
                      statusLabel,
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
                        MaterialPageRoute(
                          builder: (_) =>
                              TicketListScreen(orderId: effectiveOrderId),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text(
                      'Buka E-Ticket Saya',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                        MaterialPageRoute(
                          builder: (_) => const EventListScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text('Kembali ke Jelajahi Event'),
                  ),
                ),
              ] else ...[
                if (canRetry) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      key: const Key('payment-status-retry-button'),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                PaymentScreen(orderId: effectiveOrderId),
                          ),
                        );
                      },
                      child: const Text('Coba Bayar Lagi'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const EventListScreen(),
                        ),
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

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
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
