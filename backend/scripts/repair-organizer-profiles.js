/* eslint-disable no-console */
// Repair idempotent: buat organizer_profiles yang hilang untuk akun organizer
// yang sudah ada. Tidak menghapus/mengubah akun atau password apa pun.
// Jalankan: node scripts/repair-organizer-profiles.js [--dry-run]
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const dryRun = process.argv.includes('--dry-run');

async function main() {
  const { rows } = await pool.query(
    `select p.id, p.email, p.name
       from profiles p
       left join organizer_profiles op on op.user_id = p.id
      where p.role = 'organizer' and op.id is null
      order by p.created_at`
  );
  console.log(`Akun organizer tanpa profil: ${rows.length}${dryRun ? ' (dry-run)' : ''}`);
  rows.forEach((r) => console.log(`  - ${r.email} (${r.id})`));

  if (rows.length === 0 || dryRun) return;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const row of rows) {
      await client.query(
        `INSERT INTO organizer_profiles (id, user_id, contact_name, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, NOW(), NOW())
         ON CONFLICT (user_id) DO NOTHING`,
        [row.id, row.name]
      );
    }
    await client.query('COMMIT');
    console.log(`Selesai: ${rows.length} profil organizer dibuat.`);
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }
}

main()
  .catch((e) => { console.error('REPAIR ERROR:', e.message); process.exitCode = 1; })
  .finally(() => pool.end());
