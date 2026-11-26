import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import '../services/session_service.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  final http.Client _http = http.Client();
  final SessionService _session = SessionService.instance;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _send('GET', path, query: query, headers: headers);

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _send('POST', path, body: body, query: query, headers: headers);

  Future<Map<String, dynamic>> put(String path, {dynamic body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    final base = Uri.parse(
      AppConfig.apiBaseUrl.endsWith('/')
          ? AppConfig.apiBaseUrl
          : '${AppConfig.apiBaseUrl}/',
    );
    final uri = base
        .resolve(path.startsWith('/') ? path.substring(1) : path)
        .replace(
          queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
        );
    return _sendUri(method, uri, body: body, headers: headers);
  }

  Future<Map<String, dynamic>> _sendUri(
    String method,
    Uri uri, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };
    if (body != null) requestHeaders['Content-Type'] = 'application/json';
    final token = await _session.readToken();
    if (token != null) requestHeaders['Authorization'] = 'Bearer $token';

    try {
      final request = http.Request(method, uri)..headers.addAll(requestHeaders);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http
          .send(request)
          .timeout(Duration(seconds: AppConfig.receiveTimeoutSeconds));
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
      final message = _errorMessage(data, response.statusCode);
      if (response.statusCode == 401) {
        await _session.clear();
        _session.notifySessionInvalidated();
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthException(message, statusCode: response.statusCode);
      }
      throw NetworkException(message, statusCode: response.statusCode);
    } on AppException {
      rethrow;
    } catch (error) {
      // Sertakan alamat tujuan agar penyebab (backend belum jalan / alamat
      // salah) langsung terlihat tanpa menebak konfigurasi.
      throw NetworkException(
        'Tidak dapat terhubung ke server (${uri.origin}). '
        'Pastikan backend berjalan dan alamat API benar.',
        originalError: error,
      );
    }
  }

  /// Menyusun pesan error dari body response.
  ///
  /// Backend mengirim `{ message, errors: [{ field, message }] }` untuk
  /// kegagalan validasi. Tanpa detail per-field, pengguna hanya melihat
  /// "Validation failed" dan tidak tahu input mana yang harus diperbaiki
  /// (mis. saat pendaftaran Organizer gagal).
  String _errorMessage(Map<String, dynamic> data, int statusCode) =>
      buildApiErrorMessage(data, statusCode);
}

/// Menyusun pesan error yang layak ditampilkan dari body response backend.
///
/// Dipisahkan dari [ApiClient] agar dapat diuji tanpa HTTP.
String buildApiErrorMessage(Map<String, dynamic> data, int statusCode) {
  final base = data['message']?.toString();
  final errors = data['errors'];
  if (errors is List) {
    for (final entry in errors) {
      if (entry is Map && entry['message'] != null) {
        final detail = entry['message'].toString().trim();
        if (detail.isEmpty) continue;
        final field = entry['field']?.toString();
        final labelled = field == null || field.isEmpty
            ? detail
            : '$field: $detail';
        if (base == null || base.isEmpty) return labelled;
        if (labelled == base) return base;
        return '$base ($labelled)';
      }
    }
  }
  if (base != null && base.isNotEmpty) return base;
  return 'Request failed ($statusCode)';
}

/// Memeriksa kesehatan backend melalui `GET /health`.
///
/// Endpoint ini berada di root server (bukan di bawah `/api`) dan melaporkan
/// status koneksi database (`database: connected|disconnected`). Dipakai layar
/// login agar pengguna dapat memastikan aplikasi benar-benar terhubung ke
/// backend dan database, bukan menebak dari pesan error login.
///
/// Dibuat sebagai fungsi top-level (bukan method [ApiClient]) supaya kelas
/// pengganti pada test yang `implements ApiClient` tidak perlu diubah.
Future<Map<String, dynamic>> fetchServerHealth({http.Client? client}) async {
  final httpClient = client ?? http.Client();
  final uri = Uri.parse(AppConfig.healthUrl);
  try {
    final response = await httpClient
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(Duration(seconds: AppConfig.receiveTimeoutSeconds));
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw NetworkException(
      buildApiErrorMessage(data, response.statusCode),
      statusCode: response.statusCode,
    );
  } on AppException {
    rethrow;
  } catch (error) {
    throw NetworkException(
      'Tidak dapat terhubung ke server (${uri.origin}). '
      'Pastikan backend berjalan dan alamat API benar.',
      originalError: error,
    );
  } finally {
    if (client == null) httpClient.close();
  }
}
