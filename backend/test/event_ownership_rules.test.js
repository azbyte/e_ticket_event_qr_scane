const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateEventInput,
  normalizePermissions,
  EDITABLE_EVENT_STATUSES,
  EVENT_PERMISSION_CODES,
} = require('../src/controllers/eventController');

const validPayload = {
  title: 'Konferensi Teknologi 2026',
  date: '2026-08-10T09:00:00.000Z',
  end_date_time: '2026-08-10T17:00:00.000Z',
  event_format: 'OFFLINE',
  location: 'Auditorium Utama UNP',
  organizer_name: 'Himpunan Informatika',
  contact_info: 'info@himatif.ac.id',
  attendee_fields: ['name', 'email', 'phone'],
  category: 'Teknologi',
};

test('validateEventInput accepts a complete and valid event payload', () => {
  assert.equal(validateEventInput(validPayload), true);
});

test('validateEventInput rejects missing or too short title', () => {
  assert.equal(validateEventInput({ ...validPayload, title: 'AB' }), false);
  assert.equal(validateEventInput({ ...validPayload, title: '' }), false);
  assert.equal(validateEventInput({ ...validPayload, title: null }), false);
});

test('validateEventInput rejects invalid dates or end date before start date', () => {
  assert.equal(validateEventInput({ ...validPayload, date: 'not-a-date' }), false);
  assert.equal(validateEventInput({ ...validPayload, end_date_time: 'not-a-date' }), false);
  assert.equal(
    validateEventInput({
      ...validPayload,
      date: '2026-08-10T17:00:00.000Z',
      end_date_time: '2026-08-10T09:00:00.000Z',
    }),
    false
  );
});

test('validateEventInput validates format-specific location and online url requirements', () => {
  // OFFLINE requires location
  assert.equal(validateEventInput({ ...validPayload, event_format: 'OFFLINE', location: '' }), false);

  // ONLINE requires valid online URL
  assert.equal(validateEventInput({ ...validPayload, event_format: 'ONLINE', online_url: '' }), false);
  assert.equal(validateEventInput({ ...validPayload, event_format: 'ONLINE', online_url: 'invalid-url' }), false);
  assert.equal(
    validateEventInput({
      ...validPayload,
      event_format: 'ONLINE',
      location: null,
      online_url: 'https://meet.google.com/abc-defg-hij',
    }),
    true
  );

  // HYBRID requires both
  assert.equal(
    validateEventInput({
      ...validPayload,
      event_format: 'HYBRID',
      location: 'Ruang Seminar',
      online_url: 'https://zoom.us/j/123456789',
    }),
    true
  );
  assert.equal(
    validateEventInput({
      ...validPayload,
      event_format: 'HYBRID',
      location: '',
      online_url: 'https://zoom.us/j/123456789',
    }),
    false
  );
});

test('validateEventInput enforces attendee fields array containing name', () => {
  assert.equal(validateEventInput({ ...validPayload, attendee_fields: [] }), false);
  assert.equal(validateEventInput({ ...validPayload, attendee_fields: ['email'] }), false);
  assert.equal(validateEventInput({ ...validPayload, attendee_fields: ['name', 'unsupported_field'] }), false);
  assert.equal(validateEventInput({ ...validPayload, attendee_fields: ['name', 'email', 'organization'] }), true);
});

test('EDITABLE_EVENT_STATUSES allows draft and review states but forbids post-approval mutations', () => {
  assert.ok(EDITABLE_EVENT_STATUSES.includes('DRAFT'));
  assert.ok(EDITABLE_EVENT_STATUSES.includes('PENDING_REVIEW'));
  assert.ok(EDITABLE_EVENT_STATUSES.includes('REVISION_REQUESTED'));
  assert.ok(EDITABLE_EVENT_STATUSES.includes('REJECTED'));
});

test('normalizePermissions filters out unrecognized permission codes and removes duplicates', () => {
  const input = ['VIEW_EVENT', 'SCAN_TICKET', 'INVALID_PERM', 'VIEW_EVENT', 'CHECK_IN_TICKET'];
  const normalized = normalizePermissions(input);
  assert.deepEqual(normalized, ['VIEW_EVENT', 'SCAN_TICKET', 'CHECK_IN_TICKET']);
  assert.deepEqual(normalizePermissions(null), []);
  assert.deepEqual(normalizePermissions('not an array'), []);
});

test('EVENT_PERMISSION_CODES contains the required event permissions', () => {
  assert.ok(EVENT_PERMISSION_CODES.has('VIEW_EVENT'));
  assert.ok(EVENT_PERMISSION_CODES.has('SCAN_TICKET'));
  assert.ok(EVENT_PERMISSION_CODES.has('CHECK_IN_TICKET'));
  assert.ok(EVENT_PERMISSION_CODES.has('VIEW_REPORTS'));
});
