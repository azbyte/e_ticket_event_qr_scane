/// Public event read service (PRD sections 4.1, 4.2).
///
/// Tanggung jawab: membaca event publik untuk alur guest/peserta
/// (`/events/public`, `/events/:id`).
///
/// Operasi tulis dan manajemen event milik Organizer **tidak** berada di sini:
/// gunakan `ApiOrganizerEventRepository` / `MockOrganizerEventRepository`
/// melalui `EventProvider` agar hanya ada satu implementasi.
library;

import '../../core/config/app_config.dart';
import '../../services/mock/mock_attendee_repository.dart';
import '../api/api_service.dart';

class EventService {
  EventService();
  final ApiService _api = ApiService();
  final MockAttendeeRepository _mockRepo = MockAttendeeRepository.instance;

  Future<List<Map<String, dynamic>>> listEvents({Map<String, dynamic>? query}) async {
    if (AppConfig.mockMode) {
      final events = _mockRepo.getEvents(
        query: query?['q']?.toString() ?? query?['search']?.toString(),
        category: query?['category']?.toString(),
      );
      return events.map((event) => event.toJson()).toList(growable: false);
    }
    final response = await _api.get('/events/public', query: query);
    return (response['events'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    if (AppConfig.mockMode) return _mockRepo.getEventById(id).toJson();
    final response = await _api.get('/events/$id');
    return Map<String, dynamic>.from(response['event'] as Map);
  }
}
