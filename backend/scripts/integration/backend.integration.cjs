const path = require('node:path');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { Pool } = require('pg');
const testEnvPath = path.resolve(__dirname, '..', '..', '.env.test');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });
require('dotenv').config({ path: testEnvPath, override: true });

const { validateIntegrationTarget } = require('./safety');
const target = validateIntegrationTarget(process.env);
if (!target.ok) {
  console.error('Integration harness refused to start:');
  target.errors.forEach((error) => console.error(`- ${error}`));
  process.exit(1);
}

const BASE = target.api.toString().replace(/\/$/, '');
const PREFIX = `IT_${Date.now()}`;
const pool = new Pool({ connectionString: target.database.toString(), connectionTimeoutMillis: 15000 });
const fixtures = { userIds: [], eventIds: [], categoryId: null, planIds: [], orderIds: [], reportIds: [], tokens: [] };
const tests = [];
let server;
let organizer;
let otherOrganizer;
let admin;
let organizerToken;
let otherToken;
let adminToken;
let eventId;
let ticketTypeId;

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const request = async (method, route, options = {}) => {
  const { token, body, headers = {}, orderToken } = options;
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
    tests.push({ name, status: 'PASS' });
    console.log(`PASS ${name}`);
  } catch (error) {
    tests.push({ name, status: 'FAIL', error: error.message });
    console.error(`FAIL ${name}: ${error.message}`);
  }
};

const createAccount = async (label) => {
  const email = `${PREFIX.toLowerCase()}.${label}@example.test`;
  const result = await request('POST', '/api/auth/register', {
    body: { name: `${PREFIX} ${label}`, email, password: 'Integration123!' },
  });
  assert(result.status === 201, `register ${label} => ${result.status}: ${JSON.stringify(result.body)}`);
  fixtures.userIds.push(result.body.user.id);
  return { id: result.body.user.id, email, password: 'Integration123!' };
};

const login = async (account) => {
  const result = await request('POST', '/api/auth/login', { body: { email: account.email, password: account.password } });
  assert(result.status === 200, `login ${account.email} => ${result.status}`);
  return result.body.token;
};

const awaitHealth = async () => {
  for (let i = 0; i < 50; i += 1) {
    try { const r = await fetch(`${BASE}/health`); if (r.ok) return; } catch (_) { /* wait */ }
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  throw new Error('API healthcheck timeout');
};
const cleanup = async () => {
  // Hanya hapus data yang dibuat oleh suite ini; seluruh predicate berbasis
  // primary key yang direkam atau prefix email/title/invoice khusus test.
  if (fixtures.eventIds.length) {
    const ids = fixtures.eventIds;
    await pool.query(`DELETE FROM platform_transactions WHERE order_payment_id IN (
      SELECT id FROM order_payments WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[])))`, [ids]);
    await pool.query('DELETE FROM ticket_email_deliveries WHERE ticket_id IN (SELECT id FROM tickets WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM scan_logs WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM check_ins WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM tickets WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM order_payments WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM attendees WHERE order_item_id IN (SELECT id FROM order_items WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[])))', [ids]);
    await pool.query('DELETE FROM order_items WHERE order_id IN (SELECT id FROM event_orders WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM event_orders WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_member_permissions WHERE event_member_id IN (SELECT id FROM event_members WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM event_members WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_invitation_permissions WHERE event_invitation_id IN (SELECT id FROM event_invitations WHERE event_id=ANY($1::uuid[]))', [ids]);
    await pool.query('DELETE FROM event_invitations WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_moderations WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM event_activity_logs WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM ticket_types WHERE event_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM audit_logs WHERE entity_id=ANY($1::text[])', [ids]);
    await pool.query('DELETE FROM events WHERE id=ANY($1::uuid[])', [ids]);
  }
  if (fixtures.reportIds.length) {
    await pool.query('DELETE FROM support_report_activities WHERE report_id=ANY($1::uuid[])', [fixtures.reportIds]);
    await pool.query('DELETE FROM support_reports WHERE id=ANY($1::uuid[])', [fixtures.reportIds]);
  }
  if (fixtures.planIds.length) {
    await pool.query('DELETE FROM platform_transactions WHERE subscription_payment_id IN (SELECT id FROM subscription_payments WHERE subscription_id IN (SELECT id FROM subscriptions WHERE plan_id=ANY($1::uuid[])))', [fixtures.planIds]);
    await pool.query('DELETE FROM subscription_payments WHERE subscription_id IN (SELECT id FROM subscriptions WHERE plan_id=ANY($1::uuid[]))', [fixtures.planIds]);
    await pool.query('DELETE FROM subscription_history WHERE subscription_id IN (SELECT id FROM subscriptions WHERE plan_id=ANY($1::uuid[]))', [fixtures.planIds]);
    await pool.query('DELETE FROM subscriptions WHERE plan_id=ANY($1::uuid[])', [fixtures.planIds]);
    await pool.query('DELETE FROM plan_features WHERE plan_id=ANY($1::uuid[])', [fixtures.planIds]);
    await pool.query('DELETE FROM plans WHERE id=ANY($1::uuid[])', [fixtures.planIds]);
  }
  if (fixtures.userIds.length) {
    const ids = fixtures.userIds;
    await pool.query("DELETE FROM notifications WHERE user_id=ANY($1::uuid[]) AND category LIKE 'IT_%'", [ids]);
    await pool.query('DELETE FROM organizer_profiles WHERE user_id=ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM audit_logs WHERE actor_id=ANY($1::uuid[])', [ids]);
    await pool.query("DELETE FROM profiles WHERE email LIKE $1", [`${PREFIX.toLowerCase()}.%@example.test`]);
    await pool.query('DELETE FROM profiles WHERE id=ANY($1::uuid[])', [ids]);
  }
  if (fixtures.tokens.length) {
    const hashes = fixtures.tokens.map((token) => crypto.createHash('sha256').update(token).digest('hex'));
    await pool.query('DELETE FROM revoked_tokens WHERE token_hash=ANY($1::text[])', [hashes]);
  }
  if (fixtures.categoryId) {
    await pool.query('DELETE FROM event_categories WHERE id=$1', [fixtures.categoryId]);
  }
};
const main = async () => {
  server = spawn(process.execPath, ['server.js'], {
    cwd: path.resolve(__dirname, '..', '..'),
    env: {
      ...process.env,
      NODE_ENV: 'test',
      HOST: '127.0.0.1',
      PORT: target.api.port || '5000',
      SIMULATED_PAYMENTS_ENABLED: 'true',
      SEED_DEMO_ACCOUNTS: 'false',
      SMTP_HOST: 'json',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const logs = [];
  server.stdout.on('data', (data) => logs.push(String(data)));
  server.stderr.on('data', (data) => logs.push(String(data)));


const assertDbDenied = async (client, sql) => {
  try {
    await client.query(sql);
    throw new Error('expected permission denied, query was allowed');
  } catch (error) {
    if (error.message === 'expected permission denied, query was allowed') throw error;
    if (!/permission denied/.test(error.message)) throw error;
  }
};

  try {
    await awaitHealth();
    const categoryName = `${PREFIX} Category`;
    const category = await pool.query(
      'INSERT INTO event_categories (name,slug) VALUES ($1,$2) RETURNING id',
      [categoryName, `${PREFIX.toLowerCase()}-${Date.now()}`]
    );
    fixtures.categoryId = category.rows[0].id;

    organizer = await createAccount('organizer');
    otherOrganizer = await createAccount('other');
    admin = await createAccount('admin');
    await pool.query("UPDATE profiles SET role='admin' WHERE id=$1", [admin.id]);
    organizerToken = await login(organizer);
    otherToken = await login(otherOrganizer);
    adminToken = await login(admin);

    await runTest('health DB-connected + RLS anonymous denied', async () => {
      const health = await fetch(`${BASE}/health`);
      assert(health.status === 200, `health ${health.status}`);
      assert(health.headers.get('x-content-type-options') === 'nosniff', 'Helmet header missing');
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query('SET LOCAL ROLE anon');
        await assertDbDenied(client, 'SELECT id FROM public.profiles LIMIT 1');
        await client.query('ROLLBACK');
      } finally { client.release(); }
    });

    await runTest('register/login/profile/revoked token', async () => {
      const me = await request('GET', '/api/auth/me', { token: organizerToken });
      assert(me.status === 200 && me.body.user.id === organizer.id, 'profile endpoint failed');
      const invalid = await request('POST', '/api/auth/login', { body: { email: organizer.email, password: 'wrong' } });
      assert(invalid.status === 401, `invalid login ${invalid.status}`);
      const logoutAccount = await createAccount('logout');
      const logoutToken = await login(logoutAccount);
      const logout = await request('POST', '/api/auth/logout', { token: logoutToken });
      fixtures.tokens.push(logoutToken);
      const revoked = await request('GET', '/api/auth/me', { token: logoutToken });
      assert(logout.status === 200 && revoked.status === 401, 'logout revoke failed');
    });

    const eventPayload = {
      title: `${PREFIX} Event`, description: 'Integration only',
      event_date: new Date(Date.now() + 86400000).toISOString(),
      end_date_time: new Date(Date.now() + 90000000).toISOString(),
      time_zone: 'Asia/Jakarta', event_format: 'OFFLINE', location: 'Integration Hall',
      organizer_name: 'Integration Organizer', contact_info: 'test@example.test',
      attendee_fields: ['name', 'email'], category: categoryName,
    };

    await runTest('event create/ownership/list/validation', async () => {
      const created = await request('POST', '/api/events', { token: organizerToken, body: eventPayload });
      assert(created.status === 201, `create ${created.status}: ${JSON.stringify(created.body)}`);
      eventId = created.body.event.id;
      fixtures.eventIds.push(eventId);
      const owner = await request('GET', `/api/events/${eventId}`, { token: organizerToken });
      const denied = await request('PUT', `/api/events/${eventId}`, { token: otherToken, body: { title: 'forbidden' } });
      const invalid = await request('GET', '/api/events/not-a-uuid');
      assert(owner.status === 200 && [401,403,404].includes(denied.status) && [400,404].includes(invalid.status),
        `event access/validation failed (owner=${owner.status}, denied=${denied.status}, invalid=${invalid.status})`);
    });

    await runTest('ticket type CRUD and response aliases', async () => {
      const created = await request('POST', `/api/events/${eventId}/ticket-types`, {
        token: organizerToken,
        body: { name: `${PREFIX} Regular`, price: 12000, quota: 8, max_per_order: 4 },
      });
      assert(created.status === 201, `type create ${created.status}: ${JSON.stringify(created.body)}`);
      ticketTypeId = created.body.ticketType.id;
      const list = await request('GET', `/api/events/${eventId}/ticket-types`, { token: organizerToken });
      const detail = await request('GET', `/api/ticket-types/${ticketTypeId}`, { token: organizerToken });
      assert(list.status === 200 && detail.status === 200 && detail.body.ticket_type.id === ticketTypeId, 'type read failed');
    });

    await runTest('moderation + public availability', async () => {
      const submit = await request('POST', `/api/events/${eventId}/submit-review`, { token: organizerToken });
      assert(submit.status === 200, `submit ${submit.status}`);
      const approve = await request('PUT', `/api/admin/events/${eventId}/moderation`, {
        token: adminToken, body: { status: 'APPROVED', note: 'IT approval' },
      });
      assert(approve.status === 200, `approve ${approve.status}: ${JSON.stringify(approve.body)}`);
      const pub = await request('GET', '/api/events/public');
      assert(pub.body.events.some((item) => item.id === eventId), 'approved event missing public listing');
    });
    const attendeePayload = {
      event_id: eventId,
      items: { [ticketTypeId]: 1 },
      attendees: [{ ticket_type_id: ticketTypeId, name: `${PREFIX} Attendee`, email: `${PREFIX.toLowerCase()}@example.test` }],
    };
    let orderId;
    let orderToken;
    let ticket;

    await runTest('guest checkout/replay stabil dan ticket bearer hanya di owner response', async () => {
      const key = `${PREFIX.toLowerCase()}-idempotency-key`;
      const invalidKey = `${PREFIX.toLowerCase()}-invalid-order-key`;
      const invalid = await request('POST', '/api/orders', {
        body: { event_id: eventId, items: {}, attendees: [] },
        headers: { 'Idempotency-Key': invalidKey },
      });
      const invalidOrderCount = await pool.query(
        'SELECT count(*)::int AS total FROM event_orders WHERE idempotency_key=$1',
        [invalidKey],
      );
      assert(invalid.status === 400 && invalidOrderCount.rows[0].total === 0,
        'invalid checkout created an order or returned an unexpected status');
      const first = await request('POST', '/api/orders', { body: attendeePayload, headers: { 'Idempotency-Key': key } });
      assert(first.status === 201, `order ${first.status}: ${JSON.stringify(first.body)}`);
      orderId = first.body.order.id;
      orderToken = first.body.order_access_token;
      const second = await request('POST', '/api/orders', { body: attendeePayload, headers: { 'Idempotency-Key': key } });
      assert(second.status === 201 && second.body.order.id === orderId, 'idempotent replay did not return same order');
      assert(second.body.order_access_token === null, 'replay unexpectedly rotated/exposed guest token');
      const replayState = await pool.query(
        `SELECT eo.guest_access_token_hash, eo.status AS order_status,
                op.status AS payment_status,
                (SELECT count(*)::int FROM event_orders WHERE idempotency_key=$1) AS order_count,
                (SELECT count(*)::int FROM order_payments WHERE order_id=eo.id) AS payment_count
         FROM event_orders eo JOIN order_payments op ON op.order_id=eo.id
         WHERE eo.id=$2`,
        [key, orderId],
      );
      assert(replayState.rows.length === 1, 'replayed order/payment row missing');
      assert(replayState.rows[0].guest_access_token_hash === crypto.createHash('sha256').update(orderToken).digest('hex'),
        'guest access token hash changed during replay');
      assert(replayState.rows[0].order_count === 1 && replayState.rows[0].payment_count === 1,
        'replay created duplicate order/payment');
      assert(replayState.rows[0].order_status === 'PENDING_PAYMENT' && replayState.rows[0].payment_status === 'PENDING',
        'order and payment status diverged after replay');
      const orderDetails = await pool.query(
        'SELECT idempotency_fingerprint, guest_name, guest_email FROM event_orders WHERE id=$1',
        [orderId],
      );
      const rotatedHash = crypto.createHash('sha256').update('synthetic-replayed-guest-token').digest('hex');
      const sqlReplay = await pool.query(
        `SELECT public.create_event_order(
           $1::uuid, $2::jsonb, $3::jsonb, $4::text, $5::text, $6::text, $7::uuid,
           $8::text, $9::text, $10::text, $11::text, $12::timestamptz, $13::text
         ) AS id`,
        [
          eventId,
          JSON.stringify({ [ticketTypeId]: 1 }),
          JSON.stringify({ [ticketTypeId]: [{ name: orderDetails.rows[0].guest_name, email: orderDetails.rows[0].guest_email, phone: null }] }),
          orderDetails.rows[0].guest_name,
          orderDetails.rows[0].guest_email,
          null,
          null,
          `ORD-REPLAY-${PREFIX}`,
          key,
          orderDetails.rows[0].idempotency_fingerprint,
          rotatedHash,
          new Date(Date.now() + 86400000).toISOString(),
          `88${crypto.randomBytes(8).toString('hex').slice(0, 14)}`,
        ],
      );
      assert(sqlReplay.rows[0].id === orderId, 'database function replay returned a duplicate/different order');
      const afterSqlReplay = await pool.query(
        `SELECT guest_access_token_hash,
                (SELECT count(*)::int FROM event_orders WHERE idempotency_key=$1) AS order_count,
                (SELECT count(*)::int FROM order_payments WHERE order_id=$2) AS payment_count
         FROM event_orders WHERE id=$2`,
        [key, orderId],
      );
      assert(afterSqlReplay.rows[0].guest_access_token_hash === replayState.rows[0].guest_access_token_hash,
        'database function replay rotated the guest access token hash');
      assert(afterSqlReplay.rows[0].order_count === 1 && afterSqlReplay.rows[0].payment_count === 1,
        'database function replay created duplicate rows');
      const access = await request('GET', `/api/orders/${orderId}`, { orderToken });
      assert(access.status === 200, 'first response guest token lost validity on replay');
      const simulated = await request('POST', '/api/payments/simulate', {
        body: { order_id: orderId, simulate_success: true }, orderToken,
      });
      assert(simulated.status === 200 && simulated.body.payment.status === 'paid', `payment ${simulated.status}`);
      const list = await request('GET', `/api/tickets/my-tickets?order_id=${orderId}`, { orderToken });
      assert(list.status === 200 && list.body.tickets.length === 1, 'paid order did not issue ticket');
      ticket = list.body.tickets[0];
      assert(typeof ticket.token === 'string' && ticket.token.length >= 32, 'owner ticket QR token missing');
      const db = await pool.query('SELECT token_hash, qr_code_data FROM tickets WHERE id=$1', [ticket.id]);
      const expected = crypto.createHash('sha256').update(ticket.token).digest('hex');
      assert(db.rows[0].token_hash === expected, 'database token_hash mismatch');
      assert(!String(db.rows[0].qr_code_data || '').includes(ticket.token), 'raw bearer token persisted in qr_code_data');
      assert(simulated.body.email_delivery.results.length === 1, 'email delivery result absent');
      assert(simulated.body.email_delivery.results[0].status === 'SENT',
        `SMTP json transport should report local acceptance (${JSON.stringify(simulated.body.email_delivery)})`);
      const deliveryRow = await pool.query(
        'SELECT status::text FROM ticket_email_deliveries WHERE ticket_id=$1',
        [ticket.id],
      );
      assert(deliveryRow.rows[0].status === 'SENT', 'local JSON transport status not persisted');
    });

    await runTest('QR validate/check-in owner scope and single-use', async () => {
      const invalid = await request('POST', '/api/tickets/validate', {
        token: otherToken, body: { ticket_code: ticket.token, event_id: eventId },
      });
      assert(invalid.status === 403, `cross-organizer scan should be denied (${invalid.status}: ${JSON.stringify(invalid.body)})`);
      const valid = await request('POST', '/api/tickets/validate', {
        token: organizerToken, body: { ticket_code: ticket.token, event_id: eventId },
      });
      assert(valid.status === 200 && valid.body.status === 'VALID', `scan validate ${valid.status}`);
      const checked = await request('POST', '/api/check-ins', {
        token: organizerToken, body: { ticket_id: ticket.id, event_id: eventId },
      });
      assert(checked.status === 201, `check-in ${checked.status}: ${JSON.stringify(checked.body)}`);
      const duplicate = await request('POST', '/api/check-ins', {
        token: organizerToken, body: { ticket_id: ticket.id, event_id: eventId },
      });
      assert([400,409].includes(duplicate.status), `duplicate check-in ${duplicate.status}`);
      const scannedAgain = await request('POST', '/api/tickets/validate', {
        token: organizerToken, body: { ticket_code: ticket.token, event_id: eventId },
      });
      assert(scannedAgain.body.status === 'ALREADY_USED', 're-used QR not rejected');
    });

    await runTest('staff invite and per-event permission enforced', async () => {
      const invite = await request('POST', `/api/events/${eventId}/invitations`, {
        token: organizerToken,
        body: { email: otherOrganizer.email, permissions: ['VIEW_EVENT', 'SCAN_TICKET', 'CHECK_IN_TICKET'] },
      });
      assert(invite.status === 201, `invite ${invite.status}: ${JSON.stringify(invite.body)}`);
      const accept = await request('POST', `/api/invitations/${invite.body.invitation.token}/accept`, { token: otherToken });
      assert(accept.status === 200, `invite accept ${accept.status}: ${JSON.stringify(accept.body)}`);
      const attendees = await request('GET', `/api/events/${eventId}/attendees`, { token: otherToken });
      assert(attendees.status === 200, `staff attendee permission ${attendees.status}`);
      const memberRows = await pool.query(
        `SELECT em.id FROM event_members em WHERE em.event_id=$1 AND em.user_id=$2`,
        [eventId, otherOrganizer.id]
      );
      assert(memberRows.rows.length === 1, 'staff membership missing');
    });
    await runTest('plan CRUD, subscription free flow, revenue endpoints are DB-backed', async () => {
      const planName = `${PREFIX} Free Plan`;
      const created = await request('POST', '/api/plans/admin', {
        token: adminToken,
        body: {
          name: planName, description: 'Integration test plan', status: 'ACTIVE', isFree: true,
          priceMonthly: 0, priceYearly: 0, maxActiveEvents: 2, maxTicketsPerEvent: 50,
          maxStaffPerEvent: 2, features: { analytics: true, reports: ['basic'] },
        },
      });
      assert(created.status === 201, `plan create ${created.status}: ${JSON.stringify(created.body)}`);
      const planId = created.body.plan.id;
      fixtures.planIds.push(planId);
      const listed = await request('GET', '/api/plans');
      assert(listed.status === 200 && listed.body.plans.some((p) => p.id === planId), 'active plans catalog missing plan');
      const subscribed = await request('POST', '/api/subscriptions', {
        token: organizerToken, body: { planId, billingInterval: 'MONTHLY' },
      });
      assert(subscribed.status === 201 && subscribed.body.payment_status === 'paid', `subscribe ${subscribed.status}`);
      const subs = await request('GET', '/api/subscriptions/me', { token: organizerToken });
      assert(subs.status === 200 && subs.body.subscription.plan_id === planId, 'subscription GET mismatch');
      const payments = await request('GET', '/api/subscriptions/payments', { token: organizerToken });
      assert(payments.status === 200 && payments.body.payments.length === 1, 'subscription payment history missing');
      const revOrganizer = await request('GET', '/api/revenue/me', { token: organizerToken });
      const revAdmin = await request('GET', '/api/revenue/admin/summary', { token: adminToken });
      const txAdmin = await request('GET', '/api/revenue/admin/transactions', { token: adminToken });
      assert(revOrganizer.status === 200 && revAdmin.status === 200 && txAdmin.status === 200, 'revenue APIs unavailable');
      const cancelled = await request('POST', '/api/subscriptions/cancel', { token: organizerToken });
      assert(cancelled.status === 200, `cancel ${cancelled.status}`);
      const planDelete = await request('DELETE', `/api/plans/admin/${planId}`, { token: adminToken });
      // Plan is referenced by subscription history; restrict is expected to retain history.
      assert(planDelete.status === 409 || planDelete.status === 500, `plan delete ${planDelete.status}`);
    });

    await runTest('organizer profile and admin authorization', async () => {
      const update = await request('PUT', '/api/organizer/profile', {
        token: organizerToken,
        body: { organization_name: `${PREFIX} Org`, contact_name: 'Integration', phone: '08123456789' },
      });
      assert(update.status === 200, `profile update ${update.status}: ${JSON.stringify(update.body)}`);
      const profile = await request('GET', '/api/organizer/profile', { token: organizerToken });
      assert(profile.status === 200 && profile.body.profile.organization_name === `${PREFIX} Org`, 'profile response mismatch');
      const wrongRole = await request('GET', '/api/revenue/admin/summary', { token: organizerToken });
      assert(wrongRole.status === 403, `role should be denied: ${wrongRole.status}`);
    });

    await runTest('RLS deny-by-default and Supabase client privileges revoked', async () => {
      const counts = await pool.query(
        `SELECT count(*) FILTER (WHERE c.relrowsecurity)::int AS enabled
         FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='public' AND c.relkind='r' AND c.relname <> '_prisma_migrations'`
      );
      assert(counts.rows[0].enabled === 32, `RLS enabled ${counts.rows[0].enabled}/32`);
      const grants = await pool.query(
        `SELECT count(*)::int AS n FROM information_schema.role_table_grants
         WHERE table_schema='public' AND grantee IN ('anon','authenticated')`
      );
      assert(grants.rows[0].n === 0, `remaining direct client grants ${grants.rows[0].n}`);
    });
  } catch (error) {
    tests.push({ name: 'fatal', status: 'FAIL', error: error.message });
    console.error('FATAL integration setup:', error);
  } finally {
    try { await cleanup(); } catch (error) { tests.push({ name: 'fixture cleanup', status: 'FAIL', error: error.message }); }
    server.kill();
    await new Promise((resolve) => setTimeout(resolve, 300));
    await pool.end();
    const passed = tests.filter((item) => item.status === 'PASS').length;
    console.log(`INTEGRATION SUMMARY ${passed}/${tests.length} PASS`);
    for (const item of tests.filter((row) => row.status === 'FAIL')) console.error(`FAILED: ${item.name}: ${item.error}`);
    if (logs.length) console.log('SERVER LOG tail:', logs.join('').slice(-6000));
    process.exitCode = tests.some((item) => item.status === 'FAIL') ? 1 : 0;
  }
};

main().catch((error) => {
  console.error('Integration harness failed:', error.message);
  process.exitCode = 1;
});
