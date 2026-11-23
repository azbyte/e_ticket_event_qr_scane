/**
 * Unit test bootstrap akun Admin.
 *
 * Memakai service asli dengan database in-memory (query/getOne diinjeksi) dan
 * bcrypt sungguhan. Tidak ada koneksi database, seed, atau mutasi data nyata.
 */
process.env.NODE_ENV = 'test';

const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');

const {
  createAdminBootstrapService,
  readAdminConfig,
  isAdminConfigComplete,
} = require('../src/services/adminBootstrapService');

const STRONG_PASSWORD = 'Adm1n-Str0ng-Passphrase!';

const createFakeStore = (seed = []) => {
  const profiles = seed.map((row) => ({ ...row }));
  let inserted = 0;

  const query = async (sql, params = []) => {
    if (sql.startsWith('SELECT id FROM profiles WHERE username')) {
      return profiles.filter((row) => row.username === params[0]).map((row) => ({ id: row.id }));
    }
    if (sql.startsWith('UPDATE profiles SET password_hash')) {
      const target = profiles.find((row) => row.id === params[1] && row.role === params[2]);
      if (target) target.password_hash = params[0];
      return [];
    }
    throw new Error(`Unexpected query in test: ${sql}`);
  };

  const getOne = async (sql, params = []) => {
    if (sql.startsWith('SELECT id, role, disabled_at FROM profiles WHERE email')) {
      return profiles.find((row) => row.email === params[0]) || null;
    }
    if (sql.startsWith('INSERT INTO profiles')) {
      inserted += 1;
      const row = {
        id: `00000000-0000-4000-8000-${String(inserted).padStart(12, '0')}`,
        name: params[0],
        email: params[1],
        username: params[2],
        password_hash: params[3],
        role: params[4],
      };
      profiles.push(row);
      return { id: row.id, email: row.email, role: row.role };
    }
    throw new Error(`Unexpected getOne in test: ${sql}`);
  };

  return { profiles, query, getOne, get insertedCount() { return inserted; } };
};

const buildService = (store) =>
  createAdminBootstrapService({
    query: store.query,
    getOne: store.getOne,
    hashPassword: (password) => bcrypt.hash(password, 4),
  });

test('konfigurasi Admin tidak lengkap ditolak tanpa menyentuh database', async () => {
  const store = createFakeStore();
  const service = buildService(store);

  const missing = await service.ensureAdminAccount({ ...readAdminConfig({}), name: 'Admin' });
  assert.equal(missing.status, 'INVALID_CONFIG');
  assert.match(missing.message, /ADMIN_EMAIL/);

  const weak = await service.ensureAdminAccount({
    email: 'admin@example.test',
    password: 'short',
    name: 'Admin',
    username: 'admin',
    rotatePassword: false,
  });
  assert.equal(weak.status, 'INVALID_CONFIG');
  assert.match(weak.message, /ADMIN_PASSWORD/);

  assert.equal(store.profiles.length, 0);
  assert.equal(store.insertedCount, 0);
});

test('akun Admin dibuat sebagai record profiles dengan role admin dan hash bcrypt', async () => {
  const store = createFakeStore();
  const service = buildService(store);

  const result = await service.ensureAdminAccount({
    email: 'admin@example.test',
    password: STRONG_PASSWORD,
    name: 'Administrator Platform',
    username: 'admin',
    rotatePassword: false,
  });

  assert.equal(result.status, 'CREATED');
  assert.equal(store.profiles.length, 1);
  const row = store.profiles[0];
  assert.equal(row.role, 'admin');
  assert.equal(row.email, 'admin@example.test');
  assert.equal(row.username, 'admin');
  assert.notEqual(row.password_hash, STRONG_PASSWORD);
  assert.equal(await bcrypt.compare(STRONG_PASSWORD, row.password_hash), true);
});

test('bootstrap idempotent tidak membuat akun Admin duplikat', async () => {
  const store = createFakeStore();
  const service = buildService(store);
  const config = {
    email: 'admin@example.test',
    password: STRONG_PASSWORD,
    name: 'Administrator Platform',
    username: 'admin',
    rotatePassword: false,
  };

  const first = await service.ensureAdminAccount(config);
  const second = await service.ensureAdminAccount(config);

  assert.equal(first.status, 'CREATED');
  assert.equal(second.status, 'UNCHANGED');
  assert.equal(store.insertedCount, 1);
  assert.equal(store.profiles.filter((row) => row.role === 'admin').length, 1);
  assert.equal(second.userId, first.userId);
});

test('email milik akun non-admin tidak dinaikkan menjadi admin', async () => {
  const store = createFakeStore([
    { id: 'organizer-1', email: 'organizer@example.test', username: 'organizer', role: 'organizer' },
  ]);
  const service = buildService(store);

  const result = await service.ensureAdminAccount({
    email: 'organizer@example.test',
    password: STRONG_PASSWORD,
    name: 'Administrator Platform',
    username: 'admin',
    rotatePassword: true,
  });

  assert.equal(result.status, 'CONFLICT');
  assert.equal(store.profiles[0].role, 'organizer');
  assert.equal(store.insertedCount, 0);
});

test('rotasi password hanya terjadi bila diminta eksplisit', async () => {
  const oldHash = await bcrypt.hash('Old-Password-123!', 4);
  const store = createFakeStore([
    { id: 'admin-1', email: 'admin@example.test', username: 'admin', role: 'admin', disabled_at: null, password_hash: oldHash },
  ]);
  const service = buildService(store);

  const unchanged = await service.ensureAdminAccount({
    email: 'admin@example.test',
    password: STRONG_PASSWORD,
    name: 'Administrator Platform',
    username: 'admin',
    rotatePassword: false,
  });
  assert.equal(unchanged.status, 'UNCHANGED');
  assert.equal(store.profiles[0].password_hash, oldHash);

  const rotated = await service.ensureAdminAccount({
    email: 'admin@example.test',
    password: STRONG_PASSWORD,
    name: 'Administrator Platform',
    username: 'admin',
    rotatePassword: true,
  });
  assert.equal(rotated.status, 'PASSWORD_ROTATED');
  assert.notEqual(store.profiles[0].password_hash, oldHash);
  assert.equal(await bcrypt.compare(STRONG_PASSWORD, store.profiles[0].password_hash), true);
  assert.equal(store.insertedCount, 0);
});

test('environment tanpa kredensial Admin menghasilkan SKIPPED, bukan akun default', async () => {
  const store = createFakeStore();
  const service = buildService(store);

  assert.equal(isAdminConfigComplete(readAdminConfig({})), false);
  const result = await service.ensureAdminAccountFromEnv({});
  assert.equal(result.status, 'SKIPPED');
  assert.equal(store.profiles.length, 0);
});
