import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(name: _name.text, email: _email.text, password: _password.text);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Pendaftaran gagal.')));
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daftar Penyelenggara')),
        body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Buat akun penyelenggara event. Hak Admin hanya dapat diberikan oleh administrator platform.'),
              const SizedBox(height: 20),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama lengkap'),
                validator: (value) => InputValidator.required(value, field: 'Nama')),
              const SizedBox(height: 14),
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'), validator: InputValidator.email),
              const SizedBox(height: 14),
              TextFormField(controller: _password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Kata sandi'), validator: InputValidator.password),
              const SizedBox(height: 20),
              Consumer<AuthProvider>(builder: (_, auth, __) => FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading ? const CircularProgressIndicator() : const Text('Daftar'),
              )),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sudah punya akun? Masuk')),
            ])),
          ),
        )),
      );
}