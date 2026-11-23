#!/usr/bin/env node
/**
 * Smoke test integrasi Tahap 1 terhadap DATABASE_URL yang terhubung dan
 * berjalan lewat API Express lokal (loopback).
 *
 * Sifat: membuat fixture sintetis (akun, event, order, tiket) lalu menghapusnya
 * kembali. Tidak menyentuh schema. Hanya untuk database pengujian.
 *
 * Jalankan: NODE_ENV=test node scripts/integration/stage1.db-smoke.cjs
 */
'use strict';

const path = require('node:path');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { Pool } = require('pg');

const ROOT = path.resolve(__dirname, '..', '..');
require('dotenv').config({ path: path.join(ROOT, '.env') });
if (process.env.NODE_ENV !== 'test') {
  console.error('Smoke test menolak berjalan tanpa NODE_ENV=test (data akan dihapus setelah uji).');
  process.exit(1);
}
if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL tidak di-set.');
  process.exit(1);
}

const BASE = (process.env.TEST_API_URL || 'http://127.0.0.1:5099').replace(/\/$/, '');
const PREFIX = `IT4_${Date.now()}`;
const PASSWORD = 'Stage1Smoke123!';
const pool = new Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 15000 });
const fixtures = { userIds: [], eventIds: [], categoryId: null, orderIds: [] };
const results = [];
let server;

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const request = async (method, route, { token, body, orderToken, headers = {} } = {}) => {
  const response = await fetch(`${BASE}${route}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(orderToken ? { 'X-Order-Access-Token': orderToken } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json;
  try { json = await response.json(); } catch (_) { json = {}; }
  return { status: response.status, body: json };
};

const runTest = async (name, fn) => {
  try {
    await fn();
    results.push({ name, status: 'PASS' });
    console.log(`PASS ${name}`);
  } catch (error) {
    results.push({ name, status: 'FAIL', error: error.message });
    console.error(`FAIL ${name}: ${error.message}`);
  }
};

const awaitHealth = async () => {
  for (let i = 0; i < 60; i += 1) {
    try {
      const r = await fetch(`${BASE}/health`);
      if (r.ok) return;
    } catch (_) { /* tunggu */ }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error('API healthcheck timeout');
};

const createAccount = async (label) => {
  const email = `${PREFIX.toLowerCase()}.${label}@example.test`;
  const result = await request('POST', '/api/auth/register', {
    body: { name: `${PREFIX} ${label}`, email, password: PASSWORD },
  });
  assert(result.status === 201, `register ${label} => ${result.status}: ${JSON.stringify(result.body)}`);
  fixtures.userIds.push(result.body.user.id);
  return { id: result.body.user.id, email, password: PASSWORD };
};

const login = async (account) => {
  const result = await request('POST', '/api/auth/login', {
    body: { email: account.email, password: account.password },
  });
  assert(result.status === 200, `login ${account.email} => ${result.status}`);
  return result.body.token;
};

const cleanup = async (stateRef = {}) => {
  // Hanya baris yang dibuat suite ini: primary key yang direkam atau prefix IT4_.
  if (stateRef.eventId && !fixtures.eventIds.includes(stateRef.eventId)) {
    fixtures.eventIds.push(stateRef.eventId);
  }
  if (stateRef.organizerId && !fixtures.userIds.includes(stateRef.organizerId)) {
    fixtures.userIds.push(stateRef.organizerId);
  }
  if (stateRef.adminId && !fixtures.userIds.includes(stateRef.adminId)) {
    fixtures.userIds.push(stateRef.adminId);
  }
  if (stateRef.categoryId && !fixtures.categoryId) {
    fixtures.categoryId = stateRef.categoryId;
  }
  if (fixtures.eventIds.length) {
    const ids = fixtures.eventIds;
    await pool.query(`DELETE FROM platform_transactions WHERE order_payment_id IN (
      SELECT id FROM order_payments WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[])))`, [ids]);
    await pool.query('DELETE FROM ticket_email_deliveries WHERE ticket_id IN (SELECT id FROM tickets WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM check_ins WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM scan_logs WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM tickets WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM order_payments WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM attendees WHERE order_item_id IN (SELECT id FROM order_items WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[])))', [ids]);
    await pool.query('DELETE FROM order_items WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM event_orders WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_member_permissions WHERE event_member_id IN (SELECT id FROM event_members WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM event_members WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_moderations WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_activity_logs WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM ticket_types WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM events WHERE id=ANY($1::uuid[])', [ids]);
  }
  if (fixtures.userIds.length) {
    await pool.query('DELETE FROM organizer_profiles WHERE user_id=ANY($1::uuid[])', [fixtures.userIds]);
    await pool.query("DELETE FROM notifications WHERE user_id=ANY($1::uuid[]) AND title LIKE 'IT4\\_%'", [fixtures.userIds]);
    await pool.query('DELETE FROM audit_logs WHERE actor_id=ANY($1::uuid[])', [fixtures.userIds]);
    await pool.query('DELETE FROM profiles WHERE id=ANY($1::uuid[])', [fixtures.userIds]);
  }
  if (fixtures.categoryId) {
    await pool.query('DELETE FROM event_categories WHERE id=$1', [fixtures.categoryId]);
  }
};


const main = async () => {
  server = spawn(process.execPath, ['server.js'], {
    cwd: ROOT,
    env: {
      ...process.env,
      NODE_ENV: 'test',
      HOST: '127.0.0.1',
      PORT: new URL(BASE).port || '5099',
      SIMULATED_PAYMENTS_ENABLED: 'true',
      SEED_DEMO_ACCOUNTS: 'false',
      SMTP_HOST: 'json',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const logs = [];
  server.stdout.on('data', (data) => logs.push(String(data)));
  server.stderr.on('data', (data) => logs.push(String(data)));

  const state = {
    eventId: null, ticketTypeId: null, orderId: null, orderToken: null, ticketId: null,
    categoryId: null, organizerId: null, adminId: null, idempotencyKey: null,
  };

  try {
    await awaitHealth();
    await runTest('health API + koneksi database hidup', async () => {
      const health = await fetch(`${BASE}/health`);
      assert(health.status === 200, `health ${health.status}`);
      const { rows } = await pool.query('SELECT current_database() AS db, version() AS v');
      assert(rows[0].db, 'database name kosong');
      console.log(`   database=${rows[0].db} server=${String(rows[0].v).split(',')[0]}`);
    });

    await runTest('schema: fungsi RPC dan tabel inti tersedia', async () => {
      const { rows } = await pool.query(
        `SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='public'
           AND proname IN ('create_event_order','simulate_event_payment','expire_event_order_reservations')`
      );
      const names = rows.map((row) => row.proname);
      for (const fn of ['create_event_order', 'simulate_event_payment']) {
        assert(names.includes(fn), `fungsi ${fn} tidak ada di database`);
      }
      const tables = await pool.query(
        `SELECT count(*)::int AS n FROM information_schema.tables
         WHERE table_schema='public' AND table_type='BASE TABLE'`
      );
      assert(tables.rows[0].n >= 30, `jumlah tabel tak terduga: ${tables.rows[0].n}`);
    });

    const organizer = await createAccount('organizer');
    const admin = await createAccount('admin');
    state.organizerId = organizer.id;
    state.adminId = admin.id;
    await pool.query("UPDATE profiles SET role='admin' WHERE id=$1", [admin.id]);
    const organizerToken = await login(organizer);
    const adminToken = await login(admin);

    await runTest('auth: role dari database dan payload invalid ditolak', async () => {
      const me = await request('GET', '/api/auth/me', { token: organizerToken });
      assert(me.status === 200, `me ${me.status}: ${JSON.stringify(me.body)}`);
      const user = me.body.user || me.body.data || me.body;
      assert(user.role === 'organizer', `role ${user.role}`);
      const bad = await request('POST', '/api/events', { token: organizerToken, body: {} });
      assert(bad.status === 400, `payload kosong seharusnya 400, dapat ${bad.status}`);
    });


    const category = await pool.query(
      'INSERT INTO event_categories (name,slug) VALUES ($1,$2) RETURNING id',
      [`${PREFIX} Category`, `${PREFIX.toLowerCase()}-category`]
    );
    fixtures.categoryId = category.rows[0].id;
    state.categoryId = category.rows[0].id;

    await runTest('event: create + owner tambah kategori tiket saat Draft (PRD §10)', async () => {
      const created = await request('POST', '/api/events', {
        token: organizerToken,
        body: {
          title: `${PREFIX} Event Integrasi`,
          description: 'Event sintetis smoke test Tahap 1',
          event_date: '2026-12-20T10:00:00.000Z',
          end_date_time: '2026-12-20T13:00:00.000Z',
          time_zone: 'Asia/Jakarta',
          event_format: 'OFFLINE',
          location: 'Auditorium Smoke',
          organizer_name: `${PREFIX} Organizer`,
          contact_info: 'smoke@example.test',
          attendee_fields: ['name', 'email'],
          category: `${PREFIX} Category`,
        },
      });
      assert(created.status === 201, `create event ${created.status}: ${JSON.stringify(created.body)}`);
      state.eventId = created.body.event.id;
      fixtures.eventIds.push(state.eventId);
      assert(created.body.event.status === 'draft', `status awal ${created.body.event.status}`);
      assert(created.body.event.organizer_id === organizer.id, 'organizer_id tidak sesuai owner');

      const pricing = await request('POST', `/api/events/${state.eventId}/ticket-types`, {
        token: organizerToken,
        body: { name: `${PREFIX} Reguler`, price: 25000, quota: 50, max_per_order: 1 },
      });
      assert(pricing.status === 201, `create ticket type ${pricing.status}: ${JSON.stringify(pricing.body)}`);
      const dto = pricing.body.ticketType;
      state.ticketTypeId = dto.id;
      assert(dto.event_id === state.eventId, 'event_id kategori tidak sesuai');
      assert(Number(dto.price) === 25000, `price ${dto.price}`);
      assert(dto.remaining_quota === 50, `remaining_quota ${dto.remaining_quota}`);
      assert(dto.is_available === true, 'kategori baru seharusnya available');

      const freeMix = await request('POST', `/api/events/${state.eventId}/ticket-types`, {
        token: organizerToken,
        body: { name: `${PREFIX} Gratis`, price: 0, quota: 5 },
      });
      assert(freeMix.status === 400, `campuran gratis/berbayar seharusnya 400, dapat ${freeMix.status}`);

      const readonly = await pool.query(
        'SELECT count(*)::int AS n FROM ticket_types WHERE event_id=$1', [state.eventId]
      );
      assert(readonly.rows[0].n === 1, `kategori tersimpan ${readonly.rows[0].n}`);
    });

    await runTest('event: submit review + admin approve + muncul di publik', async () => {
      const submitted = await request('POST', `/api/events/${state.eventId}/submit-review`, { token: organizerToken });
      assert(submitted.status === 200, `submit ${submitted.status}: ${JSON.stringify(submitted.body)}`);

      const approved = await request('PUT', `/api/admin/events/${state.eventId}/moderation`, {
        token: adminToken,
        body: { status: 'APPROVED', note: 'smoke approval' },
      });
      assert(approved.status === 200, `approve ${approved.status}: ${JSON.stringify(approved.body)}`);

      const publicList = await request('GET', '/api/events/public');
      assert(publicList.status === 200, `public list ${publicList.status}`);
      const found = (publicList.body.events || []).some((item) => item.id === state.eventId);
      assert(found, 'event approved tidak muncul di daftar publik');

      const publicTypes = await request('GET', `/api/events/${state.eventId}/ticket-types`);
      assert(publicTypes.status === 200, `public ticket types ${publicTypes.status}`);
      assert(Array.isArray(publicTypes.body.ticket_types), 'ticket_types bukan array');
      assert(publicTypes.body.ticket_types.some((item) => item.id === state.ticketTypeId), 'kategori tidak tampil publik');

      // Regresi finishing F-09: owner tetap bisa menambah kategori saat event APPROVED,
      // event yang ditahan/selesai tetap ditolak.
      const extra = await request('POST', `/api/events/${state.eventId}/ticket-types`, {
        token: organizerToken,
        body: { name: `${PREFIX} Onsite`, price: 30000, quota: 10 },
      });
      assert(extra.status === 201, `tambah kategori pada APPROVED seharusnya 201, dapat ${extra.status}: ${JSON.stringify(extra.body)}`);

      const addedId = extra.body.ticketType.id;
      await pool.query("UPDATE events SET status='SUSPENDED' WHERE id=$1", [state.eventId]);
      const blocked = await request('POST', `/api/events/${state.eventId}/ticket-types`, {
        token: organizerToken,
        body: { name: `${PREFIX} Ditolak`, price: 1000, quota: 1 },
      });
      assert(blocked.status === 409, `event SUSPENDED seharusnya 409, dapat ${blocked.status}`);
      await pool.query("UPDATE events SET status='APPROVED' WHERE id=$1", [state.eventId]);
      await pool.query('DELETE FROM ticket_types WHERE id=$1', [addedId]);
    });

    await runTest('kategori tiket: DTO publik + daftar publik setelah approve', async () => {
      const publicTypes = await request('GET', `/api/events/${state.eventId}/ticket-types`);
      assert(publicTypes.status === 200, `public ticket types ${publicTypes.status}`);
      assert(Array.isArray(publicTypes.body.ticket_types), 'ticket_types bukan array');
      const dto = publicTypes.body.ticket_types.find((item) => item.id === state.ticketTypeId);
      assert(dto, 'kategori tidak tampil publik');
      assert(Number(dto.price) === 25000, `price publik ${dto.price}`);
      assert(dto.remaining_quota === 50, `remaining_quota ${dto.remaining_quota}`);
      assert(dto.is_available === true, 'kategori publik seharusnya available');
    });


    const orderBody = () => ({
      event_id: state.eventId,
      items: { [state.ticketTypeId]: 1 },
      attendees: [{
        ticket_type_id: state.ticketTypeId,
        name: `${PREFIX} Peserta`,
        email: `${PREFIX.toLowerCase()}.peserta@example.test`,
      }],
    });
    // RPC menolak idempotency key < 16 karakter (validasi server yang benar).
    state.idempotencyKey = `${PREFIX.toLowerCase()}-idempotency-key`;

    await runTest('order guest: validasi 1 tiket + kontrak OrderModel + token di-hash', async () => {
      const invalid = await request('POST', '/api/orders', {
        body: { event_id: state.eventId, items: {}, attendees: [] },
        headers: { 'idempotency-key': `${PREFIX}-invalid` },
      });
      assert(invalid.status === 400, `order invalid seharusnya 400, dapat ${invalid.status}`);

      const multi = await request('POST', '/api/orders', {
        body: {
          ...orderBody(),
          items: { [state.ticketTypeId]: 2 },
          attendees: [
            { ticket_type_id: state.ticketTypeId, name: 'A', email: 'a@example.test' },
            { ticket_type_id: state.ticketTypeId, name: 'B', email: 'b@example.test' },
          ],
        },
        headers: { 'idempotency-key': `${PREFIX}-multi` },
      });
      assert(multi.status === 400, `order multi tiket seharusnya 400, dapat ${multi.status}`);

      const created = await request('POST', '/api/orders', {
        body: orderBody(),
        headers: { 'idempotency-key': state.idempotencyKey },
      });
      assert(created.status === 201, `order ${created.status}: ${JSON.stringify(created.body)}`);
      const order = created.body.order;
      state.orderId = order.id;
      state.orderToken = created.body.order_access_token;
      const dbg = await pool.query('SELECT idempotency_key, status FROM event_orders WHERE event_id=$1', [state.eventId]);
      const dbgAll = await pool.query('SELECT count(*)::int AS n FROM event_orders WHERE idempotency_key=$1', [state.idempotencyKey]);

      assert(order.event_id === state.eventId, 'event_id order tidak sesuai');
      assert(order.event_title === `${PREFIX} Event Integrasi`, `event_title ${order.event_title}`);
      assert(order.status === 'pending_payment', `status order ${order.status}`);
      assert(Number(order.total_amount) === 25000, `total_amount ${order.total_amount}`);
      assert(Number(order.grand_total) === 30000, `grand_total ${order.grand_total}`);
      assert(Array.isArray(order.items) && order.items.length === 1, 'items order tidak sesuai');
      assert(order.items[0].quantity === 1, `quantity ${order.items[0].quantity}`);
      assert(order.payment && order.payment.status === 'pending', 'payment pada order tidak pending');
      assert(typeof state.orderToken === 'string' && state.orderToken.length >= 40, 'token akses guest tidak ada');
      assert(!Object.hasOwn(order, 'guest_access_token_hash'), 'hash token bocor di response');

      const dbRow = await pool.query(
        'SELECT guest_access_token_hash, status FROM event_orders WHERE id=$1', [order.id]
      );
      assert(dbRow.rows.length === 1, 'order tidak tersimpan di database');
      assert(dbRow.rows[0].guest_access_token_hash === crypto.createHash('sha256').update(state.orderToken).digest('hex'),
        'hash token akses tidak sesuai');
      assert(dbRow.rows[0].status === 'PENDING_PAYMENT', `status DB ${dbRow.rows[0].status}`);
    });

    await runTest('order guest: replay idempoten tidak menggandakan order/payment', async () => {
      const replay = await request('POST', '/api/orders', {
        body: orderBody(),
        headers: { 'idempotency-key': state.idempotencyKey },
      });
      if (replay.status === 201 && replay.body.order.id !== state.orderId) {
        // Diagnosa: bandingkan fingerprint tersimpan vs payload ulang.
        const dbRow = await pool.query(
          'SELECT id, idempotency_fingerprint, idempotency_key FROM event_orders WHERE idempotency_key=$1',
          [`${PREFIX.toLowerCase()}-idempotency-key`]
        );
      }
      assert(replay.status === 201, `replay ${replay.status}: ${JSON.stringify(replay.body)}`);
      assert(replay.body.order.id === state.orderId, 'replay menghasilkan order berbeda');
      assert(replay.body.order_access_token === null, 'replay membocorkan token akses');
      const { rows } = await pool.query(
        `SELECT (SELECT count(*)::int FROM event_orders WHERE idempotency_key=$1) AS orders,
                (SELECT count(*)::int FROM order_payments WHERE order_id=$2) AS payments`,
        [`${PREFIX.toLowerCase()}-idempotency-key`, state.orderId]
      );
      assert(rows[0].orders === 1, `order ganda: ${rows[0].orders}`);
      assert(rows[0].payments === 1, `payment ganda: ${rows[0].payments}`);
    });

    await runTest('order guest: token salah ditolak, token benar boleh baca', async () => {
      const wrong = await request('GET', `/api/orders/${state.orderId}`, { orderToken: 'token-palsu' });
      assert(wrong.status === 404, `token salah seharusnya 404, dapat ${wrong.status}`);
      const right = await request('GET', `/api/orders/${state.orderId}`, { orderToken: state.orderToken });
      assert(right.status === 200, `token benar ${right.status}`);
      assert(right.body.order.id === state.orderId, 'order id tidak sesuai');
      assert(right.body.order.status === 'pending_payment', `status ${right.body.order.status}`);
    });


    await runTest('payment simulasi: pending -> paid, tiket terbit, status final ditolak', async () => {
      const pending = await request('GET', `/api/payments/${state.orderId}`, { orderToken: state.orderToken });
      assert(pending.status === 200, `get payment ${pending.status}`);
      assert(pending.body.payment.status === 'pending', `status payment ${pending.body.payment.status}`);
      assert(pending.body.payment.method === 'virtual_account', `method ${pending.body.payment.method}`);
      assert(Number(pending.body.payment.amount) === 30000, `amount ${pending.body.payment.amount}`);

      const wrongToken = await request('POST', '/api/payments/simulate', {
        body: { order_id: state.orderId, simulate_success: true },
        orderToken: 'token-palsu',
      });
      assert(wrongToken.status === 404, `simulasi dengan token salah seharusnya 404, dapat ${wrongToken.status}`);

      const paid = await request('POST', '/api/payments/simulate', {
        body: { order_id: state.orderId, simulate_success: true },
        orderToken: state.orderToken,
      });
      assert(paid.status === 200, `simulate ${paid.status}: ${JSON.stringify(paid.body)}`);
      assert(paid.body.payment.status === 'paid', `payment ${paid.body.payment.status}`);
      assert(paid.body.email_delivery && paid.body.email_delivery.transport === 'json',
        'email delivery tidak memakai transport json');

      const dbState = await pool.query(
        `SELECT eo.status AS order_status, op.status AS payment_status, op.paid_at,
                (SELECT count(*)::int FROM tickets WHERE event_id=$2) AS tickets
         FROM event_orders eo JOIN order_payments op ON op.order_id=eo.id WHERE eo.id=$1`,
        [state.orderId, state.eventId]
      );
      assert(dbState.rows[0].order_status === 'PAID', `order DB ${dbState.rows[0].order_status}`);
      assert(dbState.rows[0].payment_status === 'PAID', `payment DB ${dbState.rows[0].payment_status}`);
      assert(dbState.rows[0].paid_at !== null, 'paid_at kosong');
      assert(dbState.rows[0].tickets === 1, `tiket terbit ${dbState.rows[0].tickets}`);

      const second = await request('POST', '/api/payments/simulate', {
        body: { order_id: state.orderId, simulate_success: true },
        orderToken: state.orderToken,
      });
      assert(second.status === 400, `simulasi ulang seharusnya 400, dapat ${second.status}`);
    });

    await runTest('tiket: kontrak TicketModel + QR unik + token cocok check-in', async () => {
      const list = await request('GET', `/api/tickets/my-tickets?order_id=${state.orderId}`, {
        orderToken: state.orderToken,
      });
      assert(list.status === 200, `my-tickets ${list.status}: ${JSON.stringify(list.body)}`);
      assert(list.body.count === 1, `jumlah tiket ${list.body.count}`);
      const ticket = list.body.tickets[0];
      state.ticketId = ticket.id;

      assert(ticket.order_id === state.orderId, `order_id tiket ${ticket.order_id}`);
      assert(ticket.attendee_name === `${PREFIX} Peserta`, `attendee_name ${ticket.attendee_name}`);
      assert(ticket.attendee_email === `${PREFIX.toLowerCase()}.peserta@example.test`, `attendee_email ${ticket.attendee_email}`);
      assert(ticket.status === 'valid', `status tiket ${ticket.status}`);
      assert(typeof ticket.token === 'string' && ticket.token.length >= 40, 'QR token tidak ada');
      assert(!Object.hasOwn(ticket, 'token_hash'), 'token_hash bocor');

      const detail = await request('GET', `/api/tickets/${ticket.id}?order_id=${state.orderId}`, {
        orderToken: state.orderToken,
      });
      assert(detail.status === 200, `ticket detail ${detail.status}`);
      assert(detail.body.ticket.status === 'valid', `status detail ${detail.body.ticket.status}`);

      const scan = await request('POST', '/api/tickets/validate', {
        token: organizerToken,
        body: { token: ticket.token, ticket_code: ticket.ticket_code, event_id: state.eventId },
      });
      if (scan.body.status !== 'VALID') {
        const dbTok = await pool.query('SELECT token_hash, status FROM tickets WHERE id=$1', [ticket.id]);
        const expected = crypto.createHash('sha256').update(ticket.token).digest('hex');
      }
      assert(scan.status === 200, `scan ${scan.status}: ${JSON.stringify(scan.body)}`);
      assert(scan.body.status === 'VALID' && scan.body.valid === true, `scan ${JSON.stringify(scan.body)}`);
    });

    await runTest('check-in: sukses sekali, scan kedua ALREADY_USED', async () => {
      const qr = await pool.query(
        'SELECT t.id, t.ticket_code FROM tickets t WHERE t.event_id=$1', [state.eventId]
      );
      const ticketToken = qr.rows[0];
      const ticketView = await request('GET', `/api/tickets/${ticketToken.id}?order_id=${state.orderId}`, {
        orderToken: state.orderToken,
      });
      assert(ticketView.status === 200, `ticket view ${ticketView.status}`);
      const rawQrToken = ticketView.body.ticket.token;
      assert(typeof rawQrToken === 'string' && rawQrToken.length >= 16, 'token QR untuk check-in tidak tersedia');
      const first = await request('POST', '/api/check-ins', {
        token: organizerToken,
        body: { token: rawQrToken, event_id: state.eventId },
      });
      assert(first.status === 201, `check-in ${first.status}: ${JSON.stringify(first.body)}`);
      assert(first.body.ticket.status === 'checked_in', `status check-in ${first.body.ticket.status}`);

      const verify = await request('POST', '/api/tickets/verify', {
        token: organizerToken,
        body: { token: rawQrToken, ticket_code: ticketToken.ticket_code, event_id: state.eventId },
      });
      assert(verify.status === 409, `scan kedua seharusnya 409, dapat ${verify.status}`);
      assert(/already used/i.test(verify.body.message || ''), `pesan scan kedua: ${verify.body.message}`);
      assert(verify.body.ticket && verify.body.ticket.status === 'used', 'status tiket scan kedua bukan used');

      const db = await pool.query('SELECT status, used_at FROM tickets WHERE id=$1', [ticketToken.id]);
      assert(db.rows[0].status === 'used', `status tiket DB ${db.rows[0].status}`);
      assert(db.rows[0].used_at !== null, 'used_at kosong');
    });

    await runTest('kuota: sold bertambah setelah paid (held dilepas oleh RPC)', async () => {
      const { rows } = await pool.query(
        'SELECT sold, held, quota FROM ticket_types WHERE id=$1', [state.ticketTypeId]
      );
      assert(rows[0].sold === 1, `sold ${rows[0].sold}`);
      assert(rows[0].held === 0, `held ${rows[0].held}`);
      assert(rows[0].quota === 50, `quota ${rows[0].quota}`);
      const dtoTypes = await request('GET', `/api/events/${state.eventId}/ticket-types`);
      const dto = (dtoTypes.body.ticket_types || []).find((item) => item.id === state.ticketTypeId);
      assert(dto, 'kategori tidak ditemukan pada response publik');
      assert(dto.remaining_quota === 49, `remaining_quota ${dto.remaining_quota}`);
      assert(dto.is_available === true, 'kategori seharusnya masih available');
    });
  } catch (error) {
    results.push({ name: 'fatal', status: 'FAIL', error: error.message });
    console.error('FATAL smoke setup:', error);
  } finally {
    try {
      await cleanup(state);
      const leftovers = await pool.query(
        `SELECT (SELECT count(*)::int FROM events WHERE title LIKE $1) AS events,
                (SELECT count(*)::int FROM profiles WHERE email LIKE $2) AS profiles,
                (SELECT count(*)::int FROM tickets t JOIN events e ON e.id=t.event_id WHERE e.title LIKE $1) AS tickets`,
        [`${PREFIX}%`, `${PREFIX.toLowerCase()}.%@example.test`]
      );
      results.push({
        name: 'fixture cleanup',
        status: leftovers.rows[0].events === 0 && leftovers.rows[0].profiles === 0 && leftovers.rows[0].tickets === 0
          ? 'PASS' : 'FAIL',
        error: JSON.stringify(leftovers.rows[0]),
      });
      console.log(`CLEANUP ${results[results.length - 1].status} ${JSON.stringify(leftovers.rows[0])}`);
    } catch (error) {
      results.push({ name: 'fixture cleanup', status: 'FAIL', error: error.message });
      console.error('CLEANUP FAIL', error.message);
    }
    if (server) server.kill();
    await new Promise((resolve) => setTimeout(resolve, 300));
    await pool.end();
    const passed = results.filter((item) => item.status === 'PASS').length;
    console.log(`STAGE1 SMOKE SUMMARY ${passed}/${results.length} PASS`);
    for (const item of results.filter((row) => row.status !== 'PASS')) {
      console.error(`FAILED: ${item.name}: ${item.error}`);
    }
    if (results.some((row) => row.status !== 'PASS')) {
      console.log('SERVER LOG tail:', logs.join('').slice(-4000));
    }
    process.exitCode = results.some((item) => item.status !== 'PASS') ? 1 : 0;
  }
};

main().catch((error) => {
  console.error('Smoke test gagal:', error.message);
  process.exitCode = 1;
});


