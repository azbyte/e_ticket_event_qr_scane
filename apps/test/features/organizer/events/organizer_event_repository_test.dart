import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_exceptions.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_validators.dart';

void main() {
  const ownerId = OrganizerEventFixtures.demoOwnerId;

  OrganizerEventDraft buildDraft({String title = 'Event Uji'}) {
    return OrganizerEventDraft(
      title: title,
      category: 'Seminar',
      description: 'Deskripsi uji',
      organizerName: 'Penyelenggara Uji',
      contactInfo: 'uji@demo.eticket.local',
      startDateTime: DateTime(2027, 3, 1, 9),
      endDateTime: DateTime(2027, 3, 1, 12),
      timeZone: OrganizerTimeZones.all.first,
      format: OrganizerEventFormat.offline,
      location: 'Ruang Uji',
      attendeeFields: const <String>[OrganizerAttendeeFields.name],
    );
  }

  group('validasi domain event', () {
    test('draft lengkap tidak menghasilkan error', () {
      expect(
        OrganizerEventValidators.validateEventDraft(buildDraft()),
        isEmpty,
      );
    });

    test('menolak waktu selesai sebelum waktu mulai', () {
      final errors = OrganizerEventValidators.validateEventDraft(
        OrganizerEventDraft(
          title: 'Event Salah Jadwal',
          category: 'Seminar',
          description: '',
          organizerName: 'Penyelenggara',
          contactInfo: 'kontak@demo.local',
          startDateTime: DateTime(2027, 3, 1, 12),
          endDateTime: DateTime(2027, 3, 1, 9),
          timeZone: OrganizerTimeZones.all.first,
          format: OrganizerEventFormat.offline,
          location: 'Ruang Uji',
        ),
      );
      expect(errors[OrganizerEventValidators.fieldEnd], isNotNull);
    });

    test('mewajibkan tautan online untuk format online', () {
      final errors = OrganizerEventValidators.validateEventDraft(
        OrganizerEventDraft(
          title: 'Webinar Uji',
          category: 'Seminar',
          description: '',
          organizerName: 'Penyelenggara',
          contactInfo: 'kontak@demo.local',
          startDateTime: DateTime(2027, 3, 1, 9),
          endDateTime: DateTime(2027, 3, 1, 12),
          timeZone: OrganizerTimeZones.all.first,
          format: OrganizerEventFormat.online,
        ),
      );
      expect(errors[OrganizerEventValidators.fieldOnlineUrl], isNotNull);
    });

    test('kuota tidak boleh lebih kecil dari terjual + tertahan', () {
      final error = OrganizerEventValidators.validateQuotaChange(
        newQuota: 10,
        sold: 8,
        held: 4,
      );
      expect(error, isNotNull);
      expect(error, contains('12'));
    });
  });

  group('MockOrganizerEventRepository — scope Owner', () {
    test('hanya mengembalikan event milik Owner aktif', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final events = await repo.listEvents(ownerId: ownerId);

      expect(events, isNotEmpty);
      expect(events.every((e) => e.organizerId == ownerId), isTrue);
      expect(events.map((e) => e.id), isNot(contains('evt-9001')));
    });

    test('membaca event milik Owner lain ditolak', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.getEvent(ownerId: ownerId, eventId: 'evt-9001'),
        throwsA(isA<OrganizerEventAccessDeniedException>()),
      );
    });

    test('filter status dan pencarian berjalan lokal', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);

      final drafts = await repo.listEvents(
        ownerId: ownerId,
        filter: OrganizerEventFilter.draft,
      );
      expect(
        drafts.map((e) => e.status),
        everyElement(OrganizerEventStatus.draft),
      );

      final filtered = await repo.listEvents(
        ownerId: ownerId,
        search: 'webinar',
      );
      expect(filtered, hasLength(1));
      expect(filtered.single.title, contains('Webinar'));
    });

    test('listEvents gagal saat mode simulasi error aktif', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero)
        ..setFailure(value: true);
      await expectLater(
        repo.listEvents(ownerId: ownerId),
        throwsA(isA<OrganizerEventException>()),
      );
    });
  });

  group('MockOrganizerEventRepository — lifecycle event', () {
    test('event baru selalu berstatus draft dan bukan publik', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final created = await repo.createEvent(
        ownerId: ownerId,
        draft: buildDraft(),
      );

      expect(created.status, OrganizerEventStatus.draft);
      expect(created.isPublic, isFalse);
      expect(created.publicUrl, isNull);
      expect(created.organizerId, ownerId);

      final listed = await repo.listEvents(ownerId: ownerId);
      expect(listed.map((e) => e.id), contains(created.id));
    });

    test('menolak draft tidak valid dari lapisan repository', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.createEvent(
          ownerId: ownerId,
          draft: OrganizerEventDraft(
            title: '',
            category: 'Seminar',
            description: '',
            organizerName: '',
            contactInfo: '',
            startDateTime: DateTime(2027, 3, 1, 9),
            endDateTime: DateTime(2027, 3, 1, 8),
            timeZone: OrganizerTimeZones.all.first,
            format: OrganizerEventFormat.offline,
          ),
        ),
        throwsA(isA<OrganizerEventValidationException>()),
      );
    });

    test('alur moderasi: draft → pending → revisi → ajukan ulang', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final created = await repo.createEvent(
        ownerId: ownerId,
        draft: buildDraft(),
      );

      final pending = await repo.submitForReview(
        ownerId: ownerId,
        eventId: created.id,
      );
      expect(pending.status, OrganizerEventStatus.pendingReview);
      expect(pending.submittedAt, isNotNull);

      final revised = await repo.simulateModeratorDecision(
        ownerId: ownerId,
        eventId: created.id,
        decision: OrganizerModerationDecision.requestRevision,
        note: 'Lengkapi poster.',
      );
      expect(revised.status, OrganizerEventStatus.revisionRequested);
      expect(revised.reviewNote, 'Lengkapi poster.');

      final resubmitted = await repo.resubmitForReview(
        ownerId: ownerId,
        eventId: created.id,
      );
      expect(resubmitted.status, OrganizerEventStatus.pendingReview);
      expect(resubmitted.reviewNote, isNull);
    });

    test('persetujuan moderator menghasilkan tautan publik', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final approved = await repo.simulateModeratorDecision(
        ownerId: ownerId,
        eventId: 'evt-1002',
        decision: OrganizerModerationDecision.approve,
      );

      expect(approved.status, OrganizerEventStatus.approved);
      expect(approved.publicUrl, isNotNull);
      expect(approved.registrationUrlIsDemo, isFalse);
    });

    test('event pending tidak dapat dikirim ulang tanpa revisi', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.resubmitForReview(ownerId: ownerId, eventId: 'evt-1002'),
        throwsA(isA<OrganizerEventException>()),
      );
    });

    test('hanya draft yang dapat dihapus', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.deleteEvent(ownerId: ownerId, eventId: 'evt-1001'),
        throwsA(isA<OrganizerEventException>()),
      );

      final created = await repo.createEvent(
        ownerId: ownerId,
        draft: buildDraft(title: 'Draft Sementara'),
      );
      await repo.deleteEvent(ownerId: ownerId, eventId: created.id);
      final listed = await repo.listEvents(ownerId: ownerId);
      expect(listed.map((e) => e.id), isNot(contains(created.id)));
    });

    test('event yang sudah diajukan tidak dapat diubah', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.updateEvent(
          ownerId: ownerId,
          eventId: 'evt-1002',
          draft: buildDraft(),
        ),
        throwsA(isA<OrganizerEventException>()),
      );
    });
  });

  group('MockOrganizerEventRepository — kategori tiket', () {
    OrganizerTicketTypeDraft buildTicketDraft({
      String name = 'Kategori Uji',
      int quota = 50,
      int? maxPerOrder,
    }) {
      return OrganizerTicketTypeDraft(
        name: name,
        price: 100000,
        quota: quota,
        maxPerOrder: maxPerOrder,
      );
    }

    test('kategori baru memiliki sold/held nol dan sisa = kuota', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final created = await repo.createTicketType(
        ownerId: ownerId,
        eventId: 'evt-1001',
        draft: buildTicketDraft(),
      );

      expect(created.sold, 0);
      expect(created.held, 0);
      expect(created.remainingQuota, 50);
      expect(created.hasTransactions, isFalse);
    });

    test('menolak kuota lebih kecil dari terjual + tertahan', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.updateTicketType(
          ownerId: ownerId,
          eventId: 'evt-1001',
          ticketTypeId: 'tt-2001',
          draft: buildTicketDraft(quota: 100),
        ),
        throwsA(isA<OrganizerEventValidationException>()),
      );
    });

    test('menolak nama kategori duplikat pada event yang sama', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.createTicketType(
          ownerId: ownerId,
          eventId: 'evt-1001',
          draft: buildTicketDraft(name: 'regular pass'),
        ),
        throwsA(isA<OrganizerEventValidationException>()),
      );
    });

    test('kategori bertransaksi tidak dapat dihapus', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      await expectLater(
        repo.deleteTicketType(
          ownerId: ownerId,
          eventId: 'evt-1001',
          ticketTypeId: 'tt-2001',
        ),
        throwsA(isA<OrganizerTicketTypeException>()),
      );
    });

    test('kategori tanpa transaksi dapat dihapus', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final created = await repo.createTicketType(
        ownerId: ownerId,
        eventId: 'evt-1001',
        draft: buildTicketDraft(name: 'Kategori Sekali Pakai'),
      );

      await repo.deleteTicketType(
        ownerId: ownerId,
        eventId: 'evt-1001',
        ticketTypeId: created.id,
      );
      final types = await repo.listTicketTypes(
        ownerId: ownerId,
        eventId: 'evt-1001',
      );
      expect(types.map((t) => t.id), isNot(contains(created.id)));
    });

    test('menonaktifkan kategori tidak menghapus data terjual', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final updated = await repo.setTicketTypeActive(
        ownerId: ownerId,
        eventId: 'evt-1001',
        ticketTypeId: 'tt-2001',
        isActive: false,
      );
      expect(updated.isActive, isFalse);
      expect(updated.sold, greaterThan(0));
      expect(updated.isSellableAt(DateTime(2026, 11, 20)), isFalse);
    });

    test('kategori tiket event lain tidak dapat diakses', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final types = await repo.listTicketTypes(
        ownerId: ownerId,
        eventId: 'evt-1001',
      );
      expect(types.map((t) => t.id), isNot(contains('tt-2005')));
    });
  });

  group('MockOrganizerEventRepository — ringkasan', () {
    test('ringkasan event menjumlahkan kuota dan penjualan demo', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final summary = await repo.eventSummary(
        ownerId: ownerId,
        eventId: 'evt-1001',
      );

      expect(summary.eventId, 'evt-1001');
      expect(summary.status, OrganizerEventStatus.published);
      expect(summary.ticketsSold, 320 + 87);
      expect(summary.ticketsRemaining, (500 - 320 - 15) + (100 - 87 - 4));
      expect(summary.grossSales, 320 * 350000 + 87 * 750000);
    });

    test('overview hanya merangkum event milik Owner', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final overview = await repo.overview(ownerId: ownerId);

      expect(overview.draftCount, 1);
      expect(overview.pendingReviewCount, 1);
      expect(overview.revisionCount, 1);
      expect(overview.publishedCount, 1);
      expect(overview.recentEvents, isNotEmpty);
      expect(
        overview.recentEvents.every((e) => e.organizerId == ownerId),
        isTrue,
      );
    });

    test('activity logger menerima entri saat draft dibuat', () async {
      final repo = MockOrganizerEventRepository(latency: Duration.zero);
      final entries = <OrganizerEventActivityEntry>[];
      repo.bindActivityLogger((entry) async => entries.add(entry));

      await repo.createEvent(ownerId: ownerId, draft: buildDraft());

      expect(entries, hasLength(1));
      expect(entries.single.action, OrganizerActivityActions.eventCreated);
      expect(entries.single.actorId, ownerId);
    });
  });
}
