import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/order_provider.dart';
import '../../payments/screens/payment_screen.dart';
import '../../tickets/screens/ticket_list_screen.dart';

/// Order detail screen — PRD section 7.3 B.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    this.orderId,
  });

  final String? orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderProvider _orderProvider = OrderProvider.instance;
  late String _effectiveOrderId;

  @override
  void initState() {
    super.initState();
    _effectiveOrderId = widget.orderId ?? 'ORD-20261020-001';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is String && routeArg.isNotEmpty) {
        _effectiveOrderId = routeArg;
      }
      _orderProvider.loadOrder(_effectiveOrderId);
    });
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
      ),
      body: ListenableBuilder(
        listenable: _orderProvider,
        builder: (context, _) {
          if (_orderProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat detail pesanan...'),
                ],
              ),
            );
          }

          final order = _orderProvider.selectedOrder;
          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('Pesanan tidak ditemukan.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _orderProvider.loadOrder(_effectiveOrderId),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isPaid = order.status == AppConstants.orderStatusPaid;
          final isPending = order.status == AppConstants.orderStatusPendingPayment;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Header Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade50
                        : isPending
                            ? Colors.amber.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPaid
                          ? Colors.green.shade200
                          : isPending
                              ? Colors.amber.shade300
                              : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid
                            ? Icons.check_circle
                            : isPending
                                ? Icons.access_time_filled
                                : Icons.info,
                        color: isPaid
                            ? Colors.green
                            : isPending
                                ? Colors.amber.shade800
                                : Colors.grey.shade700,
                        size: 30,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaid
                                  ? 'Pesanan Lunas'
                                  : isPending
                                      ? 'Menunggu Pembayaran'
                                      : 'Status: ${order.status.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isPaid
                                    ? Colors.green.shade900
                                    : isPending
                                        ? Colors.amber.shade900
                                        : Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nomor Pesanan: ${order.id}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Event Info Section
                const Text('Informasi Acara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.eventTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Dibuat: ${app_date.DateUtils.formatDateTime(order.createdAt)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Purchased Items Breakdown
                const Text('Rincian Tiket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.ticketTypeName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${item.quantity} x ${_formatCurrency(item.unitPrice)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(item.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      _buildSummaryRow('Subtotal Tiket', _formatCurrency(order.totalAmount)),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Biaya Layanan', _formatCurrency(order.serviceFee)),
                      const Divider(height: 20),
                      _buildSummaryRow(
                        'Total Biaya',
                        _formatCurrency(order.grandTotal),
                        isBold: true,
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                if (isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(orderId: order.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text(
                        'Lanjutkan ke Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else if (isPaid) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TicketListScreen()),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text(
                        'Lihat E-Ticket & QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
