/// Notification state provider (PRD section: Notifications).
///
/// State management for app notifications, alert badges, and read status.
library;

import 'package:flutter/foundation.dart';

import '../services/notification/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  final NotificationService _notificationService;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => n['is_read'] != true).length;

  /// Loads notifications list.
  Future<bool> loadNotifications({Map<String, dynamic>? query}) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _notificationService.listNotifications(query: query);
      _notifications = list;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (idx != -1) {
      _notifications[idx]['is_read'] = true;
      notifyListeners();
    }
  }

  /// Marks all notifications as read.
  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
    for (final n in _notifications) {
      n['is_read'] = true;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
