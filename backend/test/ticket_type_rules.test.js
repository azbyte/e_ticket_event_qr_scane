const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateDraft,
  validateTicketTypeUpdate,
  buildTicketTypeUpdate,
} = require('../src/controllers/ticketTypeController');

const existing = {
  name: 'Reguler',
  price: '10000.00',
  quota: 100,
  sold: 20,
  held: 10,
  max_per_order: 10,
};

test('ticket type accepts immutable price and a quota increase', () => {
  assert.deepEqual(validateTicketTypeUpdate({ price: 10000, quota: 120 }, existing), []);
});

test('ticket type rejects price changes and quota reductions', () => {
  const errors = validateTicketTypeUpdate({ price: 12000, quota: 90 }, existing);
  assert.ok(errors.some((error) => error.includes('price cannot be changed')));
  assert.ok(errors.some((error) => error.includes('quota can only be increased')));
});

test('ticket type rejects quota below sold plus held tickets', () => {
  const errors = validateTicketTypeUpdate({ quota: 25 }, existing);
  assert.ok(errors.some((error) => error.includes('sold plus held')));
});

test('ticket type update SQL compares immutable and monotonic values atomically', () => {
  const update = buildTicketTypeUpdate({ price: 10000, quota: 120 }, 'ticket-id', 'event-id');
  assert.match(update.sql, /price = \$\d+/);
  assert.match(update.sql, /quota <= \$\d+/);
  assert.match(update.sql, /\$\d+ >= sold \+ held/);
  assert.deepEqual(update.params, [10000, 120, 'ticket-id', 'event-id', 10000, 120]);
});

test('ticket type creation retains nonnegative price validation', () => {
  const errors = validateDraft({ name: 'Gratis', price: -1, quota: 10 });
  assert.ok(errors.some((error) => error.includes('zero or greater')));
});