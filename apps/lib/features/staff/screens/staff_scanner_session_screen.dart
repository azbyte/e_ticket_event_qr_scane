/// Pintu masuk scanner untuk staf yang memakai undangan kode akses.
///
/// Halaman ini TIDAK dapat dipakai tanpa sesi staf yang valid. Sesi diverifikasi
/// ke backend setiap kali halaman dibuka, sehingga:
///  - URL scanner yang dibuka langsung tanpa kode akses menampilkan penolakan;
///  - undangan yang dicabut/kedaluwarsa langsung kehilangan akses;
///  - staf hanya diarahkan ke scanner event pada undangannya (event lain
///    ditolak walau `eventId` diubah pada URL).
library;

import 'package:flutter/material.dart';

import '../../../core/services/staff_session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/staff_access/staff_access_service.dart';
import '../../scanner/screens/scanner_screen.dart';

class StaffScannerSessionScreen extends StatefulWidget {
  const StaffScannerSessionScreen({
    super.key,
    this.eventId,
    this.service,
    this.scannerBuilder,
  });

  /// Event dari argumen navigasi (opsional). Bila diisi, harus sama dengan
  /// event pada sesi staf.
  final String? eventId;

  /// Dapat diganti pada test agar tidak memanggil HTTP.
  final StaffAccessService? service;

  /// Pembuat tampilan scanner (default: [ScannerScreen]). Dapat diganti pada
  /// test agar kamera/platform channel tidak dibutuhkan.
  final Widget Function(StaffSession session)? scannerBuilder;

  @override
  State<StaffScannerSessionScreen> createState() =>
      _StaffScannerSessionScreenState();
}

class _StaffScannerSessionScreenState extends State<StaffScannerSessionScreen> {
  late final StaffAccessService _service =
      widget.service ?? StaffAccessService();

  bool _loading = true;
  StaffSession? _session;
  String? _deniedReason;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _deniedReason = null;
    });
    final session = await _service.restoreSession();
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _loading = false;
        _session = null;
        _deniedReason =
            'Sesi staf tidak ditemukan atau sudah berakhir. Masukkan kode akses '
            'dari tautan undangan Organizer.';
      });
      return;
    }
    final requested = (widget.eventId ?? '').trim();
    if (requested.isNotEmpty && requested != session.eventId) {
      setState(() {
        _loading = false;
        _session = null;
        _deniedReason =
            'Sesi staf Anda hanya berlaku untuk event pada undangan. '
            'Anda tidak dapat membuka scanner event lain.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _session = session;
    });
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    setState(() {
      _session = null;
      _deniedReason = 'Sesi staf diakhiri.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session == null) return _buildDenied();
    return Stack(
      children: <Widget>[
        widget.scannerBuilder?.call(session) ??
            ScannerScreen(
              key: const Key('staff-scanner-session'),
              eventId: session.eventId,
              staffId: 'staff:${session.staffName}',
              staffName: session.staffName,
            ),
        Positioned(
          // Di bawah AppBar agar tidak menutupi judul/tombol flash scanner.
          top: 56,
          right: 12,
          child: SafeArea(
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _logout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.logout, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        session.staffName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDenied() => Scaffold(
    appBar: AppBar(title: const Text('Akses Staf')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            key: const Key('staff-scanner-denied'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: const <Widget>[
                      Icon(Icons.lock_outline, color: AppTheme.errorColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tidak memiliki akses ke scanner',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _deniedReason ??
                        'Akses staf tidak valid untuk halaman ini.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Periksa ulang sesi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
