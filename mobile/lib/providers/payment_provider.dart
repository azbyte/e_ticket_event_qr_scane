/// Payment state provider for simulated Virtual Account (PRD section 4.7).
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/payment/payment_model.dart';
import '../services/payment/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider([PaymentService? paymentService])
      : _paymentService = paymentService ?? PaymentService();

  static final PaymentProvider instance = PaymentProvider();

  final PaymentService _paymentService;

  PaymentModel? _payment;
  bool _isLoading = false;
  String? _error;

  PaymentModel? get payment => _payment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPaid => _payment?.status == AppConstants.paymentStatusPaid;
  bool get isPending => _payment?.status == AppConstants.paymentStatusPending;

  Future<bool> simulatePayment({
    required String orderId,
    required String virtualAccountNumber,
    bool simulateSuccess = true,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _paymentService.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: virtualAccountNumber,
        simulateSuccess: simulateSuccess,
      );
      _payment = PaymentModel.fromJson(data);
      notifyListeners();
      return _payment?.status == AppConstants.paymentStatusPaid;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadPayment(String orderId) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _paymentService.getPayment(orderId);
      _payment = PaymentModel.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearPayment() {
    _payment = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
