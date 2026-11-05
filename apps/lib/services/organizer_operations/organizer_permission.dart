/// Granular permissions for Organizer event operations per PRD sections 2, 4.9, 13 & PEMBAGIAN_TUGAS_2.
library;

enum OrganizerPermission {
  viewEvent('VIEW_EVENT', 'Melihat Informasi Event'),
  viewParticipants('VIEW_PARTICIPANTS', 'Melihat Daftar Peserta'),
  assistRegistration('ASSIST_REGISTRATION', 'Melakukan Registrasi Dibantu'),
  viewOrders('VIEW_ORDERS', 'Melihat Rincian Pesanan'),
  scanTicket('SCAN_TICKET', 'Memindai QR Tiket'),
  checkInTicket('CHECK_IN_TICKET', 'Mengonfirmasi Check-in'),
  viewScanHistory('VIEW_SCAN_HISTORY', 'Melihat Riwayat Check-in'),
  viewReports('VIEW_REPORTS', 'Melihat Laporan & Statistik'),
  exportParticipants('EXPORT_PARTICIPANTS', 'Mengekspor Data Peserta');

  const OrganizerPermission(this.code, this.label);

  final String code;
  final String label;

  static OrganizerPermission? fromCode(String code) {
    for (final perm in OrganizerPermission.values) {
      if (perm.code == code) return perm;
    }
    return null;
  }
}

/// Represents the active user's role and permission scope within an event.
///
/// In accordance with PRD: Owner has full privileges for their event.
/// Staff only has granular permissions explicitly assigned by the Owner.
class OrganizerMembershipContext {
  const OrganizerMembershipContext({
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.role,
    this.permissions = const {},
  });

  final String eventId;
  final String userId;
  final String userName;
  final String role; // 'owner' or 'staff'
  final Set<OrganizerPermission> permissions;

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isStaff => role.toLowerCase() == 'staff';

  /// Evaluates whether the user has the required permission for the current event.
  bool hasPermission(OrganizerPermission permission) {
    if (isOwner) return true;
    return permissions.contains(permission);
  }

  /// Convenience factory for an event Owner (has all permissions).
  factory OrganizerMembershipContext.owner({
    required String eventId,
    String userId = 'usr-org-001',
    String userName = 'Penyelenggara Utama',
  }) {
    return OrganizerMembershipContext(
      eventId: eventId,
      userId: userId,
      userName: userName,
      role: 'owner',
      permissions: OrganizerPermission.values.toSet(),
    );
  }

  /// Convenience factory for a Staff member with specific granted permissions.
  factory OrganizerMembershipContext.staff({
    required String eventId,
    required Set<OrganizerPermission> permissions,
    String userId = 'usr-stf-001',
    String userName = 'Staf Operasional',
  }) {
    return OrganizerMembershipContext(
      eventId: eventId,
      userId: userId,
      userName: userName,
      role: 'staff',
      permissions: permissions,
    );
  }
}

