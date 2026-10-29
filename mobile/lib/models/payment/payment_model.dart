/// Payment model (PRD sections 4.7, 6.2). Simulated Virtual Account for MVP.
class PaymentModel {
  final String id;
  final String orderId;
  final String method; // virtual_account
  final String status; // pending, paid, failed, expired
  final double amount;
  final String? virtualAccountNumber;
  final String? vaBank;
  final DateTime? paidAt;
  final DateTime? expiredAt;
  final String? proofUrl;
  final String? notes;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    required this.status,
    required this.amount,
    this.virtualAccountNumber,
    this.vaBank,
    this.paidAt,
    this.expiredAt,
    this.proofUrl,
    this.notes,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      method: json['method'] as String? ?? 'virtual_account',
      status: json['status'] as String? ?? 'pending',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      virtualAccountNumber: json['virtual_account_number'] as String?,
      vaBank: json['va_bank'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.tryParse(json['expired_at'] as String)
          : null,
      proofUrl: json['proof_url'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'method': method,
      'status': status,
      'amount': amount,
      'virtual_account_number': virtualAccountNumber,
      'va_bank': vaBank,
      'paid_at': paidAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'proof_url': proofUrl,
      'notes': notes,
    };
  }

  @override
  String toString() =>
      'PaymentModel(id: $id, orderId: $orderId, status: $status)';
}
