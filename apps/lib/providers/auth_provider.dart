/// Authentication state provider (PRD section 4.1).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
library;

import 'package:flutter/foundation.dart';
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

  Future<void> restoreSession() async {
    _setLoading(true);
    try {
      _user = UserModel.fromJson(await _authService.me());
    } catch (_) {
      await _authService.logout();
      _user = null;
    } finally {
      _setLoading(false);
    }
  }

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

  Future<bool> updateProfile({required String name}) async {
    _setLoading(true);
    _error = null;
    try {
      final response = await _authService.updateProfile(name: name);
      _user = UserModel.fromJson(response);
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
    try {
      await _authService.logout();
    } finally {
      _user = null;
      notifyListeners();
    }
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
