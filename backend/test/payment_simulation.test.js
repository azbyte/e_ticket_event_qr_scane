process.env.NODE_ENV = 'test';
const test = require('node:test');
const assert = require('node:assert/strict');
const { serializePayment } = require('../src/utils/orderResponse');
const { simulatePayment } = require('../src/controllers/paymentController');

test('serializePayment returns proper contract envelope', () => {
  const payment = {
    id: 'pay-123',
    order_id: 'ord-456',
    status: 'PAID',
    amount: '25000.00',
    payment_reference: 'VA-REF-999',
    virtual_account_number: '8800112233445566',
    virtual_account_bank: 'BCA Virtual Account',
    paid_at: '2026-11-23T10:00:00Z',
    expires_at: '2026-11-24T10:00:00Z',
    failure_reason: null,
  };

  const serialized = serializePayment(payment);

  assert.equal(serialized.id, 'pay-123');
  assert.equal(serialized.order_id, 'ord-456');
  assert.equal(serialized.method, 'virtual_account');
  assert.equal(serialized.status, 'paid');
  assert.equal(serialized.amount, 25000);
  assert.equal(serialized.virtual_account_number, '8800112233445566');
  assert.equal(serialized.va_bank, 'BCA Virtual Account');
  assert.equal(serialized.payment_reference, 'VA-REF-999');
});

test('simulatePayment rejects invalid request body without boolean simulate_success', async () => {
  const req = {
    body: {
      order_id: 'ord-123',
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
      await simulatePayment(req, res);
    },
    (err) => {
      assert.equal(statusCode, 400);
      assert.match(err.message, /boolean simulation result are required/i);
      return true;
    }
  );
});

test('simulatePayment rejects request without order_id', async () => {
  const req = {
    body: {
      simulate_success: true,
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
      await simulatePayment(req, res);
    },
    (err) => {
      assert.equal(statusCode, 400);
      assert.match(err.message, /Order ID and a boolean simulation result/i);
      return true;
    }
  );
});
