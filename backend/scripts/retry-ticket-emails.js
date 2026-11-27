#!/usr/bin/env node
/*
 * Coba ulang pengiriman e-ticket yang belum terkirim (PENDING/FAILED).
 *
 * Tidak membuat tiket baru, tidak mengirim yang sudah SENT, dan menghormati
 * `next_attempt_at` serta batas 5 percobaan otomatis. Jalankan dari `backend/`:
 *   npm run retry:emails
 *   npm run retry:emails -- --limit=50
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const parseLimit = () => {
  const arg = process.argv.find((item) => item.startsWith('--limit='));
  const value = arg ? Number(arg.split('=')[1]) : 20;
  return Number.isInteger(value) && value > 0 ? Math.min(value, 200) : 20;
};

(async () => {
  const emailService = require('../src/services/emailService');
  const emailQueue = require('../src/services/emailQueue');
  const { query, pool } = require('../src/config/db');

  const status = emailService.smtpStatus();
  console.log(`Mode transport: ${status.mode}`);
  if (status.reason) console.log(`Keterangan: ${status.reason}`);
  if (status.mode !== 'smtp' && status.mode !== 'brevo' && status.mode !== 'resend') {
    console.log(
      'Tidak ada pengiriman yang dijalankan: layanan email belum siap. '
      + 'Lengkapi SMTP atau RESEND_API_KEY pada backend/.env lalu ulangi.',
    );
    await pool.end();
    return;
  }

  const limit = parseLimit();
  const queued = await emailQueue.retryPending(limit);
  await emailQueue.drain();
  console.log(`Dijadwalkan ulang: ${queued.length} tiket (batas ${limit}).`);

  const rows = await query(
    `SELECT status::text AS status, count(*)::int AS total
       FROM ticket_email_deliveries
      GROUP BY status ORDER BY status`,
  );
  console.log('Status delivery saat ini:', rows.map((r) => `${r.status}=${r.total}`).join(', '));
  await pool.end();
})().catch((error) => {
  console.error('Gagal menjalankan retry email:', error.message);
  process.exitCode = 1;
});
