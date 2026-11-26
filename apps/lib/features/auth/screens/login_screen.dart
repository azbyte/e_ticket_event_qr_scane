import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/validators/input_validator.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.redirectRoute});

  /// Tujuan setelah login berhasil. Dipakai deep link seperti `/invite/:token`
  /// agar pengguna kembali ke halaman yang diminta (D1-1).
  final String? redirectRoute;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _checkingConnection = false;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Memeriksa `/health` backend agar pengguna dapat memastikan aplikasi
  /// benar-benar terhubung ke backend dan database sebelum mencoba masuk.
  Future<void> _checkConnection() async {
    setState(() => _checkingConnection = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final health = await fetchServerHealth();
      final database = health['database']?.toString() ?? 'unknown';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            database == 'connected'
                ? 'Terhubung ke ${AppConfig.apiBaseUrl} (database: connected).'
                : 'Backend terjangkau, tetapi database: $database.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AppException
                ? error.message
                : 'Tidak dapat terhubung ke ${AppConfig.apiBaseUrl}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    // Identitas dikirim apa adanya: backend menerima email ATAU username.
    final identity = _identity.text.trim();
    final success = await auth.login(email: identity, password: _password.text);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login gagal.')),
      );
      return;
    }
    final redirect = widget.redirectRoute;
    // AuthGate (`/`) mengarahkan ke dashboard sesuai role pengguna; deep link
    // yang eksplisit tetap diprioritaskan.
    Navigator.of(context).pushNamedAndRemoveUntil(
      redirect != null && redirect.isNotEmpty ? redirect : AppRoutes.initial,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.confirmation_number, size: 56),
                    const SizedBox(height: 12),
                    Text('Masuk ke Event Ticket', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 28),
                    TextFormField(controller: _identity, keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email atau username', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => InputValidator.required(value, field: 'Email atau username')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _password, obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(labelText: 'Kata sandi', prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure))),
                      validator: (value) => InputValidator.required(value, field: 'Kata sandi')),
                    const SizedBox(height: 24),
                    Consumer<AuthProvider>(builder: (_, auth, _) => FilledButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Masuk'),
                    )),
                    TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text('Belum punya akun? Daftar sebagai penyelenggara')),
                    TextButton.icon(
                      onPressed: _checkingConnection ? null : _checkConnection,
                      icon: _checkingConnection
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('Cek koneksi server'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}