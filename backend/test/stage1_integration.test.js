/**
 * Test integrasi Tahap 1 (integrator/Developer 4).
 *
 * Cakupan: auth/role middleware -> event & kategori tiket -> order guest ->
 * pembayaran simulasi -> pembacaan tiket, memakai controller/middleware/service
 * asli dengan lapisan `pg` in-memory. Tidak ada koneksi database, seed, atau
 * mutasi data sungguhan (lihat `task/TAHAP_1/LAPORAN_DEVELOPER_4.md`).
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://stage1:stage1@127.0.0.1:5432/e_ticket_stage1_test';
process.env.JWT_SECRET = 'stage1-integration-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'stage1-integration-ticket-secret';
process.env.SMTP_HOST = 'json';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const jwt = require('jsonwebtoken');

const db = require('../src/config/db');

const ORGANIZER = {
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Organizer Uji',
  email: 'organizer@example.test',
  role: 'organizer',
  disabled_at: null,
};
const ADMIN = {
  id: '99999999-9999-4999-8999-999999999999',
  name: 'Admin Uji',
  email: 'admin@example.test',
  role: 'admin',
  disabled_at: null,
};
const ATTENDEE = {
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  name: 'Peserta Uji',
  email: 'peserta@example.test',
  role: 'attendee',
  disabled_at: null,
};

const CATEGORY_ID = '22222222-2222-4222-8222-222222222222';
const DRAFT_EVENT_ID = '33333333-3333-4333-8333-333333333333';
const PUBLIC_EVENT_ID = '44444444-4444-4444-8444-444444444444';
const TICKET_TYPE_ID = '55555555-5555-4555-8555-555555555555';
const ORDER_ID = '66666666-6666-4666-8666-666666666666';
const PAYMENT_ID = '77777777-7777-4777-8777-777777777777';
const TICKET_ID = '88888888-8888-4888-8888-888888888888';
const ATTENDEE_ID = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

const NOW = '2026-11-23T08:00:00.000Z';
// Batas kedaluwarsa dihitung relatif terhadap waktu berjalan supaya test tidak
// gagal hanya karena tanggal fixture sudah terlewati.
const DAY_IN_MS = 24 * 60 * 60 * 1000;
const FUTURE = new Date(Date.now() + DAY_IN_MS).toISOString();
const PAST = new Date(Date.now() - DAY_IN_MS).toISOString();

const state = {
  profiles: [ORGANIZER, ADMIN, ATTENDEE],
  events: {},
  ticketTypes: [],
  existingTicketTypes: [],
  createOrderParams: null,
  createOrderCalls: 0,
  simulateCalls: 0,
  idempotencyExisting: null,
  orderTokenHash: null,
  orderStatus: 'PENDING_PAYMENT',
  orderExpiresAt: FUTURE,
  paymentStatus: 'PENDING',
  ticketRows: [],
};

const resetState = () => {
  state.profiles = [ORGANIZER, ADMIN, ATTENDEE];
  state.events = {
    [DRAFT_EVENT_ID]: {
      id: DRAFT_EVENT_ID,
      created_by: ORGANIZER.id,
      status: 'DRAFT',
      is_public: false,
    },
    [PUBLIC_EVENT_ID]: {
      id: PUBLIC_EVENT_ID,
      created_by: ORGANIZER.id,
      status: 'PUBLISHED',
      is_public: true,
    },
  };
  state.ticketTypes = [];
  state.existingTicketTypes = [];
  state.createOrderParams = null;
  state.createOrderCalls = 0;
  state.simulateCalls = 0;
  state.idempotencyExisting = null;
  state.orderTokenHash = null;
  state.orderStatus = 'PENDING_PAYMENT';
  state.orderExpiresAt = FUTURE;
  state.paymentStatus = 'PENDING';
  state.ticketRows = [];
};

const normalizeSql = (sql) => String(sql).replace(/\s+/g, ' ').trim();
const hasSql = (sql, ...fragments) => {
  const normalized = normalizeSql(sql);
  return fragments.every((fragment) => normalized.includes(fragment));
};

const buildOrderRow = (overrides = {}) => ({
  id: ORDER_ID,
  order_number: 'ORD-STAGE1-0001',
  event_id: PUBLIC_EVENT_ID,
  purchaser_id: null,
  assisted_by_member_id: null,
  registration_method: 'SELF_SERVICE',
  guest_name: 'Budi Santoso',
  guest_email: 'budi@example.test',
  guest_phone: '081200000000',
  guest_access_token_hash: state.orderTokenHash,
  idempotency_key: 'stage1-idempotency-key-0001',
  idempotency_fingerprint: 'fingerprint-stage1',
  status: state.orderStatus,
  subtotal: '25000.00',
  service_fee: '5000.00',
  commission_rate: '0.050000',
  commission_amount: '1250.00',
  grand_total: '30000.00',
  expires_at: state.orderExpiresAt,
  created_at: NOW,
  updated_at: NOW,
  event_title: 'Konser Uji Integrasi',
  ...overrides,
});

const buildOrderItems = () => [{
  id: 'item-1',
  order_id: ORDER_ID,
  ticket_type_id: TICKET_TYPE_ID,
  quantity: 1,
  unit_price: '25000.00',
  subtotal: '25000.00',
  ticket_type_name: 'Reguler',
}];

const buildPaymentRow = () => ({
  id: PAYMENT_ID,
  order_id: ORDER_ID,
  method: 'SIMULATED_VIRTUAL_ACCOUNT',
  status: state.paymentStatus,
  amount: '30000.00',
  payment_reference: 'SIM-ORD-STAGE1-0001',
  idempotency_key: null,
  virtual_account_number: '8800112233445566',
  virtual_account_bank: 'VA Simulasi',
  expires_at: FUTURE,
  paid_at: state.paymentStatus === 'PAID' ? NOW : null,
  failure_reason: state.paymentStatus === 'FAILED' ? 'Simulasi gagal' : null,
  created_at: NOW,
  updated_at: NOW,
});

const buildTicketRow = (overrides = {}) => ({
  id: TICKET_ID,
  ticket_code: 'TKT-STAGE1-0001',
  token_hash: null,
  event_id: PUBLIC_EVENT_ID,
  user_id: null,
  ticket_type_id: TICKET_TYPE_ID,
  attendee_id: ATTENDEE_ID,
  qr_code_data: 'TKT-STAGE1-0001',
  status: 'active',
  purchased_at: NOW,
  issued_at: NOW,
  used_at: null,
  attendee_name: 'Budi Santoso',
  attendee_email: 'budi@example.test',
  attendee_phone: '081200000000',
  order_id: ORDER_ID,
  events_id: PUBLIC_EVENT_ID,
  events_title: 'Konser Uji Integrasi',
  events_event_date: '2026-12-01T10:00:00.000Z',
  events_status: 'PUBLISHED',
  events_is_public: true,
  ...overrides,
});

const fakeQuery = async (sql, params = []) => {
  if (hasSql(sql, 'FROM profiles WHERE id = $1')) {
    return state.profiles.filter((profile) => profile.id === params[0]);
  }
  if (hasSql(sql, 'FROM revoked_tokens')) return [];
  if (hasSql(sql, 'FROM event_categories WHERE name = $1')) {
    return [{ id: CATEGORY_ID, name: params[0] }];
  }
  if (hasSql(sql, 'INSERT INTO events')) {
    const created = {
      id: DRAFT_EVENT_ID,
      title: params[0],
      description: params[1],
      poster_url: params[2],
      event_date: params[3],
      end_date_time: params[4],
      time_zone: params[5],
      event_format: params[6],
      location: params[7],
      online_url: params[8],
      contact_info: params[9],
      organizer_name: params[10],
      public_info: params[11],
      attendee_fields: JSON.parse(params[12]),
      category_id: params[13],
      status: 'DRAFT',
      is_public: false,
      review_note: null,
      created_by: params[18],
      created_at: params[19],
      updated_at: params[20],
    };
    state.events[DRAFT_EVENT_ID] = created;
    return [created];
  }
  // Auto-publish (D1-2): transisi status yang ditulis controller.
  if (hasSql(sql, 'UPDATE events SET status =')) {
    const eventId = params[4];
    const existing = state.events[eventId] || {};
    const published = normalizeSql(sql).includes("status = 'PUBLISHED'");
    const updated = {
      ...existing,
      id: eventId,
      status: published ? 'PUBLISHED' : 'DRAFT',
      is_public: params[0],
      review_note: params[1],
      public_url: params[3],
      submitted_at: params[2] ? NOW : existing.submitted_at || null,
      event_date: existing.event_date || validEventPayload.event_date,
      end_date_time: existing.end_date_time || validEventPayload.end_date_time,
      event_format: existing.event_format || 'OFFLINE',
      title: existing.title || validEventPayload.title,
      category_id: existing.category_id || CATEGORY_ID,
      organizer_name: existing.organizer_name || 'Himpunan Informatika',
      contact_info: existing.contact_info || 'organizer@example.test',
      location: existing.location || 'Auditorium Utama UNP',
      attendee_fields: existing.attendee_fields || ['name', 'email', 'phone'],
    };
    state.events[eventId] = updated;
    return [updated];
  }
  if (hasSql(sql, 'SELECT id, attendee_fields FROM events WHERE id = $1')) {
    const event = state.events[params[0]];
    if (!event) return [];
    return [{
      id: event.id,
      attendee_fields: event.attendee_fields || ['name', 'email', 'phone'],
    }];
  }
  if (hasSql(sql, 'c.name AS category_name', 'WHERE e.id = $1')) {
    const event = state.events[params[0]];
    return event ? [{ ...event, category_name: 'Teknologi' }] : [];
  }
  if (hasSql(sql, 'SELECT id, created_by, status, is_public FROM events WHERE id = $1')) {
    return state.events[params[0]] ? [state.events[params[0]]] : [];
  }
  if (hasSql(sql, 'SELECT id, price FROM ticket_types WHERE event_id = $1')) {
    return state.existingTicketTypes;
  }
  if (hasSql(sql, 'INSERT INTO ticket_types')) {
    return [{
      id: TICKET_TYPE_ID,
      event_id: params[0],
      name: params[1],
      description: params[2],
      price: Number(params[3]).toFixed(2),
      quota: params[4],
      sold: 0,
      held: 0,
      max_per_order: params[5],
      sales_start: params[6],
      sales_end: params[7],
      is_active: params[8],
      created_at: NOW,
      updated_at: NOW,
    }];
  }
  if (hasSql(sql, 'SELECT * FROM ticket_types WHERE event_id = $1')) {
    return state.ticketTypes.filter((row) => row.event_id === params[0]);
  }

  if (hasSql(sql, 'FROM event_orders WHERE idempotency_key = $1', 'idempotency_fingerprint')) {
    return state.idempotencyExisting ? [state.idempotencyExisting] : [];
  }
  if (hasSql(sql, 'SELECT public.create_event_order(')) {
    state.createOrderCalls += 1;
    state.createOrderParams = params;
    return [{ create_event_order: ORDER_ID }];
  }
  if (hasSql(sql, 'FROM event_orders WHERE idempotency_key = $1')) {
    return [{
      id: ORDER_ID,
      guest_access_token_hash: state.createOrderParams ? state.createOrderParams[10] : null,
      purchaser_id: null,
    }];
  }
  if (hasSql(sql, 'FROM event_orders eo JOIN events e ON e.id = eo.event_id WHERE eo.id = $1')) {
    return [buildOrderRow()];
  }
  if (hasSql(sql, 'FROM order_items oi JOIN ticket_types tt ON tt.id = oi.ticket_type_id WHERE oi.order_id = $1')) {
    return buildOrderItems();
  }
  if (hasSql(sql, 'SELECT * FROM order_payments WHERE order_id = $1')) {
    return [buildPaymentRow()];
  }
  if (hasSql(sql, 'SELECT public.simulate_event_payment(')) {
    state.simulateCalls += 1;
    state.paymentStatus = params[3] ? 'PAID' : 'FAILED';
    state.orderStatus = params[3] ? 'PAID' : 'PENDING_PAYMENT';
    return [{ simulate_event_payment: PAYMENT_ID }];
  }
  if (hasSql(sql, 'SELECT * FROM order_payments WHERE id = $1')) {
    return [buildPaymentRow()];
  }
  if (hasSql(sql, 'SELECT 1 FROM attendees a JOIN order_items oi ON oi.id = a.order_item_id')) {
    return [{ membership: 1 }];
  }
  if (hasSql(sql, 'FROM tickets t JOIN events e ON e.id=t.event_id', 'WHERE oi.order_id=$1')) {
    return state.ticketRows;
  }
  if (hasSql(sql, 'FROM tickets t JOIN events e ON e.id=t.event_id', 'WHERE t.id=$1')) {
    return state.ticketRows.filter((row) => row.id === params[0]);
  }
  if (hasSql(sql, 'UPDATE tickets SET token_hash = $1 WHERE id = $2')) {
    return [];
  }
  return [];
};

const fakeGetOne = async (sql, params = []) => {
  const rows = await fakeQuery(sql, params);
  return rows[0] || null;
};

// Lapisan `pg` diganti sebelum controller di-require agar controller memakai
// implementasi in-memory. Pool sengaja dibuat gagal keras supaya tidak ada
// koneksi database nyata yang lolos tanpa sengaja.
db.query = fakeQuery;
db.getOne = fakeGetOne;
db.supabase = { query: fakeQuery, getOne: fakeGetOne };
db.pool = {
  query: fakeQuery,
  on: () => {},
  // Transaksi order (D1-5) memakai client yang sama dengan fake query;
  // tidak ada koneksi database nyata yang dibuka.
  connect: async () => ({ query: fakeQuery, release: () => {} }),
};

const { authMiddleware, optionalAuth } = require('../src/middleware/authMiddleware');
const allowRoles = require('../src/middleware/roleMiddleware');
const { createEvent } = require('../src/controllers/eventController');
const {
  createTicketType,
  listEventTicketTypes,
} = require('../src/controllers/ticketTypeController');
const {
  createOrder,
  getOrder,
  hashAccessToken,
} = require('../src/controllers/orderController');
const { getPayment, simulatePayment } = require('../src/controllers/paymentController');
const { getMyTickets, getTicketById } = require('../src/controllers/ticketController');

const createRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
};

const createReq = ({ body = {}, params = {}, query = {}, user = null, headers = {} } = {}) => ({
  body,
  params,
  query,
  user,
  headers,
  get: (name) => headers[String(name).toLowerCase()] ?? null,
});

const signToken = (profile) => jwt.sign(
  { id: profile.id, email: profile.email, role: profile.role },
  process.env.JWT_SECRET,
  { expiresIn: '1h' },
);

const bearer = (profile) => ({ authorization: `Bearer ${signToken(profile)}` });

const validEventPayload = {
  title: 'Konser Uji Integrasi',
  description: 'Event sintetis untuk test integrasi',
  event_date: '2026-12-01T10:00:00.000Z',
  end_date_time: '2026-12-01T13:00:00.000Z',
  time_zone: 'Asia/Jakarta',
  event_format: 'OFFLINE',
  location: 'Auditorium Uji',
  organizer_name: 'Organizer Uji',
  contact_info: 'organizer@example.test',
  attendee_fields: ['name', 'email', 'phone'],
  category: 'Teknologi',
};

const validOrderBody = () => ({
  event_id: PUBLIC_EVENT_ID,
  items: { [TICKET_TYPE_ID]: 1 },
  attendees: [{
    ticket_type_id: TICKET_TYPE_ID,
    name: 'Budi Santoso',
    email: 'budi@example.test',
    phone: '081200000000',
  }],
});

test.beforeEach(() => resetState());


// ---------------------------------------------------------------------------
// 1. Auth -> role (server-authoritative)
// ---------------------------------------------------------------------------

test('auth middleware memakai role dari database, bukan klaim token', async () => {
  const forged = jwt.sign(
    { id: ORGANIZER.id, email: ORGANIZER.email, role: 'admin' },
    process.env.JWT_SECRET,
    { expiresIn: '1h' },
  );
  const req = createReq({ headers: { authorization: `Bearer ${forged}` } });
  const res = createRes();
  let resolved = null;

  await authMiddleware(req, res, () => { resolved = req.user; });

  assert.equal(resolved.id, ORGANIZER.id);
  assert.equal(resolved.role, 'organizer');
});

test('auth middleware menolak request tanpa token dan akun disabled', async () => {
  const noTokenRes = createRes();
  let noTokenError = null;
  await authMiddleware(createReq(), noTokenRes, (err) => { noTokenError = err; });
  assert.equal(noTokenRes.statusCode, 401);
  assert.match(noTokenError.message, /no token/i);

  state.profiles = [{ ...ORGANIZER, disabled_at: NOW }, ADMIN, ATTENDEE];
  const disabledRes = createRes();
  let disabledError = null;
  await authMiddleware(
    createReq({ headers: bearer(ORGANIZER) }),
    disabledRes,
    (err) => { disabledError = err; },
  );
  assert.equal(disabledRes.statusCode, 401);
  assert.match(disabledError.message, /disabled/i);
});

test('optionalAuth membiarkan guest tetap lanjut saat token tidak valid', async () => {
  const req = createReq({ headers: { authorization: 'Bearer token-tidak-valid' } });
  let called = false;

  await optionalAuth(req, createRes(), () => { called = true; });

  assert.equal(called, true);
  assert.equal(req.user, null);
});

test('role gate organizer menolak admin dan mengizinkan organizer', () => {
  const gate = allowRoles('organizer');

  const adminRes = createRes();
  let adminNext = false;
  gate({ user: { role: 'admin' } }, adminRes, () => { adminNext = true; });
  assert.equal(adminRes.statusCode, 403);
  assert.equal(adminNext, false);

  let organizerNext = false;
  gate({ user: { role: 'organizer' } }, createRes(), () => { organizerNext = true; });
  assert.equal(organizerNext, true);
});

// ---------------------------------------------------------------------------
// 2. Event & kategori tiket -> kontrak Flutter
// ---------------------------------------------------------------------------

test('createEvent menyimpan draft dan mengembalikan kontrak EventModel', async () => {
  const res = createRes();
  await createEvent(createReq({ body: validEventPayload, user: ORGANIZER }), res);

  assert.equal(res.statusCode, 201);
  const event = res.body.event;
  assert.equal(event.id, DRAFT_EVENT_ID);
  assert.equal(event.organizer_id, ORGANIZER.id);
  assert.equal(event.status, 'draft');
  assert.equal(event.event_type, 'offline');
  assert.equal(event.start_date_time, validEventPayload.event_date);
  assert.equal(event.end_date_time, validEventPayload.end_date_time);
  assert.equal(event.category, 'Teknologi');
  assert.equal(event.is_public, false);
  // Kontrak attendee_fields kini bertipe (D1-5) dan kompatibel dengan array
  // string lama; kunci tetap sama seperti payload.
  assert.deepEqual(
    event.attendee_fields.map((field) => field.key),
    ['name', 'email', 'phone'],
  );
  assert.equal(event.attendee_fields[0].required, true);
  assert.equal(event.validation_errors.length, 1);
  assert.match(event.validation_errors[0], /kategori tiket aktif/i);
  assert.equal(event.contact_info, 'organizer@example.test');
});

test('createEvent menolak payload tidak valid tanpa menyentuh penyimpanan', async () => {
  const res = createRes();
  await assert.rejects(
    async () => createEvent(createReq({
      body: { ...validEventPayload, title: 'AB', attendee_fields: [] },
      user: ORGANIZER,
    }), res),
    /valid title/i,
  );
  assert.equal(res.statusCode, 400);
});

test('kategori tiket baru mengembalikan DTO harga/kuota yang dipakai checkout', async () => {
  const res = createRes();
  await createTicketType(createReq({
    params: { eventId: DRAFT_EVENT_ID },
    user: ORGANIZER,
    body: {
      name: 'Reguler',
      price: 25000,
      quota: 100,
      max_per_order: 1,
      sales_start: '2026-11-01T00:00:00.000Z',
      sales_end: '2026-11-30T00:00:00.000Z',
    },
  }), res);

  assert.equal(res.statusCode, 201);
  const dto = res.body.ticket_type;
  assert.equal(dto.event_id, DRAFT_EVENT_ID);
  assert.equal(dto.price, 25000);
  assert.equal(dto.remaining_quota, 100);
  assert.equal(dto.is_sold_out, false);
  assert.equal(dto.is_available, true);
  assert.equal(res.body.ticketType.id, TICKET_TYPE_ID);
});

test('kategori tiket menolak pencampuran gratis dan berbayar dalam satu event', async () => {
  state.existingTicketTypes = [{ id: 'existing-free', price: '0.00' }];
  const res = createRes();

  await assert.rejects(
    async () => createTicketType(createReq({
      params: { eventId: DRAFT_EVENT_ID },
      user: ORGANIZER,
      body: { name: 'VIP', price: 50000, quota: 10 },
    }), res),
    /Event gratis tidak boleh memiliki kategori tiket berbayar/,
  );
  assert.equal(res.statusCode, 400);
});

test('daftar kategori publik hanya dapat dibaca untuk event publik', async () => {
  state.ticketTypes = [{
    id: TICKET_TYPE_ID,
    event_id: PUBLIC_EVENT_ID,
    name: 'Reguler',
    price: '25000.00',
    quota: 100,
    sold: 40,
    held: 10,
    is_active: true,
    sales_start: null,
    sales_end: null,
    created_at: NOW,
  }];

  const okRes = createRes();
  await listEventTicketTypes(createReq({ params: { eventId: PUBLIC_EVENT_ID } }), okRes);
  assert.equal(okRes.statusCode, 200);
  assert.equal(okRes.body.ticket_types.length, 1);
  assert.equal(okRes.body.ticket_types[0].remaining_quota, 50);
  assert.equal(okRes.body.ticket_types[0].is_available, true);

  const draftRes = createRes();
  await assert.rejects(
    async () => listEventTicketTypes(createReq({ params: { eventId: DRAFT_EVENT_ID } }), draftRes),
    (err) => {
      assert.match(err.message, /Event not found/);
      assert.equal(err.statusCode, 404);
      return true;
    },
  );
});


// ---------------------------------------------------------------------------
// 3. Order guest -> pembayaran -> tiket
// ---------------------------------------------------------------------------

test('createOrder menolak quantity selain 1 dan assisted registration', async () => {
  const overQuantity = createRes();
  await assert.rejects(
    async () => createOrder(createReq({
      body: {
        ...validOrderBody(),
        items: { [TICKET_TYPE_ID]: 2 },
        attendees: [
          { ticket_type_id: TICKET_TYPE_ID, name: 'Budi', email: 'budi@example.test' },
          { ticket_type_id: TICKET_TYPE_ID, name: 'Dewi', email: 'dewi@example.test' },
        ],
      },
    }), overQuantity),
    /exactly one ticket and one attendee/i,
  );
  assert.equal(overQuantity.statusCode, 400);

  const assisted = createRes();
  await assert.rejects(
    async () => createOrder(createReq({
      body: { ...validOrderBody(), assisted_by_member_id: ORGANIZER.id },
    }), assisted),
    /Assisted registration is not supported/i,
  );
  assert.equal(assisted.statusCode, 400);
});

test('createOrder guest mengembalikan kontrak OrderModel dan token akses order', async () => {
  const res = createRes();
  await createOrder(createReq({
    body: validOrderBody(),
    headers: { 'idempotency-key': 'stage1-idempotency-key-0001' },
  }), res);

  assert.equal(res.statusCode, 201);
  const order = res.body.order;

  // Kontrak Flutter OrderModel.
  assert.equal(order.id, ORDER_ID);
  assert.equal(order.event_id, PUBLIC_EVENT_ID);
  assert.equal(order.event_title, 'Konser Uji Integrasi');
  assert.equal(order.status, 'pending_payment');
  assert.equal(order.total_amount, 25000);
  assert.equal(order.service_fee, 5000);
  assert.equal(order.grand_total, 30000);
  assert.equal(order.items.length, 1);
  assert.equal(order.items[0].ticket_type_name, 'Reguler');
  assert.equal(order.items[0].quantity, 1);
  assert.equal(order.payment.status, 'pending');
  assert.equal(order.payment.virtual_account_number, '8800112233445566');
  assert.equal(order.payment_reference, 'SIM-ORD-STAGE1-0001');
  assert.equal(Object.hasOwn(order, 'guest_access_token_hash'), false);
  assert.equal(Object.hasOwn(order, 'idempotency_key'), false);

  // Token guest berkekuatan tinggi; hanya hash-nya yang dikirim ke database.
  assert.equal(typeof res.body.order_access_token, 'string');
  assert.ok(res.body.order_access_token.length >= 40);
  const params = state.createOrderParams;
  assert.equal(params[6], null, 'order guest tidak boleh mengikat purchaser');
  assert.equal(params[10], hashAccessToken(res.body.order_access_token));
  assert.notEqual(params[10], res.body.order_access_token);

  // Harga tidak dipercaya dari klien: hanya ticket_type_id + quantity dikirim.
  assert.deepEqual(params[1], { [TICKET_TYPE_ID]: 1 });
});

test('retry idempotent mengembalikan order yang sama tanpa membuat order baru', async () => {
  const first = createRes();
  await createOrder(createReq({
    body: validOrderBody(),
    headers: { 'idempotency-key': 'stage1-idempotency-key-0001' },
  }), first);
  assert.equal(state.createOrderCalls, 1);

  state.idempotencyExisting = {
    id: ORDER_ID,
    idempotency_fingerprint: state.createOrderParams[9],
    purchaser_id: null,
  };

  const replay = createRes();
  await createOrder(createReq({
    body: validOrderBody(),
    headers: { 'idempotency-key': 'stage1-idempotency-key-0001' },
  }), replay);

  assert.equal(replay.statusCode, 201);
  assert.equal(replay.body.idempotent_replay, true);
  assert.equal(replay.body.order_access_token, null);
  assert.equal(replay.body.order.status, 'pending_payment');
  assert.equal(state.createOrderCalls, 1, 'replay tidak boleh memanggil RPC lagi');

  const conflict = createRes();
  await assert.rejects(
    async () => createOrder(createReq({
      body: {
        ...validOrderBody(),
        attendees: [{
          ticket_type_id: TICKET_TYPE_ID,
          name: 'Nama Berbeda',
          email: 'beda@example.test',
        }],
      },
      headers: { 'idempotency-key': 'stage1-idempotency-key-0001' },
    }), conflict),
    /different order data/i,
  );
  assert.equal(conflict.statusCode, 409);
});

test('order guest hanya dapat dibaca dengan token akses order yang benar', async () => {
  const res = createRes();
  await createOrder(createReq({
    body: validOrderBody(),
    headers: { 'idempotency-key': 'stage1-idempotency-key-0002' },
  }), res);
  const token = res.body.order_access_token;
  state.orderTokenHash = hashAccessToken(token);

  const authorized = createRes();
  await getOrder(createReq({
    params: { id: ORDER_ID },
    headers: { 'x-order-access-token': token },
  }), authorized);
  assert.equal(authorized.statusCode, 200);
  assert.equal(authorized.body.order.status, 'pending_payment');
  assert.deepEqual(authorized.body.data, authorized.body.order);

  const wrongToken = createRes();
  await assert.rejects(
    async () => getOrder(createReq({
      params: { id: ORDER_ID },
      headers: { 'x-order-access-token': 'token-palsu-yang-tidak-cocok' },
    }), wrongToken),
    /Order not found/,
  );
  assert.equal(wrongToken.statusCode, 404);

  const noToken = createRes();
  await assert.rejects(
    async () => getOrder(createReq({ params: { id: ORDER_ID } }), noToken),
    /Order not found/,
  );
  assert.equal(noToken.statusCode, 404);
});


test('pembayaran simulasi memakai kontrak PaymentModel dan menolak status final', async () => {
  state.orderTokenHash = hashAccessToken('token-akses-guest-stage1');
  const tokenHeaders = { 'x-order-access-token': 'token-akses-guest-stage1' };

  const pending = createRes();
  await getPayment(createReq({ params: { orderId: ORDER_ID }, headers: tokenHeaders }), pending);
  assert.equal(pending.statusCode, 200);
  assert.equal(pending.body.payment.method, 'virtual_account');
  assert.equal(pending.body.payment.status, 'pending');
  assert.equal(pending.body.payment.va_bank, 'VA Simulasi');
  assert.equal(pending.body.payment.amount, 30000);

  const paid = createRes();
  await simulatePayment(createReq({
    body: { order_id: ORDER_ID, simulate_success: true },
    headers: tokenHeaders,
  }), paid);
  assert.equal(paid.statusCode, 200);
  assert.equal(paid.body.payment.status, 'paid');
  assert.equal(paid.body.email_delivery.transport, 'json');
  assert.deepEqual(paid.body.email_delivery.results, []);
  assert.equal(state.simulateCalls, 1);

  const alreadyPaid = createRes();
  await assert.rejects(
    async () => simulatePayment(createReq({
      body: { order_id: ORDER_ID, simulate_success: true },
      headers: tokenHeaders,
    }), alreadyPaid),
    /already been paid/i,
  );
  assert.equal(alreadyPaid.statusCode, 400);

  state.orderStatus = 'PENDING_PAYMENT';
  state.orderExpiresAt = PAST;
  const expired = createRes();
  await assert.rejects(
    async () => simulatePayment(createReq({
      body: { order_id: ORDER_ID, simulate_success: true },
      headers: tokenHeaders,
    }), expired),
    /expired/i,
  );
  assert.equal(expired.statusCode, 400);

  state.orderExpiresAt = FUTURE;
  const failed = createRes();
  await simulatePayment(createReq({
    body: { order_id: ORDER_ID, simulate_success: false },
    headers: tokenHeaders,
  }), failed);
  assert.equal(failed.statusCode, 200);
  assert.equal(failed.body.payment.status, 'failed');
});

test('pembacaan tiket order mengembalikan kontrak TicketModel untuk guest', async () => {
  state.orderTokenHash = hashAccessToken('token-akses-guest-stage1');
  state.ticketRows = [buildTicketRow()];
  const headers = { 'x-order-access-token': 'token-akses-guest-stage1' };

  const list = createRes();
  await getMyTickets(createReq({ query: { order_id: ORDER_ID }, headers }), list);
  assert.equal(list.statusCode, 200);
  assert.equal(list.body.count, 1);
  const ticket = list.body.tickets[0];
  assert.equal(ticket.id, TICKET_ID);
  assert.equal(ticket.order_id, ORDER_ID);
  assert.equal(ticket.attendee_name, 'Budi Santoso');
  assert.equal(ticket.attendee_email, 'budi@example.test');
  assert.equal(ticket.status, 'valid');
  assert.equal(ticket.event_id, PUBLIC_EVENT_ID);
  assert.equal(typeof ticket.token, 'string');
  assert.ok(ticket.token.length >= 40);
  assert.equal(Object.hasOwn(ticket, 'token_hash'), false);
  assert.equal(ticket.events.title, 'Konser Uji Integrasi');

  const detail = createRes();
  await getTicketById(createReq({
    params: { id: TICKET_ID },
    query: { order_id: ORDER_ID },
    headers,
  }), detail);
  assert.equal(detail.statusCode, 200);
  assert.equal(detail.body.ticket.status, 'valid');
  assert.equal(detail.body.ticket.order_id, ORDER_ID);
  assert.equal(detail.body.ticket.attendee_name, 'Budi Santoso');

  const forbidden = createRes();
  await assert.rejects(
    async () => getTicketById(createReq({
      params: { id: TICKET_ID },
      query: { order_id: ORDER_ID },
      headers: { 'x-order-access-token': 'token-palsu' },
    }), forbidden),
    /Ticket not found/,
  );
  assert.equal(forbidden.statusCode, 404);
});

// ---------------------------------------------------------------------------
// 4. Route surface yang dikonsumsi klien Flutter
// ---------------------------------------------------------------------------

test('route Tahap 1 yang dipakai klien Flutter tetap terdaftar', () => {
  const readRoute = (file) =>
    fs.readFileSync(path.join(__dirname, '..', 'src', 'routes', file), 'utf8');

  // Route digabung per domain (Tier C): events.js memuat event + kategori tiket
  // + undangan; orders.js memuat order + pembayaran + tiket + check-in.
  const events = readRoute('events.js');
  assert.match(events, /eventRouter\.get\('\/public'/);
  assert.match(events, /eventRouter\.get\('\/:eventId\/ticket-types', optionalAuth/);
  assert.match(events, /eventRouter\.post\('\/:eventId\/ticket-types', authMiddleware, allowRoles\('organizer'\)/);

  const orders = readRoute('orders.js');
  assert.match(orders, /orderRouter\.post\('\/', optionalAuth/);
  assert.match(orders, /orderRouter\.get\('\/:id', optionalAuth/);
  assert.match(orders, /paymentRouter\.post\('\/simulate', optionalAuth/);
  assert.match(orders, /ticketRouter\.get\('\/my-tickets', optionalAuth/);
});

