import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/services/organizer_operations/event_activity_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_operations_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  group('Developer 2 - Organizer Operations Unit & Flow Tests', () {
    late OrganizerOperationsRepository repo;
    late OrganizerMembershipContext ownerContext;
    late OrganizerMembershipContext gateStaffContext;
    late OrganizerMembershipContext restrictedStaffContext;

    setUp(() {
      repo = OrganizerOperationsRepository.instance;
      ownerContext = OrganizerMembershipContext.owner(
        userId: 'usr-org-001',
        userName: 'Penyelenggara Tech (Owner)',
        eventId: 'evt-001',
      );
      gateStaffContext = OrganizerMembershipContext.staff(
        userId: 'usr-stf-002',
        userName: 'Siti Rahma (Staf Pintu)',
        eventId: 'evt-001',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.scanTicket,
          OrganizerPermission.checkInTicket,
          OrganizerPermission.viewScanHistory,
        },
      );
      restrictedStaffContext = OrganizerMembershipContext.staff(
        userId: 'usr-stf-003',
        userName: 'Doni (Staf Terbatas)',
        eventId: 'evt-001',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.viewParticipants,
        },
      );
    });

    test('1. Attendee filtering, searching, and data minimization compliance (FR-67-69)', () {
      final attendees = repo.getAttendeesForEvent('evt-001');
      expect(attendees.isNotEmpty, isTrue);

      // Verify data minimization
      final attendee = attendees.first;
      expect(attendee.maskedEmail, contains('***@'));
      expect(attendee.maskedPhone, contains('****'));
      expect(attendee.email, isNot(equals(attendee.maskedEmail)));

      // Search by name
      final searchResult = repo.getAttendeesForEvent('evt-001', search: 'Ahmad');
      expect(searchResult.any((a) => a.name.contains('Ahmad')), isTrue);

      // Filter by check-in status
      final checkedInOnly = repo.getAttendeesForEvent('evt-001', filterStatus: 'checked_in');
      for (final a in checkedInOnly) {
        expect(a.checkedIn, isTrue);
      }

      // Isolation from other events
      final otherEventAttendees = repo.getAttendeesForEvent('evt-999');
      expect(otherEventAttendees.isEmpty, isTrue);
    });

    test('2. Assisted Registration validation, VA creation, and pending status (FR-30-35)', () {
      // Rejects empty orderer
      final emptyResult = repo.createAssistedRegistration(
        eventId: 'evt-001',
        ordererName: '',
        ordererEmail: '',
        ordererPhone: '',
        ticketType: 'Regular Pass',
        unitPrice: 350000,
        attendeeDetails: [],
        actorId: ownerContext.userId,
        actorName: ownerContext.userName,
      );
      expect(emptyResult.isSuccess, isFalse);

      // Rejects duplicate attendee email in same order
      final duplicateResult = repo.createAssistedRegistration(
        eventId: 'evt-001',
        ordererName: 'Hendra Gunawan',
        ordererEmail: 'hendra@example.com',
        ordererPhone: '081233445566',
        ticketType: 'Regular Pass',
        unitPrice: 350000,
        attendeeDetails: [
          {'name': 'Peserta 1', 'email': 'same@example.com', 'phone': '081111111'},
          {'name': 'Peserta 2', 'email': 'same@example.com', 'phone': '082222222'},
        ],
        actorId: ownerContext.userId,
        actorName: ownerContext.userName,
      );
      expect(duplicateResult.isSuccess, isFalse);
      expect(duplicateResult.message, contains('Duplikasi email'));

      // Successfully creates assisted order with Virtual Account & pending payment status
      final successResult = repo.createAssistedRegistration(
        eventId: 'evt-001',
        ordererName: 'Bambang Sudiro',
        ordererEmail: 'bambang.sudiro@example.com',
        ordererPhone: '081555667788',
        ticketType: 'Regular Pass',
        unitPrice: 350000,
        attendeeDetails: [
          {'name': 'Bambang Sudiro', 'email': 'bambang.sudiro@example.com', 'phone': '081555667788'},
        ],
        actorId: ownerContext.userId,
        actorName: ownerContext.userName,
      );

      expect(successResult.isSuccess, isTrue);
      expect(successResult.vaNumber, isNotNull);
      expect(successResult.vaExpiry, isNotNull);
      expect(successResult.orderId, isNotNull);

      // Ensure ticket & payment is strictly PENDING, not falsely marked paid
      final createdAttendee = successResult.createdAttendees.first;
      expect(createdAttendee.registrationMethod, equals('ASSISTED'));
      expect(createdAttendee.paymentStatus, equals('pending'));
      expect(createdAttendee.orderStatus, equals('pending'));
      expect(createdAttendee.checkedIn, isFalse);
      expect(createdAttendee.assistedBy, equals(ownerContext.userName));
    });

    test('3. Scanner validation & edge cases (valid, already used, wrong event, cancelled, invalid)', () {
      // Permission Denied Check
      final deniedResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-003',
        context: restrictedStaffContext, // Lacks SCAN_TICKET
      );
      expect(deniedResult.isSuccess, isFalse);
      expect(deniedResult.status, equals('DENIED'));

      // Invalid QR code
      final invalidResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'INV-999',
        context: gateStaffContext,
      );
      expect(invalidResult.isSuccess, isFalse);
      expect(invalidResult.status, equals('INVALID_CODE'));

      // Ticket for wrong event
      final wrongEventResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-WRONG-999',
        context: gateStaffContext,
      );
      expect(wrongEventResult.isSuccess, isFalse);
      expect(wrongEventResult.status, equals('WRONG_EVENT'));

      // Cancelled ticket
      final cancelledResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-006',
        context: gateStaffContext,
      );
      expect(cancelledResult.isSuccess, isFalse);
      expect(cancelledResult.status, equals('CANCELLED'));

      // Already checked-in ticket (TK-TECH-001 is already checked in in mock fixture)
      final usedResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-001',
        context: gateStaffContext,
      );
      expect(usedResult.isSuccess, isFalse);
      expect(usedResult.status, equals('ALREADY_CHECKED_IN'));

      // Valid ticket check-in (TK-TECH-003 is valid and unchecked)
      final validResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-003',
        context: gateStaffContext,
      );
      expect(validResult.isSuccess, isTrue);
      expect(validResult.status, equals('VALID'));
      expect(validResult.attendee?.checkedIn, isTrue);
      expect(validResult.attendee?.checkedInBy, equals(gateStaffContext.userName));

      // Re-scan same ticket must now fail
      final reScanResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-003',
        context: gateStaffContext,
      );
      expect(reScanResult.isSuccess, isFalse);
      expect(reScanResult.status, equals('ALREADY_CHECKED_IN'));
    });

    test('4. Offline scanner queueing and sync conflict resolution', () {
      repo.toggleOfflineMode(true);
      expect(repo.isOfflineModeEnabled, isTrue);

      // Offline check-in on TK-TECH-004
      final offlineResult = repo.validateAndCheckIn(
        eventId: 'evt-001',
        ticketCode: 'TK-TECH-004',
        context: gateStaffContext,
      );

      expect(offlineResult.isSuccess, isTrue);
      expect(offlineResult.isOfflineQueued, isTrue);
      expect(offlineResult.status, equals('OFFLINE_QUEUED'));
      expect(repo.offlineQueue.length, greaterThanOrEqualTo(1));

      // Sync offline queue
      final syncSummary = repo.syncOfflineQueue('evt-001');
      expect(syncSummary['synced'], greaterThanOrEqualTo(1));

      repo.toggleOfflineMode(false);
      expect(repo.isOfflineModeEnabled, isFalse);
    });

    test('5. Financial metrics isolation (Gross vs Commission vs Gateway vs Proceeds)', () {
      final report = repo.getEventReport('evt-001');

      expect(report.eventId, equals('evt-001'));
      expect(report.totalOrders, greaterThan(0));
      expect(report.totalTicketsSold, greaterThan(0));
      expect(report.grossSales, greaterThan(0));
      expect(report.platformCommission, greaterThan(0));
      expect(report.paymentGatewayFee, greaterThan(0));

      // Strict PRD 13.3 math check: Organizer Proceeds = Gross - Commission - Gateway
      final calculatedProceeds = report.grossSales - report.platformCommission - report.paymentGatewayFee;
      expect(report.organizerProceeds, closeTo(calculatedProceeds, 0.01));

      // Package revenue is isolated
      expect(report.packageRevenue, equals(500000.0));
    });

    test('6. CSV export permission enforcement and data minimization', () {
      // Restricted staff should be denied export
      expect(
        () => repo.exportAttendeesCsv('evt-001', restrictedStaffContext),
        throwsA(isA<Exception>()),
      );

      // Owner should successfully generate CSV
      final csv = repo.exportAttendeesCsv('evt-001', ownerContext);
      expect(csv, contains('ID,Nama,Email,No_HP,Kategori_Tiket,Kode_Tiket'));
      expect(csv, contains('***@')); // Masked email
      expect(csv, contains('****')); // Masked phone
    });

    test('7. Event Activity Logger API records operational actions', () {
      final initialCount = EventActivityLogger.instance
          .getActivitiesForEvent('evt-001')
          .length;

      EventActivityLogger.instance.log(
        eventId: 'evt-001',
        actorId: 'usr-org-001',
        actorName: 'Penyelenggara Tech',
        action: 'UPDATE_EVENT_SCHEDULE',
        summary: 'Mengubah jadwal sesi keynote pada event.',
      );

      final updatedCount = EventActivityLogger.instance
          .getActivitiesForEvent('evt-001')
          .length;
      expect(updatedCount, equals(initialCount + 1));

      final latest = EventActivityLogger.instance
          .getActivitiesForEvent('evt-001')
          .first;
      expect(latest.action, equals('UPDATE_EVENT_SCHEDULE'));
      expect(latest.summary, contains('keynote'));
    });
  });
}
