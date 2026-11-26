const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
// config/env.js memvalidasi JWT_SECRET saat startup. Unit test ini tidak pernah
// menyentuh database (lapisan `db` di-stub di bawah), tetapi modul controller
// yang di-require tetap memuat config/env, jadi secret khusus test disediakan.
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const dbPath = require.resolve('../src/config/db');
const state = {};

function resetDbState(overrides = {}) {
  Object.assign(
    state,
    {
      eventRow: null,
      memberRow: null,
      permissionRows: [],
      ticketByToken: null,
      ticketByCode: null,
      ticketById: null,
      orderItemRow: null,
      orderRow: null,
      existingCheckIn: null,
      lockedTicketRow: null,
      insertedCheckIn: null,
      attendeeRows: [],
      calls: [],
    },
    overrides
  );
}

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    query: async (sql, params) => {
      state.calls.push({ sql, params });
      if (sql.includes('FROM event_member_permissions')) {
        return state.permissionRows;
      }
      if (sql.includes('FROM tickets t') && sql.includes('WHERE t.event_id = $1')) {
        return state.attendeeRows;
      }
      return [];
    },
    getOne: async (sql, params) => {
      state.calls.push({ sql, params });
      if (sql.includes('FROM events WHERE id = $1')) {
        return state.eventRow;
      }
      if (sql.includes('FROM event_members WHERE')) {
        return state.memberRow;
      }
      if (sql.includes('FROM tickets t') && sql.includes('WHERE t.token_hash = $1')) {
        return state.ticketByToken;
      }
      if (sql.includes('FROM tickets t') && sql.includes('WHERE t.ticket_code = $1')) {
        return state.ticketByCode;
      }
      if (sql.includes('FROM tickets t') && sql.includes('WHERE t.id = $1')) {
        return state.ticketById;
      }
      if (sql.includes('FROM order_items WHERE id = $1')) {
        return state.orderItemRow;
      }
      if (sql.includes('FROM event_orders WHERE id = $1')) {
        return state.orderRow;
      }
      if (sql.includes('FROM check_ins WHERE ticket_id = $1')) {
        return state.existingCheckIn;
      }
      return null;
    },
    pool: {
      connect: async () => ({
        query: async (sql, params) => {
          state.calls.push({ sql, params });
          if (sql.includes('FOR UPDATE')) {
            return { rows: state.lockedTicketRow ? [state.lockedTicketRow] : [] };
          }
          if (sql.includes('INSERT INTO check_ins')) {
            return { rows: state.insertedCheckIn ? [state.insertedCheckIn] : [] };
          }
          if (sql.includes('UPDATE tickets')) {
            return { rowCount: 1 };
          }
          if (sql.includes('INSERT INTO scan_logs')) {
            return { rowCount: 1 };
          }
          return { rows: [] };
        },
        release: () => {},
      }),
    },
  },
};

const {
  validateTicket,
  recordCheckIn,
  listEventAttendees,
  assertScanPermission,
  findTicketByIdentifier,
  orderOfTicket,
  normalizeTicketStatus,
  SCAN_RESULTS,
} = require('../src/controllers/checkInController');
const tokens = require('../src/services/ticketTokenService');

function mockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

// 1. Constants & Status Mapping
test('SCAN_RESULTS exposes PRD-defined scanner outcome codes', () => {
  assert.equal(SCAN_RESULTS.VALID, 'VALID');
  assert.equal(SCAN_RESULTS.ALREADY_USED, 'ALREADY_USED');
  assert.equal(SCAN_RESULTS.INVALID, 'INVALID');
  assert.equal(SCAN_RESULTS.WRONG_EVENT, 'WRONG_EVENT');
  assert.equal(SCAN_RESULTS.PAYMENT_REQUIRED, 'PAYMENT_REQUIRED');
  assert.equal(SCAN_RESULTS.CANCELLED, 'CANCELLED');
  assert.equal(SCAN_RESULTS.REVOKED, 'REVOKED');
});

test('normalizeTicketStatus maps active to valid and used to checked_in', () => {
  assert.equal(normalizeTicketStatus('active'), 'valid');
  assert.equal(normalizeTicketStatus('used'), 'checked_in');
  assert.equal(normalizeTicketStatus('cancelled'), 'cancelled');
  assert.equal(normalizeTicketStatus(null), 'unknown');
});

// 2. assertScanPermission
test('assertScanPermission rejects unauthenticated users with 401', async () => {
  resetDbState();
  await assert.rejects(
    () => assertScanPermission('evt-1', null),
    (err) => err.statusCode === 401 && err.message.includes('Authentication required')
  );
});

test('assertScanPermission rejects non-existent event with 404', async () => {
  resetDbState({ eventRow: null });
  await assert.rejects(
    () => assertScanPermission('evt-not-found', { id: 'u-1', role: 'organizer' }),
    (err) => err.statusCode === 404 && err.message.includes('Event not found')
  );
});

test('assertScanPermission allows admin and event creator without member check', async () => {
  resetDbState({ eventRow: { id: 'evt-1', created_by: 'u-creator' } });
  // Admin role
  const adminRes = await assertScanPermission('evt-1', { id: 'u-admin', role: 'admin' });
  assert.equal(adminRes, null);

  // Event creator
  const creatorRes = await assertScanPermission('evt-1', { id: 'u-creator', role: 'organizer' });
  assert.equal(creatorRes, null);
});

test('assertScanPermission rejects non-staff or inactive staff with 403', async () => {
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    memberRow: null,
  });
  await assert.rejects(
    () => assertScanPermission('evt-1', { id: 'u-stranger', role: 'staff' }),
    (err) => err.statusCode === 403 && err.message.includes('not an active staff member')
  );

  // Inactive member
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    memberRow: { id: 'm-1', status: 'INACTIVE' },
  });
  await assert.rejects(
    () => assertScanPermission('evt-1', { id: 'u-stranger', role: 'staff' }),
    (err) => err.statusCode === 403
  );
});

test('assertScanPermission rejects staff lacking SCAN_TICKET or CHECK_IN_TICKET permission with 403', async () => {
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    memberRow: { id: 'm-1', status: 'ACTIVE' },
    permissionRows: [{ permission: 'VIEW_REPORTS' }],
  });
  await assert.rejects(
    () => assertScanPermission('evt-1', { id: 'u-staff', role: 'staff' }),
    (err) => err.statusCode === 403 && err.message.includes('permission')
  );
});

test('assertScanPermission accepts staff with SCAN_TICKET permission', async () => {
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    memberRow: { id: 'm-1', status: 'ACTIVE' },
    permissionRows: [{ permission: 'SCAN_TICKET' }],
  });
  const memberId = await assertScanPermission('evt-1', { id: 'u-staff', role: 'staff' });
  assert.equal(memberId, 'm-1');
});

// 3. findTicketByIdentifier
test('findTicketByIdentifier finds ticket by token hash or ticket_code', async () => {
  const dummyTicket = { id: 't-1', ticket_code: 'TK-TECH-001', event_id: 'evt-1', status: 'active' };
  resetDbState({ ticketByToken: dummyTicket, ticketByCode: dummyTicket });

  // Empty or invalid input
  assert.equal(await findTicketByIdentifier(''), null);
  assert.equal(await findTicketByIdentifier(null), null);

  // Via code lookup
  resetDbState({ ticketByToken: null, ticketByCode: dummyTicket });
  const byCode = await findTicketByIdentifier('TK-TECH-001');
  assert.equal(byCode?.id, 't-1');
});

// 4. validateTicket
test('validateTicket rejects unauthenticated scan request with 401', async () => {
  const req = { user: null, body: { token: 'sample-token' } };
  const res = mockRes();
  await assert.rejects(
    () => validateTicket(req, res),
    (err) => err.statusCode === 401
  );
});

test('validateTicket rejects missing token with 400', async () => {
  const req = { user: { id: 'u-creator', role: 'organizer' }, body: {} };
  const res = mockRes();
  await assert.rejects(
    () => validateTicket(req, res),
    (err) => err.statusCode === 400
  );
});

test('validateTicket returns INVALID when ticket is not found', async () => {
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByToken: null,
    ticketByCode: null,
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { token: 'UNKNOWN_TOKEN_000', event_id: 'evt-1' },
  };
  const res = mockRes();
  await validateTicket(req, res);
  assert.equal(res.body.success, true);
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, SCAN_RESULTS.INVALID);
});

test('validateTicket returns WRONG_EVENT when ticket does not belong to scanning event', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-DIFF-001',
    event_id: 'evt-another',
    status: 'active',
  };
  resetDbState({
    eventRow: { id: 'evt-current', created_by: 'u-creator' },
    ticketByCode: ticket,
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-DIFF-001', event_id: 'evt-current' },
  };
  const res = mockRes();
  await validateTicket(req, res);
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, SCAN_RESULTS.WRONG_EVENT);
  assert.match(res.body.message, /tidak berlaku untuk event ini/);
});

test('validateTicket returns ALREADY_USED when ticket has already been checked in', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-USED-001',
    event_id: 'evt-1',
    status: 'used',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: ticket,
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-USED-001', event_id: 'evt-1' },
  };
  const res = mockRes();
  await validateTicket(req, res);
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, SCAN_RESULTS.ALREADY_USED);
  assert.match(res.body.message, /sudah digunakan/);
});

test('validateTicket returns CANCELLED and REVOKED for invalidated tickets', async () => {
  const cancelledTicket = {
    id: 't-1',
    ticket_code: 'TK-CANC-001',
    event_id: 'evt-1',
    status: 'cancelled',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: cancelledTicket,
  });
  const req1 = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-CANC-001', event_id: 'evt-1' },
  };
  const res1 = mockRes();
  await validateTicket(req1, res1);
  assert.equal(res1.body.valid, false);
  assert.equal(res1.body.status, SCAN_RESULTS.CANCELLED);

  const revokedTicket = {
    id: 't-2',
    ticket_code: 'TK-REV-001',
    event_id: 'evt-1',
    status: 'revoked',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: revokedTicket,
  });
  const req2 = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-REV-001', event_id: 'evt-1' },
  };
  const res2 = mockRes();
  await validateTicket(req2, res2);
  assert.equal(res2.body.valid, false);
  assert.equal(res2.body.status, SCAN_RESULTS.REVOKED);
});

test('validateTicket returns PAYMENT_REQUIRED when order is not paid', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-UNPAID-001',
    event_id: 'evt-1',
    status: 'active',
    attendee_order_item_id: 'item-1',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: ticket,
    orderItemRow: { order_id: 'ord-1' },
    orderRow: { id: 'ord-1', status: 'PENDING' },
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-UNPAID-001', event_id: 'evt-1' },
  };
  const res = mockRes();
  await validateTicket(req, res);
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, SCAN_RESULTS.PAYMENT_REQUIRED);
  assert.match(res.body.message, /Pembayaran belum terkonfirmasi/);
});

test('validateTicket returns VALID for eligible paid ticket on matching event', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-VALID-001',
    event_id: 'evt-1',
    status: 'active',
    attendee_order_item_id: 'item-1',
    attendee_name: 'Budi Hartono',
    attendee_email: 'budi@example.com',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: ticket,
    orderItemRow: { order_id: 'ord-1' },
    orderRow: { id: 'ord-1', status: 'PAID' },
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-VALID-001', event_id: 'evt-1' },
  };
  const res = mockRes();
  await validateTicket(req, res);
  assert.equal(res.body.valid, true);
  assert.equal(res.body.status, SCAN_RESULTS.VALID);
  assert.equal(res.body.ticket.status, 'valid');
  assert.equal(res.body.ticket.attendee_name, 'Budi Hartono');
});

// 5. recordCheckIn
test('recordCheckIn rejects duplicate check-in with 409', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-VALID-001',
    event_id: 'evt-1',
    status: 'active',
    attendee_order_item_id: 'item-1',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: ticket,
    orderItemRow: { order_id: 'ord-1' },
    orderRow: { id: 'ord-1', status: 'PAID' },
    existingCheckIn: { id: 'chk-existing' },
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-VALID-001', event_id: 'evt-1' },
  };
  const res = mockRes();
  await assert.rejects(
    () => recordCheckIn(req, res),
    (err) => err.statusCode === 409 && err.message.includes('Tiket sudah di-check-in')
  );
});

test('recordCheckIn commits atomic one-time check-in and scan log', async () => {
  const ticket = {
    id: 't-1',
    ticket_code: 'TK-VALID-001',
    event_id: 'evt-1',
    status: 'active',
    attendee_order_item_id: 'item-1',
  };
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    ticketByCode: ticket,
    orderItemRow: { order_id: 'ord-1' },
    orderRow: { id: 'ord-1', status: 'PAID' },
    existingCheckIn: null,
    lockedTicketRow: { status: 'active' },
    insertedCheckIn: { id: 'chk-new-1', ticket_id: 't-1', event_id: 'evt-1' },
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    body: { ticket_code: 'TK-VALID-001', event_id: 'evt-1' },
  };
  const res = mockRes();
  await recordCheckIn(req, res);
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.success, true);
  assert.equal(res.body.ticket.status, 'checked_in');

  // Verify atomic SQL sequence: BEGIN -> SELECT FOR UPDATE -> INSERT check_ins -> UPDATE tickets -> INSERT scan_logs -> COMMIT
  const sqls = state.calls.map((c) => c.sql);
  assert.ok(sqls.includes('BEGIN'));
  assert.ok(sqls.some((s) => s.includes('FOR UPDATE')));
  assert.ok(sqls.some((s) => s.includes('INSERT INTO check_ins')));
  assert.ok(sqls.some((s) => s.includes('UPDATE tickets SET status = $1')));
  assert.ok(sqls.some((s) => s.includes('INSERT INTO scan_logs')));
  assert.ok(sqls.includes('COMMIT'));
});

// 6. listEventAttendees
test('listEventAttendees sorts PAID orders first and includes registration_number', async () => {
  resetDbState({
    eventRow: { id: 'evt-1', created_by: 'u-creator' },
    attendeeRows: [
      {
        id: 't-1',
        ticket_code: 'TK-001',
        attendee_name: 'Alice',
        attendee_email: 'alice@test.id',
        ticket_type_name: 'VIP',
        status: 'active',
        order_number: 'ORD-2026-001',
        payment_status: 'PAID',
        purchased_at: new Date('2026-05-01'),
      },
      {
        id: 't-2',
        ticket_code: 'TK-002',
        attendee_name: 'Bob',
        attendee_email: 'bob@test.id',
        ticket_type_name: 'Reguler',
        status: 'active',
        order_number: null,
        payment_status: 'PENDING',
        purchased_at: new Date('2026-05-02'),
      },
    ],
  });
  const req = {
    user: { id: 'u-creator', role: 'organizer' },
    params: { eventId: 'evt-1' },
  };
  const res = mockRes();
  await listEventAttendees(req, res);
  assert.equal(res.body.success, true);
  assert.equal(res.body.count, 2);
  assert.equal(res.body.attendees[0].attendee_name, 'Alice');
  assert.equal(res.body.attendees[0].registration_number, 'ORD-2026-001');
  assert.equal(res.body.attendees[0].payment_status, 'PAID');
  assert.equal(res.body.attendees[1].attendee_name, 'Bob');
  assert.equal(res.body.attendees[1].registration_number, 'TK-002');
  assert.equal(res.body.attendees[1].payment_status, 'PENDING');
});
