#!/usr/bin/env node
/*
 * Perbaiki catatan delivery lama yang salah berstatus SENT.
 *
 * Sebelum perbaikan, transport uji `SMTP_HOST=json` mencatat `SENT` walau
 * email hanya "dirender lokal" dan tidak pernah keluar dari server. Buktinya
 * tersimpan pada `last_error` ("json transport ... TIDAK dikirim ...").
 *
 * Skrip ini TIDAK menghapus data: hanya menurunkan status menjadi PENDING,
 * mengosongkan sent_at, dan menandai alasan yang jujur. Default dry-run.
 *
 *   node scripts/repair-email-delivery-status.js            (lihat dampak)
 *   node scripts/repair-email-delivery-status.js --apply    (terapkan)
 */
const fs = require('node:fs');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const APPLY = process.argv.includes('--apply');
const BACKUP_DIR = path.join(__dirname, '..', 'backups');

(async () => {
  const { query, pool } = require('../src/config/db');
  const rows = await query(
    `SELECT id, ticket_id, recipient, status::text AS status, attempt_count,
            last_error, sent_at, created_at
       FROM ticket_email_deliveries
      WHERE status = 'SENT'
        AND (last_error ILIKE '%json transport%' OR last_error ILIKE '%TIDAK dikirim%')
      ORDER BY created_at ASC`,
  );

  console.log(`Catatan SENT yang tidak pernah benar-benar terkirim: ${rows.length}`);
  if (rows.length === 0) {
    await pool.end();
    return;
  }

  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(BACKUP_DIR, `email-delivery-sent-repair-${stamp}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(rows, null, 2), 'utf8');
  console.log(`Backup baris terdampak: ${path.relative(process.cwd(), backupPath)}`);

  if (!APPLY) {
    console.log('Dry-run: tidak ada data diubah. Jalankan dengan --apply untuk menerapkan.');
    await pool.end();
    return;
  }

  const ids = rows.map((row) => row.id);
  const updated = await query(
    `UPDATE ticket_email_deliveries
        SET status = 'PENDING',
            sent_at = NULL,
            next_attempt_at = NOW(),
            last_error = 'Status SENT lama dibatalkan: transport uji json tidak '
                       || 'pernah mengirim email. Silakan kirim ulang setelah SMTP nyata dikonfigurasi.'
      WHERE id = ANY($1::uuid[])
      RETURNING id`,
    [ids],
  );
  console.log(`Diperbarui menjadi PENDING: ${updated.length} catatan.`);
  await pool.end();
})().catch((error) => {
  console.error('Perbaikan status delivery gagal:', error.message);
  process.exitCode = 1;
});
