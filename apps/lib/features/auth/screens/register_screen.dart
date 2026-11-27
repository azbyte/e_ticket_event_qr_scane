import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/input_validator.dart';
import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _name.text,
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Pendaftaran gagal.')),
      );
      return;
    }
    // Akun Organizer berhasil dibuat: beri konfirmasi lalu arahkan ke halaman
    // yang sesuai dengan role yang dikembalikan server (AuthGate / dashboard).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akun penyelenggara berhasil dibuat.')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: const Text('Daftar Penyelenggara'),
          backgroundColor: AppTheme.pureWhite,
          foregroundColor: AppTheme.offBlack,
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppTheme.subtleGray),
          ),
        ),
        body: Center(
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
                      const Text(
                        'Buat akun penyelenggara event. Hak Admin hanya dapat diberikan oleh administrator platform.',
                        style: TextStyle(color: AppTheme.slateGray, fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('register-name-field'),
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nama lengkap',
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) => InputValidator.required(value, field: 'Nama'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('register-email-field'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                        ),
                        validator: InputValidator.email,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('register-password-field'),
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            key: const Key('register-password-visibility-toggle'),
                            tooltip: _obscurePassword
                                ? 'Tampilkan kata sandi'
                                : 'Sembunyikan kata sandi',
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppTheme.slateGray,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: InputValidator.password,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('register-confirm-password-field'),
                        controller: _confirmPassword,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Verifikasi kata sandi',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                          suffixIcon: IconButton(
                            key: const Key('register-confirm-password-visibility-toggle'),
                            tooltip: _obscureConfirmPassword
                                ? 'Tampilkan verifikasi kata sandi'
                                : 'Sembunyikan verifikasi kata sandi',
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppTheme.slateGray,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (value) => InputValidator.confirmPassword(
                          value,
                          _password.text,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Consumer<AuthProvider>(
                        builder: (_, auth, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (auth.error != null) ...[
                              Text(
                                auth.error!,
                                style: const TextStyle(color: AppTheme.errorColor),
                              ),
                              const SizedBox(height: 12),
                            ],
                            FilledButton(
                              key: const Key('register-submit-button'),
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
                                  : const Text('Daftar', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Sudah punya akun? Masuk'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
