/**
 * Backup JSON seluruh tabel public sebelum operasi destruktif.
 *
 * Pengganti `pg_dump` yang tidak tersedia di environment ini. Hasil ditulis ke
 * `backend/backups/backup-<timestamp>.json` (di-ignore Git) dan dapat dipulihkan
 * dengan `scripts/restore-json-backup.js`.
 *
 * Pemakaian: node scripts/backup-db-json.js
 */
require('dotenv').config();
const fs = require('node:fs');
const path = require('node:path');
const { pool } = require('../src/config/db');

(async () => {
  const tables = await pool.query(
    "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name",
  );

  const dump = { createdAt: new Date().toISOString(), tables: {} };
  let totalRows = 0;

  for (const { table_name: table } of tables.rows) {
    // `_prisma_migrations` tidak perlu diikutkan; struktur dikelola Prisma.
    if (table === '_prisma_migrations') continue;
    const rows = await pool.query(`select * from "${table}"`);
    dump.tables[table] = rows.rows;
    totalRows += rows.rowCount;
    process.stdout.write(`  ${table}: ${rows.rowCount}\n`);
  }

  const dir = path.join(__dirname, '..', 'backups');
  fs.mkdirSync(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(dir, `backup-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(dump));

  console.log(`\nTabel: ${Object.keys(dump.tables).length}, baris: ${totalRows}`);
  console.log(`Backup: ${file}`);
  console.log(`Ukuran: ${(fs.statSync(file).size / 1024).toFixed(1)} KB`);
  await pool.end();
})().catch(async (e) => {
  console.error('BACKUP GAGAL:', e.message);
  try { await pool.end(); } catch {}
  process.exit(1);
});
