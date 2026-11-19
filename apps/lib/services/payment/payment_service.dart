/// Payment service for simulated Virtual Account (PRD section 4.7).
///
/// NOTE: Real payment gateway integration is postponed (PRD section 3.2).
library;

import '../../core/config/app_config.dart';
import '../../core/services/order_access_token_store.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class PaymentService {
  PaymentService({ApiService? api, OrderAccessTokenStore? orderTokens})
    : _api = api ?? ApiService(),
      _orderTokens = orderTokens ?? const SecureOrderAccessTokenStore();

  final ApiService _api;
  final OrderAccessTokenStore _orderTokens;
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

    final accessToken = await _orderTokens.read(orderId);
    final result = await _api.post(
      '/payments/simulate',
      body: {'order_id': orderId, 'simulate_success': simulateSuccess},
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
    final payment = result['payment'] as Map<String, dynamic>?;
    if (payment == null) {
      throw const FormatException('Respons API tidak berisi data pembayaran.');
    }
    return payment;
  }

  Future<Map<String, dynamic>> getPayment(String orderId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getPaymentByOrderId(orderId).toJson();
    }

    final accessToken = await _orderTokens.read(orderId);
    final result = await _api.get(
      '/payments/$orderId',
      headers: accessToken == null
          ? null
          : {'X-Order-Access-Token': accessToken},
    );
    final payment = result['payment'] as Map<String, dynamic>?;
    if (payment == null) {
      throw const FormatException('Respons API tidak berisi data pembayaran.');
    }
    return payment;
  }
}
