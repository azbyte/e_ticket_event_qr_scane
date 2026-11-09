/// Kontrak domain Event/TicketType milik Developer 1 (Tahap 0 — mock lokal).
///
/// File ini adalah API publik domain Event yang dipakai Developer 1, 2 dan 3.
/// Tidak ada request jaringan di sini; seluruh konstanta, payload, dan DTO
/// ringkasan bersifat lokal dan hanya untuk prototipe UI (PRD bagian 15 & 18).
library;

import '../../core/constants/app_constants.dart';
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';

/// Status event pada alur Organizer (PRD bagian 9.1).
///
/// Nilai diambil dari [AppConstants] bila sudah tersedia agar konsisten dengan
/// kode yang ada. `suspended` belum ada di [AppConstants] sehingga didefinisikan
/// lokal di sini; file core tidak diubah karena bukan milik Developer 1.
class OrganizerEventStatus {
  OrganizerEventStatus._();

  static const String draft = AppConstants.eventStatusDraft;
  static const String pendingReview = AppConstants.eventStatusPendingReview;
  static const String revisionRequested =
      AppConstants.eventStatusRevisionRequired;
  static const String approved = AppConstants.eventStatusApproved;
  static const String published = AppConstants.eventStatusPublished;
  static const String rejected = AppConstants.eventStatusRejected;
  static const String completed = AppConstants.eventStatusCompleted;
  static const String cancelled = AppConstants.eventStatusCancelled;

  /// Belum ada pada [AppConstants]; status PRD 9.1 (ditangguhkan).
  static const String suspended = 'suspended';

  static const List<String> all = <String>[
    draft,
    pendingReview,
    revisionRequested,
    approved,
    published,
    rejected,
    suspended,
    completed,
    cancelled,
  ];

  static const Map<String, String> _labels = <String, String>{
    draft: 'Draft',
    pendingReview: 'Menunggu moderasi',
    revisionRequested: 'Perlu revisi',
    approved: 'Disetujui',
    published: 'Dipublikasikan',
    rejected: 'Ditolak',
    suspended: 'Ditangguhkan',
    completed: 'Selesai',
    cancelled: 'Dibatalkan',
  };

  /// Label status untuk ditampilkan pada UI.
  static String label(String status) => _labels[status] ?? status;

  /// Status yang masih boleh diubah Owner (PRD 5.4 aturan edit).
  ///
  /// Event yang sedang menunggu moderasi, ditangguhkan, dibatalkan, atau selesai
  /// tidak boleh diubah. Event yang sudah tayang tetap bisa diubah, tetapi
  /// perubahan penting dapat memerlukan moderasi ulang (kebijakan belum final).
  static bool isEditable(String status) => const <String>[
        draft,
        revisionRequested,
        rejected,
        approved,
        published,
      ].contains(status);

  /// Status yang boleh diajukan untuk moderasi pertama kali.
  static bool canSubmit(String status) => status == draft;

  /// Status yang boleh diajukan ulang setelah revisi/penolakan.
  static bool canResubmit(String status) =>
      status == revisionRequested || status == rejected;

  /// Hanya draft yang aman dihapus (PRD 5.3 "hapus bila aman").
  static bool canDelete(String status) => status == draft;

  /// Event dianggap tayang bila sudah disetujui atau dipublikasikan.
  static bool isPublishedLike(String status) =>
      status == approved || status == published;
}

/// Format pelaksanaan event (PRD 5.4 C).
class OrganizerEventFormat {
  OrganizerEventFormat._();

  static const String offline = 'offline';
  static const String online = 'online';
  static const String hybrid = 'hybrid';

  static const List<String> all = <String>[offline, online, hybrid];

  static const Map<String, String> _labels = <String, String>{
    offline: 'Offline',
    online: 'Online',
    hybrid: 'Hybrid',
  };

  static String label(String format) => _labels[format] ?? format;
}

/// Kategori event yang tersedia pada prototipe (PRD 5.4 A).
///
/// Daftar ini netral (tidak mengunci kebijakan bisnis) dan boleh diperluas
/// setelah kategori resmi ditetapkan.
class OrganizerEventCategories {
  OrganizerEventCategories._();

  static const List<String> all = <String>[
    'Musik',
    'Seminar',
    'Workshop',
    'Olahraga',
    'Pameran',
    'Komunitas',
    'Lainnya',
  ];
}

/// Pilihan zona waktu pada form event (PRD 5.4 B).
class OrganizerTimeZones {
  OrganizerTimeZones._();

  static const List<String> all = <String>[
    'Asia/Jakarta',
    'Asia/Makassar',
    'Asia/Jayapura',
    'UTC',
  ];

  static const Map<String, String> _labels = <String, String>{
    'Asia/Jakarta': 'WIB (Asia/Jakarta)',
    'Asia/Makassar': 'WITA (Asia/Makassar)',
    'Asia/Jayapura': 'WIT (Asia/Jayapura)',
    'UTC': 'UTC',
  };

  static String label(String? timeZone) =>
      _labels[timeZone] ?? (timeZone ?? 'WIB (Asia/Jakarta)');
}

/// Informasi peserta yang wajib diisi (PRD 5.4 E).
class OrganizerAttendeeFields {
  OrganizerAttendeeFields._();

  static const String name = 'name';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String organization = 'organization';

  /// [name] selalu wajib dan tidak dapat dilepas.
  static const List<String> optional = <String>[email, phone, organization];

  static const Map<String, String> _labels = <String, String>{
    name: 'Nama lengkap',
    email: 'Email',
    phone: 'Nomor telepon',
    organization: 'Instansi/organisasi',
  };

  static String label(String field) => _labels[field] ?? field;
}

/// Filter daftar "Event Saya" (PRD 5.3).
enum OrganizerEventFilter {
  all('Semua'),
  draft('Draft'),
  pendingReview('Menunggu moderasi'),
  revisionRequested('Perlu revisi'),
  published('Disetujui/dipublikasikan'),
  completed('Selesai'),
  rejected('Ditolak'),
  suspendedOrCancelled('Ditangguhkan/dibatalkan');

  const OrganizerEventFilter(this.label);

  /// Label filter untuk chip/tab.
  final String label;

  /// Apakah [status] event termasuk dalam filter ini.
  bool matches(String status) {
    switch (this) {
      case OrganizerEventFilter.all:
        return true;
      case OrganizerEventFilter.draft:
        return status == OrganizerEventStatus.draft;
      case OrganizerEventFilter.pendingReview:
        return status == OrganizerEventStatus.pendingReview;
      case OrganizerEventFilter.revisionRequested:
        return status == OrganizerEventStatus.revisionRequested;
      case OrganizerEventFilter.published:
        return OrganizerEventStatus.isPublishedLike(status);
      case OrganizerEventFilter.completed:
        return status == OrganizerEventStatus.completed;
      case OrganizerEventFilter.rejected:
        return status == OrganizerEventStatus.rejected;
      case OrganizerEventFilter.suspendedOrCancelled:
        return status == OrganizerEventStatus.suspended ||
            status == OrganizerEventStatus.cancelled;
    }
  }
}

/// Payload form Buat/Edit Event (PRD 5.4 A–E).
///
/// Dipakai repository sebagai satu-satunya signature mutasi event agar kontrak
/// tidak berubah setiap ada field baru.
class OrganizerEventDraft {
  const OrganizerEventDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.organizerName,
    required this.contactInfo,
    required this.startDateTime,
    required this.endDateTime,
    required this.timeZone,
    required this.format,
    this.posterUrl,
    this.location,
    this.onlineUrl,
    this.publicInfo,
    this.attendeeFields = const <String>[OrganizerAttendeeFields.name],
  });

  final String title;
  final String category;
  final String description;
  final String organizerName;
  final String contactInfo;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String timeZone;

  /// Salah satu nilai [OrganizerEventFormat].
  final String format;
  final String? posterUrl;
  final String? location;
  final String? onlineUrl;
  final String? publicInfo;

  /// Field data peserta yang wajib diisi saat registrasi.
  final List<String> attendeeFields;

  /// Membuat draft dari event tersimpan (mode edit).
  factory OrganizerEventDraft.fromEvent(EventModel event) {
    return OrganizerEventDraft(
      title: event.title,
      category: event.category ?? OrganizerEventCategories.all.first,
      description: event.description ?? '',
      organizerName: event.organizerName ?? '',
      contactInfo: event.contactInfo ?? '',
      startDateTime: event.startDateTime,
      endDateTime: event.endDateTime,
      timeZone: event.timeZone ?? OrganizerTimeZones.all.first,
      format: event.eventType,
      posterUrl: event.posterUrl,
      location: event.location,
      onlineUrl: event.onlineUrl,
      publicInfo: event.publicInfo,
      attendeeFields: event.attendeeFields.isEmpty
          ? const <String>[OrganizerAttendeeFields.name]
          : event.attendeeFields,
    );
  }
}

/// Keputusan moderator pada simulasi demo (PRD 8.1 langkah 8).
///
/// Ini bukan aksi Owner dan bukan endpoint Admin; hanya untuk memperagakan
/// siklus moderasi pada prototipe Tahap 0.
enum OrganizerModerationDecision {
  approve('Disetujui'),
  requestRevision('Minta revisi'),
  reject('Ditolak');

  const OrganizerModerationDecision(this.label);

  final String label;
}

/// Payload form Kategori Tiket (PRD 5.4 D, 5.5.3).
class OrganizerTicketTypeDraft {
  const OrganizerTicketTypeDraft({
    required this.name,
    required this.price,
    required this.quota,
    this.description,
    this.maxPerOrder,
    this.salesStart,
    this.salesEnd,
    this.isActive = true,
  });

  final String name;
  final double price;
  final int quota;
  final String? description;

  /// Batas pembelian per order; null berarti mengikuti batas platform.
  final int? maxPerOrder;
  final DateTime? salesStart;
  final DateTime? salesEnd;
  final bool isActive;

  factory OrganizerTicketTypeDraft.fromModel(TicketTypeModel model) {
    return OrganizerTicketTypeDraft(
      name: model.name,
      price: model.price,
      quota: model.quota,
      description: model.description,
      maxPerOrder: model.maxPerOrder,
      salesStart: model.salesStart,
      salesEnd: model.salesEnd,
      isActive: model.isActive,
    );
  }
}

/// Angka ringkasan operasional sebuah event (PRD 5.5.1).
///
/// Nilai diturunkan dari fixture lokal Tahap 0. Rincian order/peserta/check-in
/// adalah data simulasi hingga adapter Developer 2 tersedia.
class OrganizerEventSummary {
  const OrganizerEventSummary({
    required this.eventId,
    required this.status,
    this.ticketsSold = 0,
    this.ticketsRemaining = 0,
    this.pendingOrders = 0,
    this.participants = 0,
    this.checkedIn = 0,
    this.grossSales = 0,
  });

  final String eventId;
  final String status;
  final int ticketsSold;
  final int ticketsRemaining;
  final int pendingOrders;
  final int participants;
  final int checkedIn;

  /// Penjualan kotor demo: `Σ (harga × tiket terjual)`.
  ///
  /// Bukan pendapatan platform, bukan fee, dan bukan komisi (PRD 7.3).
  final double grossSales;

  static OrganizerEventSummary empty(String eventId) => OrganizerEventSummary(
        eventId: eventId,
        status: OrganizerEventStatus.draft,
      );
}

/// Metrik operasional per event yang disediakan fixture Developer 1.
///
/// Sumbernya dapat diganti adapter Developer 2 tanpa mengubah file ini
/// (lihat `metricsSource` pada mock repository).
class OrganizerEventMetrics {
  const OrganizerEventMetrics({
    this.pendingOrders = 0,
    this.participants = 0,
    this.checkedIn = 0,
  });

  final int pendingOrders;
  final int participants;
  final int checkedIn;
}

/// Titik data grafik demo penjualan/check-in (PRD 5.5.1).
class OrganizerEventSalesPoint {
  const OrganizerEventSalesPoint({
    required this.date,
    this.tickets = 0,
    this.checkIns = 0,
  });

  final DateTime date;
  final int tickets;
  final int checkIns;
}

/// Ringkasan lintas event untuk dashboard Owner (kontrak untuk Developer 3).
///
/// Hanya merangkum event milik Owner tersebut, bukan pendapatan platform.
class OrganizerOverview {
  const OrganizerOverview({
    this.draftCount = 0,
    this.pendingReviewCount = 0,
    this.revisionCount = 0,
    this.publishedCount = 0,
    this.ticketsSold = 0,
    this.pendingOrders = 0,
    this.participants = 0,
    this.checkedIn = 0,
    this.grossSales = 0,
    this.recentEvents = const <EventModel>[],
  });

  final int draftCount;
  final int pendingReviewCount;
  final int revisionCount;
  final int publishedCount;
  final int ticketsSold;
  final int pendingOrders;
  final int participants;
  final int checkedIn;
  final double grossSales;

  /// Event terbaru (maksimal 5) untuk kartu dashboard.
  final List<EventModel> recentEvents;
}

/// Satu entri aktivitas event yang dikirim domain Event ke event logger.
///
/// Penyimpanan/implementasi log milik Developer 2; domain Developer 1 hanya
/// memanggil [OrganizerEventActivityLogger] tanpa mengedit file log tersebut.
class OrganizerEventActivityEntry {
  const OrganizerEventActivityEntry({
    required this.eventId,
    required this.actorId,
    required this.action,
    required this.summary,
    required this.timestamp,
  });

  final String eventId;
  final String actorId;
  final String action;
  final String summary;
  final DateTime timestamp;

  @override
  String toString() =>
      'OrganizerEventActivityEntry($action, event: $eventId, actor: $actorId)';
}

/// Signature event logger lintas domain (default-nya no-op).
typedef OrganizerEventActivityLogger = Future<void> Function(
  OrganizerEventActivityEntry entry,
);

/// Aksi aktivitas yang dikirim domain Event.
class OrganizerActivityActions {
  OrganizerActivityActions._();

  static const String eventCreated = 'event.created';
  static const String eventUpdated = 'event.updated';
  static const String eventSubmitted = 'event.submitted';
  static const String eventResubmitted = 'event.resubmitted';
  static const String eventModerated = 'event.moderated_demo';
  static const String eventDeleted = 'event.deleted';
  static const String ticketTypeCreated = 'ticket_type.created';
  static const String ticketTypeUpdated = 'ticket_type.updated';
  static const String ticketTypeDeleted = 'ticket_type.deleted';
}

/// Helper turunan [EventModel] sesuai aturan PRD 5.3–5.5.
///
/// Diletakkan di lapisan service (bukan di model) agar model tetap murni dan
/// dapat dipakai alur publik/Participant yang tidak mengenal alur Organizer.
extension OrganizerEventModelExtension on EventModel {
  bool get isDraft => status == OrganizerEventStatus.draft;
  bool get isPendingReview => status == OrganizerEventStatus.pendingReview;
  bool get isRevisionRequested =>
      status == OrganizerEventStatus.revisionRequested;
  bool get isRejected => status == OrganizerEventStatus.rejected;
  bool get isPublishedLike => OrganizerEventStatus.isPublishedLike(status);
  bool get canBeEdited => OrganizerEventStatus.isEditable(status);
  bool get canSubmitForReview => OrganizerEventStatus.canSubmit(status);
  bool get canResubmit => OrganizerEventStatus.canResubmit(status);
  bool get canBeDeleted => OrganizerEventStatus.canDelete(status);

  String get statusLabel => OrganizerEventStatus.label(status);
  String get formatLabel => OrganizerEventFormat.label(eventType);

  bool get needsOnlineUrl =>
      eventType == OrganizerEventFormat.online ||
      eventType == OrganizerEventFormat.hybrid;

  bool get needsPhysicalLocation =>
      eventType == OrganizerEventFormat.offline ||
      eventType == OrganizerEventFormat.hybrid;

  /// Tautan registrasi yang dapat disalin.
  ///
  /// Memakai [publicUrl] bila event sudah dipublikasikan; jika belum, memakai
  /// tautan demo lokal dan [registrationUrlIsDemo] bernilai true supaya UI tidak
  /// mengklaim event sudah tayang di server.
  String get registrationUrl =>
      publicUrl ?? 'https://demo.eticket.local/e/$id';

  bool get registrationUrlIsDemo => publicUrl == null;
}



