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
  static String templateUrl(String format) {
    final normalized = format.toLowerCase() == 'png' ? 'png' : 'pdf';
    return '${AppConfig.apiOrigin}/api/ticket-design-template?format=$normalized';
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

  /// Unggah desain. [scope] `event` (default event) atau `ticket_type`.
  Future<TicketDesignModel> upload({
    required String eventId,
    required Uint8List bytes,
    required String contentType,
    String scope = 'event',
    String? ticketTypeId,
    TicketQrPlacement qr = TicketDesignModel.defaultQr,
    TicketInfoPlacement info = TicketDesignModel.defaultInfo,
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

    try {
      final response = await _api.put(
        '/events/$eventId/ticket-design',
        body: <String, dynamic>{
          'scope': scope,
          'ticket_type_id': ?ticketTypeId,
          'content_type': contentType,
          'image_base64': base64Encode(bytes),
          'qr': qr.toJson(),
          'info': info.toJson(),
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
