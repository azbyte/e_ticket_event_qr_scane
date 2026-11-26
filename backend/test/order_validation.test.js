const test = require('node:test');
const assert = require('node:assert/strict');

// Unit test murni: seluruh skenario di bawah ditolak pada validasi awal
// sehingga koneksi database tidak pernah dipakai. Variabel ini hanya memenuhi
// validasi startup `config/env.js` saat controller di-require.
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const { createOrder, hashAccessToken, getAuthorizedOrder } = require('../src/controllers/orderController');

test('createOrder rejects request with quantity greater than 1 in Tahap 1', async () => {
  const req = {
    body: {
      event_id: '11111111-1111-4111-8111-111111111111',
      items: {
        '22222222-2222-4222-8222-222222222222': 2,
      },
      attendees: [
        { ticket_type_id: '22222222-2222-4222-8222-222222222222', name: 'Budi Santoso', email: 'budi@example.com' },
        { ticket_type_id: '22222222-2222-4222-8222-222222222222', name: 'Dewi Lestari', email: 'dewi@example.com' },
      ],
    },
    get: () => null,
  };
  let statusCode = 200;
  const res = {
    status: (code) => { statusCode = code; return res; },
    json: () => res,
  };

  await assert.rejects(
    async () => {
      await createOrder(req, res);
    },
    (err) => {
      assert.equal(statusCode, 400);
      assert.match(err.message, /exactly one ticket and one attendee/i);
      return true;
    }
  );
});

test('createOrder rejects multi-item ticket types in Tahap 1', async () => {
  const req = {
    body: {
      event_id: '11111111-1111-4111-8111-111111111111',
      items: {
        '22222222-2222-4222-8222-222222222222': 1,
        '33333333-3333-4333-8333-333333333333': 1,
      },
      attendees: [
        { ticket_type_id: '22222222-2222-4222-8222-222222222222', name: 'Budi Santoso', email: 'budi@example.com' },
        { ticket_type_id: '33333333-3333-4333-8333-333333333333', name: 'Dewi Lestari', email: 'dewi@example.com' },
      ],
    },
    get: () => null,
  };
  let statusCode = 200;
  const res = {
    status: (code) => { statusCode = code; return res; },
    json: () => res,
  };

  await assert.rejects(
    async () => {
      await createOrder(req, res);
    },
    (err) => {
      assert.equal(statusCode, 400);
      assert.match(err.message, /exactly one ticket and one attendee/i);
      return true;
    }
  );
});

test('createOrder rejects assisted registration attempts in public checkout', async () => {
  const req = {
    body: {
      event_id: '11111111-1111-4111-8111-111111111111',
      assisted_by_member_id: '99999999-9999-4999-8999-999999999999',
      items: {
        '22222222-2222-4222-8222-222222222222': 1,
      },
      attendees: [
        { ticket_type_id: '22222222-2222-4222-8222-222222222222', name: 'Budi Santoso', email: 'budi@example.com' },
      ],
    },
    get: () => null,
  };
  let statusCode = 200;
  const res = {
    status: (code) => { statusCode = code; return res; },
    json: () => res,
  };

  await assert.rejects(
    async () => {
      await createOrder(req, res);
    },
    (err) => {
      assert.equal(statusCode, 400);
      assert.match(err.message, /assisted registration is not supported/i);
      return true;
    }
  );
});

test('hashAccessToken produces deterministic SHA-256 digest', () => {
  const token = 'test-token-12345-secure-entropy';
  const hash1 = hashAccessToken(token);
  const hash2 = hashAccessToken(token);

  assert.equal(typeof hash1, 'string');
  assert.equal(hash1.length, 64);
  assert.equal(hash1, hash2);
  assert.notEqual(hash1, token);
});
