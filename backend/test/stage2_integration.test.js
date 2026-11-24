/**
 * Test integrasi Tahap 2 (integrator/Developer 4).
 *
 * Cakupan rantai lintas developer: undangan staff (D2) -> membership & permission
 * (D2) -> validasi token QR + check-in (D2) -> daftar & export peserta (D3),
 * memakai controller/service asli dengan lapisan `pg` in-memory. Tidak ada
 * koneksi database, seed, atau mutasi data sungguhan.
 *
 * Endpoint yang belum diimplementasikan pemilik domain tidak dibuat seolah lulus
 * di sini; temuan dicatat di `task/TAHAP_2/LAPORAN_DEVELOPER_4.md`.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://stage2:stage2@127.0.0.1:5432/e_ticket_stage2_test';
process.env.JWT_SECRET = 'stage2-integration-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'stage2-integration-ticket-secret';
process.env.APP_PUBLIC_URL = 'https://app.eticket.test';
process.env.SMTP_HOST = 'json';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const db = require('../src/config/db');

const APP_URL = 'https://app.eticket.test';

const ORGANIZER = {
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Organizer Uji',
  email: 'organizer@example.test',
  role: 'organizer',
};
const STAFF = {
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Staf Uji',
  email: 'staff@example.test',
  role: 'staff',
};
const STRANGER = {
  id: '33333333-3333-4333-8333-333333333333',
  name: 'Bukan Staf',
  email: 'stranger@example.test',
  role: 'staff',
};

const EVENT_ID = '44444444-4444-4444-8444-444444444444';
const OTHER_EVENT_ID = '55555555-5555-4555-8555-555555555555';
const ORDER_ID = '66666666-6666-4666-8666-666666666666';
const TICKET_ID = '77777777-7777-4777-8777-777777777777';
const ATTENDEE_ID = '88888888-8888-4888-8888-888888888888';
const MEMBER_ID = '99999999-9999-4999-8999-999999999999';
const OTHER_MEMBER_ID = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';

const NOW = '2026-11-24T08:00:00.000Z';
const FUTURE = '2026-11-30T08:00:00.000Z';
const PAST = '2026-11-01T08:00:00.000Z';

const state = {
  events: {},
  members: [],
  memberPermissions: [],
  invitations: [],
  invitationPermissions: [],
  ticket: null,
  ticketStatus: 'active',
  checkIns: [],
  scanLogs: [],
  attendeeRows: [],
  lastAttendeeSql: '',
};

const buildTicketRow = () => ({
  id: TICKET_ID,
  ticket_code: 'TKT-STAGE2-0001',
  token_hash: null,
  event_id: EVENT_ID,
  user_id: null,
  ticket_type_id: 'tt-reguler',
  attendee_id: ATTENDEE_ID,
  status: state.ticketStatus,
  purchased_at: NOW,
  issued_at: NOW,
  used_at: state.ticketStatus === 'used' ? NOW : null,
  attendee_name: 'Peserta Uji',
  attendee_email: 'peserta@example.test',
  attendee_phone: '081200000001',
  attendee_order_item_id: 'item-1',
  ticket_type_name: 'Reguler',
});


const buildAttendeeRows = () => ([
  {
    attendee_id: 'att-paid',
    attendee_order_item_id: 'item-paid',
    attendee_name: 'Peserta Lunas',
    attendee_email: 'lunas@example.test',
    attendee_phone: '081200000002',
    organization: 'Kampus Uji',
    custom_fields: { instansi: 'Informatika' },
    attendee_created_at: PAST,
    ticket_type_name: 'VIP',
    ticket_type_id: 'tt-vip',
    ticket_id: 'tkt-paid',
    ticket_code: 'TKT-PAID-1',
    ticket_status: 'used',
    purchased_at: PAST,
    used_at: NOW,
    checked_in_at: NOW,
    order_id: ORDER_ID,
    order_number: 'ORD-2026-0001',
    order_status: 'PAID',
    payment_status: 'PAID',
  },
  {
    attendee_id: 'att-pending',
    attendee_order_item_id: 'item-pending',
    attendee_name: 'Peserta Menunggu',
    attendee_email: 'pending@example.test',
    attendee_phone: '081200000003',
    organization: null,
    custom_fields: {},
    attendee_created_at: NOW,
    ticket_type_name: 'Reguler',
    ticket_type_id: 'tt-reguler',
    ticket_id: 'tkt-pending',
    ticket_code: 'TKT-PENDING-1',
    ticket_status: 'active',
    purchased_at: NOW,
    used_at: null,
    checked_in_at: null,
    order_id: 'ord-2',
    order_number: 'ORD-2026-0002',
    order_status: 'PENDING_PAYMENT',
    payment_status: 'PENDING',
  },
]);

const resetState = () => {
  state.events = {
    [EVENT_ID]: {
      id: EVENT_ID,
      created_by: ORGANIZER.id,
      status: 'PUBLISHED',
      is_public: true,
      title: 'Event Uji Integrasi',
    },
    [OTHER_EVENT_ID]: {
      id: OTHER_EVENT_ID,
      created_by: ORGANIZER.id,
      status: 'PUBLISHED',
      is_public: true,
      title: 'Event Lain',
    },
  };
  state.members = [];
  state.memberPermissions = [];
  state.invitations = [];
  state.invitationPermissions = [];
  state.ticketStatus = 'active';
  state.ticket = buildTicketRow();
  state.checkIns = [];
  state.scanLogs = [];
  state.attendeeRows = buildAttendeeRows();
  state.lastAttendeeSql = '';
};

const normalizeSql = (sql) => String(sql).replace(/\s+/g, ' ').trim();
const hasSql = (sql, ...fragments) => {
  const normalized = normalizeSql(sql);
  return fragments.every((fragment) => normalized.includes(normalizeSql(fragment)));
};

const insertPermissions = (target, key, id, permissions) => {
  for (const permission of permissions) {
    const exists = target.some((row) => row[key] === id && row.permission === permission);
    if (!exists) target.push({ [key]: id, permission });
  }
};

const fakeQuery = async (sql, params = []) => {
  const normalized = normalizeSql(sql);

  // --- Undangan (D2) -------------------------------------------------------
  if (normalized.startsWith('INSERT INTO event_invitations')) {
    const row = {
      id: `inv-${state.invitations.length + 1}`,
      event_id: params[0],
      invited_by_id: params[1],
      email: params[2],
      token_hash: params[3],
      status: 'PENDING',
      expires_at: params[4],
      accepted_at: null,
      accepted_by_id: null,
      revoked_at: null,
      created_at: NOW,
    };
    state.invitations.push(row);
    return [row];
  }
  if (normalized.startsWith('INSERT INTO event_invitation_permissions')) {
    insertPermissions(state.invitationPermissions, 'event_invitation_id', params[0], params.slice(1));
    return [];
  }
  if (hasSql(sql, 'FROM event_invitations WHERE token_hash = $1')) {
    return state.invitations.filter((row) => row.token_hash === params[0]);
  }
  if (hasSql(sql, "UPDATE event_invitations SET status = 'ACCEPTED'")) {
    const row = state.invitations.find((item) => item.id === params[1]);
    if (!row) return [];
    row.status = 'ACCEPTED';
    row.accepted_by_id = params[0];
    row.accepted_at = NOW;
    return [row];
  }
  if (hasSql(sql, 'SELECT permission FROM event_invitation_permissions WHERE event_invitation_id = $1')) {
    return state.invitationPermissions
      .filter((row) => row.event_invitation_id === params[0])
      .map((row) => ({ permission: row.permission }));
  }

  // --- Membership (D2) -----------------------------------------------------
  if (hasSql(sql, 'INSERT INTO event_members')) {
    const existing = state.members.find(
      (row) => row.event_id === params[0] && row.user_id === params[1]
    );
    if (existing) return [existing];
    const row = {
      id: state.members.length === 0 ? MEMBER_ID : OTHER_MEMBER_ID,
      event_id: params[0],
      user_id: params[1],
      role: 'staff',
      status: 'ACTIVE',
      created_at: NOW,
    };
    state.members.push(row);
    return [row];
  }
  if (hasSql(sql, 'SELECT em.id AS member_id', 'WHERE em.event_id = $1 AND em.user_id = $2')) {
    const row = state.members.find(
      (item) => item.event_id === params[0] && item.user_id === params[1]
    );
    return row ? [{ member_id: row.id, role: row.role, created_at: row.created_at }] : [];
  }
  if (hasSql(sql, 'INSERT INTO event_member_permissions')) {
    insertPermissions(state.memberPermissions, 'event_member_id', params[0], params.slice(1));
    return [];
  }
  if (hasSql(sql, 'SELECT permission FROM event_member_permissions WHERE event_member_id = $1')) {
    return state.memberPermissions
      .filter((row) => row.event_member_id === params[0])
      .map((row) => ({ permission: row.permission }));
  }

  // --- Pratinjau undangan publik (D2-2) -----------------------------------
  if (hasSql(sql, 'FROM event_invitations i', 'JOIN events e ON e.id = i.event_id', 'WHERE i.token_hash = $1')) {
    const row = state.invitations.find((item) => item.token_hash === params[0]);
    if (!row) return [];
    const event = state.events[row.event_id] || {};
    return [{
      id: row.id,
      event_id: row.event_id,
      email: row.email,
      status: row.status,
      expires_at: row.expires_at,
      created_at: row.created_at,
      event_title: event.title || 'Event Uji Integrasi',
      event_status: event.status || 'PUBLISHED',
      event_date: NOW,
      end_date_time: NOW,
      location: 'Auditorium Uji',
      event_format: 'OFFLINE',
      online_url: null,
    }];
  }

  // --- Membership milik pengguna login (D2-2) ------------------------------
  if (hasSql(sql, 'FROM event_members em', 'WHERE em.user_id = $1')) {
    return state.members
      .filter((row) => row.user_id === params[0])
      .flatMap((row) => {
        const event = state.events[row.event_id] || {};
        const base = {
          member_id: row.id,
          event_id: row.event_id,
          role: row.role,
          created_at: row.created_at,
          event_title: event.title || 'Event Uji Integrasi',
          event_status: event.status || 'PUBLISHED',
          event_date: NOW,
          location: 'Auditorium Uji',
          event_format: 'OFFLINE',
        };
        const perms = state.memberPermissions.filter((p) => p.event_member_id === row.id);
        return perms.length === 0
          ? [{ ...base, permission: null }]
          : perms.map((p) => ({ ...base, permission: p.permission }));
      });
  }

  // --- Event & izin (D2/D3) ------------------------------------------------
  if (hasSql(sql, 'FROM events WHERE id = $1')) {
    const event = state.events[params[0]];
    if (!event) return [];
    if (normalized.includes('SELECT id, created_by, status FROM events')) {
      return [{ id: event.id, created_by: event.created_by, status: event.status }];
    }
    return [{ id: event.id, created_by: event.created_by }];
  }
  if (hasSql(sql, 'SELECT id, status FROM event_members WHERE event_id = $1 AND user_id = $2')) {
    const row = state.members.find(
      (item) => item.event_id === params[0] && item.user_id === params[1]
    );
    return row ? [{ id: row.id, status: row.status }] : [];
  }
  if (hasSql(sql, 'SELECT id FROM event_members WHERE event_id = $1 AND user_id = $2')) {
    const row = state.members.find(
      (item) => item.event_id === params[0] && item.user_id === params[1]
    );
    return row ? [{ id: row.id }] : [];
  }


  // --- Tiket, order, check-in (D2) ----------------------------------------
  if (hasSql(sql, 'WHERE t.token_hash = $1')) {
    if (state.ticket && state.ticket.token_hash === params[0]) return [state.ticket];
    return [];
  }
  if (hasSql(sql, 'WHERE t.ticket_code = $1')) {
    if (state.ticket && state.ticket.ticket_code === params[0]) return [state.ticket];
    return [];
  }
  if (hasSql(sql, 'SELECT order_id FROM order_items WHERE id = $1')) {
    return [{ order_id: ORDER_ID }];
  }
  if (hasSql(sql, 'SELECT id, status FROM event_orders WHERE id = $1')) {
    return [{ id: ORDER_ID, status: 'PAID' }];
  }
  if (hasSql(sql, 'SELECT id FROM check_ins WHERE ticket_id = $1')) {
    return state.checkIns.filter((row) => row.ticket_id === params[0]);
  }
  if (hasSql(sql, 'SELECT status FROM tickets WHERE id = $1 FOR UPDATE')) {
    return [{ status: state.ticketStatus }];
  }
  if (hasSql(sql, 'INSERT INTO check_ins')) {
    const duplicate = state.checkIns.some((row) => row.ticket_id === params[0]);
    if (duplicate) return [];
    const row = {
      id: `chk-${state.checkIns.length + 1}`,
      ticket_id: params[0],
      event_id: params[1],
      actor_user_id: params[2],
      event_member_id: params[3],
      source: 'ONLINE',
      checked_in_at: params[4],
    };
    state.checkIns.push(row);
    return [row];
  }
  if (hasSql(sql, 'UPDATE tickets SET status = $1, used_at = $2 WHERE id = $3')) {
    state.ticketStatus = params[0];
    state.ticket.status = params[0];
    state.ticket.used_at = params[1];
    return [];
  }
  if (hasSql(sql, 'INSERT INTO scan_logs')) {
    state.scanLogs.push({ id: `log-${state.scanLogs.length + 1}`, ticket_id: params[1], result: 'VALID' });
    return [];
  }

  // --- Daftar & export peserta (D3) ---------------------------------------
  if (hasSql(sql, 'WITH event_attendees AS')) {
    state.lastAttendeeSql = normalized;
    return state.attendeeRows;
  }

  return [];
};

const fakeGetOne = async (sql, params = []) => {
  const rows = await fakeQuery(sql, params);
  return rows[0] || null;
};

const fakeClient = {
  // `pg` Client mengembalikan objek `{ rows }`, bukan array seperti helper query().
  query: async (sql, params = []) => ({ rows: await fakeQuery(sql, params) }),
  release: () => {},
};

// Lapisan `pg` diganti sebelum controller di-require agar controller memakai
// implementasi in-memory. Pool tidak dapat membuka koneksi database nyata.
db.query = fakeQuery;
db.getOne = fakeGetOne;
db.supabase = { query: fakeQuery, getOne: fakeGetOne };
db.pool = {
  query: fakeQuery,
  on: () => {},
  connect: async () => fakeClient,
};

const ticketTokens = require('../src/services/ticketTokenService');
const {
  createInvitation,
  acceptInvitation,
  getInvitationPreview,
  myMemberships,
} = require('../src/controllers/eventInvitationController');
const { verifyTicket } = require('../src/controllers/ticketController');
const {
  validateTicket,
  recordCheckIn,
  listEventAttendees,
  exportEventAttendeesCsv,
} = require('../src/controllers/checkInController');

const createRes = () => {
  const res = {
    statusCode: 200,
    body: null,
    sent: null,
    headers: {},
  };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  res.setHeader = (name, value) => {
    res.headers[String(name).toLowerCase()] = value;
    return res;
  };
  res.send = (payload) => {
    res.sent = payload;
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

const scanToken = () => ticketTokens.rawTokenFor(state.ticket);

const grantMembership = (userId, eventId, permissions, memberId = MEMBER_ID) => {
  state.members.push({
    id: memberId,
    event_id: eventId,
    user_id: userId,
    role: 'staff',
    status: 'ACTIVE',
    created_at: NOW,
  });
  insertPermissions(state.memberPermissions, 'event_member_id', memberId, permissions);
};

const invitationWithToken = (rawToken, overrides = {}) => {
  const row = {
    id: `inv-${state.invitations.length + 1}`,
    event_id: EVENT_ID,
    invited_by_id: ORGANIZER.id,
    email: STAFF.email,
    token_hash: crypto.createHash('sha256').update(rawToken).digest('hex'),
    status: 'PENDING',
    expires_at: FUTURE,
    accepted_at: null,
    accepted_by_id: null,
    revoked_at: null,
    created_at: NOW,
    ...overrides,
  };
  state.invitations.push(row);
  return row;
};

test.beforeEach(() => {
  resetState();
});


// ---------------------------------------------------------------------------
// 1. Undangan staff: invite_url berbeda dari public_url, DB hanya simpan hash
// ---------------------------------------------------------------------------
test('D2-2: undangan menyimpan hash token dan invite_url berbeda dari public_url', async () => {
  const res = createRes();
  await createInvitation(
    createReq({
      params: { eventId: EVENT_ID },
      body: { email: 'Staff@Example.test', permissions: ['SCAN_TICKET', 'VIEW_PARTICIPANTS'] },
      user: ORGANIZER,
      headers: { origin: 'https://organizer.example' },
    }),
    res
  );

  assert.equal(res.statusCode, 201);
  const invitation = res.body.invitation;
  assert.ok(invitation.token, 'token mentah dikembalikan sekali ke pembuat undangan');
  assert.equal(invitation.invite_url, `${APP_URL}/invite/${invitation.token}`);
  assert.equal(invitation.invitation_link, `https://organizer.example/invite/${invitation.token}`);

  const stored = state.invitations[0];
  assert.equal(stored.email, 'staff@example.test', 'email undangan dinormalisasi');
  assert.equal(
    stored.token_hash,
    crypto.createHash('sha256').update(invitation.token).digest('hex'),
    'database hanya menyimpan hash token undangan'
  );
  assert.notEqual(stored.token_hash, invitation.token);
  assert.deepEqual(invitation.permissions, ['SCAN_TICKET', 'VIEW_PARTICIPANTS']);
  assert.notEqual(invitation.invite_url, `${APP_URL}/e/${EVENT_ID}`, 'invite_url != public_url');
});

// ---------------------------------------------------------------------------
// 2. Penerimaan undangan: token tidak dikenal / kedaluwarsa / revoked ditolak
// ---------------------------------------------------------------------------
test('D2-2: token undangan tidak dikenal ditolak 404 tanpa membuat membership', async () => {
  const res = createRes();
  await assert.rejects(
    () =>
      acceptInvitation(
        createReq({ params: { token: 'token-tidak-dikenal-sama-sekali' }, user: STAFF }),
        res
      )
  );
  assert.equal(res.statusCode, 404);
  assert.equal(state.members.length, 0);
});

test('D2-2: undangan kedaluwarsa 410 dan revoked 409 tidak membuat membership', async () => {
  const expiredToken = 'undangan-kedaluwarsa-token-0001';
  invitationWithToken(expiredToken, { expires_at: PAST });
  const expiredRes = createRes();
  await assert.rejects(
    () => acceptInvitation(createReq({ params: { token: expiredToken }, user: STAFF }), expiredRes)
  );
  assert.equal(expiredRes.statusCode, 410);

  const revokedToken = 'undangan-revoked-token-0000001';
  invitationWithToken(revokedToken, { status: 'REVOKED' });
  const revokedRes = createRes();
  await assert.rejects(
    () => acceptInvitation(createReq({ params: { token: revokedToken }, user: STAFF }), revokedRes)
  );
  assert.equal(revokedRes.statusCode, 409);
  assert.equal(state.members.length, 0);
});

test('D2-2: undangan untuk email lain ditolak 403', async () => {
  const token = 'undangan-email-lain-token-00001';
  invitationWithToken(token, { email: 'orang.lain@example.test' });
  const res = createRes();
  await assert.rejects(
    () => acceptInvitation(createReq({ params: { token }, user: STAFF }), res)
  );
  assert.equal(res.statusCode, 403);
  assert.equal(state.members.length, 0);
});

test('D2-2: undangan valid membuat membership staff dan menyalin permission', async () => {
  const token = 'undangan-valid-token-00000001';
  const invitation = invitationWithToken(token);
  state.invitationPermissions.push(
    { event_invitation_id: invitation.id, permission: 'SCAN_TICKET' },
    { event_invitation_id: invitation.id, permission: 'VIEW_PARTICIPANTS' }
  );

  const res = createRes();
  await acceptInvitation(createReq({ params: { token }, user: STAFF }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(state.members.length, 1);
  assert.equal(state.members[0].user_id, STAFF.id);
  assert.equal(state.members[0].role, 'staff');
  assert.equal(state.invitations[0].status, 'ACCEPTED');
  assert.deepEqual(
    state.memberPermissions.map((row) => row.permission).sort(),
    ['SCAN_TICKET', 'VIEW_PARTICIPANTS'],
    'permission undangan tersalin ke event_member_permissions'
  );
});


// ---------------------------------------------------------------------------
// 3. Scanner: validasi token QR memakai membership hasil undangan
// ---------------------------------------------------------------------------
test('D2-3: staf hasil undangan memvalidasi tiket event-nya sebagai VALID tanpa kebocoran token', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET', 'CHECK_IN_TICKET']);
  state.ticket.token_hash = ticketTokens.hashToken(scanToken());

  const res = createRes();
  await validateTicket(
    createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.valid, true);
  assert.equal(res.body.status, 'VALID');
  assert.equal(res.body.ticket.attendee_name, 'Peserta Uji');
  assert.equal('token_hash' in res.body.ticket, false, 'token_hash tidak boleh bocor ke klien');
  assert.equal('token' in res.body.ticket, false, 'token mentah tidak dikirim pada hasil scan');
});

test('D2-3: token palsu menghasilkan INVALID tanpa membuka data tiket', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET']);
  const res = createRes();
  await validateTicket(
    createReq({ body: { token: 'token-palsu-yang-tidak-terdaftar', event_id: EVENT_ID }, user: STAFF }),
    res
  );
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, 'INVALID');
  assert.equal(res.body.ticket, null);
});

test('D2-3: staf bukan anggota dan staf tanpa izin scan ditolak 403', async () => {
  state.ticket.token_hash = ticketTokens.hashToken(scanToken());

  await assert.rejects(
    () =>
      validateTicket(
        createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STRANGER }),
        createRes()
      ),
    (error) => error.statusCode === 403
  );

  grantMembership(STAFF.id, EVENT_ID, ['VIEW_PARTICIPANTS']);
  await assert.rejects(
    () =>
      validateTicket(
        createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
        createRes()
      ),
    (error) => error.statusCode === 403
  );
});

test('D2-3: tiket event lain menghasilkan WRONG_EVENT pada pos pemindaian berbeda', async () => {
  state.ticket.token_hash = ticketTokens.hashToken(scanToken());
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET'], MEMBER_ID);
  grantMembership(STAFF.id, OTHER_EVENT_ID, ['SCAN_TICKET'], OTHER_MEMBER_ID);

  const res = createRes();
  await validateTicket(
    createReq({ body: { token: scanToken(), event_id: OTHER_EVENT_ID }, user: STAFF }),
    res
  );
  assert.equal(res.body.valid, false);
  assert.equal(res.body.status, 'WRONG_EVENT');
});

// ---------------------------------------------------------------------------
// 4. Check-in: satu baris check_ins + scan_logs, duplikat 409
// ---------------------------------------------------------------------------
test('D2-4: check-in pertama 201, check-in ulang ditolak tanpa baris baru, validasi ALREADY_USED', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET', 'CHECK_IN_TICKET']);
  state.ticket.token_hash = ticketTokens.hashToken(scanToken());

  const first = createRes();
  await recordCheckIn(
    createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
    first
  );
  assert.equal(first.statusCode, 201);
  assert.equal(first.body.success, true);
  assert.equal(first.body.ticket.status, 'checked_in');
  assert.equal(state.checkIns.length, 1, 'tepat satu baris check_ins dibuat');
  assert.equal(state.scanLogs.length, 1, 'tepat satu baris scan_logs dibuat');
  assert.equal(state.ticketStatus, 'used');

  // Catatan kontrak: jalur "tiket sudah used" mengembalikan 400, sedangkan
  // jalur balapan (status masih active + baris check_ins sudah ada) 409.
  const duplicate = createRes();
  await assert.rejects(
    () =>
      recordCheckIn(
        createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
        duplicate
      )
  );
  assert.equal(duplicate.statusCode, 400);
  assert.equal(state.checkIns.length, 1, 'duplikat tidak menambah baris check_ins');
  assert.equal(state.scanLogs.length, 1, 'duplikat tidak menambah baris scan_logs');

  const revalidate = createRes();
  await validateTicket(
    createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
    revalidate
  );
  assert.equal(revalidate.body.valid, false);
  assert.equal(revalidate.body.status, 'ALREADY_USED');
});


// ---------------------------------------------------------------------------
// 5. Daftar peserta: kontrak D2 (scan) + D3 (order/export) menyatu
// ---------------------------------------------------------------------------
test('D3-1: daftar peserta memuat field kontrak D2 dan D3, urut PAID lebih dulu', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['VIEW_PARTICIPANTS']);

  const res = createRes();
  await listEventAttendees(createReq({ params: { eventId: EVENT_ID }, user: STAFF }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.count, 2);
  const [first, second] = res.body.attendees;

  assert.equal(first.payment_status, 'PAID');
  assert.equal(second.payment_status, 'PENDING');
  assert.equal(first.registration_number, 'ORD-2026-0001');
  assert.equal(second.registration_number, 'ORD-2026-0002');
  assert.equal(first.order_number, 'ORD-2026-0001');
  assert.equal(first.order_id, ORDER_ID);
  assert.equal(first.order_status, 'PAID');
  assert.deepEqual(first.custom_fields, { instansi: 'Informatika' });
  assert.equal(first.checked_in_at, NOW);
  assert.equal(first.status, 'checked_in');
  assert.equal(second.status, 'valid');

  assert.ok(
    state.lastAttendeeSql.includes("WHEN UPPER(COALESCE(payment_status, '')) = 'PAID' THEN 0"),
    'urutan paid-first ditentukan di SQL server'
  );
  assert.ok(state.lastAttendeeSql.includes('order_number ASC'));
});

test('D3-1: staf tanpa VIEW_PARTICIPANTS ditolak 403 dan event tidak dikenal 404', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET']);
  await assert.rejects(
    () => listEventAttendees(createReq({ params: { eventId: EVENT_ID }, user: STAFF }), createRes()),
    (error) => error.statusCode === 403
  );

  await assert.rejects(
    () =>
      listEventAttendees(
        createReq({ params: { eventId: 'event-tidak-ada' }, user: ORGANIZER }),
        createRes()
      ),
    (error) => error.statusCode === 404
  );
});

// ---------------------------------------------------------------------------
// 6. Export CSV: izin, escaping formula, urutan identik daftar peserta
// ---------------------------------------------------------------------------
test('D3-2: export memerlukan EXPORT_PARTICIPANTS', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['VIEW_PARTICIPANTS']);
  await assert.rejects(
    () => exportEventAttendeesCsv(createReq({ params: { id: EVENT_ID }, user: STAFF }), createRes()),
    (error) => error.statusCode === 403
  );
});

test('D3-2: export meng-escape formula/koma dan menjaga urutan paid-first', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['EXPORT_PARTICIPANTS']);
  state.attendeeRows[0].attendee_name = '=SUM(1,2)';
  state.attendeeRows[0].attendee_email = 'koma,dalam@example.test';

  const res = createRes();
  await exportEventAttendeesCsv(createReq({ params: { id: EVENT_ID }, user: STAFF }), res);

  assert.equal(res.statusCode, 200);
  assert.match(String(res.headers['content-type']), /text\/csv/);
  const lines = String(res.sent).split('\r\n');
  assert.equal(lines[0].split(',')[0], 'ID');
  assert.ok(String(res.sent).includes("'=SUM(1,2)"), 'formula injection dinetralkan');
  assert.ok(String(res.sent).includes('"koma,dalam@example.test"'), 'koma di-escape dengan kutip');
  assert.ok(
    String(res.sent).indexOf('ORD-2026-0001') < String(res.sent).indexOf('ORD-2026-0002'),
    'urutan CSV identik dengan daftar peserta (paid-first)'
  );
  assert.ok(
    String(res.sent).includes('TIDAK') && String(res.sent).includes('YA'),
    'kolom check-in terisi sesuai status tiket'
  );
});

// ---------------------------------------------------------------------------
// 7. Endpoint pratinjau undangan publik & membership pengguna (D2-2)
// ---------------------------------------------------------------------------
test('D2-2: pratinjau undangan publik menyamarkan email dan memuat data event', async () => {
  const rawToken = 'pratinjau-undangan-token-000001';
  invitationWithToken(rawToken, { expires_at: FUTURE });

  const res = createRes();
  await getInvitationPreview(createReq({ params: { token: rawToken } }), res);

  assert.equal(res.statusCode, 200);
  const preview = res.body.invitation;
  assert.equal(preview.status, 'PENDING');
  assert.equal(preview.event.id, EVENT_ID);
  assert.equal(preview.event.title, 'Event Uji Integrasi');
  assert.equal(preview.invited_email.includes('staff@example.test'), false);
  assert.ok(preview.invited_email.includes('***'), 'email undangan disamarkan');
  assert.deepEqual(preview.permissions, []);
});

test('D2-2: pratinjau undangan kedaluwarsa -> EXPIRED, token tak dikenal -> 404', async () => {
  const expiredToken = 'pratinjau-undangan-kedaluwarsa-01';
  invitationWithToken(expiredToken, { expires_at: PAST });

  const expiredRes = createRes();
  await getInvitationPreview(createReq({ params: { token: expiredToken } }), expiredRes);
  assert.equal(expiredRes.statusCode, 200);
  assert.equal(expiredRes.body.invitation.status, 'EXPIRED');

  const missingRes = createRes();
  await assert.rejects(
    () => getInvitationPreview(createReq({ params: { token: 'token-tidak-terdaftar' } }), missingRes)
  );
  assert.equal(missingRes.statusCode, 404);
});

test('D2-2: GET /api/me/memberships memuat event dan permission staf', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET', 'VIEW_PARTICIPANTS']);

  const res = createRes();
  await myMemberships(createReq({ user: STAFF }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.count, 1);
  const membership = res.body.memberships[0];
  assert.equal(membership.event_id, EVENT_ID);
  assert.equal(membership.event_title, 'Event Uji Integrasi');
  assert.equal(membership.status, 'ACTIVE');
  assert.equal(membership.role, 'staff');
  assert.equal(membership.expires_at, null);
  assert.deepEqual(membership.permissions.sort(), ['SCAN_TICKET', 'VIEW_PARTICIPANTS']);
});

test('D2-2: membership kosong dikembalikan sebagai daftar kosong', async () => {
  const res = createRes();
  await myMemberships(createReq({ user: STRANGER }), res);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.count, 0);
  assert.deepEqual(res.body.memberships, []);
});

// ---------------------------------------------------------------------------
// 8. POST /api/tickets/verify wajib membuat baris check-in (D2-4 K3)
// ---------------------------------------------------------------------------
test('D2-4 K3: verify membuat check_ins + scan_logs, duplikat ditolak 409', async () => {
  grantMembership(STAFF.id, EVENT_ID, ['SCAN_TICKET', 'CHECK_IN_TICKET']);
  state.ticket.token_hash = ticketTokens.hashToken(scanToken());

  const res = createRes();
  await verifyTicket(
    createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(state.checkIns.length, 1, 'verify harus membuat baris check_ins');
  assert.equal(state.scanLogs.length, 1, 'verify harus mencatat scan_logs');
  assert.equal(state.ticketStatus, 'used');
  assert.ok(res.body.check_in && res.body.check_in.ticket_id === TICKET_ID);

  const duplicate = createRes();
  await verifyTicket(
    createReq({ body: { token: scanToken(), event_id: EVENT_ID }, user: STAFF }),
    duplicate
  );
  assert.equal(duplicate.statusCode, 409);
  assert.equal(state.checkIns.length, 1, 'duplikat tidak menambah baris check_ins');
});


