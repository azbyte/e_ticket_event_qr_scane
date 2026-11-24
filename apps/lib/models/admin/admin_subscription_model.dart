/// Admin subscription management entity model (PRD Section 6.6, FR-79).
library;

class SubscriptionChangeEvent {
  final String fromPlan;
  final String toPlan;
  final DateTime changedAt;
  final String reason;

  const SubscriptionChangeEvent({
    required this.fromPlan,
    required this.toPlan,
    required this.changedAt,
    required this.reason,
  });
}

class SubscriptionPaymentRecord {
  final String invoiceNumber;
  final double amount;
  final String paymentMethod;
  final String status; // 'PAID', 'PENDING', 'FAILED'
  final DateTime paidAt;

  const SubscriptionPaymentRecord({
    required this.invoiceNumber,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paidAt,
  });
}

class AdminSubscriptionModel {
  final String id;
  final String organizerId;
  final String organizerName;
  final String organizerEmail;
  final String planId;
  final String planName;
  final String status; // 'ACTIVE', 'PENDING_PAYMENT', 'EXPIRED', 'CANCELLED', 'SUSPENDED'
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final double lastPaymentAmount;
  final DateTime lastPaymentDate;
  final List<SubscriptionChangeEvent> changeHistory;
  final List<SubscriptionPaymentRecord> paymentHistory;

  const AdminSubscriptionModel({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    required this.organizerEmail,
    required this.planId,
    required this.planName,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.autoRenew = true,
    required this.lastPaymentAmount,
    required this.lastPaymentDate,
    this.changeHistory = const [],
    this.paymentHistory = const [],
  });

  factory AdminSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionModel(
      id: json['id']?.toString() ?? '',
      organizerId: json['organizerId']?.toString() ?? json['organizer_id']?.toString() ?? '',
      organizerName: json['organizerName']?.toString() ?? json['organizer_name']?.toString() ?? 'Organizer',
      organizerEmail: json['organizerEmail']?.toString() ?? json['organizer_email']?.toString() ?? '',
      planId: json['planId']?.toString() ?? json['plan_id']?.toString() ?? '',
      planName: json['planName']?.toString() ?? json['plan_name']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? json['end_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      autoRenew: json['autoRenew'] as bool? ?? json['auto_renew'] as bool? ?? true,
      lastPaymentAmount: (json['lastPaymentAmount'] ?? json['last_payment_amount'] ?? 0).toDouble(),
      lastPaymentDate: DateTime.tryParse(json['lastPaymentDate']?.toString() ?? json['last_payment_date']?.toString() ?? '') ?? DateTime.now(),
      changeHistory: const [],
      paymentHistory: const [],
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isSuspended => status == 'SUSPENDED';
  bool get isExpired => status == 'EXPIRED';
  bool get isPendingPayment => status == 'PENDING_PAYMENT';

  int get remainingDays => endDate.difference(DateTime.now()).inDays;

  AdminSubscriptionModel copyWith({
    String? status,
    DateTime? endDate,
    bool? autoRenew,
    List<SubscriptionChangeEvent>? changeHistory,
    List<SubscriptionPaymentRecord>? paymentHistory,
  }) {
    return AdminSubscriptionModel(
      id: id,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerEmail: organizerEmail,
      planId: planId,
      planName: planName,
      status: status ?? this.status,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      autoRenew: autoRenew ?? this.autoRenew,
      lastPaymentAmount: lastPaymentAmount,
      lastPaymentDate: lastPaymentDate,
      changeHistory: changeHistory ?? this.changeHistory,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }
}

