const test = require('node:test');
const assert = require('node:assert/strict');

// Unit test murni: koneksi database tidak pernah dipakai. Variabel ini hanya
// memenuhi validasi startup `config/env.js` sehingga `require` controller tidak
// berhenti dengan "Missing required environment variables".
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const db = require('../src/config/db');

const EVENT_ID = '11111111-1111-4111-8111-111111111111';
const OWNER_ID = '22222222-2222-4222-8222-222222222222';
const STAFF_ID = '33333333-3333-4333-8333-333333333333';
const STAFF_NO_PERM_ID = '44444444-4444-4444-8444-444444444444';

// Setup mock DB responses
const fakeQuery = async (sql, params = []) => {
  const norm = sql.replace(/\s+/g, ' ');

  if (norm.includes('FROM events WHERE id = $1')) {
    if (params[0] === EVENT_ID) {
      return [{ id: EVENT_ID, created_by: OWNER_ID, status: 'PUBLISHED' }];
    }
    return [];
  }

  if (norm.includes('FROM event_members WHERE event_id = $1 AND user_id = $2')) {
    if (params[1] === STAFF_ID) {
      return [{ id: 'mem-staff-01', event_id: EVENT_ID, user_id: STAFF_ID }];
    }
    if (params[1] === STAFF_NO_PERM_ID) {
      return [{ id: 'mem-staff-02', event_id: EVENT_ID, user_id: STAFF_NO_PERM_ID }];
    }
    return [];
  }

  if (norm.includes('FROM event_member_permissions WHERE event_member_id = $1')) {
    if (params[0] === 'mem-staff-01') {
      return [{ permission: 'VIEW_PARTICIPANTS' }];
    }
    return [{ permission: 'CHECK_IN_TICKET' }];
  }

  if (norm.includes('event_attendees') || norm.includes('FROM attendees a')) {
    return [
      {
        attendee_id: 'att-01',
        attendee_order_item_id: 'oi-01',
        attendee_name: 'Budi Santoso',
        attendee_email: 'budi@example.com',
        attendee_phone: '081234567890',
        organization: 'Komunitas Tech',
        custom_fields: { job: 'Engineer' },
        ticket_type_name: 'VIP Pass',
        ticket_id: 'tkt-01',
        ticket_code: 'TK-001',
        ticket_status: 'active',
        purchased_at: new Date('2026-10-01T10:00:00Z'),
        used_at: null,
        checked_in_at: null,
        order_id: 'ord-01',
        order_number: 'ORD-101',
        order_status: 'PAID',
        payment_status: 'PAID',
      },
      {
        attendee_id: 'att-02',
        attendee_order_item_id: 'oi-02',
        attendee_name: 'Citra Kirana',
        attendee_email: 'citra@example.com',
        attendee_phone: '081234567891',
        organization: 'Design Hub',
        custom_fields: {},
        ticket_type_name: 'Regular Pass',
        ticket_id: 'tkt-02',
        ticket_code: 'TK-002',
        ticket_status: 'active',
        purchased_at: new Date('2026-10-02T10:00:00Z'),
        used_at: null,
        checked_in_at: null,
        order_id: 'ord-02',
        order_number: 'ORD-102',
        order_status: 'PAID',
        payment_status: 'PAID',
      },
      {
        attendee_id: 'att-03',
        attendee_order_item_id: 'oi-03',
        attendee_name: 'Agus Setiawan',
        attendee_email: 'agus@example.com',
        attendee_phone: '081234567892',
        organization: null,
        custom_fields: {},
        ticket_type_name: 'Early Bird',
        ticket_id: null,
        ticket_code: null,
        ticket_status: 'pending',
        purchased_at: null,
        used_at: null,
        checked_in_at: null,
        order_id: 'ord-03',
        order_number: 'ORD-201',
        order_status: 'PENDING_PAYMENT',
        payment_status: 'PENDING',
      },
    ];
  }

  return [];
};

db.query = fakeQuery;
db.getOne = async (sql, params = []) => (await fakeQuery(sql, params))[0] || null;

const { listEventAttendees } = require('../src/controllers/checkInController');

const createRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; return res; };
  return res;
};

test('listEventAttendees (K1): memuat order_number dan payment_status untuk setiap peserta', async () => {
  const req = {
    user: { id: OWNER_ID, role: 'organizer' },
    params: { eventId: EVENT_ID },
    query: {},
  };
  const res = createRes();

  await listEventAttendees(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.attendees.length, 3);

  for (const attendee of res.body.attendees) {
    assert.ok(attendee.order_number, 'Peserta harus memiliki order_number');
    assert.ok(attendee.payment_status, 'Peserta harus memiliki payment_status');
    assert.ok('custom_fields' in attendee, 'Peserta harus memiliki custom_fields');
    assert.ok('order_status' in attendee, 'Peserta harus memiliki order_status');
  }
});

test('listEventAttendees (K2 & K3): peserta PAID tampil sebelum PENDING_PAYMENT, urut order_number menaik', async () => {
  const req = {
    user: { id: OWNER_ID, role: 'organizer' },
    params: { eventId: EVENT_ID },
    query: {},
  };
  const res = createRes();

  await listEventAttendees(req, res);

  assert.equal(res.statusCode, 200);
  const attendees = res.body.attendees;

  // K2: PAID muncul lebih dulu
  assert.equal(attendees[0].payment_status, 'PAID');
  assert.equal(attendees[1].payment_status, 'PAID');
  assert.equal(attendees[2].payment_status, 'PENDING');

  // K3: urutan dalam kelompok sama = order_number ASC
  assert.equal(attendees[0].order_number, 'ORD-101');
  assert.equal(attendees[1].order_number, 'ORD-102');
});

test('listEventAttendees (K4): staff tanpa VIEW_PARTICIPANTS ditolak dengan 403', async () => {
  const req = {
    user: { id: STAFF_NO_PERM_ID, role: 'staff' },
    params: { eventId: EVENT_ID },
    query: {},
  };
  const res = createRes();

  await assert.rejects(
    async () => {
      await listEventAttendees(req, res);
    },
    (err) => {
      assert.equal(err.statusCode, 403);
      assert.match(err.message, /permission/i);
      return true;
    }
  );
});

test('listEventAttendees: staff dengan VIEW_PARTICIPANTS diizinkan membaca data peserta', async () => {
  const req = {
    user: { id: STAFF_ID, role: 'staff' },
    params: { eventId: EVENT_ID },
    query: {},
  };
  const res = createRes();

  await listEventAttendees(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.count, 3);
});
