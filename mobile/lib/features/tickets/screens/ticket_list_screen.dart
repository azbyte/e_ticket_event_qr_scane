import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as app_date;
import '../../../providers/ticket_provider.dart';
import '../../events/screens/event_list_screen.dart';
import 'ticket_detail_screen.dart';

/// Ticket list screen (attendee ticket repository) — PRD section 3.1 #11.
class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketProvider _ticketProvider = TicketProvider.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ticketProvider.loadTickets();
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
        label = 'VALID / AKTIF';
        break;
      case AppConstants.ticketStatusCheckedIn:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'SUDAH CHECK-IN';
        break;
      case AppConstants.ticketStatusCancelled:
      case AppConstants.ticketStatusRevoked:
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'TIDAK AKTIF';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiket Saya'),
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

          if (_ticketProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      _ticketProvider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _ticketProvider.loadTickets(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tickets = _ticketProvider.tickets;

          if (tickets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 76, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Tiket',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Setelah Anda mendaftar atau menyelesaikan pembayaran event, tiket elektronik Anda akan otomatis muncul di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const EventListScreen()),
                        );
                      },
                      child: const Text('Jelajahi Event Sekarang'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _ticketProvider.loadTickets(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final ticket = tickets[index];

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top decorative accent
                        Container(
                          height: 6,
                          width: double.infinity,
                          color: ticket.isValid ? AppTheme.primaryColor : Colors.grey,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code_2, color: AppTheme.primaryColor, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        ticket.token,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  _buildStatusBadge(ticket.status),
                                ],
                              ),
                              const Divider(height: 20),
                              Text(
                                'Peserta: ${ticket.attendeeName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID Pesanan: ${ticket.orderId}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (ticket.issuedAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Diterbitkan: ${app_date.DateUtils.formatDateTime(ticket.issuedAt)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ticket.isValid ? 'Tunjukkan saat check-in' : 'Telah digunakan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ticket.isValid ? Colors.green.shade700 : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Tampilkan QR',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right, size: 18, color: AppTheme.primaryColor),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
