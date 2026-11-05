/// Organizer attendee & order detail screen (PRD sections 4.9 & FR-67–69).
///
/// Displays attendee details with minimum sensitive data exposure (masked email/phone),
/// distinct ticket/order/check-in statuses, and attribution tracking.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/organizer_operations/organizer_operations_repository.dart';
import '../../../services/organizer_operations/organizer_permission.dart';

class OrganizerAttendeeDetailScreen extends StatelessWidget {
  const OrganizerAttendeeDetailScreen({
    super.key,
    required this.attendee,
    required this.contextScope,
  });

  final OrganizerAttendee attendee;
  final OrganizerMembershipContext contextScope;

  @override
  Widget build(BuildContext context) {
    final canViewOrders =
        contextScope.hasPermission(OrganizerPermission.viewOrders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Peserta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attendee.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attendee.maskedEmail,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          Text(
                            attendee.maskedPhone,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ticket & Status Section
            const Text(
              'Status Tiket & Check-in',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow('Kategori Tiket', attendee.ticketType),
                    const Divider(),
                    _buildRow('Kode Tiket QR', attendee.ticketCode),
                    const Divider(),
                    _buildRow('Status Tiket', attendee.ticketStatus.toUpperCase(),
                        valueColor: attendee.ticketStatus == 'valid'
                            ? Colors.green
                            : attendee.ticketStatus == 'checked_in'
                                ? Colors.blue
                                : Colors.red),
                    const Divider(),
                    _buildRow(
                      'Status Check-in',
                      attendee.checkedIn ? 'SUDAH CHECK-IN' : 'BELUM CHECK-IN',
                      valueColor: attendee.checkedIn ? Colors.blue : Colors.orange,
                    ),
                    if (attendee.checkedIn) ...[
                      const Divider(),
                      _buildRow(
                        'Waktu Check-in',
                        '${attendee.checkedInAt?.hour}:${attendee.checkedInAt?.minute.toString().padLeft(2, '0')} WIB',
                      ),
                      const Divider(),
                      _buildRow(
                        'Staf Pemeriksa',
                        attendee.checkedInBy ?? 'Staf Event',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Order & Method Section
            const Text(
              'Informasi Pesanan & Registrasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow('Nomor Pesanan', canViewOrders ? attendee.orderId : 'ORD-**** (Izin VIEW_ORDERS Diperlukan)'),
                    const Divider(),
                    _buildRow(
                      'Metode Registrasi',
                      attendee.registrationMethod == 'ASSISTED'
                          ? 'DIBANTU PANITIA (ASSISTED)'
                          : 'MANDIRI (SELF-SERVICE)',
                      valueColor: attendee.registrationMethod == 'ASSISTED'
                          ? Colors.purple
                          : Colors.indigo,
                    ),
                    if (attendee.assistedBy != null) ...[
                      const Divider(),
                      _buildRow('Didaftarkan Oleh', attendee.assistedBy!),
                    ],
                    const Divider(),
                    _buildRow('Status Pembayaran', attendee.paymentStatus.toUpperCase()),
                    const Divider(),
                    _buildRow('Tanggal Registrasi', '${attendee.createdAt.day}/${attendee.createdAt.month}/${attendee.createdAt.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sensitive data notice
            Center(
              child: Text(
                'Data email dan nomor telepon disamarkan (masked) sesuai prinsip kepatuhan privasi PRD section 4.9.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

