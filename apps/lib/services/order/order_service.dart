/// Order service (PRD sections 4.4, 4.7).
library;

import '../../core/config/app_config.dart';
import '../../core/services/order_access_token_store.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class OrderService {
  OrderService({ApiService? api, OrderAccessTokenStore? orderTokens})
    : _api = api ?? ApiService(),
      _orderTokens = orderTokens ?? const SecureOrderAccessTokenStore();

  final ApiService _api;
  final OrderAccessTokenStore _orderTokens;
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final eventId = payload['event_id'] as String? ?? '';
      final attendeeName = payload['attendee_name'] as String? ?? 'Peserta';
      final attendeeEmail =
          payload['attendee_email'] as String? ?? 'peserta@example.com';
      final attendeePhone = payload['attendee_phone'] as String?;
      final itemsMap = (payload['items'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, value as int),
      );

      final order = _mockRepo.createOrder(
        eventId: eventId,
        attendeeName: attendeeName,
        attendeeEmail: attendeeEmail,
        attendeePhone: attendeePhone,
        selectedTicketQuantities: itemsMap,
      );
      return order.toJson();
    }

    final result = await _api.post('/orders', body: payload);
    final order = result['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw const FormatException('Respons API tidak berisi data pesanan.');
    }
    final accessToken = result['order_access_token'] as String?;
    if (accessToken != null) {
      await _orderTokens.save(order['id'] as String, accessToken);
    }
    return order;
  }

  Future<List<Map<String, dynamic>>> listOrders({
    Map<String, dynamic>? query,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = query?['q'] as String?;
      final orders = _mockRepo.getOrders(query: q);
      return orders.map((o) => o.toJson()).toList();
    }

    final result = await _api.get('/orders', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getOrderById(orderId).toJson();
    }

    final accessToken = await _orderTokens.read(orderId);
    final result = await _api.get(
      '/orders/$orderId',
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
    final order = result['order'] as Map<String, dynamic>?;
    if (order == null) {
      throw const FormatException('Respons API tidak berisi data pesanan.');
    }
    return order;
  }
}
