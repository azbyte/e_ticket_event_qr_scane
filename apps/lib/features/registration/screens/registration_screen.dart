import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validators/input_validator.dart';
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/event_provider.dart';
import '../../payments/screens/payment_screen.dart';

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
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _emailControllers = {};
  final Map<String, TextEditingController> _phoneControllers = {};

  final Map<String, int> _selectedQuantities = {};
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

  String _attendeeKey(String ticketTypeId, int index) => '$ticketTypeId:$index';

  void _syncAttendeeControllers() {
    final activeKeys = <String>{};
    for (final entry in _selectedQuantities.entries) {
      for (var index = 0; index < entry.value; index++) {
        final key = _attendeeKey(entry.key, index);
        activeKeys.add(key);
        _nameControllers.putIfAbsent(key, TextEditingController.new);
        _emailControllers.putIfAbsent(key, TextEditingController.new);
        _phoneControllers.putIfAbsent(key, TextEditingController.new);
      }
    }

    for (final controllers in [
      _nameControllers,
      _emailControllers,
      _phoneControllers,
    ]) {
      final removedKeys = controllers.keys
          .where((key) => !activeKeys.contains(key))
          .toList();
      for (final key in removedKeys) {
        controllers.remove(key)?.dispose();
      }
    }
  }

  List<Map<String, String>> _attendeePayload() {
    final attendees = <Map<String, String>>[];
    for (final ticketType in _ticketTypes) {
      final quantity = _selectedQuantities[ticketType.id] ?? 0;
      for (var index = 0; index < quantity; index++) {
        final key = _attendeeKey(ticketType.id, index);
        attendees.add({
          'ticket_type_id': ticketType.id,
          'name': _nameControllers[key]!.text.trim(),
          'email': _emailControllers[key]!.text.trim(),
          if (_phoneControllers[key]!.text.trim().isNotEmpty)
            'phone': _phoneControllers[key]!.text.trim(),
        });
      }
    }
    return attendees;
  }

  List<Widget> _buildAttendeeForms() {
    final fields = <Widget>[];
    for (final ticketType in _ticketTypes) {
      final quantity = _selectedQuantities[ticketType.id] ?? 0;
      for (var index = 0; index < quantity; index++) {
        final key = _attendeeKey(ticketType.id, index);
        fields.addAll([
          Text(
            '${ticketType.name} - Peserta ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('attendee-name-$key'),
            controller: _nameControllers[key],
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) =>
                InputValidator.required(value, field: 'Nama peserta'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('attendee-email-$key'),
            controller: _emailControllers[key],
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Alamat Email Aktif *',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: InputValidator.email,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('attendee-phone-$key'),
            controller: _phoneControllers[key],
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor WhatsApp / HP (Opsional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 18),
        ]);
      }
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
      setState(() {
        _event = _eventProvider.selectedEvent ?? widget.event;
        _ticketTypes = _eventProvider.ticketTypes;
        _loadError = _eventProvider.loadError ?? _eventProvider.error;
        _isLoadingEvent = false;
        for (final tt in _ticketTypes) {
          _selectedQuantities[tt.id] = 0;
        }
        _syncAttendeeControllers();
      });
    }
  }

  @override
  void dispose() {
    for (final controllers in [
      _nameControllers,
      _emailControllers,
      _phoneControllers,
    ]) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  int get _totalTicketCount =>
      _selectedQuantities.values.fold(0, (sum, q) => sum + q);

  double get _subtotalAmount {
    double total = 0;
    for (final tt in _ticketTypes) {
      final qty = _selectedQuantities[tt.id] ?? 0;
      total += tt.price * qty;
    }
    return total;
  }

  double get _serviceFee => _subtotalAmount > 0 ? 5000.0 : 0.0;
  double get _grandTotal => _subtotalAmount + _serviceFee;

  String _formatCurrency(double amount) {
    if (amount <= 0) return 'Gratis';
    final str = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }

  void _updateQuantity(String ticketTypeId, int delta) {
    final current = _selectedQuantities[ticketTypeId] ?? 0;
    final newQty = current + delta;
    if (newQty < 0) return;

    final tt = _ticketTypes.firstWhere((t) => t.id == ticketTypeId);
    if (newQty > tt.availableQuota) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sisa kuota untuk "${tt.name}" hanya ${tt.availableQuota} tiket.',
          ),
        ),
      );
      return;
    }

    if (delta > 0 && _totalTicketCount >= AppConstants.maxTicketsPerOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maksimal ${AppConstants.maxTicketsPerOrder} tiket per pesanan.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedQuantities[ticketTypeId] = newQty;
      _syncAttendeeControllers();
    });
  }

  Future<void> _submitOrder() async {
    final event = _event;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail event belum tersedia.')),
      );
      return;
    }

    if (_totalTicketCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih minimal 1 tiket untuk melanjutkan.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final newOrder = await OrderProvider.instance.createOrder(
      eventId: event.id,
      selectedTicketQuantities: _selectedQuantities,
      attendees: _attendeePayload(),
      idempotencyKey: _idempotencyKey,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (newOrder != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentScreen(orderId: newOrder.id)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            OrderProvider.instance.error ?? 'Gagal membuat pesanan.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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

              // Section 1: Choose Tickets
              const Text(
                '1. Pilih Jenis & Jumlah Tiket',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_ticketTypes.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ..._ticketTypes.map((tt) {
                  final qty = _selectedQuantities[tt.id] ?? 0;
                  final isSoldOut = tt.isSoldOut;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSoldOut ? Colors.grey.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: qty > 0
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: qty > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tt.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSoldOut
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatCurrency(tt.price),
                                style: TextStyle(
                                  color: isSoldOut
                                      ? Colors.grey
                                      : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                isSoldOut
                                    ? 'Habis terjual'
                                    : 'Sisa kuota: ${tt.availableQuota}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSoldOut
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSoldOut)
                          const Text(
                            'HABIS',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          )
                        else
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: qty > 0
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade400,
                                onPressed: qty > 0
                                    ? () => _updateQuantity(tt.id, -1)
                                    : null,
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppTheme.primaryColor,
                                onPressed: () => _updateQuantity(tt.id, 1),
                              ),
                            ],
                          ),
                      ],
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

              if (_totalTicketCount == 0)
                const Text('Pilih tiket untuk menambahkan data peserta.')
              else
                ..._buildAttendeeForms(),

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
                          'Jumlah Tiket ($_totalTicketCount tiket)',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        Text(_formatCurrency(_subtotalAmount)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Biaya Layanan & Admin',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        Text(_formatCurrency(_serviceFee)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatCurrency(_grandTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
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
                          _grandTotal == 0
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
