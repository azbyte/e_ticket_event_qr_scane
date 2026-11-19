const { createHmac, createHash, timingSafeEqual } = require('node:crypto');
const asyncHandler = require('express-async-handler');
const config = require('../config/env');
const { query, getOne } = require('../config/db');

/**
 * Token QR tiket.
 *
 * Token asli TIDAK disimpan di database. Yang disimpan hanya
 * `tickets.token_hash` = SHA-256(token). Token bersifat deterministik dari
 * (ticket id + waktu terbit) dengan kunci rahasia server, sehingga:
 *  - pemilik tiket dapat melihat QR-nya kapan saja tanpa menyimpan token asli,
 *  - pencatatan di database tidak membocorkan token yang dapat dipakai check-in,
 *  - verifikasi dilakukan dengan membandingkan hash (constant-time compare).
 *
 * Konsekuensi keamanan: siapa pun yang memiliki `TICKET_TOKEN_SECRET` dapat
 * memproduksi token valid, sehingga secret ini harus diperlakukan sama seperti
 * `JWT_SECRET` (jangan di-commit, rotasi bila bocor).
 */
const tokenSecret = () => config.ticketTokenSecret;

const hashToken = (rawToken) =>
  createHash('sha256').update(String(rawToken), 'utf8').digest('hex');

const issuedReference = (ticket) => {
  const issued = ticket.issued_at || ticket.purchased_at;
  const value = issued instanceof Date ? issued.toISOString() : String(issued);
  return value;
};

/** Token asli (deterministik) untuk sebuah baris tiket. */
const rawTokenFor = (ticket) => {
  if (!ticket || !ticket.id) {
    throw new TypeError('Ticket id is required to build a QR token');
  }
  const payload = `ticket:${ticket.id}:${issuedReference(ticket)}`;
  return createHmac('sha256', tokenSecret()).update(payload, 'utf8').digest('base64url');
};

const safeEqual = (left, right) => {
  const a = Buffer.from(String(left), 'utf8');
  const b = Buffer.from(String(right), 'utf8');
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
};

/**
 * Pastikan `token_hash` tersimpan untuk satu tiket. Idempotent; hanya menulis
 * bila kolom masih kosong atau tidak sesuai (mis. tiket lama).
 * @returns {Promise<string>} hash yang tersimpan
 */
const ensureTokenHash = async (ticket) => {
  const expected = hashToken(rawTokenFor(ticket));
  if (ticket.token_hash && safeEqual(ticket.token_hash, expected)) return ticket.token_hash;
  await query('UPDATE tickets SET token_hash = $1 WHERE id = $2', [expected, ticket.id]);
  ticket.token_hash = expected;
  return expected;
};

/** Backfill hash untuk seluruh tiket pada satu order (setelah pembayaran). */
const ensureOrderTokenHashes = async (orderId) => {
  const rows = await query(
    `SELECT t.* FROM tickets t
     JOIN attendees a ON a.id = t.attendee_id
     JOIN order_items oi ON oi.id = a.order_item_id
     WHERE oi.order_id = $1`,
    [orderId]
  );
  for (const row of rows) {
    await ensureTokenHash(row);
  }
  return rows.length;
};

/** Cari tiket berdasarkan token asli yang dipindai. */
const findTicketByRawToken = async (rawToken) => {
  if (typeof rawToken !== 'string' || rawToken.trim().length < 16) return null;
  const hash = hashToken(rawToken.trim());
  const row = await getOne(
    `SELECT t.*,
            a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
            a.order_item_id AS attendee_order_item_id,
            tt.name AS ticket_type_name
     FROM tickets t
     LEFT JOIN attendees a ON a.id = t.attendee_id
     LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
     WHERE t.token_hash = $1`,
    [hash]
  );
  return row;
};

/**
 * Bentuk tiket untuk response API.
 * `token` hanya disertakan ketika pemanggil berhak melihat QR (pemilik/admin).
 */
const presentTicket = async (ticket, { includeToken = false } = {}) => {
  const { token_hash: _hash, ...rest } = ticket;
  if (!includeToken) return rest;
  await ensureTokenHash(ticket);
  return { ...rest, token: rawTokenFor(ticket) };
};

module.exports = {
  hashToken,
  rawTokenFor,
  ensureTokenHash,
  ensureOrderTokenHashes,
  findTicketByRawToken,
  presentTicket,
  safeEqual,
};
