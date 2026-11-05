import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validators/input_validator.dart';
import '../../../models/event/event_model.dart';
import '../../../models/event/ticket_type_model.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/order_provider.dart';
import '../../payments/screens/payment_screen.dart';

/// Registration screen — choose ticket types & quantity + attendee info (PRD sections 3.1 #5,#6, 4.4, 7.2 D).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    this.event,
    this.eventId,
  });

  final EventModel? event;
  final String? eventId;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final Map<String, int> _selectedQuantities = {};
  bool _isSubmitting = false;

  late EventModel _event;
  List<TicketTypeModel> _ticketTypes = [];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event!;
      _loadTicketTypes(_event.id);
    } else {
      final id = widget.eventId ?? 'evt-001';
      final found = EventProvider.instance.events.firstWhere(
        (e) => e.id == id,
        orElse: () => EventProvider.instance.selectedEvent ?? _buildFallbackEvent(id),
      );
      _event = found;
      _loadTicketTypes(_event.id);
    }
  }

  void _loadTicketTypes(String eventId) async {
    await EventProvider.instance.loadTicketTypes(eventId);
    if (mounted) {
      setState(() {
        _ticketTypes = EventProvider.instance.ticketTypes;
        for (final tt in _ticketTypes) {
          _selectedQuantities[tt.id] = 0;
        }
      });
    }
  }

  EventModel _buildFallbackEvent(String id) {
    return EventModel(
      id: id,
      organizerId: 'org-001',
      title: 'Event Pilihan',
      startDateTime: DateTime.now().add(const Duration(days: 7)),
      endDateTime: DateTime.now().add(const Duration(days: 7, hours: 4)),
      eventType: 'offline',
      status: AppConstants.eventStatusPublished,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
        SnackBar(content: Text('Sisa kuota untuk "${tt.name}" hanya ${tt.availableQuota} tiket.')),
      );
      return;
    }

    if (delta > 0 && _totalTicketCount >= AppConstants.maxTicketsPerOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal ${AppConstants.maxTicketsPerOrder} tiket per pesanan.')),
      );
      return;
    }

    setState(() {
      _selectedQuantities[ticketTypeId] = newQty;
    });
  }

  Future<void> _submitOrder() async {
    if (_totalTicketCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih minimal 1 tiket untuk melanjutkan.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final newOrder = await OrderProvider.instance.createOrder(
      eventId: _event.id,
      attendeeName: _nameController.text.trim(),
      attendeeEmail: _emailController.text.trim(),
      attendeePhone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      selectedTicketQuantities: _selectedQuantities,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (newOrder != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(orderId: newOrder.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(OrderProvider.instance.error ?? 'Gagal membuat pesanan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemesanan Tiket'),
      ),
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
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: AppTheme.primaryColor, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _event.location ?? (_event.onlineUrl ?? 'Online'),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                        color: qty > 0 ? AppTheme.primaryColor : Colors.grey.shade300,
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
                                  color: isSoldOut ? Colors.grey : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatCurrency(tt.price),
                                style: TextStyle(
                                  color: isSoldOut ? Colors.grey : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                isSoldOut ? 'Habis terjual' : 'Sisa kuota: ${tt.availableQuota}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSoldOut ? Colors.red : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSoldOut)
                          const Text(
                            'HABIS',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                          )
                        else
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: qty > 0 ? AppTheme.primaryColor : Colors.grey.shade400,
                                onPressed: qty > 0 ? () => _updateQuantity(tt.id, -1) : null,
                              ),
                              Text(
                                '$qty',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                'Tiket elektronik akan dikirimkan langsung ke alamat email ini.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  hintText: 'Misal: Budi Santoso',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => InputValidator.required(val, field: 'Nama lengkap'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Alamat Email Aktif *',
                  hintText: 'budi@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: InputValidator.email,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp / HP (Opsional)',
                  hintText: '081234567890',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jumlah Tiket ($_totalTicketCount tiket)', style: TextStyle(color: Colors.grey.shade700)),
                        Text(_formatCurrency(_subtotalAmount)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Biaya Layanan & Admin', style: TextStyle(color: Colors.grey.shade700)),
                        Text(_formatCurrency(_serviceFee)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pembayaran',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _grandTotal == 0 ? 'Daftar Sekarang (Gratis)' : 'Lanjut ke Pembayaran',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
