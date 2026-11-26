import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR pendaftaran peserta yang benar-benar dapat dipindai.
///
/// Isi QR adalah URL pendaftaran publik event (`{origin}/e/{eventId}`), bukan
/// pola dekoratif. Bila event belum tayang ([data] null/kosong), widget
/// menampilkan status jujur "belum tersedia" alih-alih QR palsu.
class RegistrationQrView extends StatelessWidget {
  const RegistrationQrView({
    super.key,
    required this.data,
    this.size = 112,
    this.semanticLabel = 'QR pendaftaran peserta',
  });

  /// URL pendaftaran publik; null/kosong berarti event belum tayang.
  final String? data;
  final double size;
  final String semanticLabel;

  bool get _hasData => (data ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      return Container(
        key: const Key('registration-qr-unavailable'),
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.qr_code_2, size: 30, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                'QR aktif setelah event tayang',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: QrImageView(
          key: const Key('registration-qr-image'),
          data: data!.trim(),
          version: QrVersions.auto,
          size: size - 16,
          gapless: true,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          backgroundColor: Colors.white,
          semanticsLabel: semanticLabel,
        ),
      ),
    );
  }
}
