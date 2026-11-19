import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _tokenKey = 'auth_token';
  static const _profileNameKey = 'profile_name';
  static const _orderAccessTokenPrefix = 'order_access_token_';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
  Future<void> clear() => _storage.deleteAll();
}
