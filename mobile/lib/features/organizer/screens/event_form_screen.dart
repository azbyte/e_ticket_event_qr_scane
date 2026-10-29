/// Event form screen (PRD sections 4.2, 7.4 C).
///
/// Comprehensive event creation and editor with ticket category definitions,
/// schedule pickers, quota controls, and moderation submission.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/validators/input_validator.dart';
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/organizer_provider.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    this.organizerProvider,
    this.initialEvent,
  });

  final OrganizerProvider? organizerProvider;
  final EventModel? initialEvent;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final OrganizerProvider _provider;

  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;
  late final TextEditingController _contactController;

  String _category = 'Teknologi';
  String _eventType = 'offline';
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 8));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  final List<Map<String, dynamic>> _ticketTypes = [
    {
      'name': 'Regular Pass',
      'price': 150000,
      'quota': 100,
    },
  ];

  @override
  void initState() {
    super.initState();
    _provider = widget.organizerProvider ?? OrganizerProvider();

    final ev = widget.initialEvent;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    _contactController = TextEditingController(text: ev?.contactInfo ?? '');

    if (ev != null) {
      _category = ev.category ?? 'Teknologi';
      _eventType = ev.eventType;
      _startDate = ev.startDateTime;
      _startTime = TimeOfDay(hour: ev.startDateTime.hour, minute: ev.startDateTime.minute);
      _endDate = ev.endDateTime;
      _endTime = TimeOfDay(hour: ev.endDateTime.hour, minute: ev.endDateTime.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addTicketTypeDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '100000');
    final quotaCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori Tiket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Tiket (cth: VIP Pass)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga (Rp)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quotaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kuota Tiket'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _ticketTypes.add({
                    'name': nameCtrl.text.trim(),
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'quota': int.tryParse(quotaCtrl.text) ?? 50,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvent(bool submitForReview) async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final status = submitForReview
        ? AppConstants.eventStatusPendingReview
        : AppConstants.eventStatusDraft;

    final event = EventModel(
      id: widget.initialEvent?.id ?? 'evt-${DateTime.now().millisecondsSinceEpoch}',
      organizerId: widget.initialEvent?.organizerId ?? 'org-001',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      location: _locationController.text.trim(),
      eventType: _eventType,
      contactInfo: _contactController.text.trim(),
      status: status,
      isPublic: submitForReview,
    );

    final ticketModels = _ticketTypes.map((t) {
      return TicketTypeModel(
        id: 'tt-${DateTime.now().millisecondsSinceEpoch}-${t['name']}',
        eventId: event.id,
        name: t['name'] as String,
        price: (t['price'] as num).toDouble(),
        quota: (t['quota'] as num).toInt(),
      );
    }).toList();

    if (widget.initialEvent != null) {
      await _provider.updateEvent(event);
    } else {
      await _provider.createEvent(event, ticketTypes: ticketModels);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitForReview
                ? 'Event berhasil diajukan untuk moderasi admin.'
                : 'Event berhasil disimpan sebagai draf.',
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEvent != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Buat Event Baru'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info Section
              Text(
                '1. Informasi Dasar Event',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nama Event *',
                  hintText: 'Misal: Konferensi AI Indonesia 2026',
                  border: OutlineInputBorder(),
                ),
                validator: InputValidator.required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori Event',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Teknologi', child: Text('Teknologi & IT')),
                  DropdownMenuItem(value: 'Bisnis', child: Text('Bisnis & Entrepreneur')),
                  DropdownMenuItem(value: 'Seni & Musik', child: Text('Seni & Musik')),
                  DropdownMenuItem(value: 'Edukasi', child: Text('Edukasi & Workshop')),
                  DropdownMenuItem(value: 'Olahraga', child: Text('Olahraga & Kesehatan')),
                  DropdownMenuItem(value: 'Umum', child: Text('Umum / Lainnya')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Acara *',
                  hintText: 'Jelaskan jadwal, pembicara, dan topik yang dibahas...',
                  border: OutlineInputBorder(),
                ),
                validator: InputValidator.required,
              ),

              const SizedBox(height: 24),

              // Format & Location Section
              Text(
                '2. Format & Lokasi Acara',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'offline', label: Text('Tatap Muka')),
                  ButtonSegment(value: 'online', label: Text('Online / Web')),
                  ButtonSegment(value: 'hybrid', label: Text('Hybrid')),
                ],
                selected: {_eventType},
                onSelectionChanged: (val) => setState(() => _eventType = val.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi / Platform URL *',
                  hintText: 'Gedung / Alamat / Tautan Webinar',
                  prefixIcon: Icon(Icons.place_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: InputValidator.required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Kontak Penyelenggara',
                  hintText: 'Email atau nomor telepon bantuan',
                  prefixIcon: Icon(Icons.mail_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // Schedule Section
              Text(
                '3. Jadwal Pelaksanaan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Mulai: ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                      onPressed: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 16),
                      label: Text('Selesai: ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                      onPressed: () => _pickDate(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Ticket Types Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '4. Kategori Tiket',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah Tiket'),
                    onPressed: _addTicketTypeDialog,
                  ),
                ],
              ),
              ..._ticketTypes.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Harga: Rp ${(t['price'] as num).toInt()} • Kuota: ${t['quota']} tiket'),
                    trailing: _ticketTypes.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => setState(() => _ticketTypes.removeAt(idx)),
                          )
                        : null,
                  ),
                );
              }),

              const SizedBox(height: 32),

              // Submission Buttons
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _saveEvent(true),
                child: const Text(
                  'Ajukan untuk Moderasi Admin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _saveEvent(false),
                child: const Text('Simpan sebagai Draf'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
