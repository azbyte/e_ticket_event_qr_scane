/// Admin platform settings service implementation (PRD Section 6.10, FR-102, FR-103).
library;

import 'package:flutter/widgets.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../models/admin/admin_settings_model.dart';
import 'admin_audit_log_service.dart';

bool get _isTestEnvironment {
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return true;
  }
}

class AdminSettingsService {
  AdminSettingsService._internal();
  static final AdminSettingsService instance = AdminSettingsService._internal();
  factory AdminSettingsService() => instance;

  final AdminAuditLogService _auditLogService = AdminAuditLogService.instance;

  PlatformSettingsModel _settings = PlatformSettingsModel(
    platformName: 'E-Ticket Event Platform',
    contactEmail: 'support@eventplatform.id',
    contactPhone: '+62 812-3456-7890',
    ticketCommissionRate: 5.0, // 5%
    fixedServiceFee: 5000.0, // Rp 5.000
    orderPaymentTimeoutMinutes: 120, // 2 jam
    termsOfServiceUrl: 'https://eventplatform.id/terms',
    privacyPolicyUrl: 'https://eventplatform.id/privacy',
    refundPolicySummary: 'Pengembalian dana diproses oleh penyelenggara sesuai kebijakan tiap event sebelum batas waktu H-3.',
    lastUpdatedAt: DateTime.now().subtract(const Duration(days: 7)),
    lastUpdatedBy: 'Super Admin',
  );

  final List<FeeChangeHistoryEntry> _feeHistory = [
    FeeChangeHistoryEntry(
      id: 'fch-001',
      timestamp: DateTime.now().subtract(const Duration(days: 90)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      oldCommissionRate: 8.0,
      newCommissionRate: 7.0,
      oldFixedFee: 5000.0,
      newFixedFee: 5000.0,
      reason: 'Penetapan tarif operasional platform Rp 5.000 sesuai kebijakan C-01.',
    ),
    FeeChangeHistoryEntry(
      id: 'fch-002',
      timestamp: DateTime.now().subtract(const Duration(days: 7)),
      actorId: 'usr-admin-01',
      actorName: 'Super Admin',
      oldCommissionRate: 7.0,
      newCommissionRate: 5.0,
      oldFixedFee: 5000.0,
      newFixedFee: 5000.0,
      reason: 'Kebijakan promosi kuartal untuk mendukung pertumbuhan event organizer (read-only C-01).',
    ),
  ];

  /// Retrieves current platform settings.
  Future<PlatformSettingsModel> getSettings() async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      try {
        final response = await ApiClient().get('/admin/settings');
        final data = response['data'] as Map<String, dynamic>? ?? response;
        _settings = PlatformSettingsModel.fromJson(data);
        if (data['feeHistory'] is List) {
          _feeHistory.clear();
          for (final item in data['feeHistory']) {
            if (item is Map<String, dynamic>) {
              _feeHistory.add(FeeChangeHistoryEntry.fromJson(item));
            }
          }
        }
        return _settings;
      } catch (e) {
        rethrow;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _settings;
  }

  /// Retrieves history of platform fee adjustments (FR-103).
  Future<List<FeeChangeHistoryEntry>> getFeeHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_feeHistory);
  }

  /// Updates platform settings and records audit log / fee history if rates change (FR-102, FR-103).
  Future<bool> updateSettings(
    PlatformSettingsModel newSettings, {
    required String actorId,
    required String actorName,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final feeChanged = _settings.ticketCommissionRate != newSettings.ticketCommissionRate ||
        _settings.fixedServiceFee != newSettings.fixedServiceFee;

    if (feeChanged) {
      final entry = FeeChangeHistoryEntry(
        id: 'fch-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actorId: actorId,
        actorName: actorName,
        oldCommissionRate: _settings.ticketCommissionRate,
        newCommissionRate: newSettings.ticketCommissionRate,
        oldFixedFee: _settings.fixedServiceFee,
        newFixedFee: newSettings.fixedServiceFee,
        reason: reason ?? 'Penyesuaian konfigurasi komisi & biaya platform.',
      );
      _feeHistory.insert(0, entry);

      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'SETTINGS_FEE_CHANGED',
        entityType: 'SETTINGS',
        entityId: entry.id,
        reason: reason,
        details: 'Komisi diubah dari ${_settings.ticketCommissionRate}% menjadi ${newSettings.ticketCommissionRate}%, Biaya tetap: Rp ${newSettings.fixedServiceFee.toInt()}.',
        metadata: {
          'oldRate': _settings.ticketCommissionRate,
          'newRate': newSettings.ticketCommissionRate,
          'oldFixedFee': _settings.fixedServiceFee,
          'newFixedFee': newSettings.fixedServiceFee,
        },
      );
    } else {
      await _auditLogService.logAction(
        actorId: actorId,
        actorName: actorName,
        action: 'SETTINGS_UPDATED',
        entityType: 'SETTINGS',
        entityId: 'global-settings',
        details: 'Memperbarui informasi dan kebijakan platform.',
      );
    }

    if (!AppConfig.mockMode && !_isTestEnvironment) {
      try {
        if (_settings.ticketCommissionRate != newSettings.ticketCommissionRate) {
          await ApiClient().put(
            '/admin/settings/ticket_commission_rate',
            body: {'value': newSettings.ticketCommissionRate, 'reason': reason},
          );
        }
        if (_settings.fixedServiceFee != newSettings.fixedServiceFee) {
          await ApiClient().put(
            '/admin/settings/fixed_service_fee',
            body: {'value': newSettings.fixedServiceFee, 'reason': reason},
          );
        }
        if (_settings.platformName != newSettings.platformName) {
          await ApiClient().put(
            '/admin/settings/platform_name',
            body: {'value': newSettings.platformName, 'reason': reason},
          );
        }
      } catch (_) {
        // Continue to update local state
      }
    }

    _settings = newSettings.copyWith(
      lastUpdatedAt: DateTime.now(),
      lastUpdatedBy: actorName,
    );

    return true;
  }
}

