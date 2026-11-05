import '../api/api_service.dart';

class EventService {
  EventService();
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listEvents({Map<String, dynamic>? query}) async {
    final response = await _api.get('/events/public', query: query);
    return (response['events'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    final response = await _api.get('/events/$id');
    return Map<String, dynamic>.from(response['event'] as Map);
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> payload) async {
    final response = await _api.post('/events', body: payload);
    return Map<String, dynamic>.from(response['event'] as Map);
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/events/$id', body: payload);
    return Map<String, dynamic>.from(response['event'] as Map);
  }

  Future<List<Map<String, dynamic>>> myEvents() async {
    final response = await _api.get('/events/mine');
    return (response['events'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create({required String title, required String description, required DateTime date, required String location}) =>
      createEvent({'title': title.trim(), 'description': description.trim(), 'date': date.toIso8601String(), 'location': location.trim()});

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> updates) => updateEvent(id, updates);
  Future<void> delete(String id) async { await _api.delete('/events/$id'); }

  Future<List<Map<String, dynamic>>> members(String id) async {
    final response = await _api.get('/events/$id/members');
    return (response['members'] as List? ?? const []).cast<Map<String, dynamic>>();
  }
  Future<void> addMember(String id, String identity) async { await _api.post('/events/$id/members', body: {'email': identity.trim()}); }
  Future<void> removeMember(String id, String userId) async { await _api.delete('/events/$id/members/$userId'); }
  Future<List<Map<String, dynamic>>> platformEvents() async {
    final response = await _api.get('/events');
    return (response['events'] as List? ?? const []).cast<Map<String, dynamic>>();
  }
  Future<Map<String, dynamic>> submitForReview(String id) => _api.post('/events/$id/submit-review');
}