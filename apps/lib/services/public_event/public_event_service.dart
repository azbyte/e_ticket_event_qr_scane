/// Service baca event untuk alur publik/guest (D1-4).
///
/// Tanggung jawab: memuat event + kategori tiket yang memang tayang. Order dan
/// pembayaran memakai [OrderService]/[PaymentService] yang sudah ada agar tidak
/// ada duplikasi logika dan token akses order tetap tersimpan dengan benar.
library;

import '../../core/errors/app_exception.dart';
import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import '../event/event_service.dart';
import '../ticket/ticket_type_service.dart';

/// Data halaman publik: event dan kategori tiketnya.
class PublicEventData {
  const PublicEventData({required this.event, required this.ticketTypes});

  final EventModel event;
  final List<TicketTypeModel> ticketTypes;

  /// Kategori yang benar-benar dapat dipesan saat ini.
  List<TicketTypeModel> sellableTypes(DateTime now) => ticketTypes
      .where((type) => type.isSellableAt(now))
      .toList(growable: false);
}

/// Event tidak tayang/tidak ditemukan atau respons API tidak dapat dipakai.
class PublicEventUnavailableException implements Exception {
  const PublicEventUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublicEventService {
  PublicEventService({
    EventService? eventService,
    TicketTypeService? ticketTypeService,
  }) : _eventService = eventService ?? EventService(),
       _ticketTypeService = ticketTypeService ?? TicketTypeService();

  final EventService _eventService;
  final TicketTypeService _ticketTypeService;

  /// Muat event publik beserta kategori tiket.
  ///
  /// Melempar [PublicEventUnavailableException] untuk event yang belum tayang,
  /// tidak ditemukan (404), atau respons yang tidak valid.
  Future<PublicEventData> loadEvent(String eventId) async {
    if (eventId.trim().isEmpty) {
      throw const PublicEventUnavailableException(
        'ID event tidak tersedia pada tautan ini.',
      );
    }
    try {
      final event = EventModel.fromJson(
        await _eventService.getEvent(eventId.trim()),
      );
      if (!isPubliclyVisible(event)) {
        throw const PublicEventUnavailableException(
          'Event belum dipublikasikan atau sudah tidak tersedia untuk '
          'pendaftaran.',
        );
      }
      final ticketTypes = await _ticketTypeService.getTicketTypesByEventId(
        event.id,
      );
      return PublicEventData(event: event, ticketTypes: ticketTypes);
    } on PublicEventUnavailableException {
      rethrow;
    } on AppException catch (error) {
      if (error.statusCode == 404) {
        throw const PublicEventUnavailableException(
          'Event tidak ditemukan atau belum dipublikasikan.',
        );
      }
      throw PublicEventUnavailableException(error.message);
    } on FormatException catch (error) {
      throw PublicEventUnavailableException(
        'Respons event tidak valid: ${error.message}',
      );
    }
  }

  /// Hanya event yang tayang (`PUBLISHED`, atau `APPROVED` legacy) yang boleh
  /// menampilkan formulir pendaftaran. Mode demo memakai aturan yang sama.
  static bool isPubliclyVisible(EventModel event) =>
      event.isPublic &&
      (event.status == 'published' || event.status == 'approved');
}
