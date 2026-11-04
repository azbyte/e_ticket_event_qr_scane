/// Check-in service (PRD sections 4.5, 4.6).
///
/// Offline queue and sync logic per PRD section 4.7 (offline mode) is a
/// placeholder pending final offline strategy (PRD section 13).
import '../api/api_service.dart';

class CheckInService {
  CheckInService();

  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listCheckIns({
    required String eventId,
    Map<String, dynamic>? query,
  }) async {
    final result = await _api.get('/events/$eventId/check-ins', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Submits pending offline check-ins when network returns. TODO: implement.
  Future<void> syncPendingCheckIns() async {
    throw UnimplementedError('Offline check-in sync is not implemented yet.');
  }
}
