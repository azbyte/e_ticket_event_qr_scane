/// Ticket service (PRD sections 4.6, 6.3).
import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class TicketService {
  TicketService();

  final ApiService _api = ApiService();
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<List<Map<String, dynamic>>> listTickets(
      {Map<String, dynamic>? query}) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = query?['q'] as String?;
      final tickets = _mockRepo.getTickets(query: q);
      return tickets.map((t) => t.toJson()).toList();
    }

    try {
      final result = await _api.get('/tickets', query: query);
      final data = result['data'] as List? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      final q = query?['q'] as String?;
      final tickets = _mockRepo.getTickets(query: q);
      return tickets.map((t) => t.toJson()).toList();
    }
  }

  Future<Map<String, dynamic>> getTicket(String ticketId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getTicketById(ticketId).toJson();
    }

    try {
      final result = await _api.get('/tickets/$ticketId');
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      return _mockRepo.getTicketById(ticketId).toJson();
    }
  }
}
