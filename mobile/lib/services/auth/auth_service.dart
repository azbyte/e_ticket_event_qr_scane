/// Authentication service (PRD sections 4.1).
///
/// Endpoints are placeholders pending final API contract (PRD section 15).
import '../api/api_service.dart';

class AuthService {
  AuthService();

  final ApiService _api = ApiService();

  /// Registers an organizer account. TODO: replace with real endpoint.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'role': 'organizer',
    });
  }

  /// Logs in a user. TODO: replace with real endpoint.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
  }

  /// Logs out the current user. TODO: replace with real endpoint.
  Future<void> logout() async {
    await _api.post('/auth/logout');
  }

  /// Returns the current authenticated user (placeholder).
  Future<Map<String, dynamic>> me() async {
    return _api.get('/auth/me');
  }
}
