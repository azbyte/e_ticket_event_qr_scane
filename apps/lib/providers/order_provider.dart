/// Order state provider (PRD sections 4.4, 4.7).
import 'package:flutter/foundation.dart';

import '../models/order/order_model.dart';
import '../services/order/order_service.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider([OrderService? orderService])
      : _orderService = orderService ?? OrderService();

  static final OrderProvider instance = OrderProvider();

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

  Future<OrderModel?> createOrder({
    required String eventId,
    required String attendeeName,
    required String attendeeEmail,
    String? attendeePhone,
    required Map<String, int> selectedTicketQuantities,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final payload = {
        'event_id': eventId,
        'attendee_name': attendeeName,
        'attendee_email': attendeeEmail,
        if (attendeePhone != null) 'attendee_phone': attendeePhone,
        'items': selectedTicketQuantities,
      };

      final data = await _orderService.createOrder(payload);
      final newOrder = OrderModel.fromJson(data);
      _orders.insert(0, newOrder);
      _selectedOrder = newOrder;
      notifyListeners();
      return newOrder;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
