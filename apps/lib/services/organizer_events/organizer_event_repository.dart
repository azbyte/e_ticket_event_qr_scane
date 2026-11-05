/// Kontrak repository Event/TicketType milik Developer 1.
///
/// Consumer (Developer 2/3) hanya boleh memakai signature di sini dan tidak
/// mengedit implementasinya. Implementasi mock Tahap 0 berada pada
/// [MockOrganizerEventRepository]; seluruh operasi bersifat lokal (tanpa HTTP).
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import 'organizer_event_contract.dart';

abstract class OrganizerEventRepository {
  /// Membaca daftar event milik [ownerId] dengan pencarian & filter status.
  ///
  /// [search] mencocokkan judul/lokasi/kategori (case-insensitive).
  Future<List<EventModel>> listEvents({
    required String ownerId,
    String search = '',
    OrganizerEventFilter filter = OrganizerEventFilter.all,
  });

  /// Membaca satu event; melempar `OrganizerEventAccessDeniedException` bila
  /// event bukan milik [ownerId].
  Future<EventModel> getEvent({
    required String ownerId,
    required String eventId,
  });

  /// Membuat event baru berstatus DRAFT (PRD 5.4 aturan).
  Future<EventModel> createEvent({
    required String ownerId,
    required OrganizerEventDraft draft,
  });

  /// Memperbarui event yang masih boleh diedit.
  Future<EventModel> updateEvent({
    required String ownerId,
    required String eventId,
    required OrganizerEventDraft draft,
  });

  /// Menghapus draft yang belum diajukan (PRD 5.3 "hapus bila aman").
  Future<void> deleteEvent({
    required String ownerId,
    required String eventId,
  });

  /// Mengajukan moderasi pertama (DRAFT → PENDING_REVIEW).
  Future<EventModel> submitForReview({
    required String ownerId,
    required String eventId,
  });

  /// Mengajukan ulang setelah revisi/ditolak.
  ///
  /// Catatan revisi lama dibersihkan karena sudah dijawab Owner.
  Future<EventModel> resubmitForReview({
    required String ownerId,
    required String eventId,
  });

  /// Simulasi keputusan moderator (demo).
  ///
  /// Hanya untuk memperagakan siklus moderasi; bukan aksi Owner dan bukan
  /// endpoint admin. UI wajib menandainya sebagai simulasi.
  Future<EventModel> simulateModeratorDecision({
    required String ownerId,
    required String eventId,
    required OrganizerModerationDecision decision,
    String? note,
  });

  /// Daftar kategori tiket milik satu event.
  Future<List<TicketTypeModel>> listTicketTypes({
    required String ownerId,
    required String eventId,
  });

  Future<TicketTypeModel> createTicketType({
    required String ownerId,
    required String eventId,
    required OrganizerTicketTypeDraft draft,
  });

  Future<TicketTypeModel> updateTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required OrganizerTicketTypeDraft draft,
  });

  /// Menghapus kategori tiket yang belum memiliki transaksi.
  ///
  /// Kategori dengan tiket terjual/tertahan ditolak (PRD 5.5.3).
  Future<void> deleteTicketType({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
  });

  /// Mengaktifkan/menonaktifkan kategori tiket.
  Future<TicketTypeModel> setTicketTypeActive({
    required String ownerId,
    required String eventId,
    required String ticketTypeId,
    required bool isActive,
  });

  /// Ringkasan operasional satu event (tab Ringkasan).
  Future<OrganizerEventSummary> eventSummary({
    required String ownerId,
    required String eventId,
  });

  /// Ringkasan untuk seluruh event milik Owner sekaligus.
  ///
  /// Dipakai daftar "Event Saya" agar tidak memanggil ringkasan satu per satu.
  Future<Map<String, OrganizerEventSummary>> eventSummaries({
    required String ownerId,
  });

  /// Seri data grafik demo penjualan/check-in.
  Future<List<OrganizerEventSalesPoint>> salesPoints({
    required String ownerId,
    required String eventId,
  });

  /// Ringkasan lintas event untuk dashboard Owner (kontrak Developer 3).
  Future<OrganizerOverview> overview({required String ownerId});

  /// Memasang logger aktivitas lintas domain (milik Developer 2).
  ///
  /// Bila tidak dipasang, domain Event memakai no-op sehingga tidak ada
  /// ketergantungan pada fitur yang belum tersedia.
  void bindActivityLogger(OrganizerEventActivityLogger logger);
}
