/* Generator migration: perbaiki replay idempotency create_event_order.
 * Dibuat sekali untuk memastikan definisi function identik dengan migration 004
 * kecuali blok replay yang diubah. Migration hasilnya di-commit; skrip ini
 * disimpan sebagai jejak asal-usul perubahan.
 */
const fs = require('node:fs');
const path = require('node:path');

const source = path.resolve(
  __dirname, '..', 'prisma', 'migrations', '20261113000400_event_orders_payments', 'migration.sql'
);
const sql = fs.readFileSync(source, 'utf8').replace(/\r\n/g, '\n');
const match = sql.match(/CREATE OR REPLACE FUNCTION public\.create_event_order[\s\S]*?\n\$\$;/);
if (!match) throw new Error('create_event_order tidak ditemukan');

const original = match[0];
const oldReplay = `  IF FOUND THEN
    IF p_purchaser_id IS NULL THEN
      UPDATE public.event_orders
      SET guest_access_token_hash = p_guest_access_token_hash
      WHERE id = order_id AND purchaser_id IS NULL;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Idempotency key belongs to another order';
      END IF;
    ELSIF NOT EXISTS (
      SELECT 1 FROM public.event_orders
      WHERE id = order_id AND purchaser_id = p_purchaser_id
    ) THEN
      RAISE EXCEPTION 'Idempotency key belongs to another order';
    END IF;
    RETURN order_id;
  END IF;`;

const newReplay = `  IF FOUND THEN
    -- Replay idempotency: JANGAN merotasi guest_access_token_hash. Token yang
    -- sudah diberikan pada response pertama harus tetap valid.
    IF p_purchaser_id IS NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.event_orders
        WHERE id = order_id AND purchaser_id IS NULL
      ) THEN
        RAISE EXCEPTION 'Idempotency key belongs to another order';
      END IF;
    ELSIF NOT EXISTS (
      SELECT 1 FROM public.event_orders
      WHERE id = order_id AND purchaser_id = p_purchaser_id
    ) THEN
      RAISE EXCEPTION 'Idempotency key belongs to another order';
    END IF;
    RETURN order_id;
  END IF;`;

if (!original.includes(oldReplay)) throw new Error('Blok replay tidak cocok');
const fixed = original.replace(oldReplay, newReplay);

const targetDir = path.resolve(
  __dirname, '..', 'prisma', 'migrations', '20261118000300_stable_guest_order_idempotency'
);
fs.mkdirSync(targetDir, { recursive: true });
const header = [
  '-- =============================================================================',
  '-- Guest order idempotency: replay tidak boleh merotasi access token.',
  '--',
  '-- Sebelumnya replay dengan Idempotency-Key yang sama menimpa',
  '-- guest_access_token_hash, sehingga token dari response pertama menjadi tidak',
  '-- valid dan klien kehilangan akses ke order yang sama. Function diganti agar',
  '-- replay hanya memvalidasi kepemilikan lalu mengembalikan order id yang sama.',
  '--',
  '-- ROLLBACK: jalankan ulang CREATE OR REPLACE FUNCTION dari migration',
  '-- 20261113000400_event_orders_payments.',
  '-- =============================================================================',
  '',
].join('\n');
fs.writeFileSync(path.join(targetDir, 'migration.sql'), `${header}${fixed}\n`, 'utf8');
console.log('Migration ditulis:', path.join(targetDir, 'migration.sql'));
