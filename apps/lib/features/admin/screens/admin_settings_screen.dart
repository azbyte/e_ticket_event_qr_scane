/// Admin platform settings management screen (PRD Section 6.10, FR-102, FR-103).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin/admin_settings_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin/admin_settings_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AdminSettingsService _settingsService = AdminSettingsService.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _commCtrl;
  late TextEditingController _fixedFeeCtrl;
  late TextEditingController _timeoutCtrl;
  late TextEditingController _refundCtrl;

  PlatformSettingsModel? _currentSettings;
  List<FeeChangeHistoryEntry> _feeHistory = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _commCtrl.dispose();
    _fixedFeeCtrl.dispose();
    _timeoutCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final settings = await _settingsService.getSettings();
      final history = await _settingsService.getFeeHistory();

      _nameCtrl = TextEditingController(text: settings.platformName);
      _emailCtrl = TextEditingController(text: settings.contactEmail);
      _phoneCtrl = TextEditingController(text: settings.contactPhone);
      _commCtrl = TextEditingController(text: settings.ticketCommissionRate.toString());
      _fixedFeeCtrl = TextEditingController(text: settings.fixedServiceFee.toInt().toString());
      _timeoutCtrl = TextEditingController(text: settings.orderPaymentTimeoutMinutes.toString());
      _refundCtrl = TextEditingController(text: settings.refundPolicySummary);

      if (!mounted) return;
      setState(() {
        _currentSettings = settings;
        _feeHistory = history;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is FormatException
            ? error.message
            : 'Gagal memuat pengaturan dari database.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _currentSettings == null) return;

    final newComm = double.tryParse(_commCtrl.text.trim()) ?? _currentSettings!.ticketCommissionRate;
    final newFixed = double.tryParse(_fixedFeeCtrl.text.trim()) ?? _currentSettings!.fixedServiceFee;

    final isFeeChanged = newComm != _currentSettings!.ticketCommissionRate ||
        newFixed != _currentSettings!.fixedServiceFee;

    if (isFeeChanged) {
      // Prompt for mandatory reason when fee changes (FR-103)
      final reasonCtrl = TextEditingController();
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konfirmasi Perubahan Tarif Komisi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perubahan komisi dari ${_currentSettings!.ticketCommissionRate}% menjadi $newComm% akan dicatat ke dalam riwayat pengaturan dan Audit Log (FR-103). Perubahan tidak berlaku surut untuk transaksi lama.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alasan Perubahan Biaya/Komisi *',
                  hintText: 'Misal: Penyesuaian kebijakan kuartal baru',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Simpan & Catat Log'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
      await _executeSave(reasonCtrl.text.trim());
    } else {
      await _executeSave(null);
    }
  }

  Future<void> _executeSave(String? feeChangeReason) async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final updated = _currentSettings!.copyWith(
      platformName: _nameCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim(),
      ticketCommissionRate: double.tryParse(_commCtrl.text.trim()) ?? _currentSettings!.ticketCommissionRate,
      fixedServiceFee: double.tryParse(_fixedFeeCtrl.text.trim()) ?? _currentSettings!.fixedServiceFee,
      orderPaymentTimeoutMinutes: int.tryParse(_timeoutCtrl.text.trim()) ?? _currentSettings!.orderPaymentTimeoutMinutes,
      refundPolicySummary: _refundCtrl.text.trim(),
    );

    try {
      await _settingsService.updateSettings(
        updated,
        actorId: auth.user?.id ?? '',
        actorName: auth.user?.name ?? 'Admin Platform',
        reason: feeChangeReason,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'Gagal menyimpan pengaturan ke database. Periksa koneksi backend.',
          ),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengaturan platform berhasil disimpan.')),
      );
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Platform'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 40, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pastikan backend berjalan dan terhubung ke database.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _loadSettings,
                          child: const Text('Muat ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // General Identity
                    _buildSectionHeader('Identitas & Kontak Platform', Icons.badge_outlined),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nama Platform *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email Kontak Resmi *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nomor Bantuan / WhatsApp *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Monetization & Fees (FR-102, FR-103)
                    _buildSectionHeader('Konfigurasi Tarif Komisi & Biaya (FR-103)', Icons.monetization_on_outlined),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sesuai keputusan produk C-01: Komisi platform (5%) dan biaya layanan tetap (Rp 5.000) bersifat tetap (read-only).',
                                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _commCtrl,
                                    readOnly: true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Komisi Tiket (%) [Read-Only]',
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _fixedFeeCtrl,
                                    readOnly: true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Biaya Layanan Tetap [Read-Only]',
                                      prefixText: 'Rp ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      filled: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _timeoutCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Batas Waktu Pembayaran Order (Menit)',
                                suffixText: 'menit',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Policy Summary
                    _buildSectionHeader('Kebijakan Pengembalian Dana (Refund)', Icons.policy_outlined),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _refundCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Ringkasan Kebijakan Refund',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Pengaturan'),
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                    const SizedBox(height: 28),

                    // Fee Adjustment History Section (FR-103)
                    _buildSectionHeader('Riwayat Penyesuaian Tarif Komisi (FR-103)', Icons.history),
                    if (_feeHistory.isEmpty)
                      const Text('Belum ada riwayat perubahan tarif.', style: TextStyle(color: Colors.grey))
                    else
                      ..._feeHistory.map(
                        (h) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              child: const Icon(Icons.trending_up, color: Colors.teal, size: 20),
                            ),
                            title: Text(
                              'Komisi: ${h.oldCommissionRate}% → ${h.newCommissionRate}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              '${h.reason}\nOleh: ${h.actorName} • ${h.timestamp.day}/${h.timestamp.month}/${h.timestamp.year}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: h.newFixedFee > 0
                                ? Text('Rp ${h.newFixedFee.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

