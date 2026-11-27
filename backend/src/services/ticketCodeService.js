/**
 * ID publik tiket.
 *
 * Latar belakang: `tickets.ticket_code` dibuat oleh fungsi database
 * (`create_event_order` / `simulate_event_payment`) sebagai
 * `TKT-<uuid tanpa strip>` = 36 karakter. ID sepanjang itu tidak layak dicetak
 * pada e-tiket maupun dibacakan petugas registrasi.
 *
 * Solusi yang dipakai (tanpa mengubah schema/primary key):
 *  - `tickets.id` (UUID) TETAP menjadi identitas internal & relasi database,
 *  - `tickets.ticket_code` (kolom unik yang sudah ada) menyimpan ID publik
 *    ringkas `ETK-XXXXXX`,
 *  - tiket lama dirapikan sekali (idempotent) saat tiket diterbitkan/dibuka,
 *    atau sekaligus lewat `npm run tickets:backfill-codes`.
 *
 * Format: prefix `ETK-` + 6 karakter alfabet Crockford Base32
 * (`0-9 A-Z` tanpa I, L, O, U) sehingga karakter yang mudah tertukar
 * (I/1, O/0, L/1, U/V) tidak dipakai. Ruang ID = 32^6 ≈ 1,07 miliar.
 *
 * Keunikan dijamin unique index `tickets_ticket_code_key`: kandidat yang bentrok
 * diulang otomatis, dan bila seluruh percobaan gagal ID lama dipertahankan
 * supaya tiket TIDAK pernah menjadi tidak valid.
 */
const { randomInt } = require('node:crypto');
const { query, getOne } = require('../config/db');
const logger = require('../utils/logger');

const PUBLIC_TICKET_ID_PREFIX = 'ETK-';
const PUBLIC_TICKET_ID_LENGTH = 6;
/** Alfabet Crockford Base32: tanpa I, L, O, U. */
const PUBLIC_TICKET_ID_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const PUBLIC_TICKET_ID_PATTERN = /^ETK-[0-9A-HJKMNP-TV-Z]{6}$/;
/** Kode lama hasil RPC database: `TKT-` + 32 hex. */
const LEGACY_TICKET_CODE_PATTERN = /^TKT-[0-9a-fA-F]{32}$/;

const MAX_ASSIGN_ATTEMPTS = 5;

/** True bila nilai sudah memakai format ID publik yang baru. */
const isPublicTicketId = (value) => PUBLIC_TICKET_ID_PATTERN.test(String(value || '').trim());

/** True bila nilai adalah kode lama buatan database (36 karakter). */
const isLegacyTicketCode = (value) => LEGACY_TICKET_CODE_PATTERN.test(String(value || '').trim());

/** Buat satu kandidat ID publik (belum dicek keunikan). */
const generatePublicTicketId = () => {
  let suffix = '';
  for (let index = 0; index < PUBLIC_TICKET_ID_LENGTH; index += 1) {
    suffix += PUBLIC_TICKET_ID_ALPHABET[randomInt(0, PUBLIC_TICKET_ID_ALPHABET.length)];
  }
  return `${PUBLIC_TICKET_ID_PREFIX}${suffix}`;
};

/**
 * Pastikan satu tiket memiliki ID publik ringkas.
 *
 * Idempotent dan aman untuk tiket lama: bila `ticket_code` sudah berformat
 * `ETK-…` nilai itu dikembalikan apa adanya (tidak pernah berubah, sehingga
 * email/PDF yang sudah terkirim tetap cocok).
 *
 * @param {string} ticketId
 * @returns {Promise<string|null>} ID publik yang berlaku (null bila tiket tidak ada)
 */
const ensurePublicTicketCode = async (ticketId) => {
  if (!ticketId) return null;
  const current = await getOne(
    'SELECT id, ticket_code FROM tickets WHERE id = $1',
    [ticketId],
  );
  if (!current) return null;
  if (isPublicTicketId(current.ticket_code)) return current.ticket_code;

  for (let attempt = 0; attempt < MAX_ASSIGN_ATTEMPTS; attempt += 1) {
    const candidate = generatePublicTicketId();
    try {
      // Guard `ticket_code` lama: bila proses lain lebih dulu mengganti,
      // UPDATE tidak mengenai baris apa pun dan nilai terbaru dibaca ulang.
      const updated = await getOne(
        `UPDATE tickets SET ticket_code = $1
          WHERE id = $2 AND ticket_code IS NOT DISTINCT FROM $3
          RETURNING ticket_code`,
        [candidate, ticketId, current.ticket_code],
      );
      if (updated?.ticket_code) {
        logger.info('ticket_public_code_assigned', {
          ticketId,
          previous: current.ticket_code,
          ticketCode: updated.ticket_code,
        });
        return updated.ticket_code;
      }
      const latest = await getOne('SELECT ticket_code FROM tickets WHERE id = $1', [ticketId]);
      if (!latest) return null;
      if (isPublicTicketId(latest.ticket_code)) return latest.ticket_code;
    } catch (error) {
      // 23505 = unique_violation: kandidat sudah dipakai tiket lain, coba lagi.
      if (error?.code !== '23505') throw error;
    }
  }

  // Tidak berhasil mendapat ID baru: pertahankan kode lama (tiket tetap valid).
  logger.warn('ticket_public_code_unassigned', {
    ticketId,
    ticketCode: current.ticket_code,
  });
  return current.ticket_code;
};

/**
 * Rapikan ID publik untuk seluruh tiket pada satu order (dipanggil setelah
 * tiket terbit: order gratis PAID maupun setelah pembayaran berhasil).
 *
 * @returns {Promise<number>} jumlah tiket yang diproses
 */
const ensureOrderPublicTicketCodes = async (orderId) => {
  if (!orderId) return 0;
  const rows = await query(
    `SELECT t.id FROM tickets t
       JOIN attendees a ON a.id = t.attendee_id
       JOIN order_items oi ON oi.id = a.order_item_id
      WHERE oi.order_id = $1
      ORDER BY t.id`,
    [orderId],
  );
  for (const row of rows) {
    try {
      await ensurePublicTicketCode(row.id);
    } catch (error) {
      // Kegagalan penyeragaman ID tidak boleh menggagalkan penerbitan tiket.
      logger.warn('ticket_public_code_failed', { ticketId: row.id, error: error.message });
    }
  }
  return rows.length;
};

/**
 * Rapikan seluruh tiket lama (dipakai skrip backfill).
 * @returns {Promise<{processed: number, changed: number}>}
 */
const backfillPublicTicketCodes = async ({ limit = null } = {}) => {
  const rows = await query(
    `SELECT id, ticket_code FROM tickets
      WHERE ticket_code IS NULL OR ticket_code !~ '^ETK-[0-9A-HJKMNP-TV-Z]{6}$'
      ORDER BY purchased_at ASC NULLS LAST
      ${limit ? 'LIMIT $1' : ''}`,
    limit ? [limit] : [],
  );
  let changed = 0;
  for (const row of rows) {
    const before = row.ticket_code;
    const after = await ensurePublicTicketCode(row.id);
    if (after && after !== before) changed += 1;
  }
  return { processed: rows.length, changed };
};

module.exports = {
  PUBLIC_TICKET_ID_PREFIX,
  PUBLIC_TICKET_ID_LENGTH,
  PUBLIC_TICKET_ID_ALPHABET,
  PUBLIC_TICKET_ID_PATTERN,
  LEGACY_TICKET_CODE_PATTERN,
  isPublicTicketId,
  isLegacyTicketCode,
  generatePublicTicketId,
  ensurePublicTicketCode,
  ensureOrderPublicTicketCodes,
  backfillPublicTicketCodes,
};
