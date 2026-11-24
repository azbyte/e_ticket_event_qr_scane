/// Live camera QR viewfinder (PRD §4.5, AC-06).
///
/// Membungkus `mobile_scanner` agar layar scanner memakai kamera nyata.
/// Overlay (reticle + laser) tetap dipakai sebagai panduan visual. Widget ini
/// tidak melakukan validasi tiket; hasil pindai dikirim ke callback pemanggil.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerView extends StatefulWidget {
  const CameraScannerView({
    super.key,
    required this.onDetected,
    this.onPermissionDenied,
    this.torchEnabled = false,
    this.paused = false,
  });

  /// Dipanggil sekali per token hasil pindai. Pemanggil bertanggung jawab
  /// menahan pemindaian berikutnya selama hasil masih diproses.
  final void Function(String rawValue) onDetected;

  /// Dipanggil saat kamera tidak dapat dibuka (izin ditolak / tanpa perangkat).
  final VoidCallback? onPermissionDenied;

  final bool torchEnabled;

  /// Saat `true` kamera berhenti memproses frame (mis. hasil masih diproses).
  final bool paused;

  @override
  State<CameraScannerView> createState() => _CameraScannerViewState();
}

class _CameraScannerViewState extends State<CameraScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  String? _lastValue;

  @override
  void didUpdateWidget(covariant CameraScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.torchEnabled != widget.torchEnabled) {
      _controller.toggleTorch();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (widget.paused) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty || value == _lastValue) continue;
      _lastValue = value;
      widget.onDetected(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _handleDetection,
          errorBuilder: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onPermissionDenied?.call();
            });
            return const ColoredBox(color: Colors.black87);
          },
        ),
        // Reticle panduan
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                ),
                _corner(Alignment.topLeft, const Border(
                  top: BorderSide(color: Colors.greenAccent, width: 4),
                  left: BorderSide(color: Colors.greenAccent, width: 4),
                )),
                _corner(Alignment.topRight, const Border(
                  top: BorderSide(color: Colors.greenAccent, width: 4),
                  right: BorderSide(color: Colors.greenAccent, width: 4),
                )),
                _corner(Alignment.bottomLeft, const Border(
                  bottom: BorderSide(color: Colors.greenAccent, width: 4),
                  left: BorderSide(color: Colors.greenAccent, width: 4),
                )),
                _corner(Alignment.bottomRight, const Border(
                  bottom: BorderSide(color: Colors.greenAccent, width: 4),
                  right: BorderSide(color: Colors.greenAccent, width: 4),
                )),
                const Center(
                  child: Text(
                    'Arahkan QR ke dalam kotak',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _corner(Alignment alignment, Border border) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(border: border),
      ),
    );
  }
}
