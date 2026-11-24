/// Halaman penerimaan undangan panitia (`/invite/:token`) â€” D2-2.
///
/// Alur: pratinjau undangan (`GET /api/invitations/:token`) â†’ tombol terima
/// (`POST /api/invitations/:token/accept`) â†’ arahkan ke workspace staf event.
/// Email akun harus cocok dengan email undangan; backend yang memutuskan dan
/// menolak dengan 403 bila tidak cocok.
library;

import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/organizer_membership/invitation_service.dart';

class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({
    super.key,
    required this.token,
    this.invitationService,
  });

  final String token;
  final InvitationService? invitationService;

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  late final InvitationService _service =
      widget.invitationService ?? InvitationService();

  InvitationPreview? _preview;
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _error;
  String? _acceptError;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final preview = await _service.preview(widget.token);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AppException
            ? error.message
            : 'Undangan tidak dapat dimuat. Periksa kembali tautan undangan.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accept() async {
    if (_isAccepting) return;
    setState(() {
      _isAccepting = true;
      _acceptError = null;
    });
    try {
      final result = await _service.accept(widget.token);
      if (!mounted) return;
      final invitation =
          result['invitation'] is Map ? result['invitation'] as Map : const {};
      final eventId = (_preview?.eventId ?? '').isNotEmpty
          ? _preview!.eventId
          : (invitation['event_id'] ?? '').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Undangan diterima. Anda kini staf pada event ini.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        eventId.isEmpty
            ? AppRoutes.staffDashboard
            : AppRoutes.staffWorkspacePath(eventId),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _acceptError = error is AppException
            ? error.message
            : 'Undangan gagal diterima. Coba lagi.';
      });
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Undangan Panitia')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildPreview(_preview!),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loadPreview,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      ],
    );
  }

  Widget _buildPreview(InvitationPreview preview) {
    final canAccept = preview.isPending && !_isAccepting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        const Text(
          'Undangan Panitia Event',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          preview.eventTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Status undangan', _statusLabel(preview.status)),
              if (preview.eventDate != null)
                _row('Jadwal', _formatDate(preview.eventDate!)),
              if ((preview.location ?? '').isNotEmpty)
                _row('Lokasi', preview.location!),
              if (preview.isOnline) _row('Format', 'Online'),
              _row('Email diundang', preview.invitedEmail),
              if (preview.permissions.isNotEmpty)
                _row('Izin akses', preview.permissions.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!preview.isPending)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              preview.isExpired
                  ? 'Undangan ini sudah kedaluwarsa. Minta penyelenggara mengirim ulang.'
                  : 'Undangan ini tidak lagi aktif (status: ${preview.status}).',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        if (_acceptError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _acceptError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade900),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('invitation-accept-button'),
          onPressed: canAccept ? _accept : null,
          icon: _isAccepting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_isAccepting ? 'Memproses...' : 'Terima Undangan'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _isAccepting ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Kembali'),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu diterima';
      case 'ACCEPTED':
        return 'Sudah diterima';
      case 'REVOKED':
        return 'Dicabut';
      case 'EXPIRED':
        return 'Kedaluwarsa';
      default:
        return status;
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
