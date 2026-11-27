import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
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
        backgroundColor: AppTheme.surfaceColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.subtleGray),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: AppTheme.softTerracottaBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.confirmation_number,
                              size: 40,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Masuk ke Event Ticket',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.offBlack,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masuk sebagai Penyelenggara, Staf, atau Admin Platform',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.slateGray, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _identity,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email atau username',
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                          ),
                          validator: (value) =>
                              InputValidator.required(value, field: 'Email atau username'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Kata sandi',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility : Icons.visibility_off,
                                color: AppTheme.slateGray,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (value) =>
                              InputValidator.required(value, field: 'Kata sandi'),
                        ),
                        const SizedBox(height: 24),
                        Consumer<AuthProvider>(
                          builder: (_, auth, _) => FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: AppTheme.pureWhite,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: auth.isLoading ? null : _submit,
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.pureWhite,
                                    ),
                                  )
                                : const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                          child: const Text('Belum punya akun? Daftar sebagai penyelenggara'),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.slateGray),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}