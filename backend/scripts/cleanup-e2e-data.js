#!/usr/bin/env node
/*
 * Bersihkan data sintetis yang dibuat skrip E2E (`npm run test:registration-flow`).
 *
 * Skrip E2E sebelumnya meninggalkan event, order, tiket, dan akun Organizer
 * `*.e2e.*@example.test` di database. Pembersihan ini HANYA menyentuh pola
 * yang dibuat skrip tersebut (judul `Event E2E %` / `Event Berbayar E2E %`,
 * email `org.e2e.%@example.test`, peserta `guest.e2e.%`/`paid.e2e.%`) sehingga
 * data nyata tidak tersentuh.
 *
 *   node scripts/cleanup-e2e-data.js           (hapus)
 *   node scripts/cleanup-e2e-data.js --dry-run (hitung saja)
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const EVENT_PATTERN = 'Event E2E %';
const PAID_EVENT_PATTERN = 'Event Berbayar E2E %';
const ORGANIZER_PATTERN = 'org.e2e.%@example.test';
const GUEST_PATTERN = 'guest.e2e.%@example.test';
const PAID_GUEST_PATTERN = 'paid.e2e.%@example.test';

const EVENT_FILTER = `SELECT id FROM events WHERE title LIKE $1 OR title LIKE $2`;
const EVENT_IDS = [EVENT_PATTERN, PAID_EVENT_PATTERN];
const ORDER_FILTER = `SELECT id FROM event_orders WHERE event_id IN (${EVENT_FILTER})`;
const ITEM_FILTER = `SELECT id FROM order_items WHERE order_id IN (${ORDER_FILTER})`;
const TICKET_FILTER = `SELECT id FROM tickets WHERE event_id IN (${EVENT_FILTER})`;

/**
 * Jalankan pembersihan memakai `query` dari `src/config/db`.
 * @returns {Promise<Array<{statement: string, removed: number}>>}
 */
const cleanupE2EData = async (query, { dryRun = false } = {}) => {
  /** @type {Array<{label: string, sql: string, params: string[]}>} */
  const steps = [
    // Tiket & turunannya
    { label: 'ticket_email_deliveries', sql: `DELETE FROM ticket_email_deliveries WHERE ticket_id IN (${TICKET_FILTER})`, params: EVENT_IDS },
    { label: 'check_ins', sql: `DELETE FROM check_ins WHERE ticket_id IN (${TICKET_FILTER})`, params: EVENT_IDS },
    { label: 'scan_logs', sql: `DELETE FROM scan_logs WHERE ticket_id IN (${TICKET_FILTER})`, params: EVENT_IDS },
    { label: 'tickets', sql: `DELETE FROM tickets WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    // Peserta & order
    { label: 'attendees', sql: `DELETE FROM attendees WHERE order_item_id IN (${ITEM_FILTER})`, params: EVENT_IDS },
    {
      label: 'platform_transactions',
      sql: `DELETE FROM platform_transactions WHERE order_payment_id IN (
         SELECT id FROM order_payments WHERE order_id IN (${ORDER_FILTER}))`,
      params: EVENT_IDS,
    },
    { label: 'order_payments', sql: `DELETE FROM order_payments WHERE order_id IN (${ORDER_FILTER})`, params: EVENT_IDS },
    { label: 'order_items', sql: `DELETE FROM order_items WHERE order_id IN (${ORDER_FILTER})`, params: EVENT_IDS },
    // Log/moderasi/undangan event
    { label: 'event_activity_logs', sql: `DELETE FROM event_activity_logs WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    { label: 'event_moderations', sql: `DELETE FROM event_moderations WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    { label: 'event_invitations', sql: `DELETE FROM event_invitations WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    { label: 'event_members', sql: `DELETE FROM event_members WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    { label: 'event_orders', sql: `DELETE FROM event_orders WHERE event_id IN (${EVENT_FILTER})`, params: EVENT_IDS },
    { label: 'events', sql: `DELETE FROM events WHERE title LIKE $1 OR title LIKE $2`, params: EVENT_IDS },
    // Akun Organizer sintetis (notifikasi & profil organizer ikut ter-cascade)
    {
      label: 'notifications',
      sql: `DELETE FROM notifications WHERE user_id IN (
         SELECT id FROM profiles WHERE lower(email) LIKE $1)`,
      params: [ORGANIZER_PATTERN],
    },
    {
      label: 'organizer_profiles',
      sql: `DELETE FROM organizer_profiles WHERE user_id IN (
         SELECT id FROM profiles WHERE lower(email) LIKE $1)`,
      params: [ORGANIZER_PATTERN],
    },
    { label: 'profiles', sql: `DELETE FROM profiles WHERE lower(email) LIKE $1`, params: [ORGANIZER_PATTERN] },
  ];

  const results = [];
  for (const step of steps) {
    if (dryRun) {
      results.push({ statement: step.label, removed: 0 });
      continue;
    }
    const rows = await query(`${step.sql} RETURNING 1`, step.params);
    results.push({ statement: step.label, removed: rows.length });
  }
  return results;
};

module.exports = {
  cleanupE2EData,
  EVENT_PATTERN,
  PAID_EVENT_PATTERN,
  ORGANIZER_PATTERN,
  GUEST_PATTERN,
  PAID_GUEST_PATTERN,
};

if (require.main === module) {
  const dryRun = process.argv.includes('--dry-run');
  (async () => {
    const { query, pool } = require('../src/config/db');
    const results = await cleanupE2EData(query, { dryRun });
    for (const row of results) {
      if (row.removed > 0) console.log(`dihapus ${row.removed} baris :: ${row.statement}`);
    }
    const total = results.reduce((sum, row) => sum + row.removed, 0);
    console.log(
      dryRun
        ? 'Dry-run: tidak ada data dihapus.'
        : `Selesai. Total baris dihapus: ${total}.`,
    );
    await pool.end();
  })().catch((error) => {
    console.error('Pembersihan data E2E gagal:', error.message);
    process.exitCode = 1;
  });
}
