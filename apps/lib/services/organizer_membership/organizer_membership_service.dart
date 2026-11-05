/// Organizer event membership and granular permission service (PRD section 2.3, 4.8, FR-60–65).
///
/// Implements Owner and Staff per-event membership, invitations, expiration,
/// acceptance, granular permission management, and revocation without global role pollution.
library;

import '../../core/config/app_config.dart';

/// Granular permissions for event staff per PRD Section 2.3 & FR-60.
enum OrganizerPermission {
  viewEvent('VIEW_EVENT', 'Melihat detail event'),
  viewParticipants('VIEW_PARTICIPANTS', 'Melihat daftar peserta'),
  assistRegistration('ASSIST_REGISTRATION', 'Melakukan registrasi dibantu'),
  viewOrders('VIEW_ORDERS', 'Melihat pesanan tiket'),
  scanTicket('SCAN_TICKET', 'Memindai QR tiket'),
  checkInTicket('CHECK_IN_TICKET', 'Melakukan konfirmasi check-in'),
  viewScanHistory('VIEW_SCAN_HISTORY', 'Melihat riwayat scan'),
  viewReports('VIEW_REPORTS', 'Melihat laporan event'),
  exportParticipants('EXPORT_PARTICIPANTS', 'Mengekspor data peserta');

  const OrganizerPermission(this.code, this.label);
  final String code;
  final String label;

  static OrganizerPermission? fromCode(String code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }
}

/// Event member entity representing Owner or Staff membership on an event.
class EventMemberModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final String userId;
  final String email;
  final String name;
  final String memberRole; // 'owner' or 'staff'
  final String status; // 'accepted', 'pending', 'expired', 'revoked'
  final Set<OrganizerPermission> permissions;
  final DateTime invitedAt;
  final DateTime? joinedAt;
  final DateTime expiresAt;

  const EventMemberModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.email,
    required this.name,
    required this.memberRole,
    required this.status,
    required this.permissions,
    required this.invitedAt,
    this.joinedAt,
    required this.expiresAt,
  });

  bool get isOwner => memberRole == 'owner';
  bool get isStaff => memberRole == 'staff';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isExpired => status == 'expired' || DateTime.now().isAfter(expiresAt);

  bool hasPermission(OrganizerPermission permission) {
    if (isOwner) return true;
    return isAccepted && permissions.contains(permission);
  }

  EventMemberModel copyWith({
    String? status,
    Set<OrganizerPermission>? permissions,
    DateTime? joinedAt,
  }) {
    return EventMemberModel(
      id: id,
      eventId: eventId,
      eventTitle: eventTitle,
      userId: userId,
      email: email,
      name: name,
      memberRole: memberRole,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      invitedAt: invitedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      expiresAt: expiresAt,
    );
  }
}

class OrganizerMembershipService {
  OrganizerMembershipService._internal();
  static final OrganizerMembershipService instance = OrganizerMembershipService._internal();
  factory OrganizerMembershipService() => instance;

  // In-memory mock database for event memberships
  static final List<EventMemberModel> _mockMembers = [
    EventMemberModel(
      id: 'mem-001',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      userId: 'usr-org-01',
      email: 'organizer@techsummit.id',
      name: 'PT Event Nusantara',
      memberRole: 'owner',
      status: 'accepted',
      permissions: OrganizerPermission.values.toSet(),
      invitedAt: DateTime.now().subtract(const Duration(days: 30)),
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    ),
    EventMemberModel(
      id: 'mem-002',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      userId: 'usr-staff-01',
      email: 'budi.santoso@eventcrew.id',
      name: 'Budi Santoso',
      memberRole: 'staff',
      status: 'accepted',
      permissions: {
        OrganizerPermission.viewEvent,
        OrganizerPermission.viewParticipants,
        OrganizerPermission.scanTicket,
        OrganizerPermission.checkInTicket,
        OrganizerPermission.viewScanHistory,
      },
      invitedAt: DateTime.now().subtract(const Duration(days: 5)),
      joinedAt: DateTime.now().subtract(const Duration(days: 4)),
      expiresAt: DateTime.now().add(const Duration(days: 60)),
    ),
    EventMemberModel(
      id: 'mem-003',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      userId: 'usr-staff-02',
      email: 'siti.rahma@eventcrew.id',
      name: 'Siti Rahma',
      memberRole: 'staff',
      status: 'accepted',
      permissions: {
        OrganizerPermission.viewEvent,
        OrganizerPermission.viewParticipants,
        OrganizerPermission.assistRegistration,
        OrganizerPermission.viewOrders,
      },
      invitedAt: DateTime.now().subtract(const Duration(days: 3)),
      joinedAt: DateTime.now().subtract(const Duration(days: 2)),
      expiresAt: DateTime.now().add(const Duration(days: 60)),
    ),
    EventMemberModel(
      id: 'mem-004',
      eventId: 'evt-001',
      eventTitle: 'Tech Innovation Summit 2026',
      userId: '',
      email: 'dimas.panitia@eventcrew.id',
      name: 'Dimas Setiawan',
      memberRole: 'staff',
      status: 'pending',
      permissions: {
        OrganizerPermission.viewEvent,
        OrganizerPermission.scanTicket,
        OrganizerPermission.checkInTicket,
      },
      invitedAt: DateTime.now().subtract(const Duration(days: 1)),
      joinedAt: null,
      expiresAt: DateTime.now().add(const Duration(days: 6)),
    ),
    EventMemberModel(
      id: 'mem-005',
      eventId: 'evt-002',
      eventTitle: 'Workshop Flutter & Backend Modern',
      userId: 'usr-staff-01',
      email: 'budi.santoso@eventcrew.id',
      name: 'Budi Santoso',
      memberRole: 'staff',
      status: 'accepted',
      permissions: {
        OrganizerPermission.viewEvent,
        OrganizerPermission.scanTicket,
        OrganizerPermission.checkInTicket,
        OrganizerPermission.viewScanHistory,
      },
      invitedAt: DateTime.now().subtract(const Duration(days: 2)),
      joinedAt: DateTime.now().subtract(const Duration(days: 1)),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    ),
  ];

  /// Lists all members (Owner and Staff) for a given event.
  Future<List<EventMemberModel>> listMembers(String eventId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _mockMembers.where((m) => m.eventId == eventId).toList();
    }
    return _mockMembers.where((m) => m.eventId == eventId).toList();
  }

  /// Invites a new staff member with specified permissions and 7-day expiration.
  Future<EventMemberModel> inviteStaff({
    required String eventId,
    required String eventTitle,
    required String email,
    required String name,
    required Set<OrganizerPermission> permissions,
    int expiryDays = 7,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final newMember = EventMemberModel(
        id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
        eventId: eventId,
        eventTitle: eventTitle,
        userId: '',
        email: email,
        name: name.isNotEmpty ? name : email.split('@').first,
        memberRole: 'staff',
        status: 'pending',
        permissions: permissions,
        invitedAt: DateTime.now(),
        joinedAt: null,
        expiresAt: DateTime.now().add(Duration(days: expiryDays)),
      );
      _mockMembers.add(newMember);
      return newMember;
    }
    throw UnimplementedError('API mode is not enabled in Phase 0.');
  }

  /// Updates staff permissions for an event.
  Future<bool> updatePermissions({
    required String eventId,
    required String memberId,
    required Set<OrganizerPermission> permissions,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final idx = _mockMembers.indexWhere((m) => m.id == memberId && m.eventId == eventId);
      if (idx != -1 && !_mockMembers[idx].isOwner) {
        _mockMembers[idx] = _mockMembers[idx].copyWith(permissions: permissions);
        return true;
      }
      return false;
    }
    return true;
  }

  /// Revokes staff access from an event.
  Future<bool> revokeAccess({
    required String eventId,
    required String memberId,
  }) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final idx = _mockMembers.indexWhere((m) => m.id == memberId && m.eventId == eventId);
      if (idx != -1 && !_mockMembers[idx].isOwner) {
        _mockMembers.removeAt(idx);
        return true;
      }
      return false;
    }
    return true;
  }

  /// Returns active events where user is assigned as Staff.
  Future<List<EventMemberModel>> getAssignedActiveEvents(String userEmailOrId) async {
    if (AppConfig.mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _mockMembers.where((m) {
        final matchesUser = m.userId == userEmailOrId || m.email == userEmailOrId;
        return matchesUser && m.isStaff && m.isAccepted && !m.isExpired;
      }).toList();
    }
    return [];
  }

  /// Checks if user has a specific permission on an event.
  Future<bool> checkPermission({
    required String eventId,
    required String userEmailOrId,
    required OrganizerPermission permission,
  }) async {
    final members = await listMembers(eventId);
    for (final m in members) {
      if (m.userId == userEmailOrId || m.email == userEmailOrId) {
        return m.hasPermission(permission);
      }
    }
    return false;
  }
}
