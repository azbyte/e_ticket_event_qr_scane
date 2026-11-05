/// Assisted registration screen for Organizer / Staff (PRD section 4.3 & FR-30–35).
///
/// Enables staff or organizer to register attendees directly, collecting orderer
/// and participant details, computing price, creating an ASSISTED order, and
/// displaying demo Virtual Account instructions without mocking false payment.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';

class AssistedRegistrationScreen extends StatefulWidget {
  const AssistedRegistrationScreen({
    super.key,
    required this.eventId,
    this.eventName = 'Tech Innovation Summit 2026',
    required this.contextScope,
  });

  final String eventId;
  final String eventName;
  final OrganizerMembershipContext contextScope;

  @override
  State<AssistedRegistrationScreen> createState() =>
      _AssistedRegistrationScreenState();
}

class _AssistedRegistrationScreenState
    extends State<AssistedRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ordererNameController = TextEditingController();
  final _ordererEmailController = TextEditingController();
  final _ordererPhoneController = TextEditingController();

  final List<Map<String, TextEditingController>> _attendeesControllers = [];

  String _selectedTicketType = 'Regular Pass';
  double _ticketPrice = 350000;
  bool _isSubmitting = false;
  AssistedRegistrationResult? _result;

  final Map<String, double> _ticketTiers = {
    'VIP Pass': 750000,
    'Regular Pass': 350000,
    'Early Bird': 250000,
  };

  @override
  void initState() {
    super.initState();
    _addAttendeeField(); // Start with 1 participant by default
  }

  @override
  void dispose() {
    _ordererNameController.dispose();
    _ordererEmailController.dispose();
    _ordererPhoneController.dispose();
    for (final map in _attendeesControllers) {
      map['name']?.dispose();
      map['email']?.dispose();
      map['phone']?.dispose();
    }
    super.dispose();
  }

  void _addAttendeeField() {
    if (_attendeesControllers.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 tiket dalam 1 pesanan.')),
      );
      return;
    }
    setState(() {
      _attendeesControllers.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeAttendeeField(int index) {
    if (_attendeesControllers.length <= 1) return;
    setState(() {
      final removed = _attendeesControllers.removeAt(index);
      removed['name']?.dispose();
      removed['email']?.dispose();
      removed['phone']?.dispose();
    });
  }

  void _handleSubmit() {
    if (!widget.contextScope.hasPermission(OrganizerPermission.assistRegistration)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Anda tidak memiliki izin ASSIST_REGISTRATION.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final attendeeDetails = _attendeesControllers.map((c) {
      return {
        'name': c['name']!.text.trim(),
        'email': c['email']!.text.trim(),
        'phone': c['phone']!.text.trim(),
      };
    }).toList();

    final result = OrganizerOperationsRepository.instance.createAssistedRegistration(
      eventId: widget.eventId,
      ordererName: _ordererNameController.text.trim(),
      ordererEmail: _ordererEmailController.text.trim(),
      ordererPhone: _ordererPhoneController.text.trim(),
      ticketType: _selectedTicketType,
      unitPrice: _ticketPrice,
      attendeeDetails: attendeeDetails,
      actorId: widget.contextScope.userId,
      actorName: widget.contextScope.userName,
    );

    setState(() {
      _isSubmitting = false;
      _result = result;
    });

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $str';
  }

  @override
  Widget build(BuildContext context) {
    final hasPermission =
        widget.contextScope.hasPermission(OrganizerPermission.assistRegistration);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Dibantu'),
      ),
      body: !hasPermission
          ? _buildAccessDenied()
          : _result != null && _result!.isSuccess
              ? _buildSuccessView(_result!)
              : _buildFormView(),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Akses Tidak Diberikan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Akun staf Anda tidak memiliki izin "${OrganizerPermission.assistRegistration.code}". Hubungi Penyelenggara untuk meminta hak akses ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final count = _attendeesControllers.length;
    final subtotal = _ticketPrice * count;
    final adminFee = 4500.0;
    final grandTotal = subtotal + adminFee;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attribution Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pendaftar: ${widget.contextScope.userName} (${widget.contextScope.role.toUpperCase()})\nEvent: ${widget.eventName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Orderer Info
            const Text(
              'Informasi Pemesan / Kontak Utama',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordererNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Pemesan *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pemesan wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordererEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Pemesan *',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email pemesan wajib diisi';
                if (!v.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordererPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP *',
                prefixIcon: Icon(Icons.phone),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor HP wajib diisi' : null,
            ),
            const SizedBox(height: 24),

            // Ticket Category Selection
            const Text(
              'Kategori Tiket',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTicketType,
              items: _ticketTiers.keys.map((tier) {
                return DropdownMenuItem(
                  value: tier,
                  child: Text('$tier (${_formatCurrency(_ticketTiers[tier]!)})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedTicketType = val;
                    _ticketPrice = _ticketTiers[val]!;
                  });
                }
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
            const SizedBox(height: 24),

            // Attendees List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data Peserta ($count Orang)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: count < 5 ? _addAttendeeField : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Peserta'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(count, (index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Peserta #${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (count > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removeAttendeeField(index),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _attendeesControllers[index]['name'],
                        decoration: const InputDecoration(labelText: 'Nama Peserta *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama peserta wajib' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _attendeesControllers[index]['email'],
                        decoration: const InputDecoration(labelText: 'Email Peserta *'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email peserta wajib';
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Price Calculation Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_selectedTicketType ($count x ${_formatCurrency(_ticketPrice)})'),
                      Text(_formatCurrency(subtotal)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Biaya Layanan Admin'),
                      Text(_formatCurrency(adminFee)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_formatCurrency(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Buat Pesanan & Terbitkan VA Demo', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(AssistedRegistrationResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 72),
          const SizedBox(height: 16),
          const Text(
            'Registrasi Dibantu Berhasil Dibuat!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesanan ${result.orderReference} tercatat dengan metode ASSISTED.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),

          // VA Demo Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(result.vaBank ?? 'BCA Virtual Account', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('MENUNGGU PEMBAYARAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Nomor Virtual Account Demo:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  result.vaNumber ?? '880012345678',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tagihan:'),
                    Text(_formatCurrency(result.totalAmount ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Batas waktu pembayaran: 24 Jam (s/d ${result.vaExpiry?.hour}:${result.vaExpiry?.minute.toString().padLeft(2, '0')} WIB)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info Note
          const Text(
            'Catatan: Sesuai aturan PRD (FR-30–35), status pembayaran tetap "pending" sampai peserta menyelesaikan transaksi melalui simulasi atau konfirmasi resmi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Selesai & Kembali ke Daftar Peserta'),
          ),
        ],
      ),
    );
  }
}
