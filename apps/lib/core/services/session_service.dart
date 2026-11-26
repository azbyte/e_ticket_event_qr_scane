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

  /// Cadangan dalam memori bila secure storage tidak tersedia.
  ///
  /// `flutter_secure_storage` versi web memakai `crypto.subtle`, yang hanya
  /// tersedia pada secure context (HTTPS atau localhost). Saat aplikasi dibuka
  /// dari alamat LAN/IP biasa, `read`/`write` melempar error. Tanpa cadangan
  /// ini login yang BERHASIL di backend tetap terlihat gagal karena token tidak
  /// dapat disimpan. Nilai di memori hanya bertahan selama sesi berjalan dan
  /// tidak pernah ditulis ke penyimpanan tidak terenkripsi.
  String? _memoryToken;
  String? _memoryProfileName;
  final Map<String, String> _memoryOrderTokens = {};

  /// Dipancarkan ketika credential auth dinyatakan tidak berlaku lagi oleh
  /// server (HTTP 401), sehingga pemegang state sesi dapat keluar tanpa harus
  /// menunggu aplikasi dibuka ulang.
  Stream<void> get onSessionInvalidated => _invalidated.stream;

  /// Memberi tahu pemantau bahwa sesi auth sudah tidak berlaku.
  void notifySessionInvalidated() {
    if (!_invalidated.isClosed) _invalidated.add(null);
  }

  Future<String?> readToken() async {
    try {
      final value = await _storage.read(key: _tokenKey);
      if (value != null) return value;
    } catch (_) {
      // Secure storage tidak tersedia pada konteks ini; pakai cadangan memori.
    }
    return _memoryToken;
  }

  Future<void> saveToken(String token) async {
    _memoryToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Token tetap tersedia di memori untuk sesi berjalan.
    }
  }

  Future<String?> readProfileName() async {
    try {
      final value = await _storage.read(key: _profileNameKey);
      if (value != null) return value;
    } catch (_) {
      // abaikan, gunakan cadangan memori
    }
    return _memoryProfileName;
  }

  Future<void> saveProfileName(String name) async {
    _memoryProfileName = name;
    try {
      await _storage.write(key: _profileNameKey, value: name);
    } catch (_) {
      // abaikan, nilai tetap tersedia di memori
    }
  }

  Future<String?> readOrderAccessToken(String orderId) async {
    try {
      final value = await _storage.read(key: '$_orderAccessTokenPrefix$orderId');
      if (value != null) return value;
    } catch (_) {
      // abaikan, gunakan cadangan memori
    }
    return _memoryOrderTokens[orderId];
  }

  Future<void> saveOrderAccessToken(String orderId, String token) async {
    _memoryOrderTokens[orderId] = token;
    try {
      await _storage.write(key: '$_orderAccessTokenPrefix$orderId', value: token);
    } catch (_) {
      // abaikan, nilai tetap tersedia di memori
    }
  }

  /// Membersihkan credential auth saja (token dan nama profil).
  ///
  /// `order_access_token_*` milik alur guest order (PRD §6.1 dan §7) sengaja
  /// dipertahankan: logout akun Organizer/Admin tidak boleh menghilangkan akses
  /// order guest yang tersimpan pada perangkat yang sama.
  Future<void> clear() async {
    _memoryToken = null;
    _memoryProfileName = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _profileNameKey);
    } catch (_) {
      // Secure storage tidak tersedia; state memori sudah dibersihkan.
    }
  }
}
