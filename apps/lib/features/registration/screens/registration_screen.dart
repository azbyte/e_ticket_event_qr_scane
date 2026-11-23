import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/event/attendee_field_definition.dart';
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/event_provider.dart';
import '../../payments/screens/payment_screen.dart';
import '../../tickets/screens/ticket_list_screen.dart';

/// Registration screen — choose ticket types & quantity + attendee info (PRD sections 3.1 #5,#6, 4.4, 7.2 D).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.event, this.eventId});

  final EventModel? event;
  final String? eventId;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checkboxValues = {};
  final Map<String, String> _selectValues = {};

  String? _selectedTicketTypeId;
  bool _isSubmitting = false;
  final String _idempotencyKey = _newIdempotencyKey();

  EventModel? _event;
  List<TicketTypeModel> _ticketTypes = [];
  final EventProvider _eventProvider = EventProvider.instance;
  bool _isLoadingEvent = true;
  String? _loadError;

  static String _newIdempotencyKey() {
    final random = Random.secure();
    return List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Siapkan state form untuk setiap field peserta event (D1-5).
  void _prepareFieldState(EventModel event) {
    for (final field in event.resolvedAttendeeFields) {
      if (field.isCheckbox) {
        _checkboxValues.putIfAbsent(field.key, () => false);
      } else if (field.isSelect) {
        _selectValues.putIfAbsent(field.key, () => '');
      } else {
        _controllers.putIfAbsent(field.key, TextEditingController.new);
      }
    }
  }

  Map<String, dynamic> _collectAnswers(EventModel event) {
    final answers = <String, dynamic>{};
    for (final field in event.resolvedAttendeeFields) {
      if (field.isCheckbox) {
        answers[field.key] = _checkboxValues[field.key] ?? false;
      } else if (field.isSelect) {
        final value = _selectValues[field.key] ?? '';
        if (value.isNotEmpty) answers[field.key] = value;
      } else {
        final value = _controllers[field.key]?.text.trim() ?? '';
        if (value.isNotEmpty) answers[field.key] = value;
      }
    }
    return answers;
  }

  String? _validateField(AttendeeFieldDefinition field, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return field.required ? '"${field.label}" wajib diisi.' : null;
    }
    if (field.isEmail &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Format email tidak valid.';
    }
    if (field.isNumber && num.tryParse(value) == null) {
      return '"${field.label}" harus berupa angka.';
    }
    if (field.isDate && DateTime.tryParse(value) == null) {
      return '"${field.label}" harus berupa tanggal (YYYY-MM-DD).';
    }
    return null;
  }

  List<Widget> _buildAttendeeForms(EventModel event) {
    final fields = <Widget>[];
    for (final field in event.resolvedAttendeeFields) {
      if (field.isCheckbox) {
        fields.add(
          CheckboxListTile(
            key: Key('attendee-field-${field.key}'),
            contentPadding: EdgeInsets.zero,
            value: _checkboxValues[field.key] ?? false,
            onChanged: (checked) => setState(
              () => _checkboxValues[field.key] = checked ?? false,
            ),
            title: Text(field.required ? '${field.label} *' : field.label),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
        continue;
      }
      if (field.isSelect) {
        final current = _selectValues[field.key];
        fields.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              key: Key('attendee-field-${field.key}'),
              initialValue: field.options.contains(current) ? current : null,
              decoration: InputDecoration(
                labelText: field.required ? '${field.label} *' : field.label,
              ),
              items: field.options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _selectValues[field.key] = value ?? ''),
              validator: (value) =>
                  field.required && (value == null || value.trim().isEmpty)
                  ? '"${field.label}" wajib dipilih.'
                  : null,
            ),
          ),
        );
        continue;
      }
      fields.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            key: Key('attendee-field-${field.key}'),
            controller: _controllers.putIfAbsent(
              field.key,
              TextEditingController.new,
            ),
            maxLines: field.isMultiline ? 3 : 1,
            keyboardType: field.isNumber
                ? TextInputType.number
                : field.isEmail
                ? TextInputType.emailAddress
                : field.isPhone
                ? TextInputType.phone
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: field.required ? '${field.label} *' : field.label,
              hintText: field.isDate ? 'YYYY-MM-DD' : null,
            ),
            validator: (value) => _validateField(field, value),
          ),
        ),
      );
    }
    return fields;
  }

  @override
  void initState() {
    super.initState();
    _loadEvent(widget.event?.id ?? widget.eventId ?? '');
  }

  Future<void> _loadEvent(String eventId) async {
    if (eventId.isEmpty) {
      setState(() {
        _isLoadingEvent = false;
        _loadError = 'ID event tidak tersedia.';
      });
      return;
    }

    await _eventProvider.loadEvent(eventId);
    if (mounted) {
      final event = _eventProvider.selectedEvent ?? widget.event;
      setState(() {
        _event = event;
        _ticketTypes = _eventProvider.ticketTypes;
        _loadError = _eventProvider.loadError ?? _eventProvider.error;
        _isLoadingEvent = false;
        if (event != null) _prepareFieldState(event);
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TicketTypeModel? get _selectedTicketType {
    if (_selectedTicketTypeId == null) return null;
    for (final type in _ticketTypes) {
      if (type.id == _selectedTicketTypeId) return type;
    }
    return null;
  }

  double get _subtotalAmount => _selectedTicketType?.price ?? 0;

  String _formatCurrency(double amount) {
    if (amount <= 0) return 'Gratis';
    final str = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  void _selectTicket(TicketTypeModel type) {
    if (!type.isSellableAt(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kategori "${type.name}" sedang tidak dapat dipesan (habis atau di '
            'luar periode penjualan).',
          ),
        ),
      );
      return;
    }
    // Satu order = satu kategori = satu tiket (PRD §7).
    setState(() => _selectedTicketTypeId = type.id);
  }

  Future<void> _submitOrder() async {
    final event = _event;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail event belum tersedia.')),
      );
      return;
    }

    final ticketType = _selectedTicketType;
    if (ticketType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemesanan harus berisi tepat 1 tiket.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final answers = _collectAnswers(event);
    final name = (answers['name'] ?? '').toString();
    final email = (answers['email'] ?? '').toString();
    final phone = (answers['phone'] ?? '').toString();
    final customFields = <String, dynamic>{
      for (final entry in answers.entries)
        if (entry.key != 'name' && entry.key != 'email' && entry.key != 'phone')
          entry.key: entry.value,
    };

    final newOrder = await OrderProvider.instance.createOrder(
      eventId: event.id,
      selectedTicketQuantities: <String, int>{ticketType.id: 1},
      attendees: <Map<String, dynamic>>[
        <String, dynamic>{
          'ticket_type_id': ticketType.id,
          'name': name,
          'email': email,
          if (phone.isNotEmpty) 'phone': phone,
          if (customFields.isNotEmpty) 'custom_fields': customFields,
        },
      ],
      idempotencyKey: _idempotencyKey,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (newOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            OrderProvider.instance.error ?? 'Gagal membuat pesanan.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Order gratis langsung PAID dan tiketnya terbit tanpa pembayaran.
    if (newOrder.isPaid || newOrder.grandTotal <= 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TicketListScreen(orderId: newOrder.id),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => PaymentScreen(orderId: newOrder.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEvent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemesanan Tiket')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final event = _event;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemesanan Tiket')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError ?? 'Event tidak ditemukan.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      _loadEvent(widget.event?.id ?? widget.eventId ?? ''),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pemesanan Tiket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Banner Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event,
                      color: AppTheme.primaryColor,
                      size: 36,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.location ?? (event.onlineUrl ?? 'Online'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: pilih tepat satu kategori tiket (PRD §7).
              const Text(
                '1. Pilih Kategori Tiket',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Satu pendaftaran hanya untuk satu tiket dan satu peserta.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),

              if (_ticketTypes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Belum ada kategori tiket yang dapat dipesan.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._ticketTypes.map((tt) {
                  final available = tt.isSellableAt(DateTime.now());
                  final selected = _selectedTicketTypeId == tt.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      key: Key('ticket-option-${tt.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: available ? () => _selectTicket(tt) : null,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: available
                              ? Colors.white
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryColor
                                : Colors.grey.shade300,
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: available
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tt.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: available
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    available
                                        ? 'Sisa kuota: ${tt.remainingQuota}'
                                        : 'Tidak tersedia',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: available
                                          ? Colors.grey.shade600
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(tt.price),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: available
                                    ? AppTheme.primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // Section 2: Attendee Info Form (No mandatory account PRD FR-04)
              const Text(
                '2. Data Peserta (Tanpa Wajib Akun)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Isi data setiap peserta. E-ticket akan dikirim ke alamat email masing-masing.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),

              if (_selectedTicketType == null)
                const Text('Pilih kategori tiket untuk menambahkan data peserta.')
              else
                ..._buildAttendeeForms(event),

              const SizedBox(height: 24),

              // Section 3: Order Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Biaya',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jumlah Tiket (${_selectedTicketType == null ? 0 : 1} tiket)',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        Text(_formatCurrency(_subtotalAmount)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Biaya layanan dan total final dihitung oleh server pada '
                      'langkah pembayaran.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _subtotalAmount <= 0
                              ? 'Daftar Sekarang (Gratis)'
                              : 'Lanjut ke Pembayaran',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
