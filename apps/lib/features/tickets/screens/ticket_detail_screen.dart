import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../models/ticket/ticket_model.dart';
import '../../../providers/ticket_provider.dart';
import '../../../services/ticket/ticket_service.dart';
import '../widgets/qr_ticket_display.dart';

/// Ticket detail screen — e-ticket with QR code (PRD sections 4.6, 7.2 F).
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    this.ticketId,
    this.orderId,
    this.ticket,
  });

  final String? ticketId;
  final String? orderId;
  final TicketModel? ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TicketProvider _ticketProvider = TicketProvider.instance;
  final TicketService _ticketService = TicketService();
  late String _effectiveTicketId;

  bool _sendingEmail = false;

  /// Status email terakhir dari backend setelah aksi kirim ulang.
  String? _emailStatusMessage;
  bool _emailStatusOk = false;

  @override
  void initState() {
    super.initState();
    _effectiveTicketId =
        widget.ticketId ?? (AppConfig.mockMode ? 'tkt-001-a' : '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is String && routeArg.isNotEmpty) {
        _effectiveTicketId = routeArg;
      }
      if (widget.ticket == null && _effectiveTicketId.isNotEmpty) {
        _ticketProvider.loadTicket(_effectiveTicketId, orderId: widget.orderId);
      }
    });
  }

  /// Kirim ulang e-ticket ke email peserta.
  ///
  /// Hasil ditampilkan apa adanya: `delivered` hanya true bila backend
  /// melaporkan email benar-benar terkirim. Pengiriman yang sudah pernah
  /// berhasil tidak diulang (backend mengembalikan `already_sent`).
  Future<void> _resendEmail() async {
    if (_effectiveTicketId.isEmpty || _sendingEmail) return;
    setState(() {
      _sendingEmail = true;
      _emailStatusMessage = null;
    });
    try {
      final result = await _ticketService.resendTicketEmail(
        _effectiveTicketId,
        orderId: widget.orderId,
      );
      final delivered = result['delivered'] == true;
      final status = result['delivery_status']?.toString() ?? 'UNKNOWN';
      final reason = result['reason']?.toString();
      if (!mounted) return;
      setState(() {
        _emailStatusOk = delivered || status == 'SKIPPED';
        _emailStatusMessage = delivered
            ? 'E-ticket berhasil dikirim ulang ke email peserta.'
            : status == 'SKIPPED'
            ? 'Email sudah pernah terkirim; tidak ada email ganda yang dikirim.'
            : 'Email belum terkirim (status: $status)'
                  '${reason == null ? '.' : ': $reason'}';
      });
      // Muat ulang status email terbaru dari backend.
      await _ticketProvider.loadTicket(
        _effectiveTicketId,
        orderId: widget.orderId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _emailStatusOk = false;
        _emailStatusMessage = 'Gagal mengirim ulang email: $error';
      });
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'valid':
      case 'active':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'VALID / SIAP CHECK-IN';
        break;
      case 'checked_in':
      case 'used':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'SUDAH CHECK-IN';
        break;
      case 'pending':
        bg = Colors.amber.shade50;
        fg = Colors.orange.shade800;
        label = 'BELUM DIBAYAR';
        break;
      case 'cancelled':
      case 'revoked':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = status.toUpperCase() == 'CANCELLED' ? 'DIBATALKAN' : 'DICABUT';
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'TIDAK VALID';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Ticket Resmi')),
      body: ListenableBuilder(
        listenable: _ticketProvider,
        builder: (context, _) {
          if (_ticketProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat e-ticket...'),
                ],
              ),
            );
          }

          final ticket = widget.ticket ?? _ticketProvider.selectedTicket;
          if (ticket == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text('E-Ticket tidak ditemukan.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _effectiveTicketId.isEmpty
                          ? null
                          : () => _ticketProvider.loadTicket(
                              _effectiveTicketId,
                              orderId: widget.orderId,
                            ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isValid = ticket.isValid;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Digital Ticket Card Frame
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isValid
                              ? AppTheme.primaryColor
                              : Colors.grey.shade700,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'E-TICKET EVENT PASS',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      // Nama kategori tiket, bukan UUID.
                                      ticket.displayTicketType,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Nama event dari database (bukan "Event ID").
                            Text(
                              ticket.displayEventTitle,
                              key: const Key('ticket-event-title'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket.attendeeName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (ticket.attendeeEmail != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                ticket.attendeeEmail!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Ticket Notch Divider
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: List.generate(
                              25,
                              (index) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Container(
                                    height: 1.5,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -12,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context)
                                  .scaffoldBackgroundColor,
                            ),
                          ),
                          Positioned(
                            right: -12,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context)
                                  .scaffoldBackgroundColor,
                            ),
                          ),
                        ],
                      ),

                      // QR Code Section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildStatusBadge(ticket.status),
                            const SizedBox(height: 20),

                            // QR Display or Status Box
                            if (ticket.isPending)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      size: 48,
                                      color: Colors.orange.shade800,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Menunggu Pembayaran',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'E-ticket dan kode QR akan aktif otomatis setelah pembayaran diverifikasi oleh sistem.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (ticket.isCancelled || ticket.isRevoked)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      size: 48,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      ticket.isCancelled ? 'Tiket Dibatalkan' : 'Tiket Dicabut',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tiket ini tidak berlaku lagi dan tidak dapat digunakan untuk memasuki acara.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              QrTicketDisplay(
                                ticketData: ticket.token,
                                size: 190,
                              ),
                            const SizedBox(height: 20),

                            // Ticket Details List — data yang bermakna untuk
                            // peserta (nama event, kategori, jadwal, lokasi,
                            // kode tiket), bukan UUID internal.
                            if (ticket.eventDate != null) ...[
                              _buildDetailRow(
                                'Jadwal',
                                app_date.DateUtils.formatDateTime(
                                  ticket.eventDate,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _buildDetailRow('Lokasi', ticket.displayLocation),
                            // Kode tiket hanya ditampilkan bila tersedia, agar
                            // tidak menduplikasi teks token QR di layar.
                            if ((ticket.ticketCode ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow('Kode Tiket', ticket.ticketCode!),
                            ],
                            if (ticket.issuedAt != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Waktu Diterbitkan',
                                app_date.DateUtils.formatDateTime(
                                  ticket.issuedAt,
                                ),
                              ),
                            ],
                            if (ticket.isCheckedIn &&
                                ticket.checkedInAt != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Waktu Check-in',
                                app_date.DateUtils.formatDateTime(
                                  ticket.checkedInAt,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Status email e-ticket (nyata, bukan asumsi) + kirim ulang.
                _buildEmailStatusCard(ticket),

                const SizedBox(height: 24),

                // Instruction notice card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panduan Check-in di Lokasi Acara',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tingkatkan kecerahan layar smartphone Anda saat mendekati meja registrasi. Tunjukkan QR Code ini kepada panitia untuk dipindai sekali saat masuk.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Kartu status email e-ticket + tombol kirim ulang.
  ///
  /// Sumber status: `email_delivery` dari backend. Bila belum ada catatan,
  /// ditampilkan sebagai "belum terkirim" (bukan diklaim berhasil).
  Widget _buildEmailStatusCard(TicketModel ticket) {
    final raw = _ticketProvider.selectedTicketRaw?['email_delivery'];
    final delivery = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final status = delivery?['status']?.toString();
    final recipient = delivery?['recipient']?.toString() ??
        ticket.attendeeEmail;
    final reason = delivery?['reason']?.toString();
    final sent = status == 'SENT';
    final pending =
        status == 'PENDING' || status == 'SENDING' || status == 'QUEUED';
    final notConfigured = status == 'NOT_CONFIGURED';
    final message = _emailStatusMessage ??
        (sent
            ? 'E-ticket PDF sudah dikirim ke ${recipient ?? 'email peserta'}.'
            : status == null
            ? 'Belum ada catatan pengiriman email untuk tiket ini.'
            : notConfigured
            ? 'Email belum terkirim${reason == null ? ': layanan email belum dikonfigurasi di server.' : ': $reason'}'
            : pending
            ? (status == 'SENDING'
                ? 'Email sedang dikirim ke ${recipient ?? 'email peserta'}...'
                : 'Email belum terkirim${reason == null ? '.' : ': $reason'}')
            : 'Email gagal terkirim${reason == null ? '.' : ': $reason'}');
    final ok = _emailStatusMessage != null ? _emailStatusOk : sent;
    return Container(
      key: const Key('ticket-email-status'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ok ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                ok ? Icons.mark_email_read : Icons.mail_outline,
                color: ok ? Colors.green.shade700 : Colors.orange.shade800,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Status Email Tiket',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ok ? Colors.green.shade800 : Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: ok ? Colors.green.shade800 : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!sent) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('ticket-resend-email'),
                onPressed: _sendingEmail ? null : _resendEmail,
                icon: _sendingEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(
                  _sendingEmail ? 'Mengirim...' : 'Kirim ulang email',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
