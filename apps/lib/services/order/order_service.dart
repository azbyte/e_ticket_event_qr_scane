/// Order service (PRD sections 4.4, 4.7).
import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class OrderService {
  OrderService();

  final ApiService _api = ApiService();
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final eventId = payload['event_id'] as String? ?? '';
      final attendeeName = payload['attendee_name'] as String? ?? 'Peserta';
      final attendeeEmail = payload['attendee_email'] as String? ?? 'peserta@example.com';
      final attendeePhone = payload['attendee_phone'] as String?;
      final itemsMap = (payload['items'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value as int));

      final order = _mockRepo.createOrder(
        eventId: eventId,
        attendeeName: attendeeName,
        attendeeEmail: attendeeEmail,
        attendeePhone: attendeePhone,
        selectedTicketQuantities: itemsMap,
      );
      return order.toJson();
    }

    try {
      final result = await _api.post('/orders', body: payload);
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      final eventId = payload['event_id'] as String? ?? '';
      final attendeeName = payload['attendee_name'] as String? ?? 'Peserta';
      final attendeeEmail = payload['attendee_email'] as String? ?? 'peserta@example.com';
      final attendeePhone = payload['attendee_phone'] as String?;
      final itemsMap = (payload['items'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value as int));

      final order = _mockRepo.createOrder(
        eventId: eventId,
        attendeeName: attendeeName,
        attendeeEmail: attendeeEmail,
        attendeePhone: attendeePhone,
        selectedTicketQuantities: itemsMap,
      );
      return order.toJson();
    }
  }

  Future<List<Map<String, dynamic>>> listOrders(
      {Map<String, dynamic>? query}) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = query?['q'] as String?;
      final orders = _mockRepo.getOrders(query: q);
      return orders.map((o) => o.toJson()).toList();
    }

    try {
      final result = await _api.get('/orders', query: query);
      final data = result['data'] as List? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      final q = query?['q'] as String?;
      final orders = _mockRepo.getOrders(query: q);
      return orders.map((o) => o.toJson()).toList();
    }
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getOrderById(orderId).toJson();
    }

    try {
      final result = await _api.get('/orders/$orderId');
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      return _mockRepo.getOrderById(orderId).toJson();
    }
  }
}
