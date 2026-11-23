const test = require('node:test');
const assert = require('node:assert/strict');

const db = require('../src/config/db');

const OWNER = { id: '11111111-1111-4111-8111-111111111111', role: 'organizer' };
const ADMIN = { id: '99999999-9999-4999-8999-999999999999', role: 'admin' };
const EVENT_ID = '33333333-3333-4333-8333-333333333333';
const CATEGORY_ID = '22222222-2222-4222-8222-222222222222';
const TICKET_TYPE_ID = '55555555-5555-4555-8555-555555555555';

const state = { eventStatus: 'DRAFT', existingTypes: [] };

const fakeQuery = async (sql, params = []) => {
  const normalized = String(sql).replace(/\s+/g, ' ').trim();
  if (normalized.includes('SELECT id, created_by, status, is_public FROM events WHERE id = $1')) {
    return [{ id: EVENT_ID, created_by: OWNER.id, status: state.eventStatus, is_public: true }];
  }
  if (normalized.includes('SELECT id, price FROM ticket_types WHERE event_id = $1')) {
    return state.existingTypes;
  }
  if (normalized.includes('FROM event_categories WHERE name = $1')) {
    return [{ id: CATEGORY_ID, name: params[0] }];
  }
  if (normalized.includes('INSERT INTO ticket_types')) {
    return [{
      id: TICKET_TYPE_ID,
      event_id: params[0],
      name: params[1],
      price: Number(params[3]).toFixed(2),
      quota: params[4],
      sold: 0,
      held: 0,
      is_active: true,
    }];
  }
  return [];
};

db.query = fakeQuery;
db.getOne = async (sql, params = []) => (await fakeQuery(sql, params))[0] || null;
db.supabase = { query: db.query, getOne: db.getOne };

const { createTicketType, TICKET_TYPE_MUTABLE_EVENT_STATUSES, TICKET_TYPE_LOCKED_EVENT_STATUSES } =
  require('../src/controllers/ticketTypeController');

const createRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; return res; };
  return res;
};

const createReq = (user = OWNER) => ({
  params: { eventId: EVENT_ID },
  user,
  body: { name: 'Reguler', price: 25000, quota: 50 },
});

test.beforeEach(() => {
  state.eventStatus = 'DRAFT';
  state.existingTypes = [];
});

test('owner dapat menambah kategori tiket pada seluruh status yang masih dapat dijual', async () => {
  for (const status of ['DRAFT', 'PENDING_REVIEW', 'REVISION_REQUESTED', 'REJECTED', 'APPROVED', 'PUBLISHED']) {
    state.eventStatus = status;
    const res = createRes();
    await createTicketType(createReq(), res);
    assert.equal(res.statusCode, 201, `status ${status} seharusnya diizinkan`);
    assert.equal(res.body.ticketType.id, TICKET_TYPE_ID);
  }
});

test('event yang ditahan/selesai menolak perubahan kategori tiket (409)', async () => {
  for (const status of ['SUSPENDED', 'COMPLETED', 'CANCELLED']) {
    state.eventStatus = status;
    const res = createRes();
    await assert.rejects(
      async () => createTicketType(createReq(), res),
      (error) => {
        assert.equal(error.statusCode, 409);
        assert.match(error.message, /does not allow ticket type changes/);
        return true;
      },
      `status ${status} harus ditolak`,
    );
  }
});

test('admin tetap dapat mengubah kategori tiket pada event yang ditahan', async () => {
  state.eventStatus = 'SUSPENDED';
  const res = createRes();
  await createTicketType(createReq(ADMIN), res);
  assert.equal(res.statusCode, 201);
});

test('invarian harga gratis/berbayar tetap berlaku pada status APPROVED', async () => {
  state.eventStatus = 'APPROVED';
  state.existingTypes = [{ id: 'existing-free', price: '0.00' }];
  const res = createRes();
  await assert.rejects(
    async () => createTicketType(createReq(), res),
    /Event gratis tidak boleh memiliki kategori tiket berbayar/,
  );
  assert.equal(res.statusCode, 400);
});

test('daftar status mutable dan locked tidak saling tumpang tindih', () => {
  for (const status of TICKET_TYPE_LOCKED_EVENT_STATUSES) {
    assert.equal(TICKET_TYPE_MUTABLE_EVENT_STATUSES.includes(status), false, `${status} tidak boleh mutable`);
  }
  assert.ok(TICKET_TYPE_MUTABLE_EVENT_STATUSES.includes('PUBLISHED'));
});
