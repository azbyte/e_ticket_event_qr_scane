/// Organizer event membership and granular permission service (PRD section 2.3, 4.8, FR-60–65).
///
/// Implements Owner and Staff per-event membership, invitations, expiration,
/// acceptance, granular permission management, and revocation without global role pollution.
library;

import '../../core/config/app_config.dart';
import '../api/api_service.dart';
import '../organizer_operations/organizer_permission.dart';

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

  /// Tautan undangan kanonik (`invite_url`) yang dikembalikan backend saat
  /// undangan dibuat. `null` untuk anggota yang sudah aktif.
  final String? inviteUrl;

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
    this.inviteUrl,
  });

  bool get isOwner => memberRole == 'owner';
  bool get isStaff => memberRole == 'staff';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isExpired =>
      status == 'expired' || DateTime.now().isAfter(expiresAt);

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
      inviteUrl: inviteUrl,
    );
  }

  /// Anggota event dari response `GET /api/events/:id/members`.
  factory EventMemberModel.fromMemberJson(
    Map<String, dynamic> json, {
    required String eventId,
    String eventTitle = '',
    String memberRole = 'staff',
    String status = 'accepted',
  }) {
    final permissions = (json['permissions'] as List? ?? const [])
        .map((code) => OrganizerPermission.fromCode(code.toString()))
        .whereType<OrganizerPermission>()
        .toSet();
    return EventMemberModel(
      id: (json['member_id'] ?? json['id'] ?? '').toString(),
      eventId: eventId,
      eventTitle: eventTitle,
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? json['username'] ?? '').toString(),
      memberRole: memberRole,
      status: status,
      permissions: permissions,
      invitedAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      joinedAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
  }

  /// Anggota event dari response `GET /api/me/memberships`.
  factory EventMemberModel.fromMembershipJson(Map<String, dynamic> json) {
    final permissions = (json['permissions'] as List? ?? const [])
        .map((code) => OrganizerPermission.fromCode(code.toString()))
        .whereType<OrganizerPermission>()
        .toSet();
    final role = (json['role'] ?? 'staff').toString().toLowerCase();
    final rawStatus = (json['status'] ?? 'ACTIVE').toString().toLowerCase();
    final expiresAt = DateTime.tryParse((json['expires_at'] ?? '').toString()) ??
        DateTime.now().add(const Duration(days: 365));
    return EventMemberModel(
      id: (json['member_id'] ?? json['event_id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      eventTitle: (json['event_title'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['event_title'] ?? '').toString(),
      memberRole: role,
      status: rawStatus == 'active' ? 'accepted' : rawStatus,
      permissions: permissions,
      invitedAt: DateTime.tryParse((json['joined_at'] ?? '').toString()) ??
          DateTime.now(),
      joinedAt: DateTime.tryParse((json['joined_at'] ?? '').toString()),
      expiresAt: expiresAt,
    );
  }
}

class OrganizerMembershipService {
  /// `api`/`mockMode` dapat diinjeksi untuk pengujian. Default memakai API
  /// backend; data demo hanya aktif bila `MOCK_MODE=true`.
  OrganizerMembershipService({ApiService? api, bool? mockMode})
      : _api = api ?? ApiService(),
        _useMock = mockMode ?? AppConfig.mockMode;

  static final OrganizerMembershipService instance =
      OrganizerMembershipService();

  final ApiService _api;
  final bool _useMock;

  // In-memory mock database for event memberships
  static final List<EventMemberModel> _mockMembers = [
    EventMemberModel(
      id: 'mem-001',
      eventId: 'evt-1001',
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
      eventId: 'evt-1001',
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
      eventId: 'evt-1001',
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
      eventId: 'evt-1001',
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
      eventTitle: 'Webinar Produk Digital 2026',
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
  Future<List<EventMemberModel>> listMembers(
    String eventId, {
    String eventTitle = '',
  }) async {
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return List<EventMemberModel>.unmodifiable(
        _mockMembers.where((m) => m.eventId == eventId),
      );
    }

    final response = await _api.get('/events/$eventId/members');
    final rows = (response['members'] as List?) ?? const [];
    return List<EventMemberModel>.unmodifiable(
      rows.map(
        (row) => EventMemberModel.fromMemberJson(
          Map<String, dynamic>.from(row as Map),
          eventId: eventId,
          eventTitle: eventTitle,
        ),
      ),
    );
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
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final newMember = EventMemberModel(
        id: 'mem-${DateTime.now().microsecondsSinceEpoch}',
        eventId: eventId,
        eventTitle: eventTitle,
        userId: '',
        email: email,
        name: name.isNotEmpty ? name : email.split('@').first,
        memberRole: 'staff',
        status: 'pending',
        permissions: Set<OrganizerPermission>.unmodifiable(permissions),
        invitedAt: DateTime.now(),
        joinedAt: null,
        expiresAt: DateTime.now().add(Duration(days: expiryDays)),
      );
      _mockMembers.add(newMember);
      return newMember;
    }

    final expiresAt = DateTime.now().add(Duration(days: expiryDays));
    final response = await _api.post(
      '/events/$eventId/invitations',
      body: {
        'email': email,
        'name': name,
        'permissions': permissions.map((p) => p.code).toList(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    );
    final invitation =
        Map<String, dynamic>.from(response['invitation'] as Map? ?? const {});
    return EventMemberModel(
      id: (invitation['id'] ?? '').toString(),
      eventId: eventId,
      eventTitle: eventTitle,
      userId: '',
      email: (invitation['email'] ?? email).toString(),
      name: name.isNotEmpty ? name : email.split('@').first,
      memberRole: 'staff',
      status: 'pending',
      permissions: Set<OrganizerPermission>.unmodifiable(permissions),
      invitedAt: DateTime.now(),
      joinedAt: null,
      expiresAt: DateTime.tryParse((invitation['expires_at'] ?? '').toString()) ??
          expiresAt,
      inviteUrl: invitation['invite_url']?.toString(),
    );
  }

  /// Updates staff permissions for an event.
  ///
  /// Backend mengunci permission per `user_id` event member, sehingga `userId`
  /// diperlukan pada mode API (dapat diambil dari [EventMemberModel.userId]).
  Future<bool> updatePermissions({
    required String eventId,
    required String memberId,
    required Set<OrganizerPermission> permissions,
    String userId = '',
  }) async {
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final idx = _mockMembers.indexWhere(
        (m) => m.id == memberId && m.eventId == eventId,
      );
      if (idx != -1 && !_mockMembers[idx].isOwner && _mockMembers[idx].isStaff) {
        _mockMembers[idx] = _mockMembers[idx].copyWith(
          permissions: Set<OrganizerPermission>.unmodifiable(permissions),
        );
        return true;
      }
      return false;
    }

    var targetUserId = userId;
    if (targetUserId.isEmpty) {
      final members = await listMembers(eventId);
      for (final member in members) {
        if (member.id == memberId) {
          targetUserId = member.userId;
          break;
        }
      }
    }
    if (targetUserId.isEmpty) return false;

    await _api.put(
      '/events/$eventId/members/$targetUserId/permissions',
      body: {'permissions': permissions.map((p) => p.code).toList()},
    );
    return true;
  }

  /// Revokes staff access from an event.
  Future<bool> revokeAccess({
    required String eventId,
    required String memberId,
    String userId = '',
  }) async {
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final idx = _mockMembers.indexWhere(
        (m) => m.id == memberId && m.eventId == eventId,
      );
      if (idx != -1 && !_mockMembers[idx].isOwner && _mockMembers[idx].isStaff) {
        _mockMembers.removeAt(idx);
        return true;
      }
      return false;
    }

    var targetUserId = userId;
    if (targetUserId.isEmpty) {
      final members = await listMembers(eventId);
      for (final member in members) {
        if (member.id == memberId) {
          targetUserId = member.userId;
          break;
        }
      }
    }
    if (targetUserId.isEmpty) return false;

    await _api.delete('/events/$eventId/members/$targetUserId');
    return true;
  }

  /// Returns active events where user is assigned as Staff.
  Future<List<EventMemberModel>> getAssignedActiveEvents(
    String userEmailOrId,
  ) async {
    if (_useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return List<EventMemberModel>.unmodifiable(
        _mockMembers.where((m) {
          final matchesUser =
              m.userId == userEmailOrId || m.email == userEmailOrId;
          return matchesUser && m.isStaff && m.isAccepted && !m.isExpired;
        }),
      );
    }

    // Mode API: `GET /api/me/memberships` mengembalikan event yang diikuti
    // pengguna yang sedang login, lengkap dengan permission-nya.
    final response = await _api.get('/me/memberships');
    final rows = (response['memberships'] as List?) ?? const [];
    return List<EventMemberModel>.unmodifiable(
      rows
          .map(
            (row) =>
                EventMemberModel.fromMembershipJson(Map<String, dynamic>.from(row as Map)),
          )
          .where((m) => !m.isExpired),
    );
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
