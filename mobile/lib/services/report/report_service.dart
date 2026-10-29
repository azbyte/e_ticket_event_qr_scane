/// Support report service (PRD section 4.10).
import '../api/api_service.dart';

class ReportService {
  ReportService();

  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> payload) async {
    return _api.post('/support-reports', body: payload);
  }

  Future<List<Map<String, dynamic>>> listReports(
      {Map<String, dynamic>? query}) async {
    final result = await _api.get('/support-reports', query: query);
    final data = result['data'] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getReport(String reportId) async {
    return _api.get('/support-reports/$reportId');
  }

  /// Admin updates report status. TODO: real endpoint.
  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
    String? note,
  }) async {
    return _api.post('/support-reports/$reportId/status', body: {
      'status': status,
      'note': note,
    });
  }
}
