const test = require('node:test');
const assert = require('node:assert/strict');
const { serializeEvent } = require('../src/utils/eventResponse');

test('serializeEvent maps persisted event columns to Flutter API fields', () => {
  const result = serializeEvent({
    id: 'event-1',
    created_by: 'user-1',
    event_date: '2026-12-01T10:00:00.000Z',
    event_format: 'HYBRID',
    status: 'APPROVED',
    event_categories: { name: 'Teknologi' },
  });

  assert.equal(result.organizer_id, 'user-1');
  assert.equal(result.start_date_time, '2026-12-01T10:00:00.000Z');
  assert.equal(result.event_type, 'hybrid');
  assert.equal(result.status, 'approved');
  assert.equal(result.category, 'Teknologi');
});

test('serializeEvent rejects rows missing required API state instead of inventing defaults', () => {
  assert.throws(
    () => serializeEvent({ id: 'event-1', event_format: 'OFFLINE' }),
    /status and format are required/,
  );
});
