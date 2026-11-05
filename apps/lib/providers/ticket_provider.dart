/// Ticket state provider (PRD sections 4.6, 6.3).
import 'package:flutter/foundation.dart';

import '../models/ticket/ticket_model.dart';
import '../services/ticket/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  TicketProvider([TicketService? ticketService])
      : _ticketService = ticketService ?? TicketService();

  static final TicketProvider instance = TicketProvider();

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

  void clearSelectedTicket() {
    _selectedTicket = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
