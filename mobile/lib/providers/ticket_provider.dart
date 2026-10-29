/// Ticket state provider (PRD sections 4.6, 6.3).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/ticket/ticket_model.dart';
import '../services/ticket/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  TicketProvider(this._ticketService);

  final TicketService _ticketService;

  List<TicketModel> _tickets = [];
  TicketModel? _selectedTicket;
  bool _isLoading = false;
  String? _error;

  List<TicketModel> get tickets => _tickets;
  TicketModel? get selectedTicket => _selectedTicket;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> loadTickets({Map<String, dynamic>? query}) async {
    _setLoading(true);
    _error = null;
    try {
      final list = await _ticketService.listTickets(query: query);
      _tickets = list.map((e) => TicketModel.fromJson(e)).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loadTicket(String ticketId) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _ticketService.getTicket(ticketId);
      _selectedTicket = TicketModel.fromJson(data);
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
