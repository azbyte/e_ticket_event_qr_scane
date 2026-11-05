/// Validasi domain Event/TicketType (PRD 5.4, 5.5.3, 9.7).
///
/// Dipakai oleh form (inline error) dan repository mock (pertahanan terakhir),
/// sehingga aturan hanya ditulis satu kali dan dapat diuji tanpa widget.
import 'organizer_event_contract.dart';

class OrganizerEventValidators {
  OrganizerEventValidators._();

  /// Kunci error form event.
  static const String fieldTitle = 'title';
  static const String fieldCategory = 'category';
  static const String fieldDescription = 'description';
  static const String fieldOrganizerName = 'organizerName';
  static const String fieldContactInfo = 'contactInfo';
  static const String fieldStart = 'start';
  static const String fieldEnd = 'end';
  static const String fieldFormat = 'format';
  static const String fieldLocation = 'location';
  static const String fieldOnlineUrl = 'onlineUrl';
  static const String fieldAttendeeFields = 'attendeeFields';

  /// Kunci error form kategori tiket.
  static const String fieldTicketName = 'ticketName';
  static const String fieldTicketPrice = 'ticketPrice';
  static const String fieldTicketQuota = 'ticketQuota';
  static const String fieldTicketMaxPerOrder = 'ticketMaxPerOrder';
  static const String fieldTicketPeriod = 'ticketPeriod';

  static final RegExp _urlPattern = RegExp(r'^https?://[^\s]+$');

  static String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
    return null;
  }

  /// Validasi seluruh field form event (PRD 5.4 A–E).
  static Map<String, String> validateEventDraft(OrganizerEventDraft draft) {
    final errors = <String, String>{};

    final titleError = _required(draft.title, 'Nama event');
    if (titleError != null) {
      errors[fieldTitle] = titleError;
    } else if (draft.title.trim().length < 3) {
      errors[fieldTitle] = 'Nama event minimal 3 karakter.';
    }

    final categoryError = _required(draft.category, 'Kategori event');
    if (categoryError != null) errors[fieldCategory] = categoryError;

    final organizerError = _required(draft.organizerName, 'Nama penyelenggara');
    if (organizerError != null) errors[fieldOrganizerName] = organizerError;

    final contactError = _required(draft.contactInfo, 'Kontak penyelenggara');
    if (contactError != null) errors[fieldContactInfo] = contactError;

    if (!draft.endDateTime.isAfter(draft.startDateTime)) {
      errors[fieldEnd] = 'Waktu selesai harus setelah waktu mulai.';
    }

    if (!OrganizerEventFormat.all.contains(draft.format)) {
      errors[fieldFormat] = 'Format event tidak dikenal.';
    }

    final needsLocation = draft.format == OrganizerEventFormat.offline ||
        draft.format == OrganizerEventFormat.hybrid;
    if (needsLocation) {
      final locationError = _required(draft.location, 'Alamat lokasi');
      if (locationError != null) errors[fieldLocation] = locationError;
    }

    final needsOnlineUrl = draft.format == OrganizerEventFormat.online ||
        draft.format == OrganizerEventFormat.hybrid;
    if (needsOnlineUrl) {
      final urlError = _required(draft.onlineUrl, 'Tautan online');
      if (urlError != null) {
        errors[fieldOnlineUrl] = urlError;
      } else if (!_urlPattern.hasMatch(draft.onlineUrl!.trim())) {
        errors[fieldOnlineUrl] =
            'Tautan online harus diawali http:// atau https://.';
      }
    }

    if (draft.attendeeFields.isEmpty) {
      errors[fieldAttendeeFields] = 'Minimal satu data peserta harus dipilih.';
    }

    return errors;
  }

  /// Validasi kuota kategori tiket terhadap kuota yang sudah terpakai.
  ///
  /// Mengembalikan pesan error atau null bila valid (PRD 5.5.3: jumlah terjual
  /// + tertahan tidak boleh melebihi kuota baru).
  static String? validateQuotaChange({
    required int newQuota,
    required int sold,
    required int held,
  }) {
    if (newQuota <= 0) return 'Kuota harus lebih dari nol.';
    if (newQuota < sold + held) {
      return 'Kuota tidak boleh kurang dari $sold terjual + $held tertahan '
          '(${sold + held}).';
    }
    return null;
  }

  /// Validasi form kategori tiket.
  static Map<String, String> validateTicketTypeDraft(
    OrganizerTicketTypeDraft draft, {
    int sold = 0,
    int held = 0,
  }) {
    final errors = <String, String>{};

    final nameError = _required(draft.name, 'Nama kategori tiket');
    if (nameError != null) errors[fieldTicketName] = nameError;

    if (draft.price < 0) {
      errors[fieldTicketPrice] = 'Harga tidak boleh negatif.';
    }

    final quotaError =
        validateQuotaChange(newQuota: draft.quota, sold: sold, held: held);
    if (quotaError != null) errors[fieldTicketQuota] = quotaError;

    final maxPerOrder = draft.maxPerOrder;
    if (maxPerOrder != null) {
      if (maxPerOrder <= 0) {
        errors[fieldTicketMaxPerOrder] =
            'Batas pembelian harus lebih dari nol.';
      } else if (maxPerOrder > draft.quota) {
        errors[fieldTicketMaxPerOrder] =
            'Batas pembelian tidak boleh melebihi kuota.';
      }
    }

    final start = draft.salesStart;
    final end = draft.salesEnd;
    if (start != null && end != null && !end.isAfter(start)) {
      errors[fieldTicketPeriod] =
          'Akhir periode penjualan harus setelah awal periode.';
    }

    return errors;
  }
}
