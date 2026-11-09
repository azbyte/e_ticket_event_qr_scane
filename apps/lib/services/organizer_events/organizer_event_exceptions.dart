/// Exception domain Event/TicketType (Tahap 0 — mock lokal).
///
/// Mengikuti basis [AppException] yang sudah dipakai lapisan service lain agar
/// provider/UI dapat menampilkan pesan yang konsisten.
library;

import '../../core/errors/app_exception.dart';

/// Kegagalan umum pada alur event Organizer.
class OrganizerEventException extends AppException {
  const OrganizerEventException(super.message);
}

/// Kegagalan validasi form event/kategori tiket.
///
/// [fieldErrors] memakai kunci nama field form agar bisa ditampilkan inline.
class OrganizerEventValidationException extends OrganizerEventException {
  const OrganizerEventValidationException(
    this.fieldErrors, [
    super.message = 'Data event belum lengkap atau tidak valid.',
  ]);

  final Map<String, String> fieldErrors;

  /// Pesan pertama untuk snackbar ringkas.
  String get firstMessage =>
      fieldErrors.isEmpty ? message : fieldErrors.values.first;
}

/// Akses ke event yang bukan milik Owner aktif.
///
/// Tidak membocorkan detail event (PRD: akses ditolak tanpa kebocoran data).
class OrganizerEventAccessDeniedException extends OrganizerEventException {
  const OrganizerEventAccessDeniedException([
    super.message = 'Anda tidak memiliki akses ke event ini.',
  ]);
}

/// Event tidak ditemukan pada fixture lokal.
class OrganizerEventNotFoundException extends OrganizerEventException {
  const OrganizerEventNotFoundException([
    super.message = 'Event tidak ditemukan.',
  ]);
}

/// Pelanggaran aturan kategori tiket (kuota, transaksi, dsb).
class OrganizerTicketTypeException extends OrganizerEventException {
  const OrganizerTicketTypeException(super.message);
}
