const test = require('node:test');
const assert = require('node:assert/strict');
const { serializeOrder } = require('../src/utils/orderResponse');

test('serializeOrder returns the Flutter order and simulated-payment contract', () => {
  const result = serializeOrder({
    id: 'order-1',
    order_number: 'ORD-1',
    purchaser_id: null,
    event_id: 'event-1',
    status: 'PENDING_PAYMENT',
    subtotal: '10000.00',
    service_fee: '5000.00',
    grand_total: '15000.00',
    expires_at: '2026-11-14T00:00:00.000Z',
    created_at: '2026-11-13T00:00:00.000Z',
    updated_at: '2026-11-13T00:00:00.000Z',
    events: { title: 'Event Uji' },
    order_items: [{
      id: 'item-1',
      order_id: 'order-1',
      ticket_type_id: 'type-1',
      quantity: 2,
      unit_price: '5000.00',
      subtotal: '10000.00',
      ticket_types: { name: 'Umum' },
    }],
    order_payments: [{
      id: 'payment-1',
      order_id: 'order-1',
      status: 'PENDING',
      amount: '15000.00',
      virtual_account_number: '8812345678901234',
      virtual_account_bank: 'VA Simulasi',
      payment_reference: 'SIM-ORD-1',
      expires_at: '2026-11-14T00:00:00.000Z',
    }],
    guest_access_token_hash: 'must-not-be-returned',
  });

  assert.equal(result.event_title, 'Event Uji');
  assert.equal(result.total_amount, 10000);
  assert.equal(result.grand_total, 15000);
  assert.equal(result.items[0].ticket_type_name, 'Umum');
  assert.equal(result.payment.status, 'pending');
  assert.equal(result.payment.virtual_account_number, '8812345678901234');
  assert.equal(Object.hasOwn(result, 'guest_access_token_hash'), false);
});
