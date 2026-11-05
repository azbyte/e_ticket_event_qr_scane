/// Order service (PRD sections 4.4, 4.7).
import '../api/api_service.dart';

class OrderService {
  OrderService();

  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async {
    return _api.post('/orders', body: payload);
  }

  Future<List<Map<String, dynamic>>> listOrders(
      {Map<String, dynamic>? query}) async {
    final result = await _api.get('/orders', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    return _api.get('/orders/$orderId');
  }
}
