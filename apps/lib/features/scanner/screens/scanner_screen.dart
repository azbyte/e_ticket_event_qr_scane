/// QR scanner screen (PRD sections 4.5, 7.5 B).
///
/// Provides camera viewfinder placeholder, manual ticket code entry,
/// and interactive test triggers for valid, duplicate, and invalid tickets.
library;

import 'package:flutter/material.dart';

import '../../../providers/check_in_provider.dart';
import '../../../services/check_in/check_in_service.dart';
import '../widgets/scanner_placeholder.dart';
import 'scan_result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.checkInProvider,
    this.staffId = 'stf-001',
    this.staffName = 'Budi Santoso',
    this.eventId = 'evt-1001',
    this.initialCameraPermission = true,
  });

  final CheckInProvider? checkInProvider;
  final String staffId;
  final String staffName;
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
    if (token.trim().isEmpty) return;

    final result = await _provider.processTicketScan(
      token.trim(),
      staffId: widget.staffId,
      staffName: widget.staffName,
      eventId: widget.eventId,
    );

    if (!mounted) return;
    _tokenController.clear();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(result: result),
      ),
    );
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
        final isOffline = _provider.isOfflineMode;

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
              IconButton(
                tooltip: isOffline ? 'Mode Offline' : 'Mode Online',
                icon: Icon(
                  isOffline ? Icons.wifi_off : Icons.wifi,
                  color: isOffline ? Colors.orange : Colors.greenAccent,
                ),
                onPressed: () {
                  _provider.toggleOfflineMode(!isOffline);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !isOffline
                            ? 'Mode Offline aktif. Scan akan disimpan lokal.'
                            : 'Mode Online aktif. Scan langsung ke server.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Viewfinder Section (atau tampilan izin ditolak)
                  Expanded(
                    flex: 4,
                    child: _hasCameraPermission
                        ? const ScannerPlaceholder()
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

                  // Bottom Control & Simulation Panel
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
                                decoration: InputDecoration(
                                  labelText: 'Input Kode / Token Tiket',
                                  hintText: 'Contoh: TK-TECH-003',
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onPressed: () => _handleScan(_tokenController.text),
                              child: const Text('Scan'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Section Title: Quick Testing Simulations
                        Text(
                          'Simulasi Pemindaian Cepat (Pengujian MVP):',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 8),

                        // Button 1: Valid Ticket
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800,
                            side: BorderSide(color: Colors.green.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          label: const Text('1. Simulasikan Scan Valid (TK-TECH-003)'),
                          onPressed: () => _handleScan('TK-TECH-003'),
                        ),
                        const SizedBox(height: 6),

                        // Button 2: Already Checked-in (Duplicate Prevention)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.warning_amber, color: Colors.orange),
                          label: const Text('2. Simulasikan Tiket Sudah Check-in (Ganda)'),
                          onPressed: () => _handleScan('TK-TECH-001'),
                        ),
                        const SizedBox(height: 6),

                        // Button 3: Invalid Ticket
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade800,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          label: const Text('3. Simulasikan Tiket Palsu / Invalid'),
                          onPressed: () => _handleScan('INV-999'),
                        ),
                        const SizedBox(height: 6),

                        // Button 4: Offline Queue Simulation
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade800,
                            side: BorderSide(color: Colors.blue.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.cloud_queue, color: Colors.blue),
                          label: const Text('4. Simulasikan Check-in Offline (Lokal)'),
                          onPressed: () {
                            _provider.toggleOfflineMode(true);
                            _handleScan('TK-TECH-004');
                          },
                        ),
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  },
);
  }
}
