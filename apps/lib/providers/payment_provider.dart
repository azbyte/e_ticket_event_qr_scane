/// Payment state provider for simulated Virtual Account (PRD section 4.7).
library;

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/payment/email_delivery_model.dart';
import '../models/payment/payment_model.dart';
import '../services/payment/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider([PaymentService? paymentService])
      : _paymentService = paymentService ?? PaymentService();

  static final PaymentProvider instance = PaymentProvider();

  final PaymentService _paymentService;

  PaymentModel? _payment;
  EmailDeliverySummary _emailDelivery = const EmailDeliverySummary();
  bool _isLoading = false;
  String? _error;

  PaymentModel? get payment => _payment;

  /// Status pengiriman email e-ticket terakhir (nyata, bukan simulasi).
  EmailDeliverySummary get emailDelivery => _emailDelivery;
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
      final result = await _paymentService.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: virtualAccountNumber,
        simulateSuccess: simulateSuccess,
      );
      _payment = PaymentModel.fromJson(result.payment);
      _emailDelivery = result.emailDelivery;
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
    _emailDelivery = const EmailDeliverySummary();
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
