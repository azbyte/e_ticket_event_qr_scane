/// Admin package entity model (PRD Section 6.5, FR-74, FR-75, FR-76).
library;

class AdminPackageModel {
  final String id;
  final String name;
  final String description;
  final double priceMonthly;
  final double priceYearly;
  final String status; // 'active', 'inactive', 'archived'
  final bool isFree;
  final int maxActiveEvents;
  final int maxTicketsPerEvent;
  final int maxStaffPerEvent;
  final bool hasAdvancedReports;
  final bool hasExportAttendees;
  final bool hasCustomBranding;
  final bool hasAnalytics;
  final int activeSubscribersCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AdminPackageModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.status,
    required this.isFree,
    required this.maxActiveEvents,
    required this.maxTicketsPerEvent,
    required this.maxStaffPerEvent,
    required this.hasAdvancedReports,
    required this.hasExportAttendees,
    required this.hasCustomBranding,
    required this.hasAnalytics,
    this.activeSubscribersCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isArchived => status == 'archived';

  AdminPackageModel copyWith({
    String? name,
    String? description,
    double? priceMonthly,
    double? priceYearly,
    String? status,
    bool? isFree,
    int? maxActiveEvents,
    int? maxTicketsPerEvent,
    int? maxStaffPerEvent,
    bool? hasAdvancedReports,
    bool? hasExportAttendees,
    bool? hasCustomBranding,
    bool? hasAnalytics,
    int? activeSubscribersCount,
    DateTime? updatedAt,
  }) {
    return AdminPackageModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      priceYearly: priceYearly ?? this.priceYearly,
      status: status ?? this.status,
      isFree: isFree ?? this.isFree,
      maxActiveEvents: maxActiveEvents ?? this.maxActiveEvents,
      maxTicketsPerEvent: maxTicketsPerEvent ?? this.maxTicketsPerEvent,
      maxStaffPerEvent: maxStaffPerEvent ?? this.maxStaffPerEvent,
      hasAdvancedReports: hasAdvancedReports ?? this.hasAdvancedReports,
      hasExportAttendees: hasExportAttendees ?? this.hasExportAttendees,
      hasCustomBranding: hasCustomBranding ?? this.hasCustomBranding,
      hasAnalytics: hasAnalytics ?? this.hasAnalytics,
      activeSubscribersCount:
          activeSubscribersCount ?? this.activeSubscribersCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

