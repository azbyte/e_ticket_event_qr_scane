import 'package:flutter/material.dart';

import '../../../services/event/event_service.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key});
  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  DateTime? _date;
  bool _saving = false;
  final _service = EventService();

  @override
  void dispose() { _title.dispose(); _description.dispose(); _location.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_date == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal event.'))); return; }
    setState(() => _saving = true);
    try {
      await _service.create(title: _title.text, description: _description.text, date: _date!, location: _location.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat event: $error')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buat Event')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Nama event'), validator: (v) => v == null || v.trim().isEmpty ? 'Nama event wajib diisi.' : null),
      const SizedBox(height: 16),
      TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi')),
      const SizedBox(height: 16),
      TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Lokasi'), validator: (v) => v == null || v.trim().isEmpty ? 'Lokasi wajib diisi.' : null),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: DateTime(now.year + 10));
        if (selected != null) setState(() => _date = selected);
      }, icon: const Icon(Icons.calendar_month), label: Text(_date == null ? 'Pilih tanggal event' : '${_date!.day}/${_date!.month}/${_date!.year}')),
      const SizedBox(height: 24),
      FilledButton(onPressed: _saving ? null : _submit, child: _saving ? const CircularProgressIndicator() : const Text('Simpan event')),
    ])),
  );
}