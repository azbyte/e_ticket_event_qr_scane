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

