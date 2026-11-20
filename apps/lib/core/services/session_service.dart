import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _tokenKey = 'auth_token';
  static const _profileNameKey = 'profile_name';
  static const _orderAccessTokenPrefix = 'order_access_token_';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final StreamController<void> _invalidated = StreamController<void>.broadcast();

  /// Dipancarkan ketika credential auth dinyatakan tidak berlaku lagi oleh
  /// server (HTTP 401), sehingga pemegang state sesi dapat keluar tanpa harus
  /// menunggu aplikasi dibuka ulang.
  Stream<void> get onSessionInvalidated => _invalidated.stream;

  /// Memberi tahu pemantau bahwa sesi auth sudah tidak berlaku.
  void notifySessionInvalidated() {
    if (!_invalidated.isClosed) _invalidated.add(null);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> readProfileName() => _storage.read(key: _profileNameKey);
  Future<void> saveProfileName(String name) =>
      _storage.write(key: _profileNameKey, value: name);
  Future<String?> readOrderAccessToken(String orderId) =>
      _storage.read(key: '$_orderAccessTokenPrefix$orderId');
  Future<void> saveOrderAccessToken(String orderId, String token) =>
      _storage.write(key: '$_orderAccessTokenPrefix$orderId', value: token);

  /// Membersihkan credential auth saja (token dan nama profil).
  ///
  /// `order_access_token_*` milik alur guest order (PRD §6.1 dan §7) sengaja
  /// dipertahankan: logout akun Organizer/Admin tidak boleh menghilangkan akses
  /// order guest yang tersimpan pada perangkat yang sama.
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _profileNameKey);
  }
}
