/// Layanan akses staf melalui tautan undangan + kode akses (PRD §6.2 revisi).
///
/// Semua keputusan otorisasi dilakukan backend:
///  - pratinjau undangan hanya memuat data event & nama staf (tanpa kode);
///  - `POST /api/staff-access/validate` memverifikasi kode akses ke database dan
///    menerbitkan sesi staf yang terikat pada undangan + event;
///  - sesi disimpan terpisah dari sesi akun (`StaffSessionStore`) dan dikirim
///    lewat header `X-Staff-Session` pada endpoint scanner.
library;

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/services/staff_session_store.dart';

/// Kesalahan akses staf dengan pesan yang siap ditampilkan.
class StaffAccessException implements Exception {
  const StaffAccessException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Data undangan untuk halaman autentikasi staf (tanpa kode akses).
class StaffInvitationPreview {
  const StaffInvitationPreview({
    required this.id,
    required this.staffName,
    required this.status,
    required this.eventId,
    required this.eventTitle,
    this.eventDate,
    this.location,
    this.expiresAt,
    this.requiresNewCode = false,
  });

  final String id;
  final String staffName;
  final String status;
  final String eventId;
  final String eventTitle;
  final DateTime? eventDate;
  final String? location;
  final DateTime? expiresAt;

  /// True untuk undangan lama (email-based) yang belum punya kode akses.
  final bool requiresNewCode;

  bool get isRevoked => status.toUpperCase() == 'REVOKED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  factory StaffInvitationPreview.fromJson(Map<String, dynamic> json) {
    final event = Map<String, dynamic>.from(json['event'] as Map? ?? const {});
    DateTime? parse(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());
    return StaffInvitationPreview(
      id: (json['id'] ?? '').toString(),
      staffName: (json['staff_name'] ?? 'Staf').toString(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      eventId: (event['id'] ?? '').toString(),
      eventTitle: (event['title'] ?? 'Event').toString(),
      eventDate: parse(event['event_date']),
      location: event['location']?.toString(),
      expiresAt: parse(json['expires_at']),
      requiresNewCode: json['requires_new_code'] == true,
    );
  }
}

class StaffAccessService {
  StaffAccessService({ApiClient? client, StaffSessionStore? store})
    : _client = client ?? ApiClient(),
      _store = store ?? StaffSessionStore.instance;

  final ApiClient _client;
  final StaffSessionStore _store;

  /// Ambil data undangan (publik). Tautan tidak memberi akses scanner.
  Future<StaffInvitationPreview> previewInvitation(String invitationId) async {
    final id = invitationId.trim();
    if (id.isEmpty) {
      throw const StaffAccessException('Tautan undangan tidak valid.');
    }
    try {
      final response = await _client.get('/staff-invitations/$id');
      final invitation = Map<String, dynamic>.from(
        response['invitation'] as Map? ?? const {},
      );
      return StaffInvitationPreview.fromJson(invitation);
    } on AppException catch (error) {
      throw StaffAccessException(
        _messageFor(error),
        statusCode: error.statusCode,
      );
    }
  }

  /// Validasi kode akses ke backend lalu simpan sesi staf.
  Future<StaffSession> requestAccess({
    required String invitationId,
    required String accessCode,
  }) async {
    try {
      final response = await _client.post(
        '/staff-access/validate',
        body: <String, dynamic>{
          'invitation_id': invitationId.trim(),
          'access_code': accessCode.trim(),
        },
      );
      final session = Map<String, dynamic>.from(
        response['session'] as Map? ?? const {},
      );
      final staff = Map<String, dynamic>.from(
        response['staff'] as Map? ?? const {},
      );
      final event = Map<String, dynamic>.from(
        response['event'] as Map? ?? const {},
      );
      final resolved = StaffSession(
        token: (session['token'] ?? '').toString(),
        staffName: (staff['name'] ?? 'Staf').toString(),
        eventId: (staff['event_id'] ?? event['id'] ?? '').toString(),
        eventTitle: (event['title'] ?? 'Event').toString(),
        expiresAt: DateTime.tryParse((session['expires_at'] ?? '').toString()),
      );
      if (resolved.token.isEmpty || resolved.eventId.isEmpty) {
        throw const StaffAccessException(
          'Server tidak mengembalikan sesi staf yang valid.',
        );
      }
      await _store.save(resolved);
      return resolved;
    } on AppException catch (error) {
      throw StaffAccessException(
        _messageFor(error),
        statusCode: error.statusCode,
      );
    }
  }

  /// Pulihkan sesi tersimpan (mis. setelah reload/browser dibuka kembali).
  ///
  /// Bila [verify] true, sesi diverifikasi ke backend sehingga pencabutan
  /// undangan atau berakhirnya masa berlaku langsung menutup akses.
  Future<StaffSession?> restoreSession({bool verify = true}) async {
    final stored = await _store.read();
    if (stored == null) return null;
    if (stored.isExpired) {
      await _store.clear();
      return null;
    }
    if (!verify) return stored;
    try {
      final response = await _client.get('/staff-access/session');
      final staff = Map<String, dynamic>.from(
        response['staff'] as Map? ?? const {},
      );
      final event = Map<String, dynamic>.from(
        response['event'] as Map? ?? const {},
      );
      final refreshed = StaffSession(
        token: stored.token,
        staffName: (staff['name'] ?? stored.staffName).toString(),
        eventId: (staff['event_id'] ?? stored.eventId).toString(),
        eventTitle: (event['title'] ?? stored.eventTitle).toString(),
        expiresAt:
            DateTime.tryParse((response['expires_at'] ?? '').toString()) ??
            stored.expiresAt,
      );
      await _store.save(refreshed);
      return refreshed;
    } on AppException {
      await _store.clear();
      return null;
    }
  }

  /// Akhiri sesi staf (token dicabut backend, lalu dihapus dari perangkat).
  Future<void> logout() async {
    try {
      await _client.post('/staff-access/logout');
    } on AppException {
      // Token lokal tetap dihapus walau backend tidak dapat dihubungi.
    } finally {
      await _store.clear();
    }
  }

  String _messageFor(AppException error) {
    final message = error.message.trim();
    if (message.isEmpty) return 'Akses staf tidak dapat diverifikasi.';
    return message;
  }
}
