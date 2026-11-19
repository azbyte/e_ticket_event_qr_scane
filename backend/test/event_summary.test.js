const test = require('node:test');
const assert = require('node:assert/strict');
const { serializeEventSummary } = require('../src/utils/eventSummary');

test('serializeEventSummary matches the organizer API snake_case contract', () => {
  const summary = serializeEventSummary(
    { id: 'event-1', status: 'PUBLISHED' },
    { ticketsSold: 3, ticketsRemaining: 7, grossSales: 1250 },
    2,
    3,
    1,
  );

  assert.deepEqual(summary, {
    event_id: 'event-1',
    status: 'published',
    tickets_sold: 3,
    tickets_remaining: 7,
    gross_sales: 1250,
    pending_orders: 2,
    participants: 3,
    checked_in: 1,
  });
});
