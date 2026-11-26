process.env.NODE_ENV = 'test';
// Unit test token tiket: lapisan database di-stub (lihat require.cache di bawah)
// sehingga tidak ada koneksi PostgreSQL. Variabel ini hanya memenuhi validasi
// startup `config/env.js` pada modul yang di-require.
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const { test } = require('node:test');
const assert = require('node:assert/strict');

// `presentTicket(includeToken: true)` memastikan `token_hash` tiket tersimpan
// agar QR milik owner dapat diverifikasi saat check-in. Di unit test ini efek
// tulis itu diarahkan ke stub in-memory — bukan database — sehingga logika
// presentasi tetap dieksekusi penuh tanpa menyentuh PostgreSQL.
const dbPath = require.resolve('../src/config/db');
const tokenHashWrites = [];
require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    pool: { connect: async () => { throw new Error('unit test tidak boleh membuka koneksi database'); } },
    query: async (sql, params = []) => {
      tokenHashWrites.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      return [];
    },
    getOne: async () => null,
    supabase: { query: async () => [], getOne: async () => null },
  },
};

const ticketTokens = require('../src/services/ticketTokenService');

test('T3-D2-02 & T3-D2-06: ticket token HMAC-SHA256 deterministik dan hash konsisten', async () => {
  const fakeTicket = {
    id: 'f87a8f90-1111-4000-8000-000000000001',
    issued_at: new Date('2026-11-25T10:00:00.000Z'),
  };

  const rawToken1 = ticketTokens.rawTokenFor(fakeTicket);
  const rawToken2 = ticketTokens.rawTokenFor(fakeTicket);

  assert.equal(rawToken1, rawToken2, 'rawToken harus deterministik untuk tiket dan timestamp yang sama');
  assert.ok(rawToken1.length >= 32, 'rawToken harus memiliki panjang minimal 32 karakter');

  const hash1 = ticketTokens.hashToken(rawToken1);
  const hash2 = ticketTokens.hashToken(rawToken2);
  assert.equal(hash1, hash2, 'hash SHA-256 harus identik');
  assert.equal(hash1.length, 64, 'hash SHA-256 harus 64 karakter hex');
});

test('T3-D2-02: presentTicket menyembunyikan token jika includeToken = false', async () => {
  const fakeTicket = {
    id: 'f87a8f90-2222-4000-8000-000000000002',
    issued_at: new Date('2026-11-25T10:00:00.000Z'),
    token_hash: 'abc123hash',
    attendee_name: 'Budi Test',
  };

  const presentedPublic = await ticketTokens.presentTicket(fakeTicket, { includeToken: false });
  assert.equal(presentedPublic.token, undefined, 'token tidak boleh ada pada presentasi non-owner');
  assert.equal(presentedPublic.token_hash, undefined, 'token_hash tidak pernah dikirim ke klien');
  assert.equal(presentedPublic.attendee_name, 'Budi Test');

  const writesBeforeOwner = tokenHashWrites.length;
  const presentedOwner = await ticketTokens.presentTicket(fakeTicket, { includeToken: true });
  assert.ok(typeof presentedOwner.token === 'string', 'token harus ada untuk owner');
  assert.equal(presentedOwner.token_hash, undefined, 'token_hash tetap tidak dikirim ke owner');
  // Efek samping penyimpanan hash tetap terjadi (diarahkan ke stub, bukan DB).
  assert.equal(
    tokenHashWrites.length - writesBeforeOwner,
    1,
    'hash tiket harus dipastikan tersimpan tepat sekali untuk owner',
  );
  const ownerWrite = tokenHashWrites[writesBeforeOwner];
  assert.match(ownerWrite.sql, /^UPDATE tickets SET token_hash = \$1 WHERE id = \$2$/);
  assert.equal(ownerWrite.params[1], fakeTicket.id);
  assert.equal(
    ownerWrite.params[0],
    ticketTokens.hashToken(presentedOwner.token),
    'hash yang disimpan harus SHA-256 dari token yang dikirim ke owner',
  );
});

test('T3-D2-06: safeEqual membandingkan hash secara constant-time tanpa exception', () => {
  const a = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
  const b = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
  const c = ' berbeda ';

  assert.equal(ticketTokens.safeEqual(a, b), true, 'hash identik harus bernilai true');
  assert.equal(ticketTokens.safeEqual(a, c), false, 'hash berbeda panjang harus bernilai false tanpa error');
});

test('T3-D2-06: findTicketByRawToken menolak input invalid atau terlalu pendek', async () => {
  const empty = await ticketTokens.findTicketByRawToken('');
  assert.equal(empty, null);

  const short = await ticketTokens.findTicketByRawToken('pendek');
  assert.equal(short, null);

  const nonString = await ticketTokens.findTicketByRawToken(null);
  assert.equal(nonString, null);
});
