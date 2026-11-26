/**
 * Pulihkan database dari backup JSON buatan `backup-db-json.js`.
 *
 * PERINGATAN: destruktif — mengosongkan tabel yang ada sebelum menulis ulang.
 * Pemakaian:
 *   node scripts/restore-json-backup.js backups/backup-<stamp>.json
 */
require('dotenv').config();
const fs = require('node:fs');
const path = require('node:path');
const { pool } = require('../src/config/db');

const fileArg = process.argv[2];
if (!fileArg) {
  console.error('Pemakaian: node scripts/restore-json-backup.js <file.json>');
  process.exit(1);
}
const file = path.resolve(fileArg);
if (!fs.existsSync(file)) {
  console.error('File tidak ditemukan:', file);
  process.exit(1);
}

const dump = JSON.parse(fs.readFileSync(file, 'utf8'));
const tables = Object.keys(dump.tables);

(async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `TRUNCATE TABLE ${tables.map((t) => `"${t}"`).join(', ')} RESTART IDENTITY CASCADE`,
    );

    let restored = 0;
    for (const table of tables) {
      const rows = dump.tables[table];
      if (!rows.length) continue;
      const columns = Object.keys(rows[0]);
      const colList = columns.map((c) => `"${c}"`).join(', ');
      for (const row of rows) {
        const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
        await client.query(
          `INSERT INTO "${table}" (${colList}) VALUES (${placeholders})`,
          columns.map((c) => row[c]),
        );
        restored += 1;
      }
    }

    // Sinkronkan sequence agar INSERT berikutnya tidak bentrok.
    for (const table of tables) {
      const seq = await client.query(
        `select pg_get_serial_sequence('"${table}"', 'id') as s`,
      );
      const sequence = seq.rows[0]?.s;
      if (sequence) {
        await client.query(
          `select setval('${sequence}', coalesce((select max(id) from "${table}"), 0) + 1, false)`,
        );
      }
    }

    await client.query('COMMIT');
    console.log(`Dipulihkan: ${restored} baris pada ${tables.length} tabel.`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('RESTORE GAGAL (di-rollback):', error.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
