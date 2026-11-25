import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_operations_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  setUp(() {
    OrganizerOperationsRepository.instance.resetMockData();
  });

  group('T3-D3-02 — Attendee Operations Tahap 3 Unit Tests', () {
    test('Attendee model mem-parsing registration_number dan custom_fields', () {
      final json = {
        'id': 'att-custom-1',
        'attendee_name': 'Budi Siregar',
        'attendee_email': 'budi.siregar@example.com',
        'attendee_phone': '081234567890',
        'ticket_type': 'VIP Pass',
        'ticket_code': 'TK-VIP-099',
        'registration_number': 'REG-2026-VIP-001',
        'order_number': 'ORD-999',
        'order_status': 'PAID',
        'payment_status': 'PAID',
        'status': 'active',
        'custom_fields': {
          'Ukuran Kaos': 'XL',
          'Institusi': 'Universitas Indonesia',
        },
      };

      final attendee = OrganizerAttendee.fromJson(json, 'evt-test-1');

      expect(attendee.name, equals('Budi Siregar'));
      expect(attendee.registrationNumber, equals('REG-2026-VIP-001'));
      expect(attendee.orderId, equals('ORD-999'));
      expect(attendee.customFields['Ukuran Kaos'], equals('XL'));
      expect(attendee.customFields['Institusi'], equals('Universitas Indonesia'));
    });

    test('Data email dan nomor telepon disamarkan (masked) untuk privasi', () {
      final attendee = OrganizerAttendee(
        id: 'att-1',
        eventId: 'evt-1',
        name: 'Ahmad Fauzi',
        email: 'ahmad.fauzi@example.com',
        phone: '081234567890',
        ticketType: 'VIP',
        ticketCode: 'TK-01',
        orderId: 'ORD-01',
        registrationNumber: 'REG-01',
        registrationMethod: 'SELF_SERVICE',
        orderStatus: 'confirmed',
        paymentStatus: 'paid',
        ticketStatus: 'valid',
        checkedIn: false,
        createdAt: DateTime.now(),
      );

      expect(attendee.maskedEmail, equals('ah***@example.com'));
      expect(attendee.maskedPhone, equals('0812****7890'));
    });

    test('getAttendeesForEvent mengurutkan peserta dengan urutan paid-first', () {
      final repo = OrganizerOperationsRepository.instance;
      final attendees = repo.getAttendeesForEvent('evt-1001');

      expect(attendees.isNotEmpty, isTrue);

      bool foundNonPaid = false;
      for (final a in attendees) {
        final isPaid = a.paymentStatus.toLowerCase() == 'paid';
        if (!isPaid) {
          foundNonPaid = true;
        } else if (foundNonPaid) {
          fail('Ditemukan tiket PAID setelah tiket non-PAID (pelanggaran urutan paid-first)');
        }
      }
    });

    test('Staff tanpa VIEW_PARTICIPANTS tidak dapat melihat peserta', () {
      final staffRestricted = OrganizerMembershipContext.staff(
        userId: 'usr-staff-restricted',
        userName: 'Staf Gate Only',
        eventId: 'evt-1001',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.scanTicket,
        },
      );

      expect(
        staffRestricted.hasPermission(OrganizerPermission.viewParticipants),
        isFalse,
      );
    });
  });
}
