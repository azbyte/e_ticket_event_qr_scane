/// Admin package service implementation (PRD Section 6.5, FR-74, FR-75, FR-76).
library;

import 'package:flutter/widgets.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../models/admin/admin_package_model.dart';
import 'admin_audit_log_service.dart';

bool get _isTestEnvironment {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return true;
  }
}

class AdminPackageService {
  AdminPackageService._internal();
  static final AdminPackageService instance = AdminPackageService._internal();
  factory AdminPackageService() => instance;

  final AdminAuditLogService _auditLogService = AdminAuditLogService.instance;

  AdminPackageModel _parseAdminPackage(Map<String, dynamic> json) {
    final features = json['features'] as Map<String, dynamic>? ?? {};
    return AdminPackageModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceMonthly: (json['price_monthly'] as num? ?? 0).toDouble(),
      priceYearly: (json['price_yearly'] as num? ?? 0).toDouble(),
      status: (json['status'] ?? 'active').toString().toLowerCase(),
      isFree: json['is_free'] == true,
      maxActiveEvents: json['max_active_events'] as int? ?? 1,
      maxTicketsPerEvent: json['max_tickets_per_event'] as int? ?? 100,
      maxStaffPerEvent: json['max_staff_per_event'] as int? ?? 2,
      hasAdvancedReports: features['has_advanced_reports'] == true || features['hasAdvancedReports'] == true,
      hasExportAttendees: features['has_export_attendees'] == true || features['hasExportAttendees'] == true,
      hasCustomBranding: features['has_custom_branding'] == true || features['hasCustomBranding'] == true,
      hasAnalytics: features['has_analytics'] == true || features['hasAnalytics'] == true,
      activeSubscribersCount: json['active_subscribers_count'] as int? ?? 0,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  final List<AdminPackageModel> _packages = [
    AdminPackageModel(
      id: 'pkg-starter',
      name: 'Starter (Gratis)',
      description: 'Paket dasar gratis untuk penyelenggara komunitas pemula.',
      priceMonthly: 0,
      priceYearly: 0,
      status: 'active',
      isFree: true,
      maxActiveEvents: 2,
      maxTicketsPerEvent: 100,
      maxStaffPerEvent: 2,
      hasAdvancedReports: false,
      hasExportAttendees: false,
      hasCustomBranding: false,
      hasAnalytics: false,
      activeSubscribersCount: 24,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AdminPackageModel(
      id: 'pkg-pro',
      name: 'Professional',
      description: 'Paket menengah untuk event seminar, pameran, dan workshop profesional.',
      priceMonthly: 299000,
      priceYearly: 2990000,
      status: 'active',
      isFree: false,
      maxActiveEvents: 10,
      maxTicketsPerEvent: 2000,
      maxStaffPerEvent: 15,
      hasAdvancedReports: true,
      hasExportAttendees: true,
      hasCustomBranding: true,
      hasAnalytics: true,
      activeSubscribersCount: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AdminPackageModel(
      id: 'pkg-enterprise',
      name: 'Enterprise Event',
      description: 'Solusi lengkap festival skala besar dengan multi-gate check-in tanpa batas.',
      priceMonthly: 999000,
      priceYearly: 9990000,
      status: 'active',
      isFree: false,
      maxActiveEvents: 999,
      maxTicketsPerEvent: 999999,
      maxStaffPerEvent: 999,
      hasAdvancedReports: true,
      hasExportAttendees: true,
      hasCustomBranding: true,
      hasAnalytics: true,
      activeSubscribersCount: 3,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AdminPackageModel(
      id: 'pkg-legacy',
      name: 'Early Bird Community (Arsip)',
      description: 'Paket lama khusus promosi rilis versi awal.',
      priceMonthly: 99000,
      priceYearly: 990000,
      status: 'archived',
      isFree: false,
      maxActiveEvents: 3,
      maxTicketsPerEvent: 300,
      maxStaffPerEvent: 5,
      hasAdvancedReports: false,
      hasExportAttendees: true,
      hasCustomBranding: false,
      hasAnalytics: false,
      activeSubscribersCount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
    ),
  ];

  /// Lists all packages with optional status filter.
  Future<List<AdminPackageModel>> getPackages({String? statusFilter}) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final query = <String, String>{};
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        query['status'] = statusFilter.toUpperCase();
      }
      final res = await ApiClient.instance.get('/plans/admin/all', query: query.isEmpty ? null : query);
      final list = (res['plans'] as List<dynamic>? ?? []);
      return list.map((p) => _parseAdminPackage(p as Map<String, dynamic>)).toList();
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (statusFilter == null || statusFilter.isEmpty || statusFilter == 'ALL') {
      return List.unmodifiable(_packages);
    }
    return _packages.where((p) => p.status == statusFilter).toList();
  }

  /// Creates a new service package (FR-74).
  Future<AdminPackageModel> createPackage(
    AdminPackageModel package, {
    required String actorId,
    required String actorName,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final body = {
        'name': package.name,
        'description': package.description,
        'priceMonthly': package.priceMonthly,
        'priceYearly': package.priceYearly,
        'status': package.status.toUpperCase(),
        'isFree': package.isFree,
        'maxActiveEvents': package.maxActiveEvents,
        'maxTicketsPerEvent': package.maxTicketsPerEvent,
        'maxStaffPerEvent': package.maxStaffPerEvent,
        'features': {
          'has_advanced_reports': package.hasAdvancedReports,
          'has_export_attendees': package.hasExportAttendees,
          'has_custom_branding': package.hasCustomBranding,
          'has_analytics': package.hasAnalytics,
        },
      };
      final res = await ApiClient.instance.post('/plans/admin', body: body);
      final created = _parseAdminPackage(res['plan'] as Map<String, dynamic>);
      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'PACKAGE_CREATED',
        entityType: 'PACKAGE',
        entityId: created.id,
        details: 'Membuat paket layanan baru: "${created.name}" (Rp ${created.priceMonthly.toInt()}/bln).',
      );
      return created;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    _packages.insert(0, package);

    await _auditLogService.logAction(
      actorId: actorId,
      actorName: actorName,
      action: 'PACKAGE_CREATED',
      entityType: 'PACKAGE',
      entityId: package.id,
      details: 'Membuat paket layanan baru: "${package.name}" (Rp ${package.priceMonthly.toInt()}/bln).',
    );

    return package;
  }

  /// Updates an existing service package (FR-74).
  Future<AdminPackageModel> updatePackage(
    AdminPackageModel package, {
    required String actorId,
    required String actorName,
    String? reason,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final body = {
        'name': package.name,
        'description': package.description,
        'priceMonthly': package.priceMonthly,
        'priceYearly': package.priceYearly,
        'status': package.status.toUpperCase(),
        'isFree': package.isFree,
        'maxActiveEvents': package.maxActiveEvents,
        'maxTicketsPerEvent': package.maxTicketsPerEvent,
        'maxStaffPerEvent': package.maxStaffPerEvent,
        'features': {
          'has_advanced_reports': package.hasAdvancedReports,
          'has_export_attendees': package.hasExportAttendees,
          'has_custom_branding': package.hasCustomBranding,
          'has_analytics': package.hasAnalytics,
        },
      };
      final res = await ApiClient.instance.put('/plans/admin/${package.id}', body: body);
      final updated = _parseAdminPackage(res['plan'] as Map<String, dynamic>);
      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'PACKAGE_UPDATED',
        entityType: 'PACKAGE',
        entityId: package.id,
        reason: reason,
        details: 'Memperbarui konfigurasi paket "${package.name}".',
      );
      return updated;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _packages.indexWhere((p) => p.id == package.id);
    if (index != -1) {
      _packages[index] = package.copyWith(updatedAt: DateTime.now());

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'PACKAGE_UPDATED',
        entityType: 'PACKAGE',
        entityId: package.id,
        reason: reason,
        details: 'Memperbarui konfigurasi paket "${package.name}".',
      );

      return _packages[index];
    }
    throw StateError('Paket dengan ID ${package.id} tidak ditemukan.');
  }

  /// Toggles active/inactive status (FR-74).
  Future<bool> togglePackageStatus(
    String packageId, {
    required String actorId,
    required String actorName,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final currentList = await getPackages();
      final target = currentList.firstWhere((p) => p.id == packageId);
      final newStatus = target.isActive ? 'INACTIVE' : 'ACTIVE';
      await ApiClient.instance.put('/plans/admin/$packageId', body: {'status': newStatus});
      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: newStatus == 'ACTIVE' ? 'PACKAGE_ACTIVATED' : 'PACKAGE_DEACTIVATED',
        entityType: 'PACKAGE',
        entityId: packageId,
        details: 'Mengubah status paket "${target.name}" menjadi $newStatus.',
      );
      return true;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _packages.indexWhere((p) => p.id == packageId);
    if (index != -1) {
      final current = _packages[index];
      final newStatus = current.isActive ? 'inactive' : 'active';
      _packages[index] = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: newStatus == 'active' ? 'PACKAGE_ACTIVATED' : 'PACKAGE_DEACTIVATED',
        entityType: 'PACKAGE',
        entityId: packageId,
        details: 'Mengubah status paket "${current.name}" menjadi $newStatus.',
      );

      return true;
    }
    return false;
  }

  /// Archives a package safely without deleting historical data (FR-74).
  Future<bool> archivePackage(
    String packageId, {
    required String actorId,
    required String actorName,
    required String reason,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      await ApiClient.instance.delete('/plans/admin/$packageId');
      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'PACKAGE_ARCHIVED',
        entityType: 'PACKAGE',
        entityId: packageId,
        reason: reason,
        details: 'Mengarsipkan paket dengan ID $packageId.',
      );
      return true;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _packages.indexWhere((p) => p.id == packageId);
    if (index != -1) {
      final current = _packages[index];
      _packages[index] = current.copyWith(
        status: 'archived',
        updatedAt: DateTime.now(),
      );

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'PACKAGE_ARCHIVED',
        entityType: 'PACKAGE',
        entityId: packageId,
        reason: reason,
        details: 'Mengarsipkan paket "${current.name}".',
      );

      return true;
    }
    return false;
  }
}

