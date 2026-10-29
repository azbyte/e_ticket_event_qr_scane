/// HTTP client wrapper for communicating with the REST API backend.
///
/// TODO: The backend API contract is a draft (PRD section 15). Endpoints,
/// headers, and response shapes below are placeholders and must be aligned
/// with the agreed API before integration.
///
/// Requires package `http` (or `dio`) to be added to pubspec.yaml.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  factory ApiClient() => instance;

  // TODO: Initialize http.Client / Dio here with baseUrl, timeouts,
  // auth interceptor (Bearer token), and error handling once package added.

  /// Performs a GET request. TODO: implement using http package.
  /// Throws [AppException] on failure.
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    throw UnimplementedError(
        'ApiClient.get is not implemented yet. Add http package and define endpoint contract.');
  }

  /// Performs a POST request. TODO: implement using http package.
  Future<Map<String, dynamic>> post(String path,
      {dynamic body, Map<String, dynamic>? query}) async {
    throw UnimplementedError(
        'ApiClient.post is not implemented yet. Add http package and define endpoint contract.');
  }

  /// Performs a PUT request. TODO: implement using http package.
  Future<Map<String, dynamic>> put(String path, {dynamic body}) async {
    throw UnimplementedError(
        'ApiClient.put is not implemented yet. Add http package and define endpoint contract.');
  }

  /// Performs a DELETE request. TODO: implement using http package.
  Future<Map<String, dynamic>> delete(String path) async {
    throw UnimplementedError(
        'ApiClient.delete is not implemented yet. Add http package and define endpoint contract.');
  }
}
