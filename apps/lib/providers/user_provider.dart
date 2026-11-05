/// User profile state provider (PRD sections 2, 4.1).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
import 'package:flutter/foundation.dart';
// ignore: unused_import
import 'package:provider/provider.dart';

import '../models/user/user_model.dart';
import '../services/auth/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider(this._authService);

  final AuthService _authService;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> loadMe() async {
    _setLoading(true);
    _error = null;
    try {
      final data = await _authService.me();
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

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
