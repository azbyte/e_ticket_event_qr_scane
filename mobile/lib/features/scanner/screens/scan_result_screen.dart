/// Scan result screen — verification result and status details (PRD sections 4.5, 6.3).
library;

import 'package:flutter/material.dart';

import '../../check_in/screens/check_in_history_screen.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({
    super.key,
    required this.result,
  });

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final status = result['status'] as String? ?? 'invalid';
    final isAlreadyUsed = status == 'already_checked_in';
    final isOffline = status == 'queued_offline' || result['is_offline'] == true;

    Color headerColor;
    IconData headerIcon;
    String statusTitle;
    String statusSubtitle;

    if (status == 'valid') {
      headerColor = Colors.green;
      headerIcon = Icons.check_circle_outline;
      statusTitle = 'CHECK-IN BERHASIL';
      statusSubtitle = 'Tiket valid dan kehadiran berhasil diverifikasi.';
    } else if (status == 'queued_offline') {
      headerColor = Colors.blue;
      headerIcon = Icons.cloud_queue;
      statusTitle = 'TERSINKRON OFFLINE';
      statusSubtitle = 'Check-in disimpan secara lokal. Sinkronkan ketika online.';
    } else if (isAlreadyUsed) {
      headerColor = Colors.amber.shade800;
      headerIcon = Icons.warning_amber_rounded;
      statusTitle = 'TIKET SUDAH DIGUNAKAN';
      statusSubtitle = 'Pencegahan Check-in Ganda: Tiket ini telah dipakai sebelumnya.';
    } else {
      headerColor = Colors.red;
      headerIcon = Icons.cancel_outlined;
      statusTitle = 'TIKET TIDAK VALID';
      statusSubtitle = result['message'] as String? ?? 'Barcode atau kode tiket tidak dikenali.';
    }

    final ticketData = (result['ticket'] as Map<String, dynamic>?) ?? {};
    final attendeeName = ticketData['attendee_name'] as String? ?? 'Tidak diketahui';
    final attendeeEmail = ticketData['attendee_email'] as String? ?? '-';
    final ticketCode = ticketData['token'] as String? ?? ticketData['id'] as String? ?? '-';
    final ticketType = ticketData['ticket_type'] as String? ?? 'General Admission';
    final eventTitle = ticketData['event_title'] as String? ?? 'Tech Innovation Summit 2026';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pemindaian'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: headerColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: headerColor, width: 2),
              ),
              child: Column(
                children: [
                  Icon(headerIcon, size: 72, color: headerColor),
                  const SizedBox(height: 12),
                  Text(
                    statusTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ticket Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Tiket & Peserta',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Divider(height: 24),
                    _buildDetailRow('Kode Tiket', ticketCode, isCode: true),
                    const SizedBox(height: 12),
                    _buildDetailRow('Nama Peserta', attendeeName),
                    const SizedBox(height: 12),
                    _buildDetailRow('Email Kontak', attendeeEmail),
                    const SizedBox(height: 12),
                    _buildDetailRow('Kategori Tiket', ticketType),
                    const SizedBox(height: 12),
                    _buildDetailRow('Nama Event', eventTitle),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Waktu Scan',
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} WIB',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Mode Sinkronisasi',
                      isOffline ? 'Tersimpan Offline' : 'Online Real-time',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Pindai Tiket Berikutnya',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.pop(context),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.history),
              label: const Text('Buka Riwayat Check-in'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckInHistoryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCode = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: isCode ? 'monospace' : null,
              color: isCode ? Colors.blue.shade900 : null,
            ),
          ),
        ),
      ],
    );
  }
}
