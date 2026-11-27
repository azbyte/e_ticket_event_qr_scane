#!/usr/bin/env node
/*
 * Rapikan ID publik tiket lama menjadi format `ETK-XXXXXX`.
 *
 * Latar belakang: tiket yang diterbitkan sebelum perubahan format memiliki
 * `ticket_code` sepanjang 36 karakter (`TKT-<uuid>`). Skrip ini menggantinya
 * dengan ID publik ringkas tanpa menyentuh primary key (`tickets.id`), relasi
 * tabel, maupun token QR (QR memakai `token_hash`, bukan `ticket_code`).
 *
 * Sifat:
 *  - idempotent: tiket yang sudah berformat `ETK-…` dilewati,
 *  - aman dijalankan saat server hidup (UPDATE bersyarat + unique index),
 *  - tidak menghapus data apa pun.
 *
 * Jalankan dari `backend/`:
 *   npm run tickets:backfill-codes
 *   npm run tickets:backfill-codes -- --limit=500
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const parseLimit = () => {
  const arg = process.argv.find((item) => item.startsWith('--limit='));
  if (!arg) return null;
  const value = Number(arg.split('=')[1]);
  return Number.isInteger(value) && value > 0 ? Math.min(value, 5000) : null;
};

(async () => {
  const { backfillPublicTicketCodes } = require('../src/services/ticketCodeService');
  const { pool } = require('../src/config/db');

  try {
    const limit = parseLimit();
    const result = await backfillPublicTicketCodes({ limit });
    console.log(
      `Selesai: ${result.processed} tiket diperiksa, ${result.changed} dirapikan`
      + `${limit ? ` (batas ${limit} per jalan)` : ''}.`,
    );
  } catch (error) {
    console.error('Gagal merapikan ID tiket:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
