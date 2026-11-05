/// Organizer mock scanner & check-in screen (PRD sections 4.5, 4.7 & FR-50–59).
///
/// Features simulated camera QR input, offline queue handling, granular
/// permission enforcement, conflict detection, and scan history.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';

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
  final OrganizerOperationsRepository _repo =
      OrganizerOperationsRepository.instance;

  ScanCheckInResult? _lastResult;
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

  void _handleScan(String code) {
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

    final result = _repo.validateAndCheckIn(
      eventId: widget.eventId,
      ticketCode: code.trim(),
      context: widget.contextScope,
      autoCommitCheckIn: true,
    );

    setState(() {
      _lastResult = result;
      _isProcessing = false;
      _tokenController.clear();
    });
  }

  void _handleSyncOffline() {
    final report = _repo.syncOfflineQueue(widget.eventId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hasil Sinkronisasi Offline'),
        content: Text(report['message'] as String),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canScan = widget.contextScope.hasPermission(OrganizerPermission.scanTicket);
    final canViewHistory = widget.contextScope.hasPermission(OrganizerPermission.viewScanHistory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemindai Tiket QR (Mock)'),
        actions: [
          // Offline mode switch
          Row(
            children: [
              Text(
                _repo.isOfflineModeEnabled ? 'OFFLINE' : 'ONLINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _repo.isOfflineModeEnabled ? Colors.orange : Colors.green,
                ),
              ),
              Switch(
                value: _repo.isOfflineModeEnabled,
                onChanged: (val) {
                  setState(() {
                    _repo.toggleOfflineMode(val);
                  });
                },
              ),
            ],
          ),
        ],
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lokasi Scan: ${widget.eventName}\nOperator: ${widget.contextScope.userName} (${widget.contextScope.role.toUpperCase()})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Offline queue alert if present
                  if (_repo.offlineQueue.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ada ${_repo.offlineQueue.length} data check-in lokal tersimpan di antrean offline.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _handleSyncOffline,
                            child: const Text('Sinkron', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

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
                            border: Border.all(color: Colors.greenAccent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_scanner, color: Colors.greenAccent, size: 48),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _repo.isOfflineModeEnabled
                                  ? 'Mode Scanner Offline Aktif'
                                  : 'Arahkan QR Code Tiket ke Kotak',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: _handleScan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _handleScan(_tokenController.text),
                        child: _isProcessing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                        label: Text('${p['label']} (${p['code']})', style: const TextStyle(fontSize: 11)),
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

  Widget _buildResultDisplay(ScanCheckInResult result) {
    Color cardColor;
    Color iconColor;
    IconData icon;

    switch (result.status) {
      case 'VALID':
        cardColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'OFFLINE_QUEUED':
        cardColor = Colors.amber.shade50;
        iconColor = Colors.orange.shade700;
        icon = Icons.cloud_off;
        break;
      case 'ALREADY_CHECKED_IN':
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        cardColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        icon = Icons.error_outline;
    }

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
                        result.status == 'VALID'
                            ? 'CHECK-IN BERHASIL'
                            : result.status == 'OFFLINE_QUEUED'
                                ? 'DISIMPAN OFFLINE'
                                : result.status == 'ALREADY_CHECKED_IN'
                                    ? 'TIKET SUDAH DIGUNAKAN'
                                    : 'CHECK-IN DITOLAK',
                        style: TextStyle(fontWeight: FontWeight.bold, color: iconColor, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(result.message, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (result.attendee != null) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Peserta:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(result.attendee!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kategori:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(result.attendee!.ticketType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kode Tiket:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(result.attendee!.ticketCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHistoryModal(BuildContext context) {
    final attendees = _repo.getAttendeesForEvent(widget.eventId);
    final checkedInList = attendees.where((a) => a.checkedIn).toList();

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
                        'Riwayat Check-in (${checkedInList.length} Peserta)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  if (checkedInList.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Belum ada tiket yang di-check-in.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: checkedInList.length,
                        itemBuilder: (_, idx) {
                          final a = checkedInList[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: a.isOfflinePending ? Colors.orange.shade100 : Colors.green.shade100,
                              child: Icon(
                                a.isOfflinePending ? Icons.cloud_off : Icons.check,
                                color: a.isOfflinePending ? Colors.orange : Colors.green,
                                size: 18,
                              ),
                            ),
                            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${a.ticketCode} • ${a.ticketType}\nOleh: ${a.checkedInBy ?? "-"} (${a.checkedInAt?.hour}:${a.checkedInAt?.minute.toString().padLeft(2, "0")} WIB)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: a.isOfflinePending
                                ? const Chip(label: Text('Offline', style: TextStyle(fontSize: 10, color: Colors.orange)))
                                : const Chip(label: Text('Tersinkron', style: TextStyle(fontSize: 10, color: Colors.green))),
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

