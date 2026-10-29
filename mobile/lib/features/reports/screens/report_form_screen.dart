/// Support report form screen (attendee) — PRD sections 4.10, 7.2 G.
///
/// Submits user issues regarding ticket delivery, payment confirmation,
/// check-in troubles, and guest data corrections.
library;

import 'package:flutter/material.dart';

import '../../../core/validators/input_validator.dart';
import '../../../providers/report_provider.dart';
import 'report_status_screen.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({
    super.key,
    this.reportProvider,
    this.initialOrderReference,
  });

  final ReportProvider? reportProvider;
  final String? initialOrderReference;

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ReportProvider _provider;

  late final TextEditingController _emailController;
  late final TextEditingController _orderRefController;
  late final TextEditingController _descController;

  String _category = 'Pembayaran';

  @override
  void initState() {
    super.initState();
    _provider = widget.reportProvider ?? ReportProvider();
    _emailController = TextEditingController();
    _orderRefController = TextEditingController(text: widget.initialOrderReference ?? '');
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _orderRefController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final created = await _provider.createReport(
      contactEmail: _emailController.text.trim(),
      category: _category,
      description: _descController.text.trim(),
      orderReference: _orderRefController.text.trim(),
    );

    if (!mounted || created == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Laporan Terkirim'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Laporan kendala Anda telah diterima oleh tim admin support.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nomor Tiket Laporan: ${created.ticketNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Simpan nomor ini untuk melacak status penanganan kendala.',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportStatusScreen(ticketNumber: created.ticketNumber),
                ),
              );
            },
            child: const Text('Lacak Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporkan Kendala Acara'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.indigo),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tim bantuan siap membantu masalah pembayaran, kegagalan check-in tiket, atau koreksi data pendaftaran.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Kontak Aktif *',
                  hintText: 'nama@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: InputValidator.email,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _orderRefController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Referensi Pesanan / Tiket (Opsional)',
                  hintText: 'Contoh: ORD-2026-9901 atau TK-TECH-001',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Kategori Kendala *',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Pembayaran', child: Text('Kendala Pembayaran / Konfirmasi')),
                  DropdownMenuItem(value: 'E-Tiket & QR', child: Text('E-Tiket & Kode QR Tidak Terbaca')),
                  DropdownMenuItem(value: 'Check-in Lapangan', child: Text('Gagal Check-in di Gerbang')),
                  DropdownMenuItem(value: 'Data Peserta', child: Text('Perubahan Data Peserta / Salah Ketik')),
                  DropdownMenuItem(value: 'Lainnya', child: Text('Pertanyaan Umum / Lainnya')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Kendala Secara Detail *',
                  hintText: 'Jelaskan kronologi kendala yang dialami dengan sejelas mungkin...',
                  border: OutlineInputBorder(),
                ),
                validator: InputValidator.required,
              ),

              const SizedBox(height: 28),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send),
                label: const Text(
                  'Kirim Laporan Bantuan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _submitReport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
