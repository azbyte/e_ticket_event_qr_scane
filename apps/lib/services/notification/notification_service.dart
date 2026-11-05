/// Notification service (PRD section: Notifications).
///
/// Backend notification contract is not final yet (PRD section 13/15).
import '../api/api_service.dart';

class NotificationService {
  NotificationService();

  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listNotifications(
      {Map<String, dynamic>? query}) async {
    final result = await _api.get('/notifications', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> markAsRead(String notificationId) async {
    await _api.post('/notifications/$notificationId/read');
  }
}
