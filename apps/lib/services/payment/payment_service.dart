/// Payment service for simulated Virtual Account (PRD section 4.7).
///
/// NOTE: Real payment gateway integration is postponed (PRD section 3.2).
import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class PaymentService {
  PaymentService();

  final ApiService _api = ApiService();
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  /// Simulates payment for MVP.
  Future<Map<String, dynamic>> simulatePayment({
    required String orderId,
    required String virtualAccountNumber,
    bool simulateSuccess = true,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final payment = _mockRepo.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: virtualAccountNumber,
        simulateSuccess: simulateSuccess,
      );
      return payment.toJson();
    }

    try {
      final result = await _api.post('/payments/simulate', body: {
        'order_id': orderId,
        'virtual_account_number': virtualAccountNumber,
        'simulate_success': simulateSuccess,
      });
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      final payment = _mockRepo.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: virtualAccountNumber,
        simulateSuccess: simulateSuccess,
      );
      return payment.toJson();
    }
  }

  Future<Map<String, dynamic>> getPayment(String orderId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getPaymentByOrderId(orderId).toJson();
    }

    try {
      final result = await _api.get('/payments/$orderId');
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      return _mockRepo.getPaymentByOrderId(orderId).toJson();
    }
  }
}
