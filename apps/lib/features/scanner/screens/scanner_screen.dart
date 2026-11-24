/// QR scanner screen (PRD sections 4.5, 7.5 B).
///
/// Memakai kamera nyata (`mobile_scanner`) untuk memindai QR e-ticket, dengan
/// input kode manual sebagai fallback bila kamera tidak tersedia. Mode offline
/// dan tombol simulasi **tidak** ditampilkan pada alur MVP; keduanya hanya
/// tersedia saat `MOCK_MODE=true` untuk keperluan demo.
library;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';
import '../widgets/camera_scanner_view.dart';
import 'scan_result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.checkInProvider,
    this.staffId = 'stf-001',
    this.staffName = 'Budi Santoso',
    this.eventId = '',
    this.initialCameraPermission = true,
  });

  final CheckInProvider? checkInProvider;
  final String staffId;
  final String staffName;

  /// Event pos pemindaian. Wajib diisi pada alur MVP agar backend dapat
  /// memvalidasi izin petugas dan kesesuaian tiket dengan event.
  final String eventId;
  final bool initialCameraPermission;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final CheckInProvider _provider;
  final TextEditingController _tokenController = TextEditingController();
  bool _isFlashOn = false;
  late bool _hasCameraPermission;

  /// Mencegah double-submit selama hasil pindai masih diproses (D2-3 K5).
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
    _hasCameraPermission = widget.initialCameraPermission;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String token) async {
    final value = token.trim();
    if (value.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    final result = await _provider.processTicketScan(
      value,
      staffId: widget.staffId,
      staffName: widget.staffName,
      eventId: widget.eventId,
    );

    if (!mounted) return;
    _tokenController.clear();
    setState(() => _isProcessing = false);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScanResultScreen(result: result)),
    );
  }

  void _handleCameraUnavailable() {
    if (!mounted) return;
    setState(() => _hasCameraPermission = false);
  }

  Widget _buildCameraPermissionDenied() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 36, color: Colors.orangeAccent),
              const SizedBox(height: 8),
              const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Aplikasi memerlukan akses kamera untuk scan QR. Anda juga dapat menggunakan input kode manual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Minta Izin Lagi'),
                onPressed: () {
                  setState(() {
                    _hasCameraPermission = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pemindai QR Tiket'),
            actions: [
              IconButton(
                tooltip: _isFlashOn ? 'Matikan Flash' : 'Nyalakan Flash',
                icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () {
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                  });
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Viewfinder kamera nyata (atau state izin ditolak).
                  Expanded(
                    flex: 4,
                    child: _hasCameraPermission
                        ? CameraScannerView(
                            torchEnabled: _isFlashOn,
                            paused: _isProcessing,
                            onDetected: _handleScan,
                            onPermissionDenied: _handleCameraUnavailable,
                          )
                        : _buildCameraPermissionDenied(),
                  ),

                  // Error / Alert Banner bila terjadi kendala
                  if (_provider.error != null)
                    Container(
                      color: Colors.red.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _provider.error!,
                              style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _provider.loadAttendees(eventId: widget.eventId)),
                          ),
                        ],
                      ),
                    ),

                  // Panel kontrol bawah (input manual + status).
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Manual Token Input
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tokenController,
                                    enabled: !_isProcessing,
                                    decoration: InputDecoration(
                                      labelText: 'Input Kode / Token Tiket',
                                      hintText: 'Tempel token QR di sini',
                                      prefixIcon: const Icon(Icons.keyboard),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      isDense: true,
                                    ),
                                    onSubmitted: _handleScan,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _handleScan(_tokenController.text),
                                  child: const Text('Scan'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            if (_isProcessing) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                            ],

                            Text(
                              _hasCameraPermission
                                  ? 'Pindai QR e-ticket peserta. Bila kamera tidak '
                                      'tersedia, masukkan token tiket secara manual.'
                                  : 'Kamera tidak aktif. Masukkan token tiket '
                                      'secara manual untuk melanjutkan check-in.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),

                            // Tombol simulasi hanya tersedia pada mode demo.
                            if (AppConfig.mockMode) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Simulasi Pemindaian (mode demo):',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    label: const Text('Tiket valid'),
                                    onPressed: () => _handleScan('TK-TECH-003'),
                                  ),
                                  ActionChip(
                                    label: const Text('Sudah check-in'),
                                    onPressed: () => _handleScan('TK-TECH-001'),
                                  ),
                                  ActionChip(
                                    label: const Text('Token invalid'),
                                    onPressed: () => _handleScan('INV-999'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_provider.isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

