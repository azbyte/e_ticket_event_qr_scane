import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/services/session_service.dart';
import '../../models/user/user_role.dart';

class _DemoAccount {
  const _DemoAccount({
    required this.username,
    required this.email,
    required this.name,
    required this.password,
    required this.role,
  });

  final String username;
  final String email;
  final String name;
  final String password;
  final UserRole role;
}

class AuthService {
  AuthService();
  final ApiClient _api = ApiClient();
  final SessionService _session = SessionService.instance;

  static const List<_DemoAccount> _demoAccounts = [
    _DemoAccount(
      username: 'admin',
      email: 'admin@event.com',
      name: 'Super Admin',
      password: 'Admin123!',
      role: UserRole.admin,
    ),
    _DemoAccount(
      username: 'organizer',
      email: 'organizer@event.com',
      name: 'Event Organizer',
      password: 'Organizer123!',
      role: UserRole.organizer,
    ),
  ];

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.mockMode) {
      final identity = email.trim().toLowerCase();
      for (final account in _demoAccounts) {
        if ((identity == account.email || identity == account.username) &&
            password == account.password) {
          final user = _demoUser(account);
          await _session.saveToken('demo:${account.role.name}');
          return user;
        }
      }
      throw const FormatException('Email/username atau kata sandi salah.');
    }
    final response = await _api.post(
      '/auth/login',
      body: {
        if (email.contains('@'))
          'email': email.trim()
        else
          'username': email.trim(),
        'password': password,
      },
    );
    final token = response['token'] as String?;
    if (token == null || token.isEmpty)
      throw const FormatException('Token autentikasi tidak ditemukan.');
    await _session.saveToken(token);
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (AppConfig.mockMode) {
      throw const FormatException(
        'Pendaftaran tidak tersedia dalam mode demo.',
      );
    }
    final response = await _api.post(
      '/auth/register',
      body: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );
    final token = response['token'] as String?;
    if (token == null || token.isEmpty)
      throw const FormatException('Token autentikasi tidak ditemukan.');
    await _session.saveToken(token);
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<Map<String, dynamic>> me() async {
    if (AppConfig.mockMode) {
      final token = await _session.readToken();
      for (final account in _demoAccounts) {
        if (token == 'demo:${account.role.name}') {
          final profileName = await _session.readProfileName();
          return _demoUser(account, name: profileName);
        }
      }
      throw const FormatException('Sesi demo tidak ditemukan.');
    }
    final response = await _api.get('/auth/me');
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    if (AppConfig.mockMode) {
      final token = await _session.readToken();
      for (final account in _demoAccounts) {
        if (token == 'demo:${account.role.name}') {
          await _session.saveProfileName(name.trim());
          return _demoUser(account, name: name.trim());
        }
      }
      throw const FormatException('Sesi demo tidak ditemukan.');
    }
    final response = await _api.put('/auth/me', body: {'name': name.trim()});
    return Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<void> logout() async {
    if (AppConfig.mockMode) {
      await _session.clear();
      return;
    }
    try {
      await _api.post('/auth/logout');
    } finally {
      await _session.clear();
    }
  }

  Map<String, dynamic> _demoUser(_DemoAccount account, {String? name}) => {
    'id': 'demo-${account.role.name}',
    'username': account.username,
    'email': account.email,
    'name': name ?? account.name,
    'role': account.role.name,
    'email_verified': true,
  };
}
