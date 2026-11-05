import 'package:flutter/material.dart';

import '../../../services/event/event_service.dart';
import 'event_form_screen.dart';
import 'staff_management_screen.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});
  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final _service = EventService();
  late Future<List<Map<String, dynamic>>> _events;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => _events = _service.myEvents();

  Future<void> _create() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EventFormScreen()));
    if (created == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event Saya')),
    floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Buat event')),
    body: RefreshIndicator(onRefresh: () async => setState(_reload), child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Gagal memuat event: ${snapshot.error}'))]);
        final events = snapshot.data ?? [];
        if (events.isEmpty) return ListView(children: const [SizedBox(height: 150), Center(child: Text('Belum ada event. Buat event pertama Anda.'))]);
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: events.length, itemBuilder: (context, index) {
          final event = events[index];
          final id = event['id'].toString();
          return Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.event)),
            title: Text(event['title']?.toString() ?? 'Event'),
            subtitle: Text('${event['location'] ?? 'Lokasi belum diisi'}\n${event['event_date'] ?? ''}', maxLines: 2),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (action) async {
              if (action == 'members') {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffManagementScreen(eventId: id, eventName: event['title']?.toString() ?? 'Event')));
              } else if (action == 'delete') {
                await _service.delete(id);
                if (mounted) setState(_reload);
              }
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'members', child: Text('Kelola anggota')), PopupMenuItem(value: 'delete', child: Text('Hapus event'))]),
          ));
        });
      },
    )),
  );
}