/// Event activity logger service (PRD section 13.3 & PEMBAGIAN_TUGAS_2 item 12).
///
/// Public API provided by Developer 2 to allow logging operational actions
/// (created events, edits, staff invitations, assisted registrations, and check-ins)
/// without modifying Developer 2's implementation files.
library;

import 'package:flutter/foundation.dart';

class EventActivityEntry {
  const EventActivityEntry({
    required this.id,
    required this.eventId,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.timestamp,
    required this.summary,
    this.metadata,
  });

  final String id;
  final String eventId;
  final String actorId;
  final String actorName;
  final String action;
  final DateTime timestamp;
  final String summary;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'actor_id': actorId,
        'actor_name': actorName,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'summary': summary,
        'metadata': metadata,
      };

  factory EventActivityEntry.fromJson(Map<String, dynamic> json) =>
      EventActivityEntry(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        actorId: json['actor_id'] as String,
        actorName: json['actor_name'] as String,
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        summary: json['summary'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

class EventActivityLogger extends ChangeNotifier {
  EventActivityLogger._internal() {
    _initPreseededActivities();
  }

  static final EventActivityLogger instance = EventActivityLogger._internal();

  final List<EventActivityEntry> _entries = [];

  List<EventActivityEntry> get entries => List.unmodifiable(_entries);

  void _initPreseededActivities() {
    final now = DateTime.now();
    _entries.addAll([
      EventActivityEntry(
        id: 'act-001',
        eventId: 'evt-001',
        actorId: 'usr-org-001',
        actorName: 'Penyelenggara Tech',
        action: 'CREATE_EVENT',
        timestamp: now.subtract(const Duration(days: 3, hours: 4)),
        summary: 'Membuat draf event "Tech Innovation Summit 2026".',
      ),
      EventActivityEntry(
        id: 'act-002',
        eventId: 'evt-001',
        actorId: 'usr-org-001',
        actorName: 'Penyelenggara Tech',
        action: 'ADD_TICKET_TYPE',
        timestamp: now.subtract(const Duration(days: 3, hours: 2)),
        summary: 'Menambahkan kategori tiket "VIP Pass" dan "Regular Pass".',
      ),
      EventActivityEntry(
        id: 'act-003',
        eventId: 'evt-001',
        actorId: 'usr-org-001',
        actorName: 'Penyelenggara Tech',
        action: 'SUBMIT_REVIEW',
        timestamp: now.subtract(const Duration(days: 2, hours: 6)),
        summary: 'Mengajukan event untuk moderasi admin platform.',
      ),
      EventActivityEntry(
        id: 'act-004',
        eventId: 'evt-001',
        actorId: 'usr-org-001',
        actorName: 'Penyelenggara Tech',
        action: 'STAFF_INVITATION',
        timestamp: now.subtract(const Duration(days: 1, hours: 8)),
        summary: 'Mengundang "budi.staf@example.com" dengan izin SCAN_TICKET dan CHECK_IN_TICKET.',
      ),
      EventActivityEntry(
        id: 'act-005',
        eventId: 'evt-001',
        actorId: 'usr-stf-001',
        actorName: 'Budi Santoso (Staf)',
        action: 'CHECK_IN_SUCCESS',
        timestamp: now.subtract(const Duration(minutes: 45)),
        summary: 'Check-in berhasil untuk tiket TK-TECH-001 (Ahmad Fauzi).',
      ),
      EventActivityEntry(
        id: 'act-006',
        eventId: 'evt-001',
        actorId: 'usr-stf-001',
        actorName: 'Budi Santoso (Staf)',
        action: 'CHECK_IN_SUCCESS',
        timestamp: now.subtract(const Duration(minutes: 20)),
        summary: 'Check-in berhasil untuk tiket TK-TECH-002 (Dewi Lestari).',
      ),
    ]);
  }

  /// Appends an operational activity record to the event stream.
  void log({
    required String eventId,
    required String actorId,
    required String actorName,
    required String action,
    required String summary,
    Map<String, dynamic>? metadata,
  }) {
    final entry = EventActivityEntry(
      id: 'act-${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      actorId: actorId,
      actorName: actorName,
      action: action,
      timestamp: DateTime.now(),
      summary: summary,
      metadata: metadata,
    );
    _entries.insert(0, entry);
    notifyListeners();
  }

  /// Retrieves filtered activity history for an event.
  List<EventActivityEntry> getActivitiesForEvent(
    String eventId, {
    String? actionCategory,
  }) {
    return _entries.where((e) {
      if (e.eventId != eventId) return false;
      if (actionCategory != null && actionCategory != 'Semua') {
        if (!e.action.contains(actionCategory)) return false;
      }
      return true;
    }).toList();
  }
}

