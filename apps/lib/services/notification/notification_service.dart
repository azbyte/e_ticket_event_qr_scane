/// Notification service (PRD section: Notifications).
///
/// Provides system notifications for events, tickets, reports, and check-ins.
library;

import '../../core/config/app_config.dart';
import '../api/api_service.dart';

class NotificationService {
  NotificationService();

  final ApiService _api = ApiService();

  // Mock list of notifications
  static final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 'notif-001',
      'title': 'Event Disetujui',
      'message': 'Event "Tech Innovation Summit 2026" telah disetujui oleh admin platform dan siap ditayangkan.',
      'type': 'event_approved',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    },
    {
      'id': 'notif-002',
      'title': 'Laporan Ditindaklanjuti',
      'message': 'Laporan kendala RPT-2026-001 telah ditanggapi oleh tim admin support.',
      'type': 'report_update',
      'is_read': false,
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    },
    {
      'id': 'notif-003',
      'title': 'Check-in Offline Tersinkron',
      'message': '5 data check-in offline berhasil disinkronkan ke server utama tanpa konflik.',
      'type': 'check_in_sync',
      'is_read': true,
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
    {
      'id': 'notif-004',
      'title': 'Undangan Staf Baru',
      'message': 'Anda telah ditugaskan sebagai Staf Verifikator QR Code pada Tech Innovation Summit 2026.',
      'type': 'staff_invite',
      'is_read': true,
      'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
  ];

  /// Lists notifications for current user/role.
  Future<List<Map<String, dynamic>>> listNotifications({
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return List<Map<String, dynamic>>.from(_mockNotifications);
    }
    final result = await _api.get('/notifications', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String notificationId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final idx = _mockNotifications.indexWhere((n) => n['id'] == notificationId);
      if (idx != -1) {
        _mockNotifications[idx]['is_read'] = true;
      }
      return;
    }
    await _api.post('/notifications/$notificationId/read');
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final n in _mockNotifications) {
        n['is_read'] = true;
      }
      return;
    }
    await _api.post('/notifications/read-all');
  }
}
