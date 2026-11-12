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

