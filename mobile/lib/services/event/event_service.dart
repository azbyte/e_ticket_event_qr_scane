/// Event service (PRD sections 4.2, 4.4, 7.4).
import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../mock/mock_attendee_repository.dart';

class EventService {
  EventService();

  final ApiService _api = ApiService();
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<List<Map<String, dynamic>>> listEvents(
      {Map<String, dynamic>? query}) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final q = query?['q'] as String?;
      final category = query?['category'] as String?;
      final events = _mockRepo.getEvents(query: q, category: category);
      return events.map((e) => e.toJson()).toList();
    }

    try {
      final result = await _api.get('/events', query: query);
      final data = result['data'] as List? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      final q = query?['q'] as String?;
      final category = query?['category'] as String?;
      final events = _mockRepo.getEvents(query: q, category: category);
      return events.map((e) => e.toJson()).toList();
    }
  }

  Future<Map<String, dynamic>> getEvent(String eventId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _mockRepo.getEventById(eventId).toJson();
    }

    try {
      final result = await _api.get('/events/$eventId');
      return (result['data'] as Map<String, dynamic>?) ?? result;
    } catch (_) {
      return _mockRepo.getEventById(eventId).toJson();
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> payload) async {
    return _api.post('/events', body: payload);
  }

  Future<Map<String, dynamic>> updateEvent(
      String eventId, Map<String, dynamic> payload) async {
    return _api.put('/events/$eventId', body: payload);
  }

  Future<Map<String, dynamic>> submitForReview(String eventId) async {
    return _api.post('/events/$eventId/submit-review');
  }
}
