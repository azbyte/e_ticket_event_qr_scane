/// Order state provider (PRD sections 4.4, 4.7).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/order/order_model.dart';
import '../services/order/order_service.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider(this._orderService);

  final OrderService _orderService;

  List<OrderModel> _orders = [];
  OrderModel? _selectedOrder;
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  OrderModel? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> loadOrders({Map<String, dynamic>? query}) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _orderService.listOrders(query: query);
      _orders = list.map((e) => OrderModel.fromJson(e)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadOrder(String orderId) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _orderService.getOrder(orderId);
      _selectedOrder = OrderModel.fromJson(data);
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
