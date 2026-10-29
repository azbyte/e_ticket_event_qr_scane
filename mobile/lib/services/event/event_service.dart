/// Event service (PRD sections 4.2, 4.4, 7.4).
import '../api/api_service.dart';

class EventService {
  EventService();

  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listEvents(
      {Map<String, dynamic>? query}) async {
    final result = await _api.get('/events', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEvent(String eventId) async {
    return _api.get('/events/$eventId');
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
