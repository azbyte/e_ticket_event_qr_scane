const test = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.STAFF_ACCESS_SECRET = 'test-only-staff-access-secret';
process.env.STAFF_SESSION_TTL = '12h';
process.env.APP_PUBLIC_URL = 'http://localhost:3000';

/**
 * Pengujian undangan staf berbasis nama + kode akses.
 *
 * Seluruh akses database di-stub: test ini memverifikasi logika controller,
 * service, dan middleware tanpa menyentuh PostgreSQL. Perilaku yang diuji
 * mengikuti skenario wajib: pembuatan kode unik, validasi kode, penolakan kode
 * salah/kedaluwarsa/dicabut, pembatasan lintas event, dan pengamanan sesi.
 */

const dbPath = require.resolve('../src/config/db');
const state = {};

const resetState = (overrides = {}) => {
  for (const key of Object.keys(state)) delete state[key];
  Object.assign(
    state,
    {
      eventRow: null,
      invitationRow: null,
      invitationRows: [],
      invitationWithEvent: null,
      middlewareInvitation: null,
      insertedInvitation: null,
      updatedInvitation: null,
      revokedInvitation: null,
      permissionRows: [],
      permissionJoinRows: [],
      revokedRow: null,
      uniqueFailures: 0,
      schemaReady: true,
      lastInsertParams: null,
      calls: [],
    },
    overrides
  );
};

const matches = (sql, fragment) => sql.replace(/\s+/g, ' ').includes(fragment);

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    query: async (sql, params) => {
      state.calls.push({ sql, params });
      if (matches(sql, 'INSERT INTO event_invitations')) {
        if (state.uniqueFailures > 0) {
          state.uniqueFailures -= 1;
          const error = new Error('duplicate key value violates unique constraint');
          error.code = '23505';
          throw error;
        }
        state.lastInsertParams = params;
        state.insertedInvitation = {
          id: params[0],
          event_id: params[1],
          invited_by_id: params[2],
          email: null,
          token_hash: params[3],
          staff_name: params[4],
          access_code_hash: params[5],
          access_code_cipher: params[6],
          access_code_issued_at: new Date().toISOString(),
          status: 'PENDING',
          expires_at: params[7],
          accepted_at: null,
          revoked_at: null,
          created_at: new Date().toISOString(),
        };
        return [state.insertedInvitation];
      }
      if (matches(sql, 'INSERT INTO event_invitation_permissions')) return [];
      if (matches(sql, 'UPDATE event_invitations SET access_code_hash')) {
        if (state.uniqueFailures > 0) {
          state.uniqueFailures -= 1;
          const error = new Error('duplicate key value violates unique constraint');
          error.code = '23505';
          throw error;
        }
        return [state.updatedInvitation];
      }
      if (matches(sql, "SET status = 'REVOKED'")) return [state.revokedInvitation];
      if (matches(sql, "SET status = 'ACCEPTED'")) return [];
      if (matches(sql, 'FROM event_invitations') && matches(sql, 'WHERE event_id = $1')) {
        return state.invitationRows;
      }
      if (matches(sql, 'SELECT event_invitation_id, permission')) return state.permissionJoinRows;
      if (matches(sql, 'SELECT permission FROM event_invitation_permissions')) {
        return state.permissionRows;
      }
      if (matches(sql, 'INSERT INTO revoked_tokens')) return [];
      if (matches(sql, 'SELECT permission FROM event_member_permissions')) return [];
      return [];
    },
    getOne: async (sql, params) => {
      state.calls.push({ sql, params });
      // Pemeriksaan kesiapan skema (migration kode akses staf).
      if (matches(sql, 'FROM information_schema.columns')) {
        return state.schemaReady === false ? null : { ready: 1 };
      }
      if (matches(sql, 'SELECT token_hash FROM revoked_tokens')) return state.revokedRow;
      // Middleware staf memuat undangan + judul event; periksa sebelum pola
      // umum `FROM event_invitations i` di bawah.
      if (matches(sql, 'SELECT i.id, i.event_id, i.status')) return state.middlewareInvitation;
      if (matches(sql, 'SELECT * FROM event_invitations WHERE id = $1 AND event_id = $2')) {
        return state.invitationRow;
      }
      if (matches(sql, 'FROM event_invitations i') && matches(sql, 'WHERE i.id = $1')) {
        return state.invitationWithEvent;
      }
      if (matches(sql, 'FROM events WHERE id = $1')) return state.eventRow;
      return null;
    },
    pool: { connect: async () => { throw new Error('pool tidak dipakai pada test ini'); } },
  },
};

const staffAccess = require('../src/services/staffAccessService');
const controller = require('../src/controllers/staffInvitationController');
const { staffAuthMiddleware, staffOrUserAuth } = require('../src/middleware/staffAuthMiddleware');
const { assertScanPermission } = require('../src/controllers/checkInController');

const OWNER = { id: 'u-owner', role: 'organizer', email: 'owner@example.com' };
const OTHER = { id: 'u-other', role: 'organizer', email: 'other@example.com' };
const EVENT_ID = '11111111-1111-4111-8111-111111111111';
const OTHER_EVENT_ID = '22222222-2222-4222-8222-222222222222';
const INVITATION_ID = '33333333-3333-4333-8333-333333333333';

const makeRes = () => ({
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
});

const makeReq = (overrides = {}) => ({
  params: {},
  body: {},
  query: {},
  headers: {},
  get() {
    return undefined;
  },
  ...overrides,
});

/** Undangan lengkap seperti baris database (kode tersimpan sebagai hash+cipher). */
const buildInvitationRow = ({
  code = 'ABCD2345',
  status = 'PENDING',
  expiresInMs = 7 * 24 * 60 * 60 * 1000,
  eventId = EVENT_ID,
  staffName = 'Budi Santoso',
  withCode = true,
} = {}) => ({
  id: INVITATION_ID,
  event_id: eventId,
  invited_by_id: OWNER.id,
  email: null,
  token_hash: 'disabled-link-token-hash',
  staff_name: staffName,
  access_code_hash: withCode ? staffAccess.hashAccessCode(code) : null,
  access_code_cipher: withCode ? staffAccess.encryptAccessCode(code) : null,
  access_code_issued_at: withCode ? new Date().toISOString() : null,
  status,
  expires_at: new Date(Date.now() + expiresInMs).toISOString(),
  accepted_at: null,
  revoked_at: null,
  created_at: new Date().toISOString(),
});

test('kode akses: format, normalisasi, dan hash tidak menyimpan plaintext', () => {
  const code = staffAccess.generateAccessCode();
  assert.equal(code.length, 8);
  for (const char of code) {
    assert.ok(staffAccess.CODE_ALPHABET.includes(char), `karakter ${char} dari alfabet aman`);
  }
  assert.equal(staffAccess.formatAccessCode(code), `${code.slice(0, 4)}-${code.slice(4)}`);
  // Normalisasi menerima huruf kecil, spasi, dan tanda hubung.
  assert.equal(staffAccess.normalizeAccessCode(` ${code.slice(0, 4)}-${code.slice(4)} `), code);
  assert.equal(staffAccess.normalizeAccessCode('ABC'), null, 'panjang salah ditolak');
  assert.equal(staffAccess.normalizeAccessCode('ABCD0O12'), null, 'karakter ambigu ditolak');

  const hash = staffAccess.hashAccessCode(code);
  assert.match(hash, /^[0-9a-f]{64}$/);
  assert.notEqual(hash, code, 'hash tidak boleh sama dengan kode');
  assert.ok(!hash.includes(code), 'hash tidak memuat kode plaintext');
});

test('kode akses: 2.000 kode yang dihasilkan tidak ada yang sama (unik)', () => {
  const codes = new Set();
  for (let index = 0; index < 2000; index += 1) codes.add(staffAccess.generateAccessCode());
  assert.equal(codes.size, 2000);
});

test('kode akses: ciphertext dapat didekripsi dan bukan plaintext', () => {
  const code = 'JKMNPQRS';
  const cipher = staffAccess.encryptAccessCode(code);
  assert.ok(!cipher.includes(code), 'ciphertext tidak memuat kode');
  assert.equal(staffAccess.decryptAccessCode(cipher), code);
  assert.equal(staffAccess.decryptAccessCode('v1.rusak'), null);
  assert.equal(staffAccess.maskAccessCode(code), '••••-••RS');
});

test('sesi staf: token memuat identitas undangan + event dan bukan token akun', () => {
  const session = staffAccess.issueStaffSession({
    invitationId: INVITATION_ID,
    eventId: EVENT_ID,
    staffName: 'Budi Santoso',
  });
  assert.ok(session.token);
  assert.ok(session.expires_at);
  const claims = staffAccess.verifyStaffSession(session.token);
  assert.equal(claims.typ, 'staff_access');
  assert.equal(claims.sid, INVITATION_ID);
  assert.equal(claims.event_id, EVENT_ID);
  assert.equal(claims.name, 'Budi Santoso');
  // Token akun biasa bukan sesi staf.
  const jwt = require('jsonwebtoken');
  const userToken = jwt.sign({ id: 'u-1', role: 'organizer' }, process.env.JWT_SECRET);
  assert.equal(staffAccess.verifyStaffSession(userToken), null);
});

test('Organizer membuat undangan staf: nama tersimpan, kode unik, DB tanpa plaintext', async () => {
  resetState({ eventRow: { id: EVENT_ID, created_by: OWNER.id, title: 'Konser' } });

  const res = makeRes();
  await controller.createStaffInvitation(
    makeReq({ params: { eventId: EVENT_ID }, user: OWNER, body: { name: '  Budi Santoso  ' } }),
    res
  );

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.invitation.staff_name, 'Budi Santoso');
  assert.match(res.body.invitation.access_code, /^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.ok(
    res.body.invitation.invite_url.endsWith(`/staff-access/${state.insertedInvitation.id}`),
    'tautan memakai id undangan, bukan kode akses'
  );
  assert.ok(!res.body.invitation.invite_url.includes(res.body.invitation.access_code));

  // Parameter INSERT yang benar-benar dikirim controller:
  // [id, eventId, invitedBy, tokenHash, staffName, codeHash, codeCipher, expiresAt]
  const capturedParams = state.lastInsertParams;
  const plainCode = res.body.invitation.access_code.replace('-', '');
  assert.equal(capturedParams[4], 'Budi Santoso', 'nama staf tersimpan');
  assert.match(capturedParams[5], /^[0-9a-f]{64}$/);
  assert.equal(staffAccess.hashAccessCode(plainCode), capturedParams[5]);
  assert.ok(!String(capturedParams[6]).includes(plainCode), 'cipher bukan plaintext');
  assert.equal(staffAccess.decryptAccessCode(capturedParams[6]), plainCode);
  // Email tidak dipakai pada mekanisme baru (NULL, bukan alamat palsu).
  const insertCall = state.calls.find((call) => matches(call.sql, 'INSERT INTO event_invitations'));
  assert.match(insertCall.sql, /email, token_hash/);
  assert.match(insertCall.sql, /NULL/);
});

test('database belum dimigrasikan: penambahan staf ditolak dengan pesan yang jelas', async () => {
  resetState({
    schemaReady: false,
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
  });

  await assert.rejects(
    () =>
      controller.createStaffInvitation(
        makeReq({
          params: { eventId: EVENT_ID },
          user: OWNER,
          body: { name: 'Budi Santoso' },
        }),
        makeRes()
      ),
    (error) => error.statusCode === 424 && /belum dimigrasikan/.test(error.message)
  );
  assert.equal(
    state.calls.some((call) => matches(call.sql, 'INSERT INTO event_invitations')),
    false,
    'tidak ada INSERT saat skema belum siap'
  );
});

test('pembuatan kode mengulang saat terjadi tabrakan unik (kode unik global)', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    uniqueFailures: 2,
    insertedInvitation: buildInvitationRow(),
  });
  const res = makeRes();
  await controller.createStaffInvitation(
    makeReq({ params: { eventId: EVENT_ID }, user: OWNER, body: { name: 'Siti Rahma' } }),
    res
  );
  assert.equal(res.statusCode, 201);
  const inserts = state.calls.filter((call) => matches(call.sql, 'INSERT INTO event_invitations'));
  assert.equal(inserts.length, 3, 'dua tabrakan lalu satu insert berhasil');
});

test('pembuatan kode menyerah dengan 503 setelah batas percobaan', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    uniqueFailures: staffAccess.MAX_CODE_ATTEMPTS,
  });
  await assert.rejects(
    () =>
      controller.createStaffInvitation(
        makeReq({ params: { eventId: EVENT_ID }, user: OWNER, body: { name: 'Siti Rahma' } }),
        makeRes()
      ),
    (error) => error.statusCode === 503
  );
});

test('Organizer lain tidak dapat mengundang staf pada event bukan miliknya', async () => {
  resetState({ eventRow: { id: EVENT_ID, created_by: OWNER.id } });
  await assert.rejects(
    () =>
      controller.createStaffInvitation(
        makeReq({ params: { eventId: EVENT_ID }, user: OTHER, body: { name: 'Penyusup' } }),
        makeRes()
      ),
    (error) => error.statusCode === 403
  );
});

test('nama staf wajib diisi', async () => {
  resetState({ eventRow: { id: EVENT_ID, created_by: OWNER.id } });
  await assert.rejects(
    () =>
      controller.createStaffInvitation(
        makeReq({ params: { eventId: EVENT_ID }, user: OWNER, body: { name: '  ' } }),
        makeRes()
      ),
    (error) => error.statusCode === 400
  );
});

test('kode akses benar: sesi staf diterbitkan dan undangan menjadi ACCEPTED', async () => {
  const row = buildInvitationRow({ code: 'ABCD2345' });
  resetState({ invitationWithEvent: { ...row, event_title: 'Konser', event_status: 'PUBLISHED' } });

  const res = makeRes();
  await controller.validateStaffAccess(
    makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'abcd-2345' } }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.staff.name, 'Budi Santoso');
  assert.equal(res.body.staff.event_id, EVENT_ID);
  assert.equal(res.body.event.title, 'Konser');
  assert.ok(res.body.session.token);
  const claims = staffAccess.verifyStaffSession(res.body.session.token);
  assert.equal(claims.sid, INVITATION_ID);
  assert.equal(claims.event_id, EVENT_ID);
  assert.ok(
    state.calls.some((call) => matches(call.sql, "SET status = 'ACCEPTED'")),
    'undangan ditandai ACCEPTED setelah kode valid'
  );
});

test('kode akses salah ditolak 401 tanpa menerbitkan sesi', async () => {
  const row = buildInvitationRow({ code: 'ABCD2345' });
  resetState({ invitationWithEvent: { ...row, event_title: 'Konser' } });
  const res = makeRes();
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'ZZZZ9999' } }),
        res
      ),
    (error) => error.statusCode === 401 && /Kode akses salah/.test(error.message)
  );
  assert.equal(res.body, null, 'tidak ada sesi pada respons gagal');
});

test('undangan yang dicabut ditolak 403', async () => {
  const row = buildInvitationRow({ status: 'REVOKED' });
  resetState({ invitationWithEvent: { ...row, event_title: 'Konser' } });
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'ABCD2345' } }),
        makeRes()
      ),
    (error) => error.statusCode === 403
  );
});

test('undangan kedaluwarsa ditolak 410', async () => {
  const row = buildInvitationRow({ expiresInMs: -60 * 1000 });
  resetState({ invitationWithEvent: { ...row, event_title: 'Konser' } });
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'ABCD2345' } }),
        makeRes()
      ),
    (error) => error.statusCode === 410
  );
});

test('undangan lama tanpa kode akses diarahkan membuat kode baru (409)', async () => {
  const row = buildInvitationRow({ withCode: false });
  resetState({ invitationWithEvent: { ...row, event_title: 'Konser' } });
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'ABCD2345' } }),
        makeRes()
      ),
    (error) => error.statusCode === 409
  );
});

test('undangan tidak dikenal ditolak 404 dan format kode salah ditolak 400', async () => {
  resetState({ invitationWithEvent: null });
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: 'ABCD2345' } }),
        makeRes()
      ),
    (error) => error.statusCode === 404
  );
  await assert.rejects(
    () =>
      controller.validateStaffAccess(
        makeReq({ body: { invitation_id: INVITATION_ID, access_code: '123' } }),
        makeRes()
      ),
    (error) => error.statusCode === 400
  );
});

const activeInvitation = (overrides = {}) => ({
  id: INVITATION_ID,
  event_id: EVENT_ID,
  status: 'ACCEPTED',
  expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
  staff_name: 'Budi Santoso',
  event_title: 'Konser',
  ...overrides,
});

const staffToken = (eventId = EVENT_ID) =>
  staffAccess.issueStaffSession({
    invitationId: INVITATION_ID,
    eventId,
    staffName: 'Budi Santoso',
  }).token;

/**
 * Jalankan middleware dan tangkap error yang diteruskan ke `next`.
 *
 * `asyncHandler` memanggil `next(error)` (bukan melempar promise), sehingga
 * test harus memeriksa argumen `next`, bukan `assert.rejects`.
 */
const runMiddleware = async (middleware, req) => {
  let called = false;
  let error = null;
  await middleware(req, makeRes(), (err) => {
    called = true;
    error = err || null;
  });
  return { called, error };
};

test('middleware staf: tanpa sesi ditolak 401 (scanner tidak dapat dibuka langsung)', async () => {
  resetState({ middlewareInvitation: activeInvitation() });
  const result = await runMiddleware(staffAuthMiddleware, makeReq());
  assert.equal(result.called, true);
  assert.equal(result.error.statusCode, 401);
});

test('middleware staf: sesi valid mengisi identitas staf + event', async () => {
  resetState({ middlewareInvitation: activeInvitation() });
  const req = makeReq({ headers: { 'x-staff-session': staffToken() } });
  const result = await runMiddleware(staffAuthMiddleware, req);
  assert.equal(result.error, null);
  assert.equal(req.user.role, 'staff');
  assert.equal(req.user.staffInvitationId, INVITATION_ID);
  assert.equal(req.user.staffEventId, EVENT_ID);
  assert.equal(req.staff.name, 'Budi Santoso');
  assert.equal(req.staff.eventTitle, 'Konser');
});

test('middleware staf: token yang dicabut (logout) ditolak 401', async () => {
  resetState({ middlewareInvitation: activeInvitation(), revokedRow: { token_hash: 'x' } });
  const result = await runMiddleware(
    staffAuthMiddleware,
    makeReq({ headers: { 'x-staff-session': staffToken() } })
  );
  assert.equal(result.error.statusCode, 401);
});

test('middleware staf: undangan dicabut atau kedaluwarsa langsung ditolak', async () => {
  resetState({ middlewareInvitation: activeInvitation({ status: 'REVOKED' }) });
  let result = await runMiddleware(
    staffAuthMiddleware,
    makeReq({ headers: { 'x-staff-session': staffToken() } })
  );
  assert.equal(result.error.statusCode, 403);

  resetState({
    middlewareInvitation: activeInvitation({
      expires_at: new Date(Date.now() - 1000).toISOString(),
    }),
  });
  result = await runMiddleware(
    staffAuthMiddleware,
    makeReq({ headers: { 'x-staff-session': staffToken() } })
  );
  assert.equal(result.error.statusCode, 403);
});

test('middleware staf: token event A tidak berlaku saat undangan berubah ke event B', async () => {
  resetState({ middlewareInvitation: activeInvitation({ event_id: OTHER_EVENT_ID }) });
  const result = await runMiddleware(
    staffAuthMiddleware,
    makeReq({ headers: { 'x-staff-session': staffToken(EVENT_ID) } })
  );
  assert.equal(result.error.statusCode, 403);
});

test('staffOrUserAuth memakai sesi staf bila header sesi staf dikirim', async () => {
  resetState({ middlewareInvitation: activeInvitation() });
  const req = makeReq({ headers: { 'x-staff-session': staffToken() } });
  const result = await runMiddleware(staffOrUserAuth, req);
  assert.equal(result.error, null);
  assert.equal(req.user.staffInvitationId, INVITATION_ID);
});

test('staf event A tidak dapat memindai event B (assertScanPermission)', async () => {
  resetState({ eventRow: { id: OTHER_EVENT_ID, created_by: OWNER.id } });
  const staffUser = {
    id: `staff:${INVITATION_ID}`,
    role: 'staff',
    staffInvitationId: INVITATION_ID,
    staffEventId: EVENT_ID,
  };
  await assert.rejects(
    () => assertScanPermission(OTHER_EVENT_ID, staffUser),
    (error) => error.statusCode === 403 && /event undangan/.test(error.message)
  );
});

test('staf dengan izin SCAN_TICKET boleh memindai event undangannya', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    permissionRows: [{ permission: 'SCAN_TICKET' }],
  });
  const memberId = await assertScanPermission(EVENT_ID, {
    id: `staff:${INVITATION_ID}`,
    role: 'staff',
    staffInvitationId: INVITATION_ID,
    staffEventId: EVENT_ID,
  });
  assert.equal(memberId, `staff-invitation:${INVITATION_ID}`);
});

test('staf tanpa izin scan/check-in ditolak 403', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    permissionRows: [{ permission: 'VIEW_EVENT' }],
  });
  await assert.rejects(
    () =>
      assertScanPermission(EVENT_ID, {
        id: `staff:${INVITATION_ID}`,
        role: 'staff',
        staffInvitationId: INVITATION_ID,
        staffEventId: EVENT_ID,
      }),
    (error) => error.statusCode === 403
  );
});

test('daftar undangan menampilkan nama, kode akses, dan tautan untuk Organizer', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    invitationRows: [buildInvitationRow({ code: 'PQRS6789', staffName: 'Siti Rahma' })],
    permissionJoinRows: [
      { event_invitation_id: INVITATION_ID, permission: 'SCAN_TICKET' },
      { event_invitation_id: INVITATION_ID, permission: 'CHECK_IN_TICKET' },
    ],
  });
  const res = makeRes();
  await controller.listStaffInvitations(makeReq({ params: { eventId: EVENT_ID }, user: OWNER }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.count, 1);
  const invitation = res.body.invitations[0];
  assert.equal(invitation.staff_name, 'Siti Rahma');
  assert.equal(invitation.access_code, 'PQRS-6789');
  assert.deepEqual(invitation.permissions, ['SCAN_TICKET', 'CHECK_IN_TICKET']);
  assert.ok(invitation.invite_url.endsWith(`/staff-access/${INVITATION_ID}`));
  assert.equal(invitation.status, 'PENDING');
});

test('kode baru menggantikan kode lama (regenerate) dan undangan kembali PENDING', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    invitationRow: buildInvitationRow({ code: 'OLDX2345', status: 'REVOKED' }),
    updatedInvitation: buildInvitationRow({ code: 'NEWK3456' }),
    permissionRows: [{ permission: 'SCAN_TICKET' }],
  });
  const res = makeRes();
  await controller.regenerateStaffAccessCode(
    makeReq({ params: { eventId: EVENT_ID, invitationId: INVITATION_ID }, user: OWNER, body: {} }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.match(res.body.invitation.access_code, /^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
  assert.notEqual(res.body.invitation.access_code, 'OLDX-2345');
  assert.equal(res.body.invitation.status, 'PENDING');
  const update = state.calls.find((call) =>
    matches(call.sql, 'UPDATE event_invitations SET access_code_hash')
  );
  assert.ok(update, 'hash kode lama ditimpa');
  // Hash yang disimpan harus cocok dengan kode baru yang dikembalikan, bukan
  // kode lama.
  assert.equal(
    update.params[0],
    staffAccess.hashAccessCode(res.body.invitation.access_code.replace('-', ''))
  );
  assert.notEqual(update.params[0], staffAccess.hashAccessCode('OLDX2345'));
});

test('regenerate dapat mengisi nama staf untuk undangan email lama', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    invitationRow: buildInvitationRow({ withCode: false, staffName: null }),
    updatedInvitation: buildInvitationRow({ staffName: 'Dimas Setiawan' }),
    permissionRows: [],
  });
  const res = makeRes();
  await controller.regenerateStaffAccessCode(
    makeReq({
      params: { eventId: EVENT_ID, invitationId: INVITATION_ID },
      user: OWNER,
      body: { name: 'Dimas Setiawan' },
    }),
    res
  );
  assert.equal(res.statusCode, 200);
  const update = state.calls.find((call) =>
    matches(call.sql, 'UPDATE event_invitations SET access_code_hash')
  );
  assert.equal(update.params[2], 'Dimas Setiawan', 'nama staf ikut diperbarui');
});

test('Organizer mencabut undangan staf', async () => {
  resetState({
    eventRow: { id: EVENT_ID, created_by: OWNER.id },
    revokedInvitation: buildInvitationRow({ status: 'REVOKED' }),
  });
  const res = makeRes();
  await controller.revokeStaffInvitation(
    makeReq({ params: { eventId: EVENT_ID, invitationId: INVITATION_ID }, user: OWNER }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.invitation.status, 'REVOKED');
});

test('pratinjau publik tidak pernah membocorkan kode akses', async () => {
  const row = buildInvitationRow({ code: 'ABCD2345' });
  resetState({
    invitationWithEvent: {
      ...row,
      event_title: 'Konser',
      event_status: 'PUBLISHED',
      event_date: '2026-12-01T10:00:00.000Z',
      end_date_time: null,
      location: 'Jakarta',
      event_format: 'OFFLINE',
    },
  });
  const res = makeRes();
  await controller.getStaffInvitationPreview(
    makeReq({ params: { invitationId: INVITATION_ID } }),
    res
  );
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.invitation.staff_name, 'Budi Santoso');
  assert.equal(res.body.invitation.event.title, 'Konser');
  assert.equal(res.body.invitation.requires_new_code, false);
  assert.equal(res.body.invitation.access_code, undefined);
  assert.equal(JSON.stringify(res.body).includes('ABCD2345'), false);
});

test('sesi staf aktif dapat dibaca ulang dan logout mencabut token', async () => {
  resetState({});
  const sessionRes = makeRes();
  await controller.getStaffSession(
    makeReq({
      staff: {
        invitationId: INVITATION_ID,
        eventId: EVENT_ID,
        eventTitle: 'Konser',
        name: 'Budi Santoso',
        expiresAt: new Date(Date.now() + 3600_000).toISOString(),
      },
    }),
    sessionRes
  );
  assert.equal(sessionRes.body.staff.name, 'Budi Santoso');
  assert.equal(sessionRes.body.event.id, EVENT_ID);

  const logoutRes = makeRes();
  const token = staffToken();
  await controller.logoutStaffSession(
    makeReq({
      staff: {
        invitationId: INVITATION_ID,
        eventId: EVENT_ID,
        name: 'Budi Santoso',
        expiresAt: new Date(Date.now() + 3600_000).toISOString(),
        rawToken: token,
      },
    }),
    logoutRes
  );
  assert.equal(logoutRes.statusCode, 200);
  const revokedInsert = state.calls.find((call) => matches(call.sql, 'INSERT INTO revoked_tokens'));
  assert.ok(revokedInsert, 'token dicatat pada revoked_tokens');
  assert.equal(revokedInsert.params[0], staffAccess.hashSessionToken(token));
});
