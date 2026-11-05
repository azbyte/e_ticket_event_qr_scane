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
    this.eventId = 'evt-001',
  });

  final CheckInProvider? checkInProvider;
  final String staffId;
  final String staffName;
  final String eventId;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late final CheckInProvider _provider;
  final TextEditingController _tokenController = TextEditingController();
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.checkInProvider ?? CheckInProvider(CheckInService());
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
          body: Column(
            children: [
              // Viewfinder Section
              const Expanded(
                flex: 4,
                child: ScannerPlaceholder(),
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
        );
      },
    );
  }
}
