/// Payment state provider for simulated Virtual Account (PRD section 4.7).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/payment/payment_model.dart';
import '../services/payment/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentProvider(this._paymentService);

  final PaymentService _paymentService;

  PaymentModel? _payment;
  bool _isLoading = false;
  String? _error;

  PaymentModel? get payment => _payment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPaid => _payment?.status == 'paid';
  bool get isPending => _payment?.status == 'pending';

  Future<bool> simulatePayment({
    required String orderId,
    required String virtualAccountNumber,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _paymentService.simulatePayment(
        orderId: orderId,
        virtualAccountNumber: virtualAccountNumber,
      );
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
