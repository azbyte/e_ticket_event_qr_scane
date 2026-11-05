/// Order model (PRD sections 4.4, 4.7, 6.2).
import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String? userId; // null for guest orders
  final String eventId;
  final String eventTitle;
  final String status; // pending_payment, paid, expired, cancelled
  final double totalAmount;
  final double serviceFee;
  final double grandTotal;
  final List<OrderItemModel> items;
  final DateTime? expiresAt;
  final String? paymentReference;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    this.userId,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.totalAmount,
    this.serviceFee = 0,
    required this.grandTotal,
    required this.items,
    this.expiresAt,
    this.paymentReference,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending_payment';
  bool get isExpired => status == 'expired';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      eventId: json['event_id'] as String? ?? '',
      eventTitle: json['event_title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_payment',
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      serviceFee: (json['service_fee'] as num? ?? 0).toDouble(),
      grandTotal: (json['grand_total'] as num? ?? 0).toDouble(),
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      paymentReference: json['payment_reference'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'event_title': eventTitle,
      'status': status,
      'total_amount': totalAmount,
      'service_fee': serviceFee,
      'grand_total': grandTotal,
      'items': items.map((e) => e.toJson()).toList(),
      'expires_at': expiresAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'OrderModel(id: $id, status: $status, total: $grandTotal)';
}
