import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_operations_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  setUp(() {
    OrganizerOperationsRepository.instance.resetMockData();
  });

  group('T3-D3-03 — Attendee Export CSV Tahap 3 Tests', () {
    test('Staff tanpa izin EXPORT_PARTICIPANTS ditolak saat mengekspor', () async {
      final repo = OrganizerOperationsRepository.instance;
      final staffWithoutExport = OrganizerMembershipContext.staff(
        userId: 'usr-stf-no-exp',
        userName: 'Staf Gate',
        eventId: 'evt-1001',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.viewParticipants,
        },
      );

      expect(
        () => repo.exportAttendeesCsv('evt-1001', staffWithoutExport),
        throwsA(isA<Exception>()),
      );

      expect(
        () async => await repo.exportAttendeesCsvFromApi('evt-1001', staffWithoutExport),
        throwsA(isA<Exception>()),
      );
    });

    test('Organizer dengan EXPORT_PARTICIPANTS dapat mengekspor CSV dengan header yang benar', () {
      final repo = OrganizerOperationsRepository.instance;
      final ownerContext = OrganizerMembershipContext.owner(
        userId: 'usr-org-001',
        userName: 'Owner Organizer',
        eventId: 'evt-1001',
      );

      final csv = repo.exportAttendeesCsv('evt-1001', ownerContext);

      expect(csv.isNotEmpty, isTrue);
      final lines = csv.split('\n');
      expect(lines.length, greaterThan(1));

      final header = lines.first.trim();
      expect(header, contains('Nama'));
      expect(header, contains('Email'));
      expect(header, contains('No_HP'));
      expect(header, contains('Kode_Tiket'));
      expect(header, contains('No_Pesanan'));
      expect(header, contains('Status_Tiket'));
    });

    test('Data email dan telepon dalam CSV terlindungi dengan masking', () {
      final repo = OrganizerOperationsRepository.instance;
      final ownerContext = OrganizerMembershipContext.owner(
        userId: 'usr-org-001',
        userName: 'Owner Organizer',
        eventId: 'evt-1001',
      );

      final csv = repo.exportAttendeesCsv('evt-1001', ownerContext);

      expect(csv, contains('***@'));
      expect(csv, contains('****'));
    });
  });
}
