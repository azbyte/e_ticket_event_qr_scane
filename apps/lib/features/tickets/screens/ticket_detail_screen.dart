import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/ticket_provider.dart';
import '../widgets/qr_ticket_display.dart';

/// Ticket detail screen — e-ticket with QR code (PRD sections 4.6, 7.2 F).
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    this.ticketId,
  });

  final String? ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TicketProvider _ticketProvider = TicketProvider.instance;
  late String _effectiveTicketId;

  @override
  void initState() {
    super.initState();
    _effectiveTicketId = widget.ticketId ?? 'tkt-001-a';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      if (routeArg is String && routeArg.isNotEmpty) {
        _effectiveTicketId = routeArg;
      }
      _ticketProvider.loadTicket(_effectiveTicketId);
    });
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AppConstants.ticketStatusValid:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'VALID / SIAP CHECK-IN';
        break;
      case AppConstants.ticketStatusCheckedIn:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'SUDAH CHECK-IN';
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
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Ticket Resmi'),
      ),
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

          final ticket = _ticketProvider.selectedTicket;
          if (ticket == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('E-Ticket tidak ditemukan.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _ticketProvider.loadTicket(_effectiveTicketId),
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
                        color: Colors.black.withOpacity(0.08),
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
                          color: isValid ? AppTheme.primaryColor : Colors.grey.shade700,
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
                                const Text(
                                  'E-TICKET EVENT PASS',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ticket.ticketTypeId.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              ticket.attendeeName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
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
                              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            ),
                          ),
                          Positioned(
                            right: -12,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

                            // QR Display
                            QrTicketDisplay(
                              ticketData: ticket.token,
                              size: 190,
                            ),
                            const SizedBox(height: 20),

                            // Ticket Details List
                            _buildDetailRow('Event ID', ticket.eventId),
                            const SizedBox(height: 8),
                            _buildDetailRow('Order ID', ticket.orderId),
                            const SizedBox(height: 8),
                            if (ticket.issuedAt != null)
                              _buildDetailRow(
                                'Waktu Diterbitkan',
                                app_date.DateUtils.formatDateTime(ticket.issuedAt),
                              ),
                            if (ticket.isCheckedIn && ticket.checkedInAt != null) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                'Waktu Check-in',
                                app_date.DateUtils.formatDateTime(ticket.checkedInAt),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

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
                      const Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panduan Check-in di Lokasi Acara',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tingkatkan kecerahan layar smartphone Anda saat mendekati meja registrasi. Tunjukkan QR Code ini kepada panitia untuk dipindai sekali saat masuk.',
                              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade800),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}
