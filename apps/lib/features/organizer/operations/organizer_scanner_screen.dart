/// Pemindai QR tiket untuk Organizer/Staf (PRD §4.5, 4.7 & FR-50–59).
///
/// Pada mode API, layar ini mendelegasikan ke [ScannerScreen] yang memakai
/// kamera nyata dan backend (`POST /api/tickets/validate` + `POST /api/check-ins`).
/// Data demo in-memory hanya dipakai ketika `MOCK_MODE=true`.
library;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../services/check_in/check_in_service.dart';
import '../../../services/organizer_operations/organizer_permission.dart';
import '../../../services/scanner/scanner_service.dart';
import '../../scanner/screens/scanner_screen.dart';

class OrganizerScannerScreen extends StatefulWidget {
  const OrganizerScannerScreen({
    super.key,
    required this.eventId,
    this.eventName = 'Tech Innovation Summit 2026',
    required this.contextScope,
  });

  final String eventId;
  final String eventName;
  final OrganizerMembershipContext contextScope;

  @override
  State<OrganizerScannerScreen> createState() => _OrganizerScannerScreenState();
}

class _OrganizerScannerScreenState extends State<OrganizerScannerScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final ScannerService _scannerService = ScannerService();
  final CheckInService _checkInService = CheckInService();

  Map<String, dynamic>? _lastResult;
  bool _isProcessing = false;

  final List<Map<String, String>> _quickPresets = [
    {'label': 'Tiket Valid (Siap Check-in)', 'code': 'TK-TECH-003'},
    {'label': 'Tiket Sudah Digunakan', 'code': 'TK-TECH-001'},
    {'label': 'Tiket Acara Lain', 'code': 'TK-MUSIC-001'},
    {'label': 'Tiket Dibatalkan', 'code': 'TK-TECH-006'},
    {'label': 'Token Tidak Valid / Rusak', 'code': 'INV-999'},
  ];

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (!widget.contextScope.hasPermission(OrganizerPermission.scanTicket)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses Ditolak: Anda tidak memiliki izin SCAN_TICKET.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (code.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _scannerService.validateTicket(
        code.trim(),
        eventId: widget.eventId,
      );

      final isValid = result['valid'] == true;
      final status = (result['status'] as String? ?? '').toUpperCase();

      if (isValid &&
          status == 'VALID' &&
          widget.contextScope.hasPermission(OrganizerPermission.checkInTicket)) {
        final ticketData = result['ticket'] as Map<String, dynamic>? ?? {};
        final attendeeName = ticketData['attendee_name'] as String? ?? 'peserta ini';

        if (!mounted) return;
        final shouldCheckIn = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Konfirmasi check-in'),
            content: Text(
              'Tiket valid untuk $attendeeName. Lanjutkan check-in?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (shouldCheckIn == true) {
          final ticketId = ticketData['id'] as String? ?? ticketData['token'] as String? ?? code.trim();
          final committed = await _scannerService.recordCheckIn(
            ticketId: ticketId,
            eventId: widget.eventId,
            staffId: widget.contextScope.userId,
            staffName: widget.contextScope.userName,
            token: code.trim(),
          );
          setState(() {
            _lastResult = {
              'status': 'VALID',
              'valid': true,
              'message': 'Check-in berhasil dicatat.',
              'ticket': ticketData,
              'check_in': committed['check_in'],
            };
            _isProcessing = false;
            _tokenController.clear();
          });
          return;
        }
      }

      setState(() {
        _lastResult = result;
        _isProcessing = false;
        _tokenController.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = {
            'status': 'INVALID',
            'valid': false,
            'message': 'Gagal memeriksa tiket: $e',
          };
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canScan = widget.contextScope.hasPermission(
      OrganizerPermission.scanTicket,
    );

    // Mode API (MVP): kamera nyata + validasi backend.
    if (!AppConfig.mockMode) {
      if (!canScan) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pemindai QR Tiket')),
          body: _buildAccessDenied(),
        );
      }
      return ScannerScreen(
        eventId: widget.eventId,
        staffName: widget.contextScope.userName,
        staffId: widget.contextScope.userId,
      );
    }

    final canViewHistory = widget.contextScope.hasPermission(
      OrganizerPermission.viewScanHistory,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemindai Tiket QR'),
      ),
      body: !canScan
          ? _buildAccessDenied()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Event Scope Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAEA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: Color(0xFFC94426)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lokasi Scan: ${widget.eventName}\nOperator: ${widget.contextScope.userName} (${widget.contextScope.role.toUpperCase()})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Simulated Camera Viewfinder
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.greenAccent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.qr_code_scanner,
                              color: Colors.greenAccent,
                              size: 48,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Arahkan QR Code Tiket ke Kotak',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Token Input Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tokenController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Input Kode / Token Tiket QR',
                            hintText: 'Contoh: TK-TECH-003',
                            prefixIcon: Icon(Icons.vpn_key),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          onSubmitted: _handleScan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _handleScan(_tokenController.text),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Periksa'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Result Card
                  if (_lastResult != null) _buildResultDisplay(_lastResult!),

                  const SizedBox(height: 20),

                  // Quick test presets
                  const Text(
                    'Simulasi Pengujian Cepat (FR-50–59):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickPresets.map((p) {
                      return ActionChip(
                        label: Text(
                          '${p['label']} (${p['code']})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _handleScan(p['code']!),
                      );
                    }).toList(),
                  ),

                  if (canViewHistory) ...[
                    const Divider(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showHistoryModal(context),
                      icon: const Icon(Icons.history),
                      label: const Text('Buka Riwayat Pemindaian Check-in'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Akses Ditolak',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Akun Anda tidak memiliki izin "${OrganizerPermission.scanTicket.code}". Hubungi Penyelenggara untuk meminta hak akses ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDisplay(Map<String, dynamic> result) {
    Color cardColor;
    Color iconColor;
    IconData icon;
    final status = (result['status'] as String? ?? 'INVALID').toUpperCase();

    switch (status) {
      case 'VALID':
        cardColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'ALREADY_USED':
      case 'ALREADY_CHECKED_IN':
        cardColor = const Color(0xFFFDF3F1);
        iconColor = const Color(0xFFC94426);
        icon = Icons.warning_amber_rounded;
        break;
      case 'WRONG_EVENT':
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        icon = Icons.wrong_location_outlined;
        break;
      case 'PAYMENT_REQUIRED':
        cardColor = Colors.deepOrange.shade50;
        iconColor = Colors.deepOrange.shade700;
        icon = Icons.payment;
        break;
      default:
        cardColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        icon = Icons.error_outline;
    }

    final ticket = (result['ticket'] as Map<String, dynamic>?) ?? {};
    final attendeeName = ticket['attendee_name'] as String?;
    final ticketType = ticket['ticket_type'] as String? ?? ticket['ticket_type_name'] as String?;
    final ticketCode = ticket['ticket_code'] as String? ?? ticket['token'] as String?;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'VALID'
                            ? 'CHECK-IN BERHASIL'
                            : status == 'ALREADY_USED' || status == 'ALREADY_CHECKED_IN'
                            ? 'TIKET SUDAH DIGUNAKAN'
                            : status == 'WRONG_EVENT'
                            ? 'EVENT TIDAK SESUAI'
                            : status == 'PAYMENT_REQUIRED'
                            ? 'PEMBAYARAN DIPERLUKAN'
                            : 'CHECK-IN DITOLAK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result['message'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (attendeeName != null) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Peserta:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    attendeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (ticketType != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kategori:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      ticketType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              if (ticketCode != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kode Tiket:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      ticketCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showHistoryModal(BuildContext context) async {
    final checkIns = await _checkInService.listCheckIns(eventId: widget.eventId);

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Riwayat Check-in (${checkIns.length} Peserta)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (checkIns.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Belum ada tiket yang di-check-in.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: checkIns.length,
                        itemBuilder: (_, idx) {
                          final a = checkIns[idx];
                          final ticketCode = a['ticket_id'] as String? ?? '-';
                          final staff = a['staff_name'] as String? ?? '-';
                          final checkedAt = a['checked_in_at'] as String? ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              'Tiket: $ticketCode',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Petugas: $staff • $checkedAt',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Chip(
                              label: Text(
                                'Tersinkron',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
