const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(
  path.resolve(__dirname, '..', 'prisma', 'migrations', '20261118000300_stable_guest_order_idempotency', 'migration.sql'),
  'utf8'
).replace(/\r\n/g, '\n');
const functionSql = source.match(/CREATE OR REPLACE FUNCTION public\.create_event_order[\s\S]*?\n\$\$;/);
if (!functionSql) throw new Error('create_event_order not found');
const oldCase = "CASE WHEN grand_total = 0 THEN 'PAID' ELSE 'PENDING' END,";
const newCase = "(CASE WHEN grand_total = 0 THEN 'PAID' ELSE 'PENDING' END)::public.\"PaymentStatus\",";
if (!functionSql[0].includes(oldCase)) throw new Error('expected enum CASE not found');
if (functionSql[0].includes('SET guest_access_token_hash = p_guest_access_token_hash')) {
  throw new Error('source migration unexpectedly rotates guest access tokens on replay');
}
const fixedFunction = functionSql[0].replace(oldCase, newCase);
if (fixedFunction.includes('SET guest_access_token_hash = p_guest_access_token_hash')) {
  throw new Error('generated function must preserve the guest replay fix');
}
const target = path.resolve(__dirname, '..', 'prisma', 'migrations', '20261118000400_restore_payment_status_enum_cast');
fs.mkdirSync(target, { recursive: true });
fs.writeFileSync(
  path.join(target, 'migration.sql'),
  `-- Repair the PaymentStatus enum cast while preserving stable guest replay.\n${fixedFunction}\n`,
  'utf8'
);
console.log('Created migration 20261118000400_restore_payment_status_enum_cast');
