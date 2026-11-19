import '../../core/config/app_config.dart';
import '../../models/event/ticket_type_model.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

/// Service for ticket types / categories (PRD sections 4.2, 4.4, 6.3).
class TicketTypeService {
  TicketTypeService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  /// Retrieves all ticket categories/types available for a specific event.
  Future<List<TicketTypeModel>> getTicketTypesByEventId(String eventId) async {
    if (AppConfig.mockMode) {
      // Simulate light async delay
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getTicketTypesByEventId(eventId);
    }

    final result = await _api.get('/events/$eventId/ticket-types');
    final data = result['ticket_types'] as List? ?? [];
    return data
        .map((e) => TicketTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retrieves a specific ticket category by its ID.
  Future<TicketTypeModel> getTicketType(String ticketTypeId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return _mockRepo.getTicketTypeById(ticketTypeId);
    }

    final result = await _api.get('/ticket-types/$ticketTypeId');
    return TicketTypeModel.fromJson(
      result['ticket_type'] as Map<String, dynamic>,
    );
  }
}
