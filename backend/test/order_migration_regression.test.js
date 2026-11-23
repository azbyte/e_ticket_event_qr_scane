const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migrationsPath = path.resolve(__dirname, '..', 'prisma', 'migrations');
const functionFromMigration = (migrationName) => {
  const sql = fs.readFileSync(path.join(migrationsPath, migrationName, 'migration.sql'), 'utf8');
  const match = sql.match(/CREATE OR REPLACE FUNCTION public\.create_event_order\([\s\S]*?\n\$\$;/);
  assert.ok(match, `create_event_order missing from ${migrationName}`);
  return match[0];
};

test('migration 004 casts order payment status and retains migration 003 stable guest replay', () => {
  const migration003 = functionFromMigration('20261118000300_stable_guest_order_idempotency');
  const migration004 = functionFromMigration('20261118000400_restore_payment_status_enum_cast');
  const oldCase = "CASE WHEN grand_total = 0 THEN 'PAID' ELSE 'PENDING' END,";
  const paymentStatusCase = "(CASE WHEN grand_total = 0 THEN 'PAID' ELSE 'PENDING' END)::public.\"PaymentStatus\",";

  assert.ok(migration003.includes(oldCase));
  assert.ok(migration004.includes(paymentStatusCase));
  assert.equal(
    migration004.replace(paymentStatusCase, oldCase).replace(/\s+/g, ' ').trim(),
    migration003.replace(/\s+/g, ' ').trim(),
    'migration 004 must differ from migration 003 only by the PaymentStatus cast',
  );

  for (const migration of [migration003, migration004]) {
    assert.match(migration, /WHERE idempotency_key = p_idempotency_key\s+AND idempotency_fingerprint = p_idempotency_fingerprint/);
    const replay = migration.match(/IF FOUND THEN([\s\S]*?)\r?\n  END IF;\r?\n  IF EXISTS/);
    assert.ok(replay, 'idempotency replay block missing');
    assert.match(replay[1], /RETURN order_id;/);
    assert.doesNotMatch(replay[1], /UPDATE\s+public\.event_orders/i);
    assert.doesNotMatch(replay[1], /SET\s+guest_access_token_hash\s*=/i);
  }

  assert.match(migration004, /IF EXISTS \([\s\S]*?WHERE idempotency_key = p_idempotency_key[\s\S]*?RAISE EXCEPTION 'Idempotency key was reused with different order data';/);
});
