/// Layanan undangan staf berbasis nama + kode akses (sisi Organizer).
///
/// Kode akses dibuat backend dan hanya dapat dilihat Organizer pemilik event
/// (endpoint dilindungi JWT + kepemilikan event). Frontend tidak pernah membuat
/// kode sendiri dan tidak menyimpan kode sebagai sumber kebenaran.
library;

import '../api/api_service.dart';

/// Satu undangan staf pada sebuah event.
class StaffInvitation {
  const StaffInvitation({
    required this.id,
    required this.staffName,
    required this.status,
    required this.permissions,
    this.accessCode,
    this.inviteUrl,
    this.expiresAt,
    this.acceptedAt,
    this.isLegacy = false,
  });

  final String id;
  final String staffName;
  final String status;
  final List<String> permissions;

  /// Kode akses yang dapat dibagikan (null bila ciphertext tidak terbaca).
  final String? accessCode;
  final String? inviteUrl;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;

  /// Undangan email lama yang belum memiliki nama/kode akses.
  final bool isLegacy;

  bool get isRevoked => status.toUpperCase() == 'REVOKED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';

  /// Undangan yang masih dapat dipakai staf untuk masuk.
  bool get isActive => (isPending || isAccepted) && !isExpired;

  factory StaffInvitation.fromJson(Map<String, dynamic> json) =>
      StaffInvitation(
        id: (json['id'] ?? '').toString(),
        staffName: (json['staff_name'] ?? 'Staf').toString(),
        status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
        permissions: (json['permissions'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        accessCode: (json['access_code'] as String?)?.trim().isEmpty == true
            ? null
            : json['access_code']?.toString(),
        inviteUrl: (json['invite_url'] as String?)?.trim().isEmpty == true
            ? null
            : json['invite_url']?.toString(),
        expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
        acceptedAt: DateTime.tryParse((json['accepted_at'] ?? '').toString()),
        isLegacy: json['is_legacy'] == true,
      );
}

class StaffInvitationService {
  StaffInvitationService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Buat undangan baru; respons memuat kode akses yang siap dibagikan.
  Future<StaffInvitation> create({
    required String eventId,
    required String name,
    Iterable<String>? permissions,
    int expiryDays = 7,
  }) async {
    final response = await _api.post(
      '/events/$eventId/staff-invitations',
      body: <String, dynamic>{
        'name': name.trim(),
        if (permissions != null) 'permissions': permissions.toList(),
        'expiryDays': expiryDays,
      },
    );
    return StaffInvitation.fromJson(
      Map<String, dynamic>.from(response['invitation'] as Map? ?? const {}),
    );
  }

  /// Daftar undangan staf pada event (kode akses ikut ditampilkan).
  Future<List<StaffInvitation>> list(String eventId) async {
    final response = await _api.get('/events/$eventId/staff-invitations');
    final rows = (response['invitations'] as List?) ?? const [];
    return rows
        .map(
          (row) =>
              StaffInvitation.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Terbitkan kode akses baru (kode lama langsung tidak berlaku).
  ///
  /// [name] opsional untuk memperbarui nama staf sekaligus, dipakai saat
  /// memigrasikan undangan email lama yang belum memiliki nama.
  Future<StaffInvitation> regenerate({
    required String eventId,
    required String invitationId,
    String? name,
    int expiryDays = 7,
  }) async {
    final trimmedName = name?.trim() ?? '';
    final response = await _api.post(
      '/events/$eventId/staff-invitations/$invitationId/regenerate',
      body: <String, dynamic>{
        'expiryDays': expiryDays,
        if (trimmedName.isNotEmpty) 'name': trimmedName,
      },
    );
    return StaffInvitation.fromJson(
      Map<String, dynamic>.from(response['invitation'] as Map? ?? const {}),
    );
  }

  /// Cabut undangan; sesi staf yang masih aktif langsung ditolak backend.
  Future<void> revoke({
    required String eventId,
    required String invitationId,
  }) async {
    await _api.delete('/events/$eventId/staff-invitations/$invitationId');
  }
}
