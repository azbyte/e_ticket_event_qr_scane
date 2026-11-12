import 'package:flutter_test/flutter_test.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_membership/organizer_membership_service.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_operations/organizer_permission.dart';

void main() {
  group('OrganizerMembershipService & Granular Permissions (FR-60–65)', () {
    late OrganizerMembershipService service;

    setUp(() {
      service = OrganizerMembershipService.instance;
    });

    test('Owner member has all permissions unconditionally', () {
      final owner = EventMemberModel(
        id: 'mem-test-owner',
        eventId: 'evt-test-1',
        eventTitle: 'Event Testing',
        userId: 'usr-owner-1',
        email: 'owner@test.id',
        name: 'Event Owner',
        memberRole: 'owner',
        status: 'accepted',
        permissions: {},
        invitedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(owner.isOwner, isTrue);
      expect(owner.hasPermission(OrganizerPermission.scanTicket), isTrue);
      expect(owner.hasPermission(OrganizerPermission.viewReports), isTrue);
      expect(owner.hasPermission(OrganizerPermission.exportParticipants), isTrue);
    });

    test('Staff member only has explicitly granted permissions', () {
      final staff = EventMemberModel(
        id: 'mem-test-staff',
        eventId: 'evt-test-1',
        eventTitle: 'Event Testing',
        userId: 'usr-staff-1',
        email: 'staff@test.id',
        name: 'Event Staff',
        memberRole: 'staff',
        status: 'accepted',
        permissions: {
          OrganizerPermission.scanTicket,
          OrganizerPermission.checkInTicket,
        },
        invitedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      expect(staff.isStaff, isTrue);
      expect(staff.hasPermission(OrganizerPermission.scanTicket), isTrue);
      expect(staff.hasPermission(OrganizerPermission.checkInTicket), isTrue);
      expect(staff.hasPermission(OrganizerPermission.viewReports), isFalse);
      expect(staff.hasPermission(OrganizerPermission.assistRegistration), isFalse);
    });

    test('inviteStaff creates pending member with 7-day expiration', () async {
      final newStaff = await service.inviteStaff(
        eventId: 'evt-1001',
        eventTitle: 'Tech Innovation Summit 2026',
        email: 'tester.crew@event.id',
        name: 'Tester Crew',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.scanTicket,
        },
        expiryDays: 7,
      );

      expect(newStaff.isPending, isTrue);
      expect(newStaff.status, equals('pending'));
      expect(newStaff.email, equals('tester.crew@event.id'));
      expect(newStaff.permissions.contains(OrganizerPermission.scanTicket), isTrue);
      expect(newStaff.isExpired, isFalse);
      expect(newStaff.expiresAt.difference(newStaff.invitedAt).inDays, equals(7));
    });

    test('updatePermissions updates staff permission set successfully', () async {
      final success = await service.updatePermissions(
        eventId: 'evt-1001',
        memberId: 'mem-002',
        permissions: {
          OrganizerPermission.viewEvent,
          OrganizerPermission.scanTicket,
          OrganizerPermission.checkInTicket,
          OrganizerPermission.viewReports,
        },
      );

      expect(success, isTrue);
      final members = await service.listMembers('evt-1001');
      final budi = members.firstWhere((m) => m.id == 'mem-002');
      expect(budi.permissions.contains(OrganizerPermission.viewReports), isTrue);
    });

    test('getAssignedActiveEvents filters only accepted, non-expired staff events', () async {
      final assigned = await service.getAssignedActiveEvents('budi.santoso@eventcrew.id');
      expect(assigned.isNotEmpty, isTrue);
      for (final event in assigned) {
        expect(event.isStaff, isTrue);
        expect(event.isAccepted, isTrue);
        expect(event.isExpired, isFalse);
      }
    });

    test('revokeAccess removes staff membership', () async {
      final invited = await service.inviteStaff(
        eventId: 'evt-1001',
        eventTitle: 'Tech Innovation Summit 2026',
        email: 'to.revoke@event.id',
        name: 'Revoke Candidate',
        permissions: {OrganizerPermission.scanTicket},
      );

      final revokeOk = await service.revokeAccess(
        eventId: 'evt-1001',
        memberId: invited.id,
      );
      expect(revokeOk, isTrue);

      final members = await service.listMembers('evt-1001');
      expect(members.any((m) => m.id == invited.id), isFalse);
    });
  });
}
