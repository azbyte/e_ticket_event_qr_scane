/// QR code display widget for e-ticket (PRD sections 4.6, FR-35, FR-36).
///
/// Stub fondasi. Requires package `qr_flutter` added to pubspec.yaml (PRD 8.1).
/// QR data must not contain passwords, payment info, or full personal data (FR-36).
import 'package:flutter/material.dart';

class QrTicketDisplay extends StatelessWidget {
  const QrTicketDisplay({super.key, required this.ticketData});

  final String ticketData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.qr_code, size: 120, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'QR Code tiket akan ditampilkan di sini.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Stub fondasi — paket qr_flutter belum ditambahkan ke pubspec.yaml.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
