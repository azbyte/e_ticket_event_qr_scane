import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sesi staf yang diperoleh dari undangan (nama + kode akses).
///
/// Disimpan TERPISAH dari token akun Organizer/Admin (`SessionService`) agar
/// staf tanpa akun dapat memakai scanner, dan agar membuka tautan undangan tidak
/// menimpa sesi Organizer pada perangkat yang sama.
class StaffSession {
  const StaffSession({
    required this.token,
    required this.staffName,
    required this.eventId,
    required this.eventTitle,
    this.expiresAt,
  });

  final String token;
  final String staffName;
  final String eventId;
  final String eventTitle;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!.toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'staff_name': staffName,
    'event_id': eventId,
    'event_title': eventTitle,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
  };

  factory StaffSession.fromJson(Map<String, dynamic> json) => StaffSession(
    token: (json['token'] ?? '').toString(),
    staffName: (json['staff_name'] ?? 'Staf').toString(),
    eventId: (json['event_id'] ?? '').toString(),
    eventTitle: (json['event_title'] ?? 'Event').toString(),
    expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
  );
}

/// Penyimpanan sesi staf (bertahan setelah reload/browser dibuka kembali).
///
/// `flutter_secure_storage` versi web memakai `crypto.subtle` yang hanya
/// tersedia pada secure context. Bila tidak tersedia (mis. dibuka lewat IP LAN),
/// sesi disimpan di memori agar scanner tetap dapat dipakai selama tab hidup —
/// pola yang sama dengan `SessionService`.
class StaffSessionStore {
  StaffSessionStore._();

  static final StaffSessionStore instance = StaffSessionStore._();

  static const String _key = 'staff_access_session';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  StaffSession? _memorySession;

  Future<StaffSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final session = StaffSession.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (session.token.isNotEmpty) {
            _memorySession = session;
            return session;
          }
        }
      }
    } catch (_) {
      // Secure storage tidak tersedia; gunakan cadangan memori.
    }
    return _memorySession;
  }

  Future<void> save(StaffSession session) async {
    _memorySession = session;
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {
      // Sesi tetap tersedia di memori untuk sesi berjalan.
    }
  }

  Future<void> clear() async {
    _memorySession = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // abaikan
    }
  }

  /// Token sesi staf untuk header `X-Staff-Session` (null bila tidak ada).
  Future<String?> readToken() async => (await read())?.token;
}
