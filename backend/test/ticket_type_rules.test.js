const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validateDraft,
  validateTicketTypeUpdate,
  buildTicketTypeUpdate,
  toTicketTypeDto,
  validateTicketTypeAvailability,
  validateTicketTypePricing,
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

test('ticket type pricing consistency rejects mixing free and paid categories in same event', () => {
  const freeEvent = [{ id: 'tt-1', price: 0 }];
  const paidEvent = [{ id: 'tt-2', price: 50000 }];

  assert.equal(validateTicketTypePricing([], 0), null);
  assert.equal(validateTicketTypePricing([], 50000), null);
  assert.equal(validateTicketTypePricing(freeEvent, 0), null);
  assert.equal(validateTicketTypePricing(paidEvent, 75000), null);

  assert.match(
    validateTicketTypePricing(freeEvent, 25000),
    /Event gratis tidak boleh memiliki kategori tiket berbayar/
  );
  assert.match(
    validateTicketTypePricing(paidEvent, 0),
    /Event berbayar tidak boleh memiliki kategori tiket gratis/
  );
});

test('ticket type availability validation rejects inactive, sold out, or out-of-window tickets', () => {
  const now = new Date('2026-06-15T12:00:00Z');

  // Inactive
  const inactive = {
    is_active: false,
    quota: 100,
    sold: 10,
    held: 0,
    sales_start: '2026-06-01T00:00:00Z',
    sales_end: '2026-06-30T00:00:00Z',
  };
  const inactiveErrors = validateTicketTypeAvailability(inactive, now);
  assert.ok(inactiveErrors.some((e) => e.includes('inactive')));

  // Sold out
  const soldOut = {
    is_active: true,
    quota: 50,
    sold: 45,
    held: 5,
    sales_start: '2026-06-01T00:00:00Z',
    sales_end: '2026-06-30T00:00:00Z',
  };
  const soldOutErrors = validateTicketTypeAvailability(soldOut, now);
  assert.ok(soldOutErrors.some((e) => e.includes('sold out')));

  // Not started yet
  const future = {
    is_active: true,
    quota: 100,
    sold: 0,
    held: 0,
    sales_start: '2026-07-01T00:00:00Z',
    sales_end: '2026-07-31T00:00:00Z',
  };
  const futureErrors = validateTicketTypeAvailability(future, now);
  assert.ok(futureErrors.some((e) => e.includes('not started yet')));

  // Already ended
  const past = {
    is_active: true,
    quota: 100,
    sold: 10,
    held: 0,
    sales_start: '2026-05-01T00:00:00Z',
    sales_end: '2026-06-01T00:00:00Z',
  };
  const pastErrors = validateTicketTypeAvailability(past, now);
  assert.ok(pastErrors.some((e) => e.includes('already ended')));

  // Valid and available
  const valid = {
    is_active: true,
    quota: 100,
    sold: 20,
    held: 5,
    sales_start: '2026-06-01T00:00:00Z',
    sales_end: '2026-06-30T00:00:00Z',
  };
  assert.deepEqual(validateTicketTypeAvailability(valid, now), []);
});

test('toTicketTypeDto computes remaining quota and availability flags correctly', () => {
  const row = {
    id: 'tt-101',
    event_id: 'evt-1',
    name: 'Early Bird',
    price: '25000.00',
    quota: 100,
    sold: 30,
    held: 10,
    is_active: true,
  };
  const dto = toTicketTypeDto(row);
  assert.equal(dto.price, 25000);
  assert.equal(dto.remaining_quota, 60);
  assert.equal(dto.is_sold_out, false);
  assert.equal(dto.is_available, true);

  const soldOutRow = {
    ...row,
    sold: 95,
    held: 5,
  };
  const soldOutDto = toTicketTypeDto(soldOutRow);
  assert.equal(soldOutDto.remaining_quota, 0);
  assert.equal(soldOutDto.is_sold_out, true);
  assert.equal(soldOutDto.is_available, false);
});