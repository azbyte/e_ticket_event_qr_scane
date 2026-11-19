import '../../core/network/api_client.dart';

/// Compatibility facade for existing feature services.
/// New feature code can use [ApiClient] directly.
class ApiService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _client.get(path, query: query, headers: headers);
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _client.post(path, body: body, query: query, headers: headers);
  Future<Map<String, dynamic>> put(String path, {dynamic body}) =>
      _client.put(path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _client.delete(path);
}
