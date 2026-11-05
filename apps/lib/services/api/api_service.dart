import '../../core/network/api_client.dart';

/// Compatibility facade for existing feature services.
/// New feature code can use [ApiClient] directly.
class ApiService {
  ApiService();
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _client.get(path, query: query).then((response) => Map<String, dynamic>.from(response['data'] as Map? ?? response));
  Future<Map<String, dynamic>> post(String path, {dynamic body, Map<String, dynamic>? query}) =>
      _client.post(path, body: body, query: query).then((response) => Map<String, dynamic>.from(response['data'] as Map? ?? response));
  Future<Map<String, dynamic>> put(String path, {dynamic body}) =>
      _client.put(path, body: body).then((response) => Map<String, dynamic>.from(response['data'] as Map? ?? response));
  Future<Map<String, dynamic>> delete(String path) => _client.delete(path).then((response) => Map<String, dynamic>.from(response['data'] as Map? ?? response));
}