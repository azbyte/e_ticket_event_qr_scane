/// Ticket service (PRD sections 4.6, 6.3).
import '../api/api_service.dart';

class TicketService {
  TicketService();

  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listTickets(
      {Map<String, dynamic>? query}) async {
    final result = await _api.get('/tickets', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTicket(String ticketId) async {
    return _api.get('/tickets/$ticketId');
  }
}
