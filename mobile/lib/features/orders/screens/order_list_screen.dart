import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/order_provider.dart';
import '../../events/screens/event_list_screen.dart';
import '../../payments/screens/payment_screen.dart';
import 'order_detail_screen.dart';

/// Order list screen (attendee order history) — PRD sections 7.3 A.
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final OrderProvider _orderProvider = OrderProvider.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orderProvider.loadOrders();
    });
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.orderStatusPaid:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'LUNAS';
        break;
      case AppConstants.orderStatusPendingPayment:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        label = 'MENUNGGU PEMBAYARAN';
        break;
      case AppConstants.orderStatusExpired:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'KEDALUWARSA';
        break;
      case AppConstants.orderStatusCancelled:
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'DIBATALKAN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
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
                  Text('Memuat riwayat pesanan...'),
                ],
              ),
            );
          }

          if (_orderProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      _orderProvider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _orderProvider.loadOrders(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = _orderProvider.orders;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum Ada Pesanan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anda belum memiliki riwayat pembelian tiket.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const EventListScreen()),
                      );
                    },
                    child: const Text('Jelajahi Event Sekarang'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _orderProvider.loadOrders(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final isPending = order.status == AppConstants.orderStatusPendingPayment;

                return Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderId: order.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              _buildStatusBadge(order.status),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            order.eventTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                app_date.DateUtils.formatDateTime(order.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const Spacer(),
                              Text(
                                '${order.items.fold(0, (sum, i) => sum + i.quantity)} Tiket',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Biaya', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text(
                                    _formatCurrency(order.grandTotal),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              if (isPending)
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PaymentScreen(orderId: order.id),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              else
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Lihat Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Icon(Icons.chevron_right, size: 18),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
