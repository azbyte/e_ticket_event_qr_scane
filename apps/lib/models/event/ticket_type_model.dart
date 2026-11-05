/// Ticket type / category model (PRD sections 4.2, 4.7, 6.3).
///
/// [sold] = tiket yang sudah terjual, [held] = kuota yang ditahan order pending
/// (PRD 9.7 butir 6). Keduanya disimpan terpisah agar aturan "terjual + tertahan
/// tidak boleh melebihi kuota" dapat ditegakkan.
class TicketTypeModel {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final int quota;
  final int sold;

  /// Kuota yang sedang ditahan order pending (fixture Tahap 0).
  final int held;

  /// Batas pembelian per order; null berarti mengikuti batas platform.
  final int? maxPerOrder;
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
    this.held = 0,
    this.maxPerOrder,
    this.salesStart,
    this.salesEnd,
    this.isActive = true,
  });

  /// Sisa kuota tanpa memperhitungkan order pending (perilaku lama).
  int get availableQuota => quota - sold;

  /// Sisa kuota yang benar-benar dapat dijual (terjual + tertahan dihitung).
  int get remainingQuota => quota - sold - held;

  /// Total kuota terpakai: terjual + ditahan.
  int get reservedCount => sold + held;

  bool get isSoldOut => availableQuota <= 0;

  /// Kuota habis termasuk order pending yang menahan kuota.
  bool get isFullyReserved => remainingQuota <= 0;

  /// Kategori sudah memiliki transaksi/kuota tertahan sehingga tidak boleh
  /// dihapus (PRD 5.5.3 batasan).
  bool get hasTransactions => sold > 0 || held > 0;

  /// Apakah kategori masih dalam periode penjualan pada [now].
  bool isWithinSalesPeriod(DateTime now) {
    final started = salesStart == null || !now.isBefore(salesStart!);
    final notEnded = salesEnd == null || now.isBefore(salesEnd!);
    return started && notEnded;
  }

  /// Apakah kategori dapat dijual pada [now] (aktif, periode, sisa kuota).
  bool isSellableAt(DateTime now) =>
      isActive && !isFullyReserved && isWithinSalesPeriod(now);

  /// Snapshot harga untuk order baru (PRD 9.7 butir 8–9).
  ///
  /// Perubahan [price] setelah order dibuat tidak boleh mengubah order lama,
  /// karena nilai ini yang harus disalin ke `OrderItem` saat order dibuat.
  double get priceSnapshot => price;

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) {
    return TicketTypeModel(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num? ?? 0).toDouble(),
      quota: (json['quota'] as num? ?? 0).toInt(),
      sold: (json['sold'] as num? ?? 0).toInt(),
      held: (json['held'] as num? ?? 0).toInt(),
      maxPerOrder: (json['max_per_order'] as num?)?.toInt(),
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
      'held': held,
      'max_per_order': maxPerOrder,
      'sales_start': salesStart?.toIso8601String(),
      'sales_end': salesEnd?.toIso8601String(),
      'is_active': isActive,
    };
  }

  TicketTypeModel copyWith({
    String? id,
    String? eventId,
    String? name,
    String? description,
    double? price,
    int? quota,
    int? sold,
    int? held,
    int? maxPerOrder,
    DateTime? salesStart,
    DateTime? salesEnd,
    bool? isActive,
    bool clearDescription = false,
    bool clearMaxPerOrder = false,
    bool clearSalesStart = false,
    bool clearSalesEnd = false,
  }) {
    return TicketTypeModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      price: price ?? this.price,
      quota: quota ?? this.quota,
      sold: sold ?? this.sold,
      held: held ?? this.held,
      maxPerOrder: clearMaxPerOrder ? null : (maxPerOrder ?? this.maxPerOrder),
      salesStart: clearSalesStart ? null : (salesStart ?? this.salesStart),
      salesEnd: clearSalesEnd ? null : (salesEnd ?? this.salesEnd),
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'TicketTypeModel(id: $id, name: $name, price: $price, sold: $sold)';
}
