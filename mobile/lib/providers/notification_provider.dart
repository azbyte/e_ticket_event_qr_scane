/// Notification state provider (PRD section: Notifications).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../services/notification/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._notificationService);

  final NotificationService _notificationService;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    _notifications.removeWhere((n) => n['id'] == notificationId);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
