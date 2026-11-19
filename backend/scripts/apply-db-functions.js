/**
 * Rekonsiliasi function PostgreSQL dari migration Prisma.
 *
 * Tabel pada database target sudah sesuai schema, tetapi function PL/pgSQL
 * (moderate_event, create_event_order, simulate_event_payment, dan
 * expire_event_order_reservations) belum ada. Skrip ini mengekstrak hanya blok
 * `CREATE OR REPLACE FUNCTION ... $$;` dari migration 002 dan 004 lalu
 * menerapkannya secara idempoten. Tidak ada DROP, DELETE, atau perubahan tabel.
 *
 * Pemakaian:
 *   node scripts/apply-db-functions.js           # dry run, daftar function
 *   node scripts/apply-db-functions.js --apply   # terapkan ke DATABASE_URL
 */
const path = require('node:path');
const fs = require('node:fs');
const { Pool } = require('pg');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const migrationFiles = [
  '20261113000200_atomic_event_moderation/migration.sql',
  '20261113000400_event_orders_payments/migration.sql',
];

const extractFunctions = () => {
  const blocks = [];
  for (const relative of migrationFiles) {
    const file = path.resolve(__dirname, '..', 'prisma', 'migrations', relative);
    const sql = fs.readFileSync(file, 'utf8');
    const pattern = /CREATE OR REPLACE FUNCTION[\s\S]*?\n\$\$;/g;
    const matches = sql.match(pattern) || [];
    for (const block of matches) {
      const nameMatch = block.match(/CREATE OR REPLACE FUNCTION\s+([\w.]+)/);
      blocks.push({ file: relative, name: nameMatch ? nameMatch[1] : '(unknown)', sql: block });
    }
  }
  return blocks;
};

const main = async () => {
  const apply = process.argv.includes('--apply');
  const blocks = extractFunctions();
  console.log(`Function ditemukan di migration: ${blocks.length}`);
  for (const block of blocks) console.log(`- ${block.name} (${block.file})`);

  if (!apply) {
    console.log('\nDry run. Jalankan dengan --apply untuk menerapkan.');
    return;
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL tidak tersedia');
  }

  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    connectionTimeoutMillis: 15000,
  });
  const client = await pool.connect();
  try {
    for (const block of blocks) {
      await client.query(block.sql);
      console.log(`APPLIED: ${block.name}`);
    }
    const result = await client.query(
      `SELECT p.proname
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' ORDER BY p.proname`
    );
    console.log(`\nFunction public sekarang: ${result.rows.length}`);
    result.rows.forEach((row) => console.log(`- ${row.proname}`));
  } finally {
    client.release();
    await pool.end();
  }
};

main().catch((error) => {
  console.error('Gagal menerapkan function:', error.message);
  process.exitCode = 1;
});
