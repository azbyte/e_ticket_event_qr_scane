const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeAttendeeFields,
  validateEventForPublish,
  resolvePublishTransition,
  parseValidationNote,
} = require('../src/utils/eventValidation');

const NOW = new Date('2026-11-23T08:00:00.000Z');

const buildEvent = (overrides = {}) => ({
  id: 'evt-1',
  title: 'Konferensi Teknologi 2026',
  event_date: '2026-12-10T09:00:00.000Z',
  end_date_time: '2026-12-10T17:00:00.000Z',
  event_format: 'OFFLINE',
  location: 'Auditorium Utama',
  online_url: null,
  category_id: 'cat-1',
  organizer_name: 'Himpunan Informatika',
  contact_info: 'info@himatif.ac.id',
  attendee_fields: ['name', 'email', 'phone'],
  ...overrides,
});

const buildTicketTypes = (overrides = {}) => [
  {
    id: 'tt-1',
    name: 'Reguler',
    price: '25000.00',
    quota: 100,
    sold: 0,
    held: 0,
    is_active: true,
    sales_start: '2026-11-01T00:00:00.000Z',
    sales_end: '2026-12-09T00:00:00.000Z',
    ...overrides,
  },
];

test('event lengkap dan kategori tiket valid lolos validasi publikasi (K1)', () => {
  const errors = validateEventForPublish(buildEvent(), buildTicketTypes(), { now: NOW });
  assert.deepEqual(errors, []);
});

test('event tanpa kategori tiket aktif tetap privat beserta alasannya (K2)', () => {
  const noTypes = validateEventForPublish(buildEvent(), [], { now: NOW });
  assert.ok(noTypes.some((message) => /kategori tiket aktif/i.test(message)));

  const inactive = validateEventForPublish(
    buildEvent(),
    buildTicketTypes({ is_active: false }),
    { now: NOW }
  );
  assert.ok(inactive.some((message) => /kategori tiket aktif/i.test(message)));
});

test('jadwal, format, lokasi, dan tautan online divalidasi server', () => {
  assert.ok(
    validateEventForPublish(
      buildEvent({ event_date: '2026-12-10T17:00:00.000Z', end_date_time: '2026-12-10T09:00:00.000Z' }),
      buildTicketTypes(),
      { now: NOW }
    ).some((message) => /setelah waktu mulai/i.test(message))
  );

  assert.ok(
    validateEventForPublish(buildEvent({ location: '' }), buildTicketTypes(), { now: NOW })
      .some((message) => /lokasi wajib/i.test(message))
  );

  assert.ok(
    validateEventForPublish(
      buildEvent({ event_format: 'ONLINE', location: null, online_url: 'bukan-url' }),
      buildTicketTypes(),
      { now: NOW }
    ).some((message) => /tautan online/i.test(message))
  );

  assert.deepEqual(
    validateEventForPublish(
      buildEvent({
        event_format: 'ONLINE',
        location: null,
        online_url: 'https://meet.example.test/abc',
      }),
      buildTicketTypes(),
      { now: NOW }
    ),
    []
  );
});

test('waktu mulai lampau menolak publikasi baru tetapi tidak membatalkan event tayang', () => {
  const past = buildEvent({
    event_date: '2026-11-01T09:00:00.000Z',
    end_date_time: '2026-11-01T17:00:00.000Z',
  });
  assert.ok(
    validateEventForPublish(past, buildTicketTypes(), { now: NOW })
      .some((message) => /sudah lewat/i.test(message))
  );
  assert.deepEqual(
    validateEventForPublish(past, buildTicketTypes(), { now: NOW, enforceFutureStart: false }),
    []
  );
});

test('kategori tiket harus homogen gratis/berbayar dan konsisten kuota', () => {
  const mixed = validateEventForPublish(
    buildEvent(),
    [...buildTicketTypes(), ...buildTicketTypes({ id: 'tt-2', name: 'Gratis', price: 0 })],
    { now: NOW }
  );
  assert.ok(mixed.some((message) => /sama-sama gratis atau sama-sama berbayar/i.test(message)));

  const overbooked = validateEventForPublish(
    buildEvent(),
    buildTicketTypes({ quota: 10, sold: 8, held: 5 }),
    { now: NOW }
  );
  assert.ok(overbooked.some((message) => /lebih kecil dari tiket terjual/i.test(message)));

  const badWindow = validateEventForPublish(
    buildEvent(),
    buildTicketTypes({
      sales_start: '2026-12-01T00:00:00.000Z',
      sales_end: '2026-11-01T00:00:00.000Z',
    }),
    { now: NOW }
  );
  assert.ok(badWindow.some((message) => /setelah awal/i.test(message)));
});

test('resolvePublishTransition menghasilkan PUBLISHED atau DRAFT + alasan (K1/K2)', () => {
  const published = resolvePublishTransition(buildEvent(), buildTicketTypes(), { now: NOW });
  assert.equal(published.valid, true);
  assert.equal(published.status, 'PUBLISHED');
  assert.equal(published.isPublic, true);
  assert.equal(published.reviewNote, null);
  assert.deepEqual(published.errors, []);

  const rejected = resolvePublishTransition(buildEvent(), [], { now: NOW });
  assert.equal(rejected.valid, false);
  assert.equal(rejected.status, 'DRAFT');
  assert.equal(rejected.isPublic, false);
  assert.deepEqual(parseValidationNote(rejected.reviewNote), rejected.errors);
});

test('edit event tayang menjadi tidak valid mengembalikan status DRAFT (K4)', () => {
  const publishedEvent = buildEvent({ status: 'PUBLISHED', is_public: true });
  const transition = resolvePublishTransition(publishedEvent, [], { now: NOW });
  assert.equal(transition.valid, false);
  assert.equal(transition.status, 'DRAFT');
  assert.equal(transition.isPublic, false);
});

test('normalizeAttendeeFields kompatibel dengan array string legacy', () => {
  const { fields, errors } = normalizeAttendeeFields(['name', 'email', 'phone']);
  assert.deepEqual(errors, []);
  assert.deepEqual(
    fields.map((field) => field.key),
    ['name', 'email', 'phone']
  );
  assert.equal(fields[0].required, true);
  assert.equal(fields[1].required, true);
  assert.equal(fields[2].required, false);
  assert.equal(fields[0].type, 'text');
});

test('normalizeAttendeeFields menerima field bertipe dan menolak konfigurasi salah', () => {
  const typed = normalizeAttendeeFields([
    { key: 'name', label: 'Nama', type: 'text', required: true },
    { key: 'email', label: 'Email', type: 'text', required: true },
    { key: 'shirt_size', label: 'Ukuran kaos', type: 'select', required: true, options: ['S', 'M', 'L'] },
  ]);
  assert.deepEqual(typed.errors, []);
  assert.deepEqual(typed.fields[2].options, ['S', 'M', 'L']);

  assert.ok(
    normalizeAttendeeFields([{ key: 'name' }, { key: 'shirt_size', type: 'select' }])
      .errors.some((message) => /opsi/i.test(message))
  );
  assert.ok(
    normalizeAttendeeFields([{ key: 'name' }, { key: 'x', type: 'unknown' }])
      .errors.some((message) => /tidak didukung/i.test(message))
  );
  assert.ok(
    normalizeAttendeeFields([{ key: 'email' }])
      .errors.some((message) => /"name"/i.test(message))
  );
  assert.ok(
    normalizeAttendeeFields(['name', 'unsupported_field'])
      .errors.some((message) => /tidak dikenal/i.test(message))
  );
});

test('normalizeAttendeeFields memakai default untuk event lama tanpa konfigurasi', () => {
  const { fields, errors } = normalizeAttendeeFields(null);
  assert.deepEqual(errors, []);
  assert.deepEqual(fields.map((field) => field.key), ['name', 'email']);
});

test('parseValidationNote mengabaikan catatan moderator teks biasa', () => {
  assert.deepEqual(parseValidationNote('Lengkapi poster.'), []);
  assert.deepEqual(parseValidationNote(null), []);
  assert.deepEqual(parseValidationNote('["A","B"]'), ['A', 'B']);
});

