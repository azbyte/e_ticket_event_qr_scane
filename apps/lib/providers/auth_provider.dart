/// Authentication state provider (PRD section 4.1).
///
/// Requires package `provider` added to pubspec.yaml (PRD section 8.1).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/services/session_service.dart';
import '../models/user/user_model.dart';
import '../services/auth/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _sessionInvalidation = SessionService.instance.onSessionInvalidated.listen(
      (_) => _onSessionInvalidated(),
    );
  }

  final AuthService _authService;

  StreamSubscription<void>? _sessionInvalidation;
  bool _disposed = false;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  /// Pesan yang ditampilkan ketika server menolak token tersimpan (HTTP 401)
  /// sehingga sesi berakhir di tengah pemakaian.
  static const String sessionExpiredMessage =
      'Sesi Anda telah berakhir. Silakan masuk kembali.';

  static const String _genericErrorMessage =
      'Terjadi kesalahan. Silakan coba lagi.';

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
      _error = _messageForError(e);
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
      _error = _messageForError(e);
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
      _error = _messageForError(e);
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
      // Logout adalah tindakan sadar pengguna, bukan kegagalan: jangan sisakan
      // pesan error (termasuk yang mungkin diisi oleh invalidasi sesi).
      _error = null;
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

  /// Menangani sesi yang dinyatakan tidak berlaku oleh server (HTTP 401).
  ///
  /// Tanpa penanganan ini, API client sudah menghapus token tetapi state
  /// Provider tetap terautentikasi sampai aplikasi dibuka ulang (GAP-2).
  void _onSessionInvalidated() {
    if (_disposed || _user == null) return;
    _user = null;
    _error = sessionExpiredMessage;
    notifyListeners();
  }

  /// Mengubah exception menjadi pesan yang layak ditampilkan ke pengguna.
  ///
  /// `Exception.toString()` menyertakan nama kelas internal (mis.
  /// `AuthException: Invalid credentials`) sehingga pesannya tidak eksplisit
  /// bagi pengguna (GAP-1).
  String _messageForError(Object error) {
    if (error is AppException) return error.message;
    if (error is FormatException && error.message.isNotEmpty) {
      return error.message;
    }
    return _genericErrorMessage;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionInvalidation?.cancel();
    _sessionInvalidation = null;
    super.dispose();
  }
}
