import 'session_service.dart';

abstract interface class OrderAccessTokenStore {
  Future<String?> read(String orderId);
  Future<void> save(String orderId, String token);
}

class SecureOrderAccessTokenStore implements OrderAccessTokenStore {
  const SecureOrderAccessTokenStore();

  @override
  Future<String?> read(String orderId) =>
      SessionService.instance.readOrderAccessToken(orderId);

  @override
  Future<void> save(String orderId, String token) =>
      SessionService.instance.saveOrderAccessToken(orderId, token);
}
