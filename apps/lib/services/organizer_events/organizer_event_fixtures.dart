/// Fixture lokal domain Event/TicketType (Tahap 0 — tanpa backend).
///
/// Semua tanggal bersifat tetap (deterministik) agar test dan demo stabil, dan
/// seluruh nilai operasional adalah data simulasi, bukan transaksi nyata.
library;

import '../../models/event/event_model.dart';
import '../../models/event/ticket_type_model.dart';
import 'organizer_event_contract.dart';

class OrganizerEventFixtures {
  OrganizerEventFixtures._();

  /// Owner aktif pada demo Organizer.
  static const String demoOwnerId = 'org-001';

  /// Owner lain; dipakai untuk membuktikan scope Owner dan akses ditolak.
  static const String otherOwnerId = 'org-002';

  /// Nama Owner demo (nilai awal form).
  static const String demoOwnerName = 'Nadia Organizer';

  /// Email Owner demo (nilai awal kontak penyelenggara).
  static const String demoOwnerEmail = 'nadia@demo.eticket.local';

  /// Event milik [demoOwnerId] (4 event) + 1 event milik [otherOwnerId].
  static List<EventModel> seedEvents() {
    return <EventModel>[
      EventModel(
        id: 'evt-1001',
        organizerId: demoOwnerId,
        title: 'Tech Innovation Summit 2026',
        description:
            'Festival musik dua hari dengan 12 penampil lokal dan nasional. '
            'Data ini adalah fixture demo, bukan event yang benar-benar tayang.',
        posterUrl: 'https://demo.eticket.local/posters/music-fest.png',
        category: 'Teknologi',
        startDateTime: DateTime(2026, 12, 20, 19, 0),
        endDateTime: DateTime(2026, 12, 20, 23, 0),
        timeZone: 'Asia/Jakarta',
        location: 'Grand Ballroom Hotel Indonesia',
        eventType: OrganizerEventFormat.offline,
        contactInfo: demoOwnerEmail,
        organizerName: demoOwnerName,
        publicInfo: 'Gerbang dibuka 60 menit sebelum acara.',
        attendeeFields: const <String>[
          OrganizerAttendeeFields.name,
          OrganizerAttendeeFields.email,
          OrganizerAttendeeFields.phone,
        ],
        status: OrganizerEventStatus.published,
        publicUrl: 'https://demo.eticket.local/e/evt-1001',
        registrationQrUrl: 'https://demo.eticket.local/qr/evt-1001',
        createdAt: DateTime(2026, 10, 2, 10, 15),
        updatedAt: DateTime(2026, 10, 9, 8, 40),
        submittedAt: DateTime(2026, 10, 5, 13, 0),
      ),
      EventModel(
        id: 'evt-1002',
        organizerId: demoOwnerId,
        title: 'Webinar Produk Digital 2026',
        description: 'Webinar gratis tentang riset pengguna dan prioritas roadmap produk.',
        posterUrl: 'https://demo.eticket.local/posters/webinar.png',
        category: 'Seminar',
        startDateTime: DateTime(2026, 12, 12, 13, 0),
        endDateTime: DateTime(2026, 12, 12, 16, 0),
        timeZone: 'Asia/Jakarta',
        onlineUrl: 'https://demo.eticket.local/live/webinar-2026',
        eventType: OrganizerEventFormat.online,
        contactInfo: demoOwnerEmail,
        organizerName: demoOwnerName,
        publicInfo: 'Tautan ruang daring dibagikan melalui email peserta.',
        attendeeFields: const <String>[
          OrganizerAttendeeFields.name,
          OrganizerAttendeeFields.email,
        ],
        status: OrganizerEventStatus.pendingReview,
        createdAt: DateTime(2026, 11, 1, 9, 30),
        updatedAt: DateTime(2026, 11, 2, 15, 12),
        submittedAt: DateTime(2026, 11, 2, 15, 12),
      ),
      EventModel(
        id: 'evt-1003',
        organizerId: demoOwnerId,
        title: 'Workshop Fotografi Produk',
        description: 'Kelas praktik fotografi produk untuk pelaku UMKM. 30 kursi terbatas.',
        category: 'Workshop',
        startDateTime: DateTime(2027, 1, 17, 9, 0),
        endDateTime: DateTime(2027, 1, 17, 15, 0),
        timeZone: 'Asia/Jakarta',
        location: 'Studio Cahaya, Bandung',
        eventType: OrganizerEventFormat.offline,
        contactInfo: '0857-0000-0001',
        organizerName: demoOwnerName,
        publicInfo: 'Peserta membawa kamera sendiri.',
        attendeeFields: const <String>[
          OrganizerAttendeeFields.name,
          OrganizerAttendeeFields.email,
          OrganizerAttendeeFields.organization,
        ],
        status: OrganizerEventStatus.revisionRequested,
        reviewNote:
            'Fixture demo: poster dan narahubung wajib dilengkapi sebelum '
            'event dapat ditinjau ulang.',
        createdAt: DateTime(2026, 10, 25, 11, 5),
        updatedAt: DateTime(2026, 10, 28, 9, 20),
        submittedAt: DateTime(2026, 10, 27, 16, 0),
      ),
      EventModel(
        id: 'evt-1004',
        organizerId: demoOwnerId,
        title: 'Lari Komunitas 5K',
        description: 'Draft event lari komunitas akhir pekan; belum diajukan.',
        category: 'Olahraga',
        startDateTime: DateTime(2027, 2, 7, 6, 0),
        endDateTime: DateTime(2027, 2, 7, 9, 0),
        timeZone: 'Asia/Jakarta',
        location: 'Lapangan Banteng, Jakarta',
        eventType: OrganizerEventFormat.offline,
        contactInfo: demoOwnerEmail,
        organizerName: demoOwnerName,
        attendeeFields: const <String>[OrganizerAttendeeFields.name],
        status: OrganizerEventStatus.draft,
        createdAt: DateTime(2026, 11, 3, 7, 45),
        updatedAt: DateTime(2026, 11, 3, 7, 45),
      ),
      EventModel(
        id: 'evt-9001',
        organizerId: otherOwnerId,
        title: 'Event Milik Owner Lain',
        description:
            'Fixture event dengan owner berbeda untuk menguji penolakan akses.',
        category: 'Komunitas',
        startDateTime: DateTime(2027, 1, 5, 10, 0),
        endDateTime: DateTime(2027, 1, 5, 12, 0),
        timeZone: 'Asia/Jakarta',
        location: 'Balai Kota, Surabaya',
        eventType: OrganizerEventFormat.offline,
        contactInfo: 'owner-lain@demo.eticket.local',
        organizerName: 'Owner Lain',
        attendeeFields: const <String>[OrganizerAttendeeFields.name],
        status: OrganizerEventStatus.published,
        publicUrl: 'https://demo.eticket.local/e/evt-9001',
        createdAt: DateTime(2026, 9, 1, 8, 0),
        updatedAt: DateTime(2026, 9, 2, 8, 0),
      ),
    ];
  }

  /// Kategori tiket awal; sengaja memuat data terjual + tertahan.
  static List<TicketTypeModel> seedTicketTypes() {
    return <TicketTypeModel>[
      TicketTypeModel(
        id: 'tt-2001',
        eventId: 'evt-1001',
        name: 'Regular Pass',
        description: 'Akses satu hari festival.',
        price: 350000,
        quota: 500,
        sold: 320,
        held: 15,
        maxPerOrder: 4,
        salesStart: DateTime(2026, 10, 10),
        salesEnd: DateTime(2026, 12, 19, 23, 59),
      ),
      TicketTypeModel(
        id: 'tt-2002',
        eventId: 'evt-1001',
        name: 'VIP Pass',
        description: 'Area depan panggung dan jalur masuk khusus.',
        price: 750000,
        quota: 100,
        sold: 87,
        held: 4,
        maxPerOrder: 2,
        salesStart: DateTime(2026, 10, 10),
        salesEnd: DateTime(2026, 12, 19, 23, 59),
      ),
      TicketTypeModel(
        id: 'tt-2003',
        eventId: 'evt-1002',
        name: 'Gratis',
        description: 'Kuota demo untuk peserta webinar.',
        price: 0,
        quota: 200,
        sold: 140,
        maxPerOrder: 2,
      ),
      TicketTypeModel(
        id: 'tt-2004',
        eventId: 'evt-1003',
        name: 'Early Bird',
        description: 'Harga khusus pendaftar awal.',
        price: 150000,
        quota: 20,
        sold: 20,
        maxPerOrder: 1,
        salesStart: DateTime(2026, 10, 1),
        salesEnd: DateTime(2026, 10, 20),
        isActive: false,
      ),
      TicketTypeModel(
        id: 'tt-2005',
        eventId: 'evt-9001',
        name: 'Umum',
        description: 'Kategori tiket milik event owner lain.',
        price: 50000,
        quota: 100,
        sold: 10,
      ),
    ];
  }

  /// Metrik operasional demo per event (bukan data order nyata).
  static Map<String, OrganizerEventMetrics> seedMetrics() {
    return const <String, OrganizerEventMetrics>{
      'evt-1001': OrganizerEventMetrics(
        pendingOrders: 6,
        participants: 407,
        checkedIn: 2,
      ),
      'evt-1002': OrganizerEventMetrics(
        pendingOrders: 3,
        participants: 140,
        checkedIn: 0,
      ),
      'evt-1003': OrganizerEventMetrics(
        pendingOrders: 1,
        participants: 20,
        checkedIn: 0,
      ),
    };
  }

  /// Titik grafik demo penjualan/check-in per event.
  static Map<String, List<OrganizerEventSalesPoint>> seedSalesPoints() {
    return <String, List<OrganizerEventSalesPoint>>{
      'evt-1001': <OrganizerEventSalesPoint>[
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 1), tickets: 42, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 8), tickets: 88, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 15), tickets: 133, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 22), tickets: 176, checkIns: 0),
      ],
      'evt-1002': <OrganizerEventSalesPoint>[
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 1), tickets: 20, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 8), tickets: 55, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 15), tickets: 95, checkIns: 0),
        OrganizerEventSalesPoint(
            date: DateTime(2026, 11, 22), tickets: 140, checkIns: 0),
      ],
    };
  }
}
