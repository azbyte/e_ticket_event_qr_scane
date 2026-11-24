const { test } = require('node:test');
const assert = require('node:assert/strict');
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

  const presentedOwner = await ticketTokens.presentTicket(fakeTicket, { includeToken: true });
  assert.ok(typeof presentedOwner.token === 'string', 'token harus ada untuk owner');
  assert.equal(presentedOwner.token_hash, undefined, 'token_hash tetap tidak dikirim ke owner');
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
