import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../services/session_service.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  final http.Client _http = http.Client();
  final SessionService _session = SessionService.instance;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {dynamic body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<Map<String, dynamic>> put(String path, {dynamic body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(String method, String path,
      {dynamic body, Map<String, dynamic>? query}) async {
    final base = Uri.parse(AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/');
    final uri = base.resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(queryParameters: query?.map((key, value) => MapEntry(key, '$value')));
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final token = await _session.readToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(
        Duration(seconds: AppConfig.receiveTimeoutSeconds),
      );
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data.containsKey('success') ? data : {'data': decoded};
      }
      final message = data['message']?.toString() ??
          data['errors']?.toString() ?? 'Request failed (${response.statusCode})';
      if (response.statusCode == 401) await _session.clear();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthException(message, statusCode: response.statusCode);
      }
      throw NetworkException(message, statusCode: response.statusCode);
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException('Tidak dapat terhubung ke server. Periksa koneksi dan alamat API.', originalError: error);
    }
  }
}