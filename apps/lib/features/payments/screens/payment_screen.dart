import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/order_provider.dart';
import '../../../providers/payment_provider.dart';
import '../../../providers/ticket_provider.dart';
import 'payment_status_screen.dart';

/// Payment screen — simulated Virtual Account (PRD sections 4.7, 7.2 E).
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    this.orderId,
  });

  final String? orderId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentProvider _paymentProvider = PaymentProvider.instance;
  late String _effectiveOrderId;

  @override
  void initState() {
    super.initState();
    _effectiveOrderId = widget.orderId ?? 'ORD-20261028-002';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is String && routeArg.isNotEmpty) {
        _effectiveOrderId = routeArg;
      }
      _paymentProvider.loadPayment(_effectiveOrderId);
    });
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSimulation({required bool success}) async {
    final payment = _paymentProvider.payment;
    final va = payment?.virtualAccountNumber ?? '88092812345678';

    final result = await _paymentProvider.simulatePayment(
      orderId: _effectiveOrderId,
      virtualAccountNumber: va,
      simulateSuccess: success,
    );

    // Refresh order and ticket list state
    await OrderProvider.instance.loadOrders();
    await TicketProvider.instance.loadTickets();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentStatusScreen(
          orderId: _effectiveOrderId,
          isSuccess: result,
          payment: _paymentProvider.payment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Virtual Account'),
      ),
      body: ListenableBuilder(
        listenable: _paymentProvider,
        builder: (context, _) {
          if (_paymentProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memproses pembayaran...'),
                ],
              ),
            );
          }

          final payment = _paymentProvider.payment;
          if (payment == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('Data pembayaran tidak ditemukan.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _paymentProvider.loadPayment(_effectiveOrderId),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isPaid = payment.status == AppConstants.paymentStatusPaid;
          final vaNumber = payment.virtualAccountNumber ?? '88092812345678';
          final bankName = payment.vaBank ?? 'BCA Virtual Account';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPaid ? Colors.green.shade200 : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.access_time_filled,
                        color: isPaid ? Colors.green : Colors.amber.shade800,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaid ? 'Pembayaran Berhasil' : 'Menunggu Pembayaran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isPaid ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPaid
                                  ? 'Tiket Anda telah diterbitkan.'
                                  : 'Batas waktu: ${app_date.DateUtils.formatDateTime(payment.expiredAt ?? DateTime.now().add(const Duration(hours: 24)))}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isPaid ? Colors.green.shade700 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Virtual Account Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bankName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VA SIMULASI',
                              style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // VA Number Row
                      Text('Nomor Virtual Account', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            vaNumber,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyToClipboard(vaNumber, 'Nomor Virtual Account'),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Amount to Pay Row
                      Text('Total Pembayaran', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatCurrency(payment.amount),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyToClipboard(payment.amount.toInt().toString(), 'Nominal pembayaran'),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ID Pesanan: ${payment.orderId}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Instructions
                const Text(
                  'Petunjuk Pembayaran (Simulasi)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Mobile Banking'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '1. Buka aplikasi m-Banking Anda.\n'
                        '2. Pilih menu Transfer > Virtual Account.\n'
                        '3. Masukkan nomor VA: $vaNumber\n'
                        '4. Periksa nominal: ${_formatCurrency(payment.amount)}\n'
                        '5. Konfirmasi pembayaran dan simpan bukti transfer.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(Icons.local_atm),
                  title: const Text('ATM Transfer'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '1. Masukkan kartu ATM dan PIN.\n'
                        '2. Pilih menu Transaksi Lainnya > Transfer > Virtual Account.\n'
                        '3. Masukkan nomor Virtual Account: $vaNumber\n'
                        '4. Tagihan akan otomatis lunas.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Simulation Buttons
                if (!isPaid) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleSimulation(success: true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Simulasikan Pembayaran Berhasil',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _handleSimulation(success: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simulasikan Pembayaran Gagal / Dibatalkan'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => PaymentStatusScreen(
                              orderId: _effectiveOrderId,
                              isSuccess: true,
                              payment: payment,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text('Lihat E-Ticket Saya'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
