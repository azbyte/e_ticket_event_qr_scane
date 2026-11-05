import 'package:flutter/material.dart';

import '../../../services/event/event_service.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key, required this.eventId, required this.eventName});
  final String eventId;
  final String eventName;
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _service = EventService();
  final _identity = TextEditingController();
  late Future<List<Map<String, dynamic>>> _members;
  bool _saving = false;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void dispose() { _identity.dispose(); super.dispose(); }
  void _reload() => _members = _service.members(widget.eventId);

  Future<void> _add() async {
    if (_identity.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.addMember(widget.eventId, _identity.text);
      _identity.clear();
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menambahkan anggota: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Anggota • ${widget.eventName}')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: TextField(controller: _identity, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email atau username', hintText: 'petugas@example.com'))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _saving ? null : _add, icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add)),
      ])),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _members, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Gagal memuat anggota: ${snapshot.error}'));
        final members = snapshot.data ?? [];
        if (members.isEmpty) return const Center(child: Text('Belum ada anggota event.'));
        return ListView.builder(itemCount: members.length, itemBuilder: (context, index) {
          final member = members[index];
          final profile = Map<String, dynamic>.from(member['profiles'] as Map? ?? {});
          final id = member['user_id'].toString();
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
            title: Text(profile['name']?.toString() ?? profile['username']?.toString() ?? 'Petugas'),
            subtitle: Text(profile['email']?.toString() ?? ''),
            trailing: IconButton(tooltip: 'Hapus anggota', icon: const Icon(Icons.person_remove_outlined), onPressed: () async {
              try { await _service.removeMember(widget.eventId, id); if (mounted) setState(_reload); }
              catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus anggota: $error'))); }
            }));
        });
      })),
    ]),
  );
}