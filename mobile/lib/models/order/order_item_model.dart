/// Order item model (links an order to a ticket type and quantity).
class OrderItemModel {
  final String id;
  final String orderId;
  final String ticketTypeId;
  final String ticketTypeName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.ticketTypeId,
    required this.ticketTypeName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      ticketTypeId: json['ticket_type_id'] as String? ?? '',
      ticketTypeName: json['ticket_type_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: (json['unit_price'] as num? ?? 0).toDouble(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'ticket_type_id': ticketTypeId,
      'ticket_type_name': ticketTypeName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}
