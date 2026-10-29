/// Authentication state provider (PRD section 4.1).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/user/user_model.dart';
import '../services/auth/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService);

  final AuthService _authService;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _authService.login(email: email, password: password);
      _user = UserModel.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      _user = UserModel.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void clearError() {
    _error = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
