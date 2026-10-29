/// Staff management screen (organizer) — PRD sections 4.8, 7.4 E.
///
/// Staff invitations, role assignments, active delegation, and access revocation.
library;

import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';
import '../../../providers/organizer_provider.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    this.organizerProvider,
    this.eventId = 'evt-001',
    this.eventTitle = 'Tech Innovation Summit 2026',
  });

  final OrganizerProvider? organizerProvider;
  final String eventId;
  final String eventTitle;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late final OrganizerProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.organizerProvider ?? OrganizerProvider();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    await _provider.loadStaff(widget.eventId);
  }

  void _showInviteStaffDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'QR Scanner Staff';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Undang Staf Event'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Undang anggota panitia untuk membantu verifikasi check-in pada event ini.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Email Staf *',
                  hintText: 'staf@eventcrew.id',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: InputValidator.email,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Hak Akses & Peran',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'QR Scanner Staff', child: Text('Pemindai Tiket (Scanner)')),
                  DropdownMenuItem(value: 'Registration Desk', child: Text('Meja Registrasi & Input Manual')),
                  DropdownMenuItem(value: 'Supervisor Gate', child: Text('Supervisor Pintu Masuk')),
                ],
                onChanged: (val) {
                  if (val != null) selectedRole = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final email = emailController.text.trim();
                Navigator.pop(ctx);
                final ok = await _provider.inviteStaff(widget.eventId, email, selectedRole);
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Undangan staf berhasil dikirim ke $email.'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
              }
            },
            child: const Text('Kirim Undangan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final staff = _provider.staffList;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manajemen Staf Event'),
            actions: [
              IconButton(
                tooltip: 'Segarkan',
                icon: const Icon(Icons.refresh),
                onPressed: _loadStaff,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Undang Staf'),
            onPressed: _showInviteStaffDialog,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Context Banner
              Container(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Event Aktif:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            widget.eventTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Staff List
              Expanded(
                child: _provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : staff.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('Belum ada staf ditugaskan pada event ini.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: staff.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = staff[index];
                              final staffId = item['id'] as String;
                              final name = item['name'] as String? ?? 'Staf';
                              final email = item['email'] as String? ?? '-';
                              final role = item['role'] as String? ?? 'Staf Event';

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.indigo.shade50,
                                    child: Icon(Icons.badge, color: Colors.indigo.shade700),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('$role\n$email', style: const TextStyle(fontSize: 12)),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: 'Cabut Akses Staf',
                                    icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Cabut Akses Staf?'),
                                          content: Text('Apakah Anda yakin ingin mencabut akses staf untuk $name ($email)?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Cabut Akses'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _provider.removeStaff(widget.eventId, staffId);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
