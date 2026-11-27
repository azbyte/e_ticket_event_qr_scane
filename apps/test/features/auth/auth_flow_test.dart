import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_ticket_event_qr_scane/core/errors/app_exception.dart';
import 'package:e_ticket_event_qr_scane/core/services/session_service.dart';
import 'package:e_ticket_event_qr_scane/core/validators/input_validator.dart';
import 'package:e_ticket_event_qr_scane/features/auth/screens/register_screen.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_model.dart';
import 'package:e_ticket_event_qr_scane/models/user/user_role.dart';
import 'package:e_ticket_event_qr_scane/providers/auth_provider.dart';
import 'package:e_ticket_event_qr_scane/services/auth/auth_service.dart';

/// Fake mengikuti pola repo (`apps/test/widget_test.dart`,
/// `apps/test/app_router_test.dart`): subclass [AuthService] lalu override
/// method yang dibutuhkan. Tidak ada HTTP/secure-storage sungguhan yang dipakai
/// kecuali pada grup uji cakupan penyimpanan sesi.
class _FakeAuthService extends AuthService {
  _FakeAuthService({
    this.loginResult,
    this.registerResult,
    this.meResult,
    this.updateProfileResult,
    this.loginError,
    this.registerError,
    this.meError,
    this.updateProfileError,
  });

  final Map<String, dynamic>? loginResult;
  final Map<String, dynamic>? registerResult;
  final Map<String, dynamic>? meResult;
  final Map<String, dynamic>? updateProfileResult;
  final Object? loginError;
  final Object? registerError;
  final Object? meError;
  final Object? updateProfileError;

  final List<Map<String, String>> loginRequests = [];
  final List<Map<String, String>> registerRequests = [];
  final List<Map<String, String>> updateProfileRequests = [];
  int logoutCalls = 0;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    loginRequests.add({'email': email, 'password': password});
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerRequests.add({'name': name, 'email': email, 'password': password});
    if (registerError != null) throw registerError!;
    return registerResult!;
  }

  @override
  Future<Map<String, dynamic>> me() async {
    if (meError != null) throw meError!;
    return meResult!;
  }

  @override
  Future<Map<String, dynamic>> updateProfile({required String name}) async {
    updateProfileRequests.add({'name': name});
    if (updateProfileError != null) throw updateProfileError!;
    return updateProfileResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

Map<String, dynamic> _organizerPayload({String name = 'Organizer Uji'}) => {
  'id': 'u-1',
  'name': name,
  'email': 'organizer@example.test',
  'username': 'organizer',
  'role': 'organizer',
  'created_at': '2026-01-01T00:00:00.000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GAP-1 — pesan error auth eksplisit', () {
    test('kegagalan login menampilkan pesan server tanpa nama kelas exception', () async {
      final service = _FakeAuthService(
        loginError: const AuthException('Invalid credentials', statusCode: 401),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.login(
        email: 'organizer@example.test',
        password: 'salah',
      );

      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.error, 'Invalid credentials');
      expect(auth.error, isNot(contains('AuthException')));
      expect(auth.error, isNot(contains('Exception')));
    });

    test('kegagalan jaringan menampilkan pesan yang dapat dipahami pengguna', () async {
      final service = _FakeAuthService(
        loginError: const NetworkException(
          'Tidak dapat terhubung ke server. Periksa koneksi dan alamat API.',
        ),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.login(email: 'organizer@example.test', password: 'rahasia123');

      expect(
        auth.error,
        'Tidak dapat terhubung ke server. Periksa koneksi dan alamat API.',
      );
      expect(auth.error, isNot(contains('NetworkException')));
    });

    test('exception tak dikenal dipetakan ke pesan generik', () async {
      final service = _FakeAuthService(loginError: Exception('boom'));
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.login(email: 'organizer@example.test', password: 'rahasia123');

      expect(auth.error, 'Terjadi kesalahan. Silakan coba lagi.');
      expect(auth.error, isNot(contains('boom')));
    });

    test('FormatException dari auth service ditampilkan apa adanya', () async {
      final service = _FakeAuthService(
        loginError: const FormatException('Token autentikasi tidak ditemukan.'),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.login(email: 'organizer@example.test', password: 'rahasia123');

      expect(auth.error, 'Token autentikasi tidak ditemukan.');
    });
  group('Sesi, role, dan payload request', () {
    test('login berhasil menyimpan user dan role yang ditetapkan server', () async {
      final service = _FakeAuthService(loginResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.login(
        email: 'organizer@example.test',
        password: 'rahasia123',
      );

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.role, UserRole.organizer);
      expect(auth.user?.email, 'organizer@example.test');
      expect(auth.error, isNull);
      expect(service.loginRequests.single, {
        'email': 'organizer@example.test',
        'password': 'rahasia123',
      });
    });

    test('login gagal tidak menghasilkan sesi mock', () async {
      final service = _FakeAuthService(
        loginError: const AuthException('Invalid credentials', statusCode: 401),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.login(email: 'organizer@example.test', password: 'x');

      expect(success, isFalse);
      expect(auth.user, isNull);
      expect(auth.isAuthenticated, isFalse);
    });

    test('register tidak pernah mengirim role dari klien', () async {
      final service = _FakeAuthService(registerResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.register(
        name: 'Organizer Uji',
        email: 'organizer@example.test',
        password: 'rahasia123',
      );

      expect(success, isTrue);
      final request = service.registerRequests.single;
      expect(request.keys.toSet(), {'name', 'email', 'password'});
      expect(request.containsKey('role'), isFalse);
      expect(auth.user?.role, UserRole.organizer, reason: 'role berasal dari server');
    });

    test('register gagal menampilkan pesan tanpa membuat sesi', () async {
      final service = _FakeAuthService(
        registerError: const NetworkException('Email sudah terdaftar.', statusCode: 400),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.register(
        name: 'Organizer Uji',
        email: 'organizer@example.test',
        password: 'rahasia123',
      );

      expect(success, isFalse);
      expect(auth.error, 'Email sudah terdaftar.');
      expect(auth.isAuthenticated, isFalse);
    });

    test('updateProfile hanya mengirim name dan memperbarui user', () async {
      final service = _FakeAuthService(
        updateProfileResult: _organizerPayload(name: 'Nama Baru'),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.updateProfile(name: 'Nama Baru');

      expect(success, isTrue);
      expect(service.updateProfileRequests.single, {'name': 'Nama Baru'});
      expect(auth.user?.name, 'Nama Baru');
      expect(auth.user?.role, UserRole.organizer);
    });

    test('restoreSession yang gagal membuat pengguna tidak terautentikasi', () async {
      final service = _FakeAuthService(
        meError: const AuthException('Not authorized, no token', statusCode: 401),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.restoreSession();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(
        service.logoutCalls,
        1,
        reason: 'sesi lokal dibersihkan saat restore gagal',
      );
    });

    test('restoreSession berhasil memuat profil dari /me', () async {
      final service = _FakeAuthService(meResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.restoreSession();

      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.role, UserRole.organizer);
      expect(service.logoutCalls, 0);
    });

    test('kegagalan updateProfile menampilkan pesan tanpa nama kelas', () async {
      final service = _FakeAuthService(
        updateProfileError: const AuthException('This session has been revoked', statusCode: 401),
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      final success = await auth.updateProfile(name: 'Nama Baru');

      expect(success, isFalse);
      expect(auth.error, 'This session has been revoked');
      expect(auth.error, isNot(contains('AuthException')));
    });
  });

  group('GAP-2 — sesi yang dibatalkan server', () {
    test('invalidasi sesi mengosongkan state provider tanpa restart', () async {
      final auth = AuthProvider(_FakeAuthService(loginResult: _organizerPayload()));
      addTearDown(auth.dispose);
      await auth.login(email: 'organizer@example.test', password: 'rahasia123');
      expect(auth.isAuthenticated, isTrue);

      SessionService.instance.notifySessionInvalidated();
      await pumpEventQueue();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.user, isNull);
      expect(auth.error, AuthProvider.sessionExpiredMessage);
    });

    test('invalidasi tanpa sesi aktif tidak memunculkan error', () async {
      final auth = AuthProvider(_FakeAuthService());
      addTearDown(auth.dispose);

      SessionService.instance.notifySessionInvalidated();
      await pumpEventQueue();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.error, isNull);
    });

    test('logout eksplisit membersihkan user dan pesan error', () async {
      final service = _FakeAuthService(loginResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);
      await auth.login(email: 'organizer@example.test', password: 'rahasia123');

      await auth.logout();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.error, isNull);
      expect(service.logoutCalls, 1);
    });

    test('provider yang sudah di-dispose tidak bereaksi terhadap invalidasi', () async {
      final auth = AuthProvider(_FakeAuthService(loginResult: _organizerPayload()));
      await auth.login(email: 'organizer@example.test', password: 'rahasia123');
      auth.dispose();

      expect(() => SessionService.instance.notifySessionInvalidated(), returnsNormally);
      await pumpEventQueue();
    });
  });


  });
  group('GAP-4 — pemetaan role sesuai PRD §2', () {
    test('role legacy backend "customer" dipetakan ke attendee tanpa hak istimewa', () {
      final user = UserModel.fromJson({
        'id': 'u-legacy',
        'name': 'Akun Lama',
        'email': 'lama@example.test',
        'role': 'customer',
      });

      expect(user.role, UserRole.attendee);
      expect(user.role, isNot(UserRole.admin));
      expect(user.role, isNot(UserRole.organizer));
      expect(user.role, isNot(UserRole.staff));
    });

    test('role PRD dipetakan tepat', () {
      expect(UserRole.fromString('organizer'), UserRole.organizer);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('staff'), UserRole.staff);
      expect(UserRole.fromString('attendee'), UserRole.attendee);
      expect(UserRole.fromString(null), isNull);
    });

    test('role tak dikenal tidak menghasilkan eskalasi hak', () {
      final user = UserModel.fromJson({
        'id': 'u-x',
        'name': 'Misterius',
        'email': 'x@example.test',
        'role': 'superadmin',
      });

      expect(user.role, UserRole.attendee);
    });

    test('payload login server menentukan role pada provider', () async {
      final service = _FakeAuthService(
        loginResult: {..._organizerPayload(), 'role': 'admin'},
      );
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await auth.login(email: 'organizer@example.test', password: 'rahasia123');

      expect(auth.user?.role, UserRole.admin, reason: 'role mengikuti payload server');
    });
  });

  group('GAP-3 — cakupan penyimpanan sesi', () {
    test('clear() menghapus credential auth tetapi mempertahankan token order guest', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'token-lama',
        'profile_name': 'Organizer Uji',
        'order_access_token_ord-001': 'guest-order-token',
      });
      final session = SessionService.instance;

      expect(await session.readToken(), 'token-lama');
      await session.clear();

      expect(await session.readToken(), isNull, reason: 'token auth dihapus');
      expect(await session.readProfileName(), isNull, reason: 'nama profil dihapus');
      expect(
        await session.readOrderAccessToken('ord-001'),
        'guest-order-token',
        reason: 'token order guest (PRD §6.1/§7) tidak boleh ikut terhapus saat logout',
      );
    });

    test('token auth yang disimpan ulang tetap terbaca setelah clear()', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionService.instance;

      await session.saveToken('token-baru');
      expect(await session.readToken(), 'token-baru');
      await session.clear();
      expect(await session.readToken(), isNull);
    });
  });

  group('RegisterScreen — verifikasi kata sandi', () {
    test('InputValidator.confirmPassword menolak input kosong atau tidak cocok', () {
      expect(InputValidator.confirmPassword('', 'rahasia123'), 'Verifikasi kata sandi wajib diisi.');
      expect(InputValidator.confirmPassword('beda123', 'rahasia123'), 'Verifikasi kata sandi tidak cocok.');
      expect(InputValidator.confirmPassword('rahasia123', 'rahasia123'), isNull);
    });

    testWidgets('menolak submit bila verifikasi kata sandi kosong atau tidak cocok', (tester) async {
      final service = _FakeAuthService(registerResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      expect(find.byKey(const Key('register-confirm-password-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('register-name-field')), 'Organizer Uji');
      await tester.enterText(find.byKey(const Key('register-email-field')), 'organizer@example.test');
      await tester.enterText(find.byKey(const Key('register-password-field')), 'rahasia123');
      await tester.enterText(find.byKey(const Key('register-confirm-password-field')), 'berbeda123');

      final submitBtn = find.byKey(const Key('register-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi kata sandi tidak cocok.'), findsOneWidget);
      expect(service.registerRequests, isEmpty);
    });

    testWidgets('mengirim registrasi saat verifikasi kata sandi cocok', (tester) async {
      final service = _FakeAuthService(registerResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            initialRoute: '/register',
            routes: {
              '/register': (_) => const RegisterScreen(),
              '/': (_) => const Scaffold(body: Text('Berhasil')),
            },
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('register-name-field')), 'Organizer Uji');
      await tester.enterText(find.byKey(const Key('register-email-field')), 'organizer@example.test');
      await tester.enterText(find.byKey(const Key('register-password-field')), 'rahasia123');
      await tester.enterText(find.byKey(const Key('register-confirm-password-field')), 'rahasia123');

      final submitBtn = find.byKey(const Key('register-submit-button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(service.registerRequests, hasLength(1));
      expect(service.registerRequests.single['email'], 'organizer@example.test');
    });

    testWidgets('ikon mata men-toggle visibilitas kata sandi dan verifikasi kata sandi', (tester) async {
      final service = _FakeAuthService(registerResult: _organizerPayload());
      final auth = AuthProvider(service);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );

      EditableText passwordInput() => tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('register-password-field')),
              matching: find.byType(EditableText),
            ),
          );
      EditableText confirmInput() => tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('register-confirm-password-field')),
              matching: find.byType(EditableText),
            ),
          );

      expect(passwordInput().obscureText, isTrue);
      expect(confirmInput().obscureText, isTrue);

      await tester.tap(find.byKey(const Key('register-password-visibility-toggle')));
      await tester.pump();
      expect(passwordInput().obscureText, isFalse);
      expect(confirmInput().obscureText, isTrue);

      await tester.tap(find.byKey(const Key('register-confirm-password-visibility-toggle')));
      await tester.pump();
      expect(passwordInput().obscureText, isFalse);
      expect(confirmInput().obscureText, isFalse);
    });
  });
}

