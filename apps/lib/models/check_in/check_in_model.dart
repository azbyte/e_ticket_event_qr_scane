/// Check-in record model (PRD sections 4.5, 4.6, 6.3).
class CheckInModel {
  final String id;
  final String ticketId;
  final String eventId;
  final String staffId;
  final String staffName;
  final DateTime checkedInAt;
  final bool synced; // whether synced to server (offline support)
  final String? syncStatus; // synced, pending, conflict

  const CheckInModel({
    required this.id,
    required this.ticketId,
    required this.eventId,
    required this.staffId,
    required this.staffName,
    required this.checkedInAt,
    this.synced = false,
    this.syncStatus,
  });

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    // Backend mengirim `actor_user_id`/`actor_name` (petugas yang memindai);
    // `staff_*` dipertahankan untuk kompatibilitas data lama/demo.
    final staffId = (json['staff_id'] ?? json['actor_user_id'] ?? '').toString();
    final staffName =
        (json['staff_name'] ?? json['actor_name'] ?? '').toString();
    return CheckInModel(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      staffId: staffId,
      staffName: staffName,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      synced: json['synced'] as bool? ?? true,
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'event_id': eventId,
      'staff_id': staffId,
      'staff_name': staffName,
      'checked_in_at': checkedInAt.toIso8601String(),
      'synced': synced,
      'sync_status': syncStatus,
    };
  }

  @override
  String toString() =>
      'CheckInModel(id: $id, ticketId: $ticketId, synced: $synced)';
}
