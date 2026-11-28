/// Service desain tiket Organizer (PRD §5).
///
/// Berkomunikasi dengan `GET/PUT/DELETE /api/events/:id/ticket-design` dan
/// menyediakan URL template PDF/PNG. Tidak ada data mock: kegagalan API
/// dilempar sebagai exception agar layar menampilkan pesan yang sebenarnya.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../models/event/ticket_design_model.dart';
import '../api/api_service.dart';

/// Kegagalan operasi desain tiket dengan pesan siap tampil.
class TicketDesignException implements Exception {
  const TicketDesignException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TicketDesignService {
  TicketDesignService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  /// Batas ukuran file desain (sama dengan validasi backend: 2 MB).
  static const int maxUploadBytes = 2 * 1024 * 1024;

  static const Set<String> allowedContentTypes = <String>{
    'image/png',
    'image/jpeg',
  };

  /// URL template PDF/PNG (generik, dapat dibuka tanpa login).
  ///
  /// Template mengikuti [orientation] yang dipilih Organizer agar acuan ukuran
  /// dan penanda area QR sesuai tiket yang akan dihasilkan.
  static String templateUrl(
    String format, {
    TicketOrientation orientation = TicketOrientation.landscape,
  }) {
    final normalized = format.toLowerCase() == 'png' ? 'png' : 'pdf';
    return '${AppConfig.apiOrigin}/api/ticket-design-template'
        '?format=$normalized&orientation=${orientation.value}';
  }

  Future<TicketDesignState> load(String eventId) async {
    try {
      final response = await _api.get('/events/$eventId/ticket-design');
      return TicketDesignState.fromJson(response);
    } on AppException catch (error) {
      throw TicketDesignException(error.message);
    } on FormatException catch (error) {
      throw TicketDesignException(
        'Respons desain tiket tidak valid: ${error.message}',
      );
    }
  }

  /// Simpan orientasi saja (sebelum/ tanpa mengunggah file desain).
  ///
  /// [scope] `event` (default untuk seluruh kategori) atau `ticket_type`
  /// (khusus satu kategori tiket).
  Future<TicketDesignModel> saveOrientation({
    required String eventId,
    required TicketOrientation orientation,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    if (scope == 'ticket_type' &&
        (ticketTypeId == null || ticketTypeId.isEmpty)) {
      throw const TicketDesignException(
        'Pilih kategori tiket untuk desain khusus kategori.',
      );
    }
    try {
      final response = await _api.put(
        '/events/$eventId/ticket-design',
        body: <String, dynamic>{
          'scope': scope,
          'ticket_type_id': ?ticketTypeId,
          'orientation_only': true,
          'orientation': orientation.value,
        },
      );
      final design = response['design'];
      if (design is! Map) {
        throw const TicketDesignException('Respons desain tiket tidak valid.');
      }
      return TicketDesignModel.fromJson(Map<String, dynamic>.from(design));
    } on AppException catch (error) {
      throw TicketDesignException(error.message);
    }
  }

  /// Unggah desain. [scope] `event` (default event) atau `ticket_type`.
  ///
  /// [layout] adalah konfigurasi tata letak yang sedang diatur Organizer,
  /// sehingga desain baru langsung memakai posisi/ukuran yang terlihat di
  /// pratinjau (bukan default sistem).
  Future<TicketDesignModel> upload({
    required String eventId,
    required Uint8List bytes,
    required String contentType,
    String scope = 'event',
    String? ticketTypeId,
    TicketOrientation orientation = TicketOrientation.landscape,
    TicketLayoutModel? layout,
  }) async {
    if (!allowedContentTypes.contains(contentType)) {
      throw const TicketDesignException('Format desain harus PNG atau JPEG.');
    }
    if (bytes.isEmpty) {
      throw const TicketDesignException('File desain tiket kosong.');
    }
    if (bytes.length > maxUploadBytes) {
      throw const TicketDesignException('Ukuran desain tiket melebihi 2 MB.');
    }
    if (scope == 'ticket_type' &&
        (ticketTypeId == null || ticketTypeId.isEmpty)) {
      throw const TicketDesignException(
        'Pilih kategori tiket untuk desain khusus kategori.',
      );
    }

    final effectiveLayout = layout ?? TicketLayoutModel.defaultsFor(orientation);
    try {
      final response = await _api.put(
        '/events/$eventId/ticket-design',
        body: <String, dynamic>{
          'scope': scope,
          'ticket_type_id': ?ticketTypeId,
          'content_type': contentType,
          'image_base64': base64Encode(bytes),
          'orientation': orientation.value,
          'layout': effectiveLayout.toJson(),
        },
      );
      final design = response['design'];
      if (design is! Map) {
        throw const TicketDesignException('Respons desain tiket tidak valid.');
      }
      return TicketDesignModel.fromJson(Map<String, dynamic>.from(design));
    } on AppException catch (error) {
      throw TicketDesignException(error.message);
    }
  }

  /// Simpan KONFIGURASI TATA LETAK (posisi & ukuran judul, ID tiket, instruksi,
  /// serta QR Code) tanpa mengunggah ulang berkas desain.
  ///
  /// Berlaku juga bila belum ada berkas desain: tiket default sistem memakai
  /// tata letak yang sama, sehingga Organizer dapat mengatur posisi elemen
  /// tanpa harus mengunggah gambar. Backend memvalidasi tumpang tindih dan
  /// menolak konfigurasi yang menutupi tulisan.
  Future<TicketDesignModel> saveLayout({
    required String eventId,
    required TicketLayoutModel layout,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    if (scope == 'ticket_type' &&
        (ticketTypeId == null || ticketTypeId.isEmpty)) {
      throw const TicketDesignException(
        'Pilih kategori tiket untuk desain khusus kategori.',
      );
    }
    try {
      final response = await _api.put(
        '/events/$eventId/ticket-design',
        body: <String, dynamic>{
          'scope': scope,
          'ticket_type_id': ?ticketTypeId,
          'layout_only': true,
          'layout': layout.toJson(),
        },
      );
      final design = response['design'];
      if (design is! Map) {
        throw const TicketDesignException('Respons desain tiket tidak valid.');
      }
      return TicketDesignModel.fromJson(Map<String, dynamic>.from(design));
    } on AppException catch (error) {
      throw TicketDesignException(error.message);
    }
  }

  /// Simpan pengaturan posisi & ukuran QR saja (kompatibilitas).
  ///
  /// Delegasi ke [saveLayout]: QR adalah bagian dari konfigurasi tata letak,
  /// sehingga hanya ada satu jalur penyimpanan.
  Future<TicketDesignModel> saveQrPlacement({
    required String eventId,
    required TicketQrPlacement qr,
    String scope = 'event',
    String? ticketTypeId,
    TicketLayoutModel? layout,
  }) => saveLayout(
    eventId: eventId,
    layout: (layout ?? TicketLayoutModel.defaultLandscape).copyWith(qr: qr),
    scope: scope,
    ticketTypeId: ticketTypeId,
  );

  /// Hapus desain sehingga tiket kembali memakai desain default sistem.
  Future<void> remove({
    required String eventId,
    String scope = 'event',
    String? ticketTypeId,
  }) async {
    try {
      await _api.delete(
        '/events/$eventId/ticket-design?scope=$scope'
        '${ticketTypeId != null ? '&ticket_type_id=$ticketTypeId' : ''}',
      );
    } on AppException catch (error) {
      throw TicketDesignException(error.message);
    }
  }
}
