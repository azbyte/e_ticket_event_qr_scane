import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../providers/auth_provider.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});
  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  late Future<List<Map<String, dynamic>>> _accounts;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _accounts = ApiClient().get('/admin/accounts').then((data) => (data['accounts'] as List? ?? const []).cast<Map<String, dynamic>>());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengelolaan Akun')),
    body: RefreshIndicator(onRefresh: () async => setState(_reload), child: FutureBuilder<List<Map<String, dynamic>>>(future: _accounts, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Gagal memuat akun: ${snapshot.error}'))]);
      final accounts = snapshot.data ?? [];
      return ListView.builder(itemCount: accounts.length, itemBuilder: (context, index) {
        final account = accounts[index];
        final isDisabled = account['disabled_at'] != null;
        final isSelf = account['id'] == context.read<AuthProvider>().user?.id;
        return ListTile(
          leading: Icon(account['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person_outline),
          title: Text(account['name']?.toString() ?? 'Akun'),
          subtitle: Text('${account['email'] ?? ''} · ${account['role'] ?? ''}${isDisabled ? ' · Dinonaktifkan' : ''}'),
          trailing: account['role'] == 'admin' || isSelf ? null : Switch(value: !isDisabled, onChanged: (enabled) async {
            try {
              await ApiClient().put('/admin/accounts/${account['id']}/status', body: {'disabled': !enabled});
              if (mounted) setState(_reload);
            } catch (error) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah status akun: $error')));
            }
          }),
        );
      });
    })),
  );
}