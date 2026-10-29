/// Ticket type / category model (PRD sections 4.2, 4.7, 6.3).
class TicketTypeModel {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final int quota;
  final int sold;
  final DateTime? salesStart;
  final DateTime? salesEnd;
  final bool isActive;

  const TicketTypeModel({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.price,
    required this.quota,
    this.sold = 0,
    this.salesStart,
    this.salesEnd,
    this.isActive = true,
  });

  int get availableQuota => quota - sold;
  bool get isSoldOut => availableQuota <= 0;

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) {
    return TicketTypeModel(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num? ?? 0).toDouble(),
      quota: json['quota'] as int? ?? 0,
      sold: json['sold'] as int? ?? 0,
      salesStart: json['sales_start'] != null
          ? DateTime.tryParse(json['sales_start'] as String)
          : null,
      salesEnd: json['sales_end'] != null
          ? DateTime.tryParse(json['sales_end'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'description': description,
      'price': price,
      'quota': quota,
      'sold': sold,
      'sales_start': salesStart?.toIso8601String(),
      'sales_end': salesEnd?.toIso8601String(),
      'is_active': isActive,
    };
  }

  @override
  String toString() => 'TicketTypeModel(id: $id, name: $name, price: $price)';
}
