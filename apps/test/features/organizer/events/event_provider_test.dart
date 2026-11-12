import 'package:flutter_test/flutter_test.dart';

import 'package:e_ticket_event_qr_scane/providers/event_provider.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/mock_organizer_event_repository.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_contract.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_fixtures.dart';
import 'package:e_ticket_event_qr_scane/services/organizer_events/organizer_event_validators.dart';

void main() {
  EventProvider buildProvider([MockOrganizerEventRepository? repository]) {
    return EventProvider(
      repository:
          repository ?? MockOrganizerEventRepository(latency: Duration.zero),
      ownerId: OrganizerEventFixtures.demoOwnerId,
    );
  }

  OrganizerEventDraft buildDraft({String title = 'Event Provider'}) {
    return OrganizerEventDraft(
      title: title,
      category: 'Seminar',
      description: 'Deskripsi',
      organizerName: 'Penyelenggara',
      contactInfo: 'kontak@demo.local',
      startDateTime: DateTime(2027, 5, 1, 9),
      endDateTime: DateTime(2027, 5, 1, 12),
      timeZone: OrganizerTimeZones.all.first,
      format: OrganizerEventFormat.offline,
      location: 'Ruang Provider',
    );
  }

  test('loadEvents mengisi state ready dan ringkasan per event', () async {
    final provider = buildProvider();
    expect(provider.status, EventLoadStatus.idle);

    await provider.loadEvents();

    expect(provider.status, EventLoadStatus.ready);
    expect(provider.events, isNotEmpty);
    expect(provider.isEmpty, isFalse);
    expect(provider.summaryFor('evt-1001'), isNotNull);
    expect(provider.summaryFor('evt-1001')!.ticketsSold, greaterThan(0));
  });

  test('loadEvents hanya memuat event milik owner aktif', () async {
    final provider = EventProvider(
      repository: MockOrganizerEventRepository(latency: Duration.zero),
      ownerId: OrganizerEventFixtures.otherOwnerId,
    );

    await provider.loadEvents();

    expect(provider.status, EventLoadStatus.ready);
    expect(provider.events, hasLength(1));
    expect(provider.events.single.id, 'evt-9001');
    expect(
      provider.events.every(
        (event) => event.organizerId == OrganizerEventFixtures.otherOwnerId,
      ),
      isTrue,
    );
  });

  test('state empty terdeteksi pada repository kosong', () async {
    final provider = buildProvider(MockOrganizerEventRepository.empty());
    await provider.loadEvents();

    expect(provider.isEmpty, isTrue);
    expect(provider.events, isEmpty);
  });

  test('state error dan retry berjalan', () async {
    final repository = MockOrganizerEventRepository(latency: Duration.zero)
      ..setFailure(value: true);
    final provider = buildProvider(repository);

    await provider.loadEvents();
    expect(provider.hasError, isTrue);
    expect(provider.loadError, isNotNull);

    repository.setFailure(value: false);
    await provider.loadEvents();
    expect(provider.status, EventLoadStatus.ready);
    expect(provider.hasError, isFalse);
  });

  test('pencarian lokal dan filter status menyaring daftar', () async {
    final provider = buildProvider();
    await provider.loadEvents();
    final total = provider.events.length;

    provider.setSearchQuery('webinar');
    expect(provider.visibleEvents, hasLength(1));
    expect(provider.visibleEvents.single.title, contains('Webinar'));

    provider.setSearchQuery('tidak-ada-yang-cocok');
    expect(provider.visibleEvents, isEmpty);
    expect(provider.hasNoMatch, isTrue);

    provider.setSearchQuery('');
    await provider.setFilter(OrganizerEventFilter.draft);
    expect(provider.filter, OrganizerEventFilter.draft);
    expect(
      provider.events.every((e) => e.status == OrganizerEventStatus.draft),
      isTrue,
    );
    expect(provider.events.length, lessThan(total));
  });

  test('loadEvent memuat detail, kategori tiket, dan grafik', () async {
    final provider = buildProvider();
    await provider.loadEvent('evt-1001');

    expect(provider.status, EventLoadStatus.ready);
    expect(provider.selectedEvent?.id, 'evt-1001');
    expect(provider.ticketTypes, hasLength(2));
    expect(provider.summary, isNotNull);
    expect(provider.salesPointSeries, isNotEmpty);
  });

  test('event milik Owner lain menghasilkan state accessDenied', () async {
    final provider = buildProvider();
    await provider.loadEvent('evt-9001');

    expect(provider.hasAccessDenied, isTrue);
    expect(provider.selectedEvent, isNull);
    expect(provider.ticketTypes, isEmpty);
  });

  test('createEvent menambah draft dan menyegarkan daftar', () async {
    final provider = buildProvider();
    await provider.loadEvents();
    final before = provider.events.length;

    final created = await provider.createEvent(buildDraft());
    expect(created, isNotNull);
    expect(created!.status, OrganizerEventStatus.draft);
    expect(provider.events, hasLength(before + 1));
    expect(provider.actionError, isNull);
  });

  test('validasi gagal mengisi fieldErrors tanpa mengubah daftar', () async {
    final provider = buildProvider();
    await provider.loadEvents();
    final before = provider.events.length;

    final created = await provider.createEvent(buildDraft(title: ''));

    expect(created, isNull);
    expect(provider.events, hasLength(before));
    expect(
      provider.fieldErrors[OrganizerEventValidators.fieldTitle],
      isNotNull,
    );
    expect(provider.actionError, isNotNull);

    provider.clearActionError();
    expect(provider.actionError, isNull);
    expect(provider.fieldErrors, isEmpty);
  });

  test('submitForReview memindahkan status ke pendingReview', () async {
    final provider = buildProvider();
    final created = await provider.createEvent(buildDraft());

    final submitted = await provider.submitForReview(created!.id);
    expect(submitted?.status, OrganizerEventStatus.pendingReview);

    final listed = provider.events.firstWhere(
      (event) => event.id == created.id,
    );
    expect(listed.status, OrganizerEventStatus.pendingReview);
  });

  test(
    'moderation revision dapat diedit dan diajukan ulang hingga approved',
    () async {
      final provider = buildProvider();
      final created = await provider.createEvent(buildDraft());
      expect(created, isNotNull);

      final submitted = await provider.submitForReview(created!.id);
      expect(submitted?.status, OrganizerEventStatus.pendingReview);
      final revision = await provider.simulateModeration(
        created.id,
        OrganizerModerationDecision.requestRevision,
        note: 'Lengkapi lokasi acara.',
      );
      expect(revision?.status, OrganizerEventStatus.revisionRequested);
      expect(revision?.reviewNote, 'Lengkapi lokasi acara.');

      final edited = await provider.updateEvent(
        created.id,
        buildDraft(title: 'Event Provider Revisi'),
      );
      expect(edited?.status, OrganizerEventStatus.revisionRequested);
      final resubmitted = await provider.submitForReview(
        created.id,
        resubmit: true,
      );
      expect(resubmitted?.status, OrganizerEventStatus.pendingReview);
      final approved = await provider.simulateModeration(
        created.id,
        OrganizerModerationDecision.approve,
      );
      expect(approved?.status, OrganizerEventStatus.approved);
      expect(approved?.isPublic, isTrue);
    },
  );

  test('deleteEvent hanya berhasil untuk draft', () async {
    final provider = buildProvider();
    await provider.loadEvents();

    expect(await provider.deleteEvent('evt-1001'), isFalse);
    expect(provider.actionError, isNotNull);

    final created = await provider.createEvent(buildDraft());
    expect(await provider.deleteEvent(created!.id), isTrue);
    expect(
      provider.events.map((event) => event.id),
      isNot(contains(created.id)),
    );
  });

  test('saveTicketType dan proteksi kuota berjalan', () async {
    final provider = buildProvider();
    await provider.loadEvent('evt-1001');

    final saved = await provider.saveTicketType(
      eventId: 'evt-1001',
      draft: const OrganizerTicketTypeDraft(
        name: 'Kategori Provider',
        price: 50000,
        quota: 25,
      ),
    );
    expect(saved, isNotNull);
    expect(
      provider.ticketTypes.map((t) => t.name),
      contains('Kategori Provider'),
    );

    final rejected = await provider.saveTicketType(
      eventId: 'evt-1001',
      ticketTypeId: 'tt-2001',
      draft: const OrganizerTicketTypeDraft(
        name: 'Regular Pass',
        price: 350000,
        quota: 2,
      ),
    );
    expect(rejected, isNull);
    expect(
      provider.fieldErrors[OrganizerEventValidators.fieldTicketQuota],
      isNotNull,
    );
  });

  test('setTicketTypeActive menonaktifkan kategori', () async {
    final provider = buildProvider();
    await provider.loadEvent('evt-1001');

    expect(
      await provider.setTicketTypeActive(
        eventId: 'evt-1001',
        ticketTypeId: 'tt-2002',
        isActive: false,
      ),
      isTrue,
    );
    final vip = provider.ticketTypes.firstWhere((t) => t.id == 'tt-2002');
    expect(vip.isActive, isFalse);
  });

  test('loadOverview mengisi ringkasan dashboard', () async {
    final provider = buildProvider();
    await provider.loadOverview();

    expect(provider.overview, isNotNull);
    expect(provider.overview!.recentEvents, isNotEmpty);
  });
}
