/// Payment service for simulated Virtual Account (PRD section 4.7).
///
/// NOTE: Real payment gateway integration is postponed (PRD section 3.2).
import '../api/api_service.dart';

class PaymentService {
  PaymentService();

  final ApiService _api = ApiService();

  /// Simulates payment for MVP. TODO: replace with real gateway + webhook verification.
  Future<Map<String, dynamic>> simulatePayment({
    required String orderId,
    required String virtualAccountNumber,
  }) async {
    return _api.post('/payments/simulate', body: {
      'order_id': orderId,
      'virtual_account_number': virtualAccountNumber,
    });
  }

  Future<Map<String, dynamic>> getPayment(String orderId) async {
    return _api.get('/payments/$orderId');
  }
}
