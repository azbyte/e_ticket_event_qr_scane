/// Organizer notification service (FR-95).
///
/// Manages organizer-specific announcements, moderation alerts, staff activity,
/// and unread status.
library;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';

class OrganizerNotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'moderation', 'ticket_sale', 'staff', 'system'
  final DateTime createdAt;
  bool isRead;

  OrganizerNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory OrganizerNotificationItem.fromJson(Map<String, dynamic> json) {
    return OrganizerNotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['body']?.toString() ?? json['message']?.toString() ?? '',
      type: (json['category'] ?? json['type'] ?? 'system').toString().toLowerCase(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isRead: json['read_at'] != null || json['isRead'] == true,
    );
  }
}

class OrganizerNotificationService {
  OrganizerNotificationService._internal();
  static final OrganizerNotificationService instance =
      OrganizerNotificationService._internal();
  factory OrganizerNotificationService() => instance;

  static final List<OrganizerNotificationItem> _mockItems = [
    OrganizerNotificationItem(
      id: 'ntf-01',
      title: 'Event Berhasil Ditayangkan',
      message:
          'Event "Tech Innovation Summit 2026" telah disetujui oleh admin platform.',
      type: 'moderation',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    OrganizerNotificationItem(
      id: 'ntf-02',
      title: 'Staf Menerima Undangan',
      message:
          'Budi Santoso telah mengonfirmasi undangan sebagai Staf Verifikator QR Code.',
      type: 'staff',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: false,
    ),
    OrganizerNotificationItem(
      id: 'ntf-03',
      title: 'Kapasitas Tiket VIP Menipis',
      message: 'Kuota tiket VIP Pass tersisa 5 tiket dari total 50 tiket.',
      type: 'ticket_sale',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    OrganizerNotificationItem(
      id: 'ntf-04',
      title: 'Laporan Bantuan Ditanggapi',
      message: 'Admin Support telah merespons tiket keluhan RPT-ORG-2026-001.',
      type: 'system',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  /// Lists organizer notifications.
  Future<List<OrganizerNotificationItem>> listNotifications() async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _mockItems;
    }
    try {
      final res = await ApiClient.instance.get('/notifications');
      final list = (res['data'] as List<dynamic>? ?? []);
      return list
          .map(
            (item) => OrganizerNotificationItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String id) async {
    if (AppConfig.mockMode) {
      final item = _mockItems.firstWhere(
        (n) => n.id == id,
        orElse: () => _mockItems.first,
      );
      item.isRead = true;
      return;
    }
    try {
      await ApiClient.instance.post('/notifications/$id/read');
    } catch (_) {
      final item = _mockItems.firstWhere(
        (n) => n.id == id,
        orElse: () => _mockItems.first,
      );
      item.isRead = true;
    }
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    if (AppConfig.mockMode) {
      for (final item in _mockItems) {
        item.isRead = true;
      }
      return;
    }
    try {
      await ApiClient.instance.post('/notifications/read-all');
    } catch (_) {
      for (final item in _mockItems) {
        item.isRead = true;
      }
    }
  }

  Future<int> fetchUnreadCount() async {
    if (AppConfig.mockMode) {
      return unreadCount;
    }
    try {
      final res = await ApiClient.instance.get(
        '/notifications',
        query: {'unread': 'true'},
      );
      return res['count'] as int? ??
          (res['data'] as List<dynamic>?)?.length ??
          0;
    } catch (_) {
      return unreadCount;
    }
  }

  int get unreadCount => _mockItems.where((n) => !n.isRead).length;
}
