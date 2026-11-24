import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as core;
import '../../../models/event/attendee_field_definition.dart';
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/order_provider.dart';
import '../../../services/public_event/public_event_service.dart';
import '../../organizer/events/widgets/organizer_summary_widgets.dart';
import '../../payments/screens/payment_screen.dart';
import '../../tickets/screens/ticket_list_screen.dart';

/// Registrasi guest satu tiket tanpa akun (PRD §7, AC-04; D1-4).
class PublicRegistrationScreen extends StatefulWidget {
  const PublicRegistrationScreen({
    super.key,
    required this.eventId,
    this.service,
    this.orderProvider,
  });

  final String eventId;

  /// Dapat diganti pada test untuk state loading/error tanpa HTTP.
  final PublicEventService? service;

  /// Dapat diganti pada test; default memakai provider aplikasi.
  final OrderProvider? orderProvider;

  @override
  State<PublicRegistrationScreen> createState() =>
      _PublicRegistrationScreenState();
}

enum _RegistrationStatus { loading, ready, unavailable, error }

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen> {
  late final PublicEventService _service =
      widget.service ?? PublicEventService();
  late final OrderProvider _orderProvider =
      widget.orderProvider ?? OrderProvider.instance;

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, bool> _checkboxValues = <String, bool>{};
  final Map<String, String> _selectValues = <String, String>{};
  final String _idempotencyKey = _newIdempotencyKey();

  _RegistrationStatus _status = _RegistrationStatus.loading;
  PublicEventData? _data;
  String? _message;
  String? _selectedTicketTypeId;
  bool _isSubmitting = false;

  static String _newIdempotencyKey() {
    final random = Random.secure();
    return List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = _RegistrationStatus.loading;
      _message = null;
    });
    try {
      final data = await _service.loadEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = _RegistrationStatus.ready;
        _prepareFieldState(data.event);
      });
    } on PublicEventUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _status = _RegistrationStatus.unavailable;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString();
        _status = _RegistrationStatus.error;
      });
    }
  }

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

  String _priceLabel(double value) =>
      value <= 0 ? 'Gratis' : OrganizerFormatters.rupiah(value);

  TicketTypeModel? get _selectedTicketType {
    final data = _data;
    if (data == null || _selectedTicketTypeId == null) return null;
    for (final type in data.ticketTypes) {
      if (type.id == _selectedTicketTypeId) return type;
    }
    return null;
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

  Future<void> _submit() async {
    final data = _data;
    final ticketType = _selectedTicketType;
    if (data == null || ticketType == null) {
      _showMessage('Pilih satu kategori tiket terlebih dahulu.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Periksa kembali data peserta.');
      return;
    }

    final event = data.event;
    final answers = _collectAnswers(event);
    final name = (answers['name'] ?? '').toString();
    final email = (answers['email'] ?? '').toString();
    final phone = (answers['phone'] ?? '').toString();
    final customFields = <String, dynamic>{
      for (final entry in answers.entries)
        if (entry.key != 'name' && entry.key != 'email' && entry.key != 'phone')
          entry.key: entry.value,
    };

    setState(() => _isSubmitting = true);
    final order = await _orderProvider.createOrder(
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
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (order == null) {
      _showMessage(
        _orderProvider.error ?? 'Gagal membuat pesanan. Silakan coba lagi.',
      );
      return;
    }

    // Order gratis sudah PAID dan tiketnya terbit langsung (PRD §8).
    if (order.isPaid || order.grandTotal <= 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TicketListScreen(orderId: order.id),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => PaymentScreen(orderId: order.id)),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran Peserta')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _RegistrationStatus.loading:
        return const Center(
          key: Key('public-registration-loading'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat formulir pendaftaran...'),
            ],
          ),
        );
      case _RegistrationStatus.unavailable:
        return _buildMessageState(
          key: const Key('public-registration-unavailable'),
          icon: Icons.event_busy_outlined,
          title: 'Pendaftaran tidak tersedia',
          message: _message ?? 'Event belum dipublikasikan.',
        );
      case _RegistrationStatus.error:
        return _buildMessageState(
          key: const Key('public-registration-error'),
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat formulir',
          message: _message ?? 'Periksa koneksi lalu coba lagi.',
          color: AppTheme.errorColor,
        );
      case _RegistrationStatus.ready:
        return _buildForm(_data!);
    }
  }

  Widget _buildMessageState({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    Color? color,
  }) => Center(
    key: key,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 64, color: color ?? Colors.grey.shade500),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
        ],
      ),
    ),
  );


  Widget _buildForm(PublicEventData data) {
    final event = data.event;
    final now = DateTime.now();
    final selected = _selectedTicketType;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              _eventHeader(event),
              const SizedBox(height: 20),
              _sectionTitle('1. Pilih kategori tiket'),
              const SizedBox(height: 6),
              Text(
                'Satu pendaftaran hanya untuk satu tiket dan satu peserta.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              if (data.ticketTypes.isEmpty)
                Container(
                  key: const Key('public-registration-empty-tickets'),
                  padding: const EdgeInsets.all(18),
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
                ...data.ticketTypes.map((type) => _ticketOption(type, now)),
              const SizedBox(height: 20),
              _sectionTitle('2. Data peserta'),
              const SizedBox(height: 6),
              Text(
                'Tidak perlu akun. E-ticket dikirim ke email yang diisi.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              ...event.resolvedAttendeeFields.map(_buildField),
              const SizedBox(height: 20),
              _sectionTitle('3. Ringkasan biaya'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          selected?.name ?? 'Belum memilih tiket',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        Text(_priceLabel(selected?.price ?? 0)),
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
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  key: const Key('public-registration-submit'),
                  onPressed: _isSubmitting ? null : _submit,
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
                          selected != null && selected.price <= 0
                              ? 'Daftar Sekarang (Gratis)'
                              : 'Lanjut ke Pembayaran',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _eventHeader(EventModel event) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.event, color: AppTheme.primaryColor, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                core.DateUtils.formatDateTime(event.startDateTime),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                event.location ?? event.onlineUrl ?? 'Online',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
  );

  Widget _ticketOption(TicketTypeModel type, DateTime now) {
    final available = type.isSellableAt(now);
    final selected = _selectedTicketTypeId == type.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: Key('public-registration-ticket-${type.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: available
            ? () => setState(() => _selectedTicketTypeId = type.id)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: available ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
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
                  children: <Widget>[
                    Text(
                      type.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: available ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? 'Sisa kuota: ${type.remainingQuota}'
                          : 'Tidak tersedia',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: available ? Colors.grey.shade600 : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _priceLabel(type.price),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: available ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(AttendeeFieldDefinition field) {
    if (field.isCheckbox) {
      return CheckboxListTile(
        key: Key('public-registration-field-${field.key}'),
        contentPadding: EdgeInsets.zero,
        value: _checkboxValues[field.key] ?? false,
        onChanged: (checked) =>
            setState(() => _checkboxValues[field.key] = checked ?? false),
        title: Text(field.required ? '${field.label} *' : field.label),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }
    if (field.isSelect) {
      final current = _selectValues[field.key];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: Key('public-registration-field-${field.key}'),
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
      );
    }

    final controller = _controllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: Key('public-registration-field-${field.key}'),
        controller: controller,
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
    );
  }
}

