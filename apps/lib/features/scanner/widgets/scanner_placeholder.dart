/// Scanner camera placeholder widget (PRD section 7.5 B).
///
/// Stub fondasi. Tampilan kamera akan mengganti widget ini setelah
/// paket `mobile_scanner` ditambahkan.
import 'package:flutter/material.dart';

class ScannerPlaceholder extends StatelessWidget {
  const ScannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Tampilan kamera pemindai QR'),
        ],
      ),
    );
  }
}
