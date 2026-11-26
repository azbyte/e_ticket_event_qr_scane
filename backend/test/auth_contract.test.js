const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';

// Lapisan database di-stub SEBELUM controller/middleware di-require karena
// keduanya men-destructure `query`/`getOne` saat import. Test ini tidak boleh
// menyentuh database sungguhan (AGENTS.md, FINISHING_AUTHORITY.md).
const dbPath = require.resolve('../src/config/db');
const state = {};

function resetState(overrides = {}) {
  Object.assign(state, {
    profileByEmail: null,
    profileByUsername: null,
    profileById: null,
    existingEmailRow: null,
    usernameRows: [],
    revokedTokenRow: null,
    insertedProfile: null,
    insertedOrganizerProfile: null,
    organizerInsertFails: false,
    updatedProfile: null,
    calls: [],
  }, overrides);
}

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    query: async (sql, params) => {
      state.calls.push({ sql, params });
      if (sql.includes('FROM profiles WHERE username')) return state.usernameRows;
      return [];
    },
    getOne: async (sql, params) => {
      state.calls.push({ sql, params });
      if (sql.includes('INSERT INTO profiles')) return state.insertedProfile;
      if (sql.includes('UPDATE profiles')) return state.updatedProfile;
      if (sql.includes('revoked_tokens')) return state.revokedTokenRow;
      if (sql.includes('password_hash')) {
        return sql.includes('WHERE username') ? state.profileByUsername : state.profileByEmail;
      }
      if (sql.includes('WHERE id = $1')) return state.profileById;
      return state.existingEmailRow;
    },
    // Klien transaksi tiruan: registerUser memakai BEGIN/COMMIT dan pool.connect
    // agar pembuatan profiles + organizer_profiles atomik. Stub ini meniru
    // kontrak `pg` seperlunya tanpa menyentuh database sungguhan.
    pool: {
      connect: async () => ({
        query: async (sql, params = []) => {
          state.calls.push({ sql, params });
          if (/^(BEGIN|COMMIT|ROLLBACK)$/i.test(sql.trim())) return { rows: [], rowCount: 0 };
          if (sql.includes('SELECT 1 FROM profiles WHERE email')) {
            const row = state.existingEmailRow;
            return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
          }
          if (sql.includes('SELECT 1 FROM profiles WHERE username')) {
            const rows = state.usernameRows || [];
            return { rows, rowCount: rows.length };
          }
          if (sql.includes('INSERT INTO profiles')) {
            const row = state.insertedProfile;
            return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
          }
          if (sql.includes('INSERT INTO organizer_profiles')) {
            if (state.organizerInsertFails) {
              const failure = new Error('insert organizer_profiles failed');
              failure.code = '23503';
              throw failure;
            }
            const row = state.insertedOrganizerProfile;
            return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
          }
          return { rows: [], rowCount: 0 };
        },
        release: () => {},
      }),
    },
  },
};

const {
  registerUser, loginUser, getMe, updateMe, logoutUser,
} = require('../src/controllers/authController');
const { authMiddleware } = require('../src/middleware/authMiddleware');
const authService = require('../src/services/authService');
const { USER_ROLES } = require('../src/utils/constants');

function createResponse() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
}

async function run(handler, req, res = createResponse()) {
  let captured;
  await handler(req, res, (error) => { captured = error; });
  return { req, res, error: captured };
}

resetState();

test('register mengabaikan role kiriman klien dan selalu menyimpan Organizer', async () => {
  resetState({
    insertedProfile: {
      id: 'u-1', name: 'Organizer Uji', email: 'organizer@example.test',
      username: 'organizer', role: USER_ROLES.ORGANIZER,
    },
    insertedOrganizerProfile: { id: 'org-1', user_id: 'u-1', organization_name: null, contact_name: 'Organizer Uji' },
  });
  const res = createResponse();
  const { error } = await run(registerUser, {
    body: {
      name: 'Organizer Uji', email: 'organizer@example.test',
      password: 'rahasia123', role: 'admin',
    },
  }, res);

  assert.equal(error, undefined);
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.success, true);
  assert.equal(res.body.user.role, 'organizer');
  assert.ok(res.body.token, 'token dikembalikan');

  const insert = state.calls.find((call) => call.sql.includes('INSERT INTO profiles'));
  assert.ok(insert, 'INSERT INTO profiles dipanggil');
  assert.ok(insert.params.includes(USER_ROLES.ORGANIZER), 'role tersimpan = organizer');
  assert.ok(!insert.params.includes('admin'), 'role klien tidak pernah menjadi parameter');

  // Profil Organizer wajib dibuat pada transaksi yang sama dengan akun User.
  const orgInsert = state.calls.find((call) => call.sql.includes('INSERT INTO organizer_profiles'));
  assert.ok(orgInsert, 'profil organizer dibuat');
  assert.equal(orgInsert.params[0], 'u-1', 'profil organizer terhubung ke user_id akun baru');
  assert.equal(res.body.user.organizer_profile_id, 'org-1', 'id profil organizer dikembalikan');
  assert.ok(state.calls.some((call) => call.sql.trim() === 'BEGIN'), 'transaksi dibuka');
  assert.ok(state.calls.some((call) => call.sql.trim() === 'COMMIT'), 'transaksi di-commit');

  const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
  assert.equal(decoded.role, 'organizer');
  assert.equal(decoded.id, 'u-1');
});

test('register membatalkan seluruh proses bila profil Organizer gagal dibuat', async () => {
  resetState({
    insertedProfile: { id: 'u-rollback', name: 'Rollback', email: 'rollback@example.test', username: 'rollback', role: USER_ROLES.ORGANIZER },
    insertedOrganizerProfile: null,
    organizerInsertFails: true,
  });
  const res = createResponse();
  const { error } = await run(registerUser, {
    body: { name: 'Rollback', email: 'rollback@example.test', password: 'rahasia123' },
  }, res);

  assert.ok(error, 'kegagalan profil organizer diteruskan sebagai error');
  assert.equal(res.body, undefined, 'tidak ada respons sukses');
  assert.ok(state.calls.some((call) => call.sql.trim() === 'BEGIN'), 'transaksi dibuka');
  assert.ok(state.calls.some((call) => call.sql.trim() === 'ROLLBACK'), 'transaksi di-rollback');
  assert.ok(!state.calls.some((call) => call.sql.trim() === 'COMMIT'), 'tidak pernah commit');
});

test('register menolak email yang sudah terdaftar', async () => {
  resetState({ existingEmailRow: { id: 'u-existing' } });
  const res = createResponse();
  const { error } = await run(registerUser, {
    body: { name: 'Duplikat', email: 'sudah@example.test', password: 'rahasia123' },
  }, res);

  assert.equal(res.statusCode, 400);
  assert.match(error.message, /already exists/i);
});

test('register menolak field wajib yang hilang, email invalid, dan password pendek', async () => {
  for (const body of [
    { name: 'Tanpa Email', password: 'rahasia123' },
    { name: 'Email Salah', email: 'bukan-email', password: 'rahasia123' },
    { name: 'Password Pendek', email: 'pendek@example.test', password: '123' },
  ]) {
    resetState();
    const res = createResponse();
    const { error } = await run(registerUser, { body }, res);
    assert.equal(res.statusCode, 400, `body ${JSON.stringify(body)} harus 400`);
    assert.ok(error, `body ${JSON.stringify(body)} harus melempar error`);
    assert.equal(state.calls.some((call) => call.sql.includes('INSERT INTO profiles')), false,
      'tidak ada INSERT saat validasi gagal');
  }
});

test('login valid mengembalikan token dengan role dari database', async () => {
  const passwordHash = await authService.hashPassword('rahasia123');
  resetState({
    profileByEmail: {
      id: 'u-1', name: 'Organizer Uji', email: 'organizer@example.test', username: 'organizer',
      password_hash: passwordHash, role: 'organizer', avatar_url: null,
      created_at: '2026-01-01T00:00:00.000Z', disabled_at: null,
    },
  });
  const res = createResponse();
  const { error } = await run(loginUser, {
    body: { email: 'organizer@example.test', password: 'rahasia123' },
  }, res);

  assert.equal(error, undefined);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.user.email, 'organizer@example.test');
  assert.equal(res.body.user.role, 'organizer');
  assert.equal(res.body.user.password_hash, undefined, 'hash tidak boleh bocor');
  const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
  assert.equal(decoded.id, 'u-1');
  assert.equal(decoded.role, 'organizer');
});

test('login menerima username ketika identitas bukan email', async () => {
  const passwordHash = await authService.hashPassword('rahasia123');
  resetState({
    profileByUsername: {
      id: 'u-2', name: 'Admin Uji', email: 'admin@example.test', username: 'adminplatform',
      password_hash: passwordHash, role: 'admin', avatar_url: null,
      created_at: '2026-01-01T00:00:00.000Z', disabled_at: null,
    },
  });
  const res = createResponse();
  const { error } = await run(loginUser, {
    body: { username: 'adminplatform', password: 'rahasia123' },
  }, res);

  assert.equal(error, undefined);
  assert.equal(res.body.user.role, 'admin');
  assert.equal(state.calls.some((call) => call.sql.includes('WHERE username')), true);
});

test('login menolak password salah, user tidak dikenal, dan akun disabled dengan 401', async () => {
  const passwordHash = await authService.hashPassword('rahasia123');
  const cases = [
    {
      name: 'password salah',
      state: {
        profileByEmail: {
          id: 'u-1', email: 'organizer@example.test', password_hash: passwordHash,
          role: 'organizer', disabled_at: null,
        },
      },
      body: { email: 'organizer@example.test', password: 'salah-total' },
      message: /invalid credentials/i,
    },
    {
      name: 'user tidak dikenal',
      state: {},
      body: { email: 'hilang@example.test', password: 'rahasia123' },
      message: /invalid credentials/i,
    },
    {
      name: 'akun disabled',
      state: {
        profileByEmail: {
          id: 'u-9', email: 'nonaktif@example.test', password_hash: passwordHash,
          role: 'organizer', disabled_at: '2026-02-01T00:00:00.000Z',
        },
      },
      body: { email: 'nonaktif@example.test', password: 'rahasia123' },
      message: /disabled/i,
    },
  ];

  for (const testCase of cases) {
    resetState(testCase.state);
    const res = createResponse();
    const { error } = await run(loginUser, { body: testCase.body }, res);
    assert.equal(res.statusCode, 401, `${testCase.name} harus 401`);
    assert.match(error.message, testCase.message, `${testCase.name}: pesan 401`);
    assert.equal(res.body, undefined, `${testCase.name}: tidak ada token yang dikirim`);
  }
});

test('login menolak request tanpa identitas atau password dengan 400', async () => {
  resetState();
  const res = createResponse();
  const { error } = await run(loginUser, { body: { email: 'organizer@example.test' } }, res);
  // Kasus ini dijawab langsung oleh controller (bukan dilempar ke error middleware).
  assert.equal(error, undefined);
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.success, false);
  assert.match(res.body.message, /required/i);
  assert.equal(res.body.token, undefined, 'tidak ada token untuk request tidak valid');
});


test('getMe memakai identitas dari token, bukan dari body klien', async () => {
  resetState({
    profileById: {
      id: 'u-1', name: 'Organizer Uji', email: 'organizer@example.test',
      username: 'organizer', role: 'organizer', avatar_url: null,
      created_at: '2026-01-01T00:00:00.000Z',
    },
  });
  const res = createResponse();
  const { error } = await run(getMe, {
    user: { id: 'u-1', role: 'organizer' },
    body: { id: 'u-lain' },
  }, res);

  assert.equal(error, undefined);
  assert.equal(res.body.success, true);
  assert.equal(res.body.user.id, 'u-1');
  const select = state.calls.find((call) => call.sql.includes('FROM profiles WHERE id'));
  assert.deepEqual(select.params, ['u-1']);
});

test('updateMe hanya menerima name/avatar_url sehingga role tidak dapat di-upgrade', async () => {
  resetState({
    updatedProfile: {
      id: 'u-1', name: 'Nama Baru', email: 'organizer@example.test', username: 'organizer',
      role: 'organizer', avatar_url: null, created_at: '2026-01-01T00:00:00.000Z',
    },
  });
  const res = createResponse();
  const { error } = await run(updateMe, {
    user: { id: 'u-1', role: 'organizer' },
    body: { name: 'Nama Baru', role: 'admin', email: 'peretas@example.test', id: 'u-lain' },
  }, res);

  assert.equal(error, undefined);
  assert.equal(res.body.user.role, 'organizer');
  const update = state.calls.find((call) => call.sql.includes('UPDATE profiles'));
  assert.ok(update, 'UPDATE profiles dipanggil');
  assert.ok(!update.sql.includes('role ='), 'kolom role tidak pernah masuk SET clause');
  assert.deepEqual(update.params, ['Nama Baru', 'u-1']);
  assert.ok(!update.params.includes('admin'), 'role kiriman klien dibuang');
  assert.ok(!update.params.includes('peretas@example.test'), 'email kiriman klien dibuang');
});

test('updateMe menolak payload tanpa field yang dapat diperbarui', async () => {
  resetState();
  const res = createResponse();
  const { error } = await run(updateMe, {
    user: { id: 'u-1', role: 'organizer' },
    body: { role: 'admin' },
  }, res);
  assert.equal(res.statusCode, 400);
  assert.match(error.message, /profile fields/i);
});

test('logout menyimpan hash SHA-256 token ke revoked_tokens, bukan token mentah', async () => {
  resetState();
  const token = authService.generateToken({
    id: 'u-1', email: 'organizer@example.test', role: 'organizer',
  });
  const res = createResponse();
  const { error } = await run(logoutUser, { headers: { authorization: `Bearer ${token}` } }, res);

  assert.equal(error, undefined);
  assert.equal(res.body.success, true);
  const insert = state.calls.find((call) => call.sql.includes('revoked_tokens'));
  assert.ok(insert, 'token dicabut di sisi server');
  assert.equal(insert.params[0], authService.hashToken(token));
  assert.match(insert.params[0], /^[a-f0-9]{64}$/);
  assert.notEqual(insert.params[0], token);
});


test('authMiddleware menolak request tanpa token dengan 401', async () => {
  resetState();
  const res = createResponse();
  const { error } = await run(authMiddleware, { headers: {} }, res);
  assert.equal(res.statusCode, 401);
  assert.match(error.message, /no token/i);
});

test('authMiddleware menolak token bertanda tangan salah dengan 401', async () => {
  resetState();
  const forged = jwt.sign({ id: 'u-1', role: 'admin' }, 'bukan-secret-server');
  const res = createResponse();
  const { error } = await run(authMiddleware, {
    headers: { authorization: `Bearer ${forged}` },
  }, res);
  assert.equal(res.statusCode, 401);
  assert.match(error.message, /token failed/i);
});

test('authMiddleware menolak token yang sudah dicabut lewat logout', async () => {
  const token = authService.generateToken({ id: 'u-1', email: 'organizer@example.test', role: 'organizer' });
  resetState({
    profileById: { id: 'u-1', name: 'Organizer Uji', email: 'organizer@example.test', role: 'organizer', disabled_at: null },
    revokedTokenRow: { token_hash: authService.hashToken(token) },
  });
  const res = createResponse();
  const { error } = await run(authMiddleware, { headers: { authorization: `Bearer ${token}` } }, res);
  assert.equal(res.statusCode, 401);
  assert.match(error.message, /revoked/i);
});

test('authMiddleware menolak akun disabled dan user yang sudah dihapus', async () => {
  const token = authService.generateToken({ id: 'u-9', email: 'nonaktif@example.test', role: 'organizer' });

  resetState({
    profileById: { id: 'u-9', name: 'Nonaktif', email: 'nonaktif@example.test', role: 'organizer', disabled_at: '2026-02-01T00:00:00.000Z' },
    revokedTokenRow: null,
  });
  let res = createResponse();
  let result = await run(authMiddleware, { headers: { authorization: `Bearer ${token}` } }, res);
  assert.equal(res.statusCode, 401);
  assert.match(result.error.message, /disabled/i);

  resetState({ profileById: null, revokedTokenRow: null });
  res = createResponse();
  result = await run(authMiddleware, { headers: { authorization: `Bearer ${token}` } }, res);
  assert.equal(res.statusCode, 401);
  assert.match(result.error.message, /no longer exists/i);
});

test('authMiddleware memakai role terbaru dari database, bukan klaim token', async () => {
  // Token memuat klaim role "admin", tetapi profil di database adalah organizer.
  // Server tetap otoritas role (kriteria task: role tidak dapat di-upgrade klien).
  const token = authService.generateToken({ id: 'u-1', email: 'organizer@example.test', role: 'admin' });
  resetState({
    profileById: { id: 'u-1', name: 'Organizer Uji', email: 'organizer@example.test', role: 'organizer', disabled_at: null },
    revokedTokenRow: null,
  });
  const res = createResponse();
  const { req, error } = await run(authMiddleware, {
    headers: { authorization: `Bearer ${token}` },
  }, res);

  assert.equal(error, undefined);
  assert.equal(req.user.id, 'u-1');
  assert.equal(req.user.role, 'organizer', 'role database menang atas klaim JWT');
  assert.equal(req.user.disabled_at, undefined, 'kolom internal tidak diteruskan');
});

test('USER_ROLES memuat aktor PRD §2 dan mempertahankan customer sebagai legacy', () => {
  assert.equal(USER_ROLES.ORGANIZER, 'organizer');
  assert.equal(USER_ROLES.ADMIN, 'admin');
  assert.equal(USER_ROLES.STAFF, 'staff');
  assert.equal(USER_ROLES.CUSTOMER, 'customer');
  assert.equal(Object.keys(USER_ROLES).length, 4);
});

