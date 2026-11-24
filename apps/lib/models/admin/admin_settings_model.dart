/// Platform settings and fee change history models (PRD Section 6.10, FR-102, FR-103).
library;

class FeeChangeHistoryEntry {
  final String id;
  final DateTime timestamp;
  final String actorId;
  final String actorName;
  final double oldCommissionRate;
  final double newCommissionRate;
  final double oldFixedFee;
  final double newFixedFee;
  final String reason;

  const FeeChangeHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.oldCommissionRate,
    required this.newCommissionRate,
    required this.oldFixedFee,
    required this.newFixedFee,
    required this.reason,
  });

  factory FeeChangeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return FeeChangeHistoryEntry(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      actorId: json['actorId']?.toString() ?? json['actor_id']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? json['actor_name']?.toString() ?? 'Admin',
      oldCommissionRate: (json['oldCommissionRate'] ?? json['old_commission_rate'] ?? 0.0).toDouble(),
      newCommissionRate: (json['newCommissionRate'] ?? json['new_commission_rate'] ?? 0.0).toDouble(),
      oldFixedFee: (json['oldFixedFee'] ?? json['old_fixed_fee'] ?? 0.0).toDouble(),
      newFixedFee: (json['newFixedFee'] ?? json['new_fixed_fee'] ?? 0.0).toDouble(),
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class PlatformSettingsModel {
  final String platformName;
  final String contactEmail;
  final String contactPhone;
  final double ticketCommissionRate; // in percent (e.g. 5.0 for 5%)
  final double fixedServiceFee; // in IDR (e.g. 2500.0)
  final int orderPaymentTimeoutMinutes; // e.g. 120 (2 hours)
  final String termsOfServiceUrl;
  final String privacyPolicyUrl;
  final String refundPolicySummary;
  final DateTime lastUpdatedAt;
  final String lastUpdatedBy;

  const PlatformSettingsModel({
    required this.platformName,
    required this.contactEmail,
    required this.contactPhone,
    required this.ticketCommissionRate,
    required this.fixedServiceFee,
    required this.orderPaymentTimeoutMinutes,
    required this.termsOfServiceUrl,
    required this.privacyPolicyUrl,
    required this.refundPolicySummary,
    required this.lastUpdatedAt,
    required this.lastUpdatedBy,
  });

  factory PlatformSettingsModel.fromJson(Map<String, dynamic> json) {
    return PlatformSettingsModel(
      platformName: json['platformName']?.toString() ?? json['platform_name']?.toString() ?? 'E-Ticket Event Platform',
      contactEmail: json['contactEmail']?.toString() ?? json['contact_email']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? json['contact_phone']?.toString() ?? '',
      ticketCommissionRate: (json['ticketCommissionRate'] ?? json['ticket_commission_rate'] ?? 5.0).toDouble(),
      fixedServiceFee: (json['fixedServiceFee'] ?? json['fixed_service_fee'] ?? 2500.0).toDouble(),
      orderPaymentTimeoutMinutes: (json['orderPaymentTimeoutMinutes'] ?? json['order_payment_timeout_minutes'] ?? 120) as int,
      termsOfServiceUrl: json['termsOfServiceUrl']?.toString() ?? json['terms_of_service_url']?.toString() ?? '',
      privacyPolicyUrl: json['privacyPolicyUrl']?.toString() ?? json['privacy_policy_url']?.toString() ?? '',
      refundPolicySummary: json['refundPolicySummary']?.toString() ?? json['refund_policy_summary']?.toString() ?? '',
      lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt']?.toString() ?? json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      lastUpdatedBy: json['lastUpdatedBy']?.toString() ?? json['updated_by']?.toString() ?? 'Super Admin',
    );
  }

  PlatformSettingsModel copyWith({
    String? platformName,
    String? contactEmail,
    String? contactPhone,
    double? ticketCommissionRate,
    double? fixedServiceFee,
    int? orderPaymentTimeoutMinutes,
    String? termsOfServiceUrl,
    String? privacyPolicyUrl,
    String? refundPolicySummary,
    DateTime? lastUpdatedAt,
    String? lastUpdatedBy,
  }) {
    return PlatformSettingsModel(
      platformName: platformName ?? this.platformName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      ticketCommissionRate:
          ticketCommissionRate ?? this.ticketCommissionRate,
      fixedServiceFee: fixedServiceFee ?? this.fixedServiceFee,
      orderPaymentTimeoutMinutes:
          orderPaymentTimeoutMinutes ?? this.orderPaymentTimeoutMinutes,
      termsOfServiceUrl: termsOfServiceUrl ?? this.termsOfServiceUrl,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      refundPolicySummary: refundPolicySummary ?? this.refundPolicySummary,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }
}

