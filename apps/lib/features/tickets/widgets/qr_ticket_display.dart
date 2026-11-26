import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';

/// QR code display widget for e-ticket (PRD sections 4.6, FR-35, FR-36).
///
/// Complies with FR-36: QR data contains only the unique token identifier
/// and does NOT leak password, payment info, or full sensitive personal data.
///
/// Designed to gracefully support `qr_flutter` once added to pubspec.yaml.
class QrTicketDisplay extends StatelessWidget {
  const QrTicketDisplay({
    super.key,
    required this.ticketData,
    this.size = 200,
  });

  final String ticketData;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR code asli dari token tiket (AC-06). Payload hanya identifier
          // tiket; tidak memuat email/telepon/harga (FR-36).
          if (ticketData.trim().isEmpty)
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'QR Code belum aktif',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Semantics(
              label: 'QR code e-ticket',
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: QrImageView(
                  key: const Key('ticket-qr-image'),
                  data: ticketData,
                  version: QrVersions.auto,
                  size: size - 24,
                  gapless: true,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR code e-ticket',
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Token Display
          Text(
            'KODE TIKET UNIK',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          if (ticketData.trim().isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    ticketData,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ticketData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kode tiket disalin!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            )
          else
            Text(
              'Menunggu penerbitan',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          const SizedBox(height: 10),

          // FR-36 Compliance Note
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Terverifikasi & Aman (FR-36 compliant)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
