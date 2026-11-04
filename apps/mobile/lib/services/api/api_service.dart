/// Base API service with shared request helpers.
///
/// All endpoints are placeholders pending the final backend API contract
/// (PRD section 15). Replace paths and payload shapes once agreed.
import 'dart:convert';

import '../core/errors/app_exception.dart';
import '../core/network/api_client.dart';

class ApiService {
  ApiService();

  final ApiClient _client = ApiClient();

  /// GET helper. TODO: align path and query with backend contract.
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    try {
      return await _client.get(path, query: query);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat data: $e', originalError: e);
    }
  }

  /// POST helper. TODO: align path and body with backend contract.
  Future<Map<String, dynamic>> post(String path,
      {dynamic body, Map<String, dynamic>? query}) async {
    try {
      return await _client.post(path, body: body, query: query);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal mengirim data: $e', originalError: e);
    }
  }

  /// PUT helper. TODO: align path and body with backend contract.
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async {
    try {
      return await _client.put(path, body: body);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memperbarui data: $e', originalError: e);
    }
  }

  /// DELETE helper. TODO: align path with backend contract.
  Future<Map<String, dynamic>> delete(String path) async {
    try {
      return await _client.delete(path);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal menghapus data: $e', originalError: e);
    }
  }
}
