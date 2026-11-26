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

/// Nilai yang ditetapkan produk (C-01) bila `platform_settings` belum memuat
/// key terkait. Dipakai hanya sebagai fallback tampilan, bukan data palsu.
const double kDefaultTicketCommissionRate = 5.0;
const double kDefaultFixedServiceFee = 5000.0;
const int kDefaultOrderPaymentTimeoutMinutes = 120;

/// `platform_settings.value` bertipe JSONB; sebagian data dapat tersimpan
/// sebagai `{ "value": ... }`. Kembalikan nilai sebenarnya.
Object? _unwrapSettingValue(Object? value) {
  if (value is Map && value.containsKey('value')) return value['value'];
  return value;
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = _unwrapSettingValue(json[key]);
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

double _readDouble(
  Map<String, dynamic> json,
  List<String> keys,
  double fallback,
) {
  for (final key in keys) {
    final value = _unwrapSettingValue(json[key]);
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

int _readInt(Map<String, dynamic> json, List<String> keys, int fallback) {
  for (final key in keys) {
    final value = _unwrapSettingValue(json[key]);
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

/// Mengubah map `settings` dari `GET /api/admin/settings` menjadi model.
///
/// Backend mengirim nilai flat per key (`ticket_commission_rate`,
/// `support_email`, ...), bukan objek bertingkat, sehingga parsing dipisah dari
/// HTTP agar dapat diuji langsung.
PlatformSettingsModel parsePlatformSettings(Map<String, dynamic> settings) {
  return PlatformSettingsModel(
    platformName: _readString(
      settings,
      const ['platform_name', 'platformName'],
      'E-Ticket Event Platform',
    ),
    contactEmail: _readString(
      settings,
      const ['support_email', 'contact_email', 'contactEmail'],
      '',
    ),
    contactPhone: _readString(
      settings,
      const ['contact_phone', 'contactPhone'],
      '',
    ),
    ticketCommissionRate: _readDouble(
      settings,
      const ['ticket_commission_rate', 'ticketCommissionRate'],
      kDefaultTicketCommissionRate,
    ),
    fixedServiceFee: _readDouble(
      settings,
      const ['fixed_service_fee', 'fixedServiceFee'],
      kDefaultFixedServiceFee,
    ),
    orderPaymentTimeoutMinutes: _readInt(
      settings,
      const ['order_payment_timeout_minutes', 'orderPaymentTimeoutMinutes'],
      kDefaultOrderPaymentTimeoutMinutes,
    ),
    termsOfServiceUrl: _readString(
      settings,
      const ['terms_of_service_url', 'termsOfServiceUrl'],
      '',
    ),
    privacyPolicyUrl: _readString(
      settings,
      const ['privacy_policy_url', 'privacyPolicyUrl'],
      '',
    ),
    refundPolicySummary: _readString(
      settings,
      const ['refund_policy_summary', 'refundPolicySummary'],
      '',
    ),
    lastUpdatedAt: DateTime.tryParse(
          _readString(
            settings,
            const ['updated_at', 'last_updated_at', 'lastUpdatedAt'],
            '',
          ),
        ) ??
        DateTime.now(),
    lastUpdatedBy: _readString(
      settings,
      const ['updated_by', 'last_updated_by', 'lastUpdatedBy'],
      'Admin Platform',
    ),
  );
}

/// Mengubah riwayat `platform_setting_history` menjadi entri tarif komisi.
///
/// Hanya baris perubahan `ticket_commission_rate` yang ditampilkan pada bagian
/// "Riwayat Penyesuaian Tarif Komisi"; baris lain (mis. nama platform) bukan
/// perubahan tarif.
List<FeeChangeHistoryEntry> parsePlatformFeeHistory(List<dynamic> rows) {
  final entries = <FeeChangeHistoryEntry>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final key = row['setting_key']?.toString() ?? '';
    if (key.isNotEmpty && key != 'ticket_commission_rate') continue;
    final oldValue = _unwrapSettingValue(row['old_value']);
    final newValue = _unwrapSettingValue(row['new_value']);
    double asDouble(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    entries.add(
      FeeChangeHistoryEntry(
        id: row['id']?.toString() ?? '',
        timestamp: DateTime.tryParse(row['changed_at']?.toString() ?? '') ??
            DateTime.now(),
        actorId: row['changed_by_id']?.toString() ?? '',
        actorName: row['changed_by_name']?.toString() ?? 'Admin Platform',
        oldCommissionRate: asDouble(oldValue),
        newCommissionRate: asDouble(newValue),
        oldFixedFee: 0,
        newFixedFee: 0,
        reason: row['reason']?.toString() ?? '',
      ),
    );
  }
  return entries;
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

  /// Riwayat tarif sudah diambil dari database pada proses ini.
  bool _historyLoadedFromApi = false;

  /// Retrieves current platform settings.
  ///
  /// Mode API membaca `settings` dan `history` dari `GET /api/admin/settings`.
  /// Nilai default C-01 hanya dipakai bila key belum ada di database.
  Future<PlatformSettingsModel> getSettings() async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final response = await ApiClient().get('/admin/settings');
      final settings = response['settings'];
      if (settings is! Map<String, dynamic>) {
        throw const FormatException(
          'Respons /admin/settings tidak memuat objek settings.',
        );
      }
      _settings = parsePlatformSettings(settings);

      final history = response['history'];
      _feeHistory
        ..clear()
        ..addAll(history is List ? parsePlatformFeeHistory(history) : const []);
      _historyLoadedFromApi = true;
      return _settings;
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _settings;
  }

  /// Retrieves history of platform fee adjustments (FR-103).
  ///
  /// Pada mode API riwayat berasal dari tabel `platform_setting_history`.
  Future<List<FeeChangeHistoryEntry>> getFeeHistory() async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      if (!_historyLoadedFromApi) {
        await getSettings();
      }
      return List.unmodifiable(_feeHistory);
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_feeHistory);
  }

  /// Updates platform settings and records audit log / fee history if rates change (FR-102, FR-103).
  ///
  /// Mode API menulis setiap key yang berubah ke `PUT /api/admin/settings/:key`
  /// lalu membaca ulang dari database. Kegagalan API diteruskan ke pemanggil
  /// (tidak lagi ditelan) agar UI tidak melaporkan "berhasil" palsu.
  Future<bool> updateSettings(
    PlatformSettingsModel newSettings, {
    required String actorId,
    required String actorName,
    String? reason,
  }) async {
    if (!AppConfig.mockMode && !_isTestEnvironment) {
      final updates = <String, Object?>{
        if (_settings.platformName != newSettings.platformName)
          'platform_name': newSettings.platformName,
        if (_settings.contactEmail != newSettings.contactEmail)
          'support_email': newSettings.contactEmail,
        if (_settings.contactPhone != newSettings.contactPhone)
          'contact_phone': newSettings.contactPhone,
        if (_settings.orderPaymentTimeoutMinutes !=
            newSettings.orderPaymentTimeoutMinutes)
          'order_payment_timeout_minutes':
              newSettings.orderPaymentTimeoutMinutes,
        if (_settings.refundPolicySummary != newSettings.refundPolicySummary)
          'refund_policy_summary': newSettings.refundPolicySummary,
        if (_settings.ticketCommissionRate != newSettings.ticketCommissionRate)
          'ticket_commission_rate': newSettings.ticketCommissionRate,
        if (_settings.fixedServiceFee != newSettings.fixedServiceFee)
          'fixed_service_fee': newSettings.fixedServiceFee,
      };

      for (final entry in updates.entries) {
        await ApiClient().put(
          '/admin/settings/${entry.key}',
          body: {'value': entry.value, 'reason': reason},
        );
      }

      // Audit log & riwayat ditulis backend; baca ulang agar UI menampilkan
      // data database yang sebenarnya.
      await getSettings();
      _settings = _settings.copyWith(
        lastUpdatedAt: DateTime.now(),
        lastUpdatedBy: actorName,
      );
      return true;
    }

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

    _settings = newSettings.copyWith(
      lastUpdatedAt: DateTime.now(),
      lastUpdatedBy: actorName,
    );

    return true;
  }
}

