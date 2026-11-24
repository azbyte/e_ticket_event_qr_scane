const test = require('node:test');
const assert = require('node:assert/strict');
const {
  serializeEvent,
  buildPublicUrl,
  buildInviteUrl,
  publicUrlFor,
} = require('../src/utils/eventResponse');

const BASE_URL = 'https://tiket.example.test';

const withBaseUrl = (callback) => {
  const previous = process.env.APP_PUBLIC_URL;
  process.env.APP_PUBLIC_URL = BASE_URL;
  try {
    callback();
  } finally {
    if (previous === undefined) delete process.env.APP_PUBLIC_URL;
    else process.env.APP_PUBLIC_URL = previous;
  }
};

const buildEvent = (overrides = {}) => ({
  id: 'event-42',
  created_by: 'user-1',
  title: 'Seminar Publik',
  event_date: '2026-12-01T10:00:00.000Z',
  event_format: 'OFFLINE',
  status: 'PUBLISHED',
  is_public: true,
  event_categories: { name: 'Seminar' },
  ...overrides,
});

test('event PUBLISHED mengembalikan public_url absolut (K1 D1-3)', () => {
  withBaseUrl(() => {
    const result = serializeEvent(buildEvent());
    assert.equal(result.public_url, `${BASE_URL}/e/event-42`);
    assert.equal(result.status, 'published');
  });
});

test('event DRAFT/REJECTED tidak memiliki public_url (K2 D1-3)', () => {
  withBaseUrl(() => {
    assert.equal(publicUrlFor(buildEvent({ status: 'DRAFT', is_public: false })), null);
    assert.equal(serializeEvent(buildEvent({ status: 'DRAFT', is_public: false })).public_url, null);
    assert.equal(serializeEvent(buildEvent({ status: 'REJECTED', is_public: false })).public_url, null);
    // PUBLISHED tetapi is_public=false tetap tidak tayang.
    assert.equal(serializeEvent(buildEvent({ is_public: false })).public_url, null);
  });
});

test('event APPROVED legacy tetap dianggap tayang (kompatibilitas data lama)', () => {
  withBaseUrl(() => {
    assert.equal(
      serializeEvent(buildEvent({ status: 'APPROVED' })).public_url,
      `${BASE_URL}/e/event-42`
    );
  });
});

test('invite_url berbeda dari public_url dan memakai token mentah (K3 D1-3)', () => {
  withBaseUrl(() => {
    const publicUrl = buildPublicUrl('event-42');
    const inviteUrl = buildInviteUrl('raw-token-abc');
    assert.equal(inviteUrl, `${BASE_URL}/invite/raw-token-abc`);
    assert.notEqual(inviteUrl, publicUrl);
  });
});

test('serializeEvent mengekspos validation_errors dari review_note JSON', () => {
  withBaseUrl(() => {
    const result = serializeEvent(
      buildEvent({
        status: 'DRAFT',
        is_public: false,
        review_note: JSON.stringify(['Minimal satu kategori tiket aktif diperlukan']),
      })
    );
    assert.deepEqual(result.validation_errors, [
      'Minimal satu kategori tiket aktif diperlukan',
    ]);
    assert.equal(result.public_url, null);
  });
});

test('serializeEvent tidak mengubah kontrak lama (status, event_type, organizer_id)', () => {
  const result = serializeEvent(buildEvent({ event_format: 'HYBRID', status: 'APPROVED' }));
  assert.equal(result.organizer_id, 'user-1');
  assert.equal(result.start_date_time, '2026-12-01T10:00:00.000Z');
  assert.equal(result.event_type, 'hybrid');
  assert.equal(result.status, 'approved');
  assert.equal(result.category, 'Seminar');
});
