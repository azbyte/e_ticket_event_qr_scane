/// Organizer event orders monitoring screen (PRD Section 4.9 & PEMBAGIAN_TUGAS_FINAL §E).
library;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../services/organizer_operations/organizer_permission.dart';

class OrganizerOrderModel {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final double subtotal;
  final double serviceFee;
  final double totalAmount;
  final String? guestName;
  final String? guestEmail;
  final String? guestPhone;
  final DateTime createdAt;
  final DateTime? paidAt;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> attendees;

  const OrganizerOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.subtotal,
    required this.serviceFee,
    required this.totalAmount,
    this.guestName,
    this.guestEmail,
    this.guestPhone,
    required this.createdAt,
    this.paidAt,
    this.items = const [],
    this.attendees = const [],
  });

  factory OrganizerOrderModel.fromJson(Map<String, dynamic> json) {
    return OrganizerOrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '-',
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      paymentStatus:
          (json['payment_status'] ?? json['status'] ?? 'PENDING')
              .toString()
              .toUpperCase(),
      paymentMethod:
          json['payment_method']?.toString() ?? 'SIMULATED_VIRTUAL_ACCOUNT',
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      serviceFee: (json['service_fee'] as num? ?? 0).toDouble(),
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      guestName: json['guest_name']?.toString(),
      guestEmail: json['guest_email']?.toString(),
      guestPhone: json['guest_phone']?.toString(),
      createdAt:
          json['created_at'] != null
              ? (DateTime.tryParse(json['created_at'].toString()) ??
                  DateTime.now())
              : DateTime.now(),
      paidAt:
          json['paid_at'] != null
              ? DateTime.tryParse(json['paid_at'].toString())
              : null,
      items:
          (json['items'] as List<dynamic>? ?? [])
              .map((i) => i as Map<String, dynamic>)
              .toList(),
      attendees:
          (json['attendees'] as List<dynamic>? ?? [])
              .map((a) => a as Map<String, dynamic>)
              .toList(),
    );
  }
}

class OrganizerOrderListScreen extends StatefulWidget {
  const OrganizerOrderListScreen({
    super.key,
    required this.eventId,
    this.eventName = 'Event',
    required this.contextScope,
  });

  final String eventId;
  final String eventName;
  final OrganizerMembershipContext contextScope;

  @override
  State<OrganizerOrderListScreen> createState() =>
      _OrganizerOrderListScreenState();
}

class _OrganizerOrderListScreenState extends State<OrganizerOrderListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OrganizerOrderModel> _orders = [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (AppConfig.mockMode) {
      _orders = [
        OrganizerOrderModel(
          id: 'ord-mock-01',
          orderNumber: 'ORD-202610-001',
          status: 'PAID',
          paymentStatus: 'PAID',
          paymentMethod: 'BCA Virtual Account (Demo)',
          subtotal: 750000,
          serviceFee: 5000,
          totalAmount: 755000,
          guestName: 'Ahmad Fauzi',
          guestEmail: 'ahmad@example.com',
          guestPhone: '081234567890',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          paidAt: DateTime.now().subtract(const Duration(hours: 2)),
          items: [
            {
              'ticket_type_name': 'VIP Pass',
              'quantity': 1,
              'unit_price': 750000,
            },
          ],
        ),
      ];
      setState(() => _isLoading = false);
      return;
    }

    try {
      final query = <String, String>{};
      if (_statusFilter != 'ALL') query['status'] = _statusFilter;

      final res = await ApiClient.instance.get(
        '/events/${widget.eventId}/orders',
        query: query,
      );
      final list = (res['orders'] as List<dynamic>? ?? []);
      setState(() {
        _orders =
            list
                .map(
                  (o) =>
                      OrganizerOrderModel.fromJson(o as Map<String, dynamic>),
                )
                .toList();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  void _showOrderDetail(OrganizerOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    _buildStatusBadge(order.paymentStatus),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pemesan: ${order.guestName ?? "-"} (${order.guestEmail ?? "-"})',
                ),
                Text('Metode: ${order.paymentMethod}'),
                Text('Total: ${_formatCurrency(order.totalAmount)}'),
                const Divider(height: 24),
                const Text(
                  'Item Tiket:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${it["quantity"]}x ${it["ticket_type_name"] ?? "-"}',
                        ),
                        Text(
                          _formatCurrency(
                            (it["unit_price"] as num? ?? 0).toDouble(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'PAID':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'PENDING':
      case 'PENDING_PAYMENT':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Daftar Pesanan - ${widget.eventName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _statusFilter == 'ALL',
                    onSelected: (_) {
                      setState(() => _statusFilter = 'ALL');
                      _loadOrders();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Lunas'),
                    selected: _statusFilter == 'PAID',
                    onSelected: (_) {
                      setState(() => _statusFilter = 'PAID');
                      _loadOrders();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Menunggu Pembayaran'),
                    selected: _statusFilter == 'PENDING',
                    onSelected: (_) {
                      setState(() => _statusFilter = 'PENDING');
                      _loadOrders();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Gagal memuat pesanan: $_errorMessage'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _loadOrders,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                    : _orders.isEmpty
                    ? const Center(
                      child: Text('Belum ada pesanan untuk acara ini.'),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return Card(
                            child: ListTile(
                              title: Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${order.guestName ?? "Peserta"} • ${_formatCurrency(order.totalAmount)}',
                              ),
                              trailing: _buildStatusBadge(order.paymentStatus),
                              onTap: () => _showOrderDetail(order),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
