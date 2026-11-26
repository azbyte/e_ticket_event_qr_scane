/**
 * Uji end-to-end NYATA terhadap API + database sungguhan (T3-D1-09).
 *
 * Menjalankan alur PRD dari awal sampai akhir:
 *   Organizer register/login -> event -> kategori -> publish ->
 *   Guest daftar -> order -> bayar -> tiket/QR ->
 *   Staff undang -> terima -> scan -> check-in -> scan ulang ->
 *   Organizer peserta -> export CSV -> order per event -> revenue ->
 *   Admin akun/suspend/audit/settings/overview/paket/langganan/moderasi/laporan.
 *
 * Prasyarat: backend berjalan (`npm start`) dan `backend/.env` menunjuk DB uji.
 * Skrip ini MENULIS data uji ke database; jalankan pada DB pengembangan/uji.
 * Exit code != 0 bila ada langkah gagal.
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const BASE = process.env.TEST_API_URL || 'http://127.0.0.1:5000';
const { pool } = require('../src/config/db');

const results = [];
let failures = 0;

function record(id, name, ok, detail) {
  results.push({ id, name, ok, detail });
  if (!ok) failures += 1;
  console.log(`[${ok ? 'PASS' : 'FAIL'}] ${id} ${name}${detail ? ` :: ${detail}` : ''}`);
}

async function api(method, path, { token, body, headers = {}, orderToken } = {}) {
  const h = { 'Content-Type': 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (orderToken) h['X-Order-Access-Token'] = orderToken;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: h,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  return { status: res.status, body: json, headers: res.headers };
}

const dataOf = (r) => {
  const b = r.body ?? {};
  if (b.data !== undefined) return b.data;
  if (b.event !== undefined) return b.event;
  if (b.ticketType !== undefined) return b.ticketType;
  if (b.invitation !== undefined) return b.invitation;
  if (b.order !== undefined) return b.order;
  if (b.tickets !== undefined) return b.tickets;
  return b;
};
const stamp = Date.now();
const orgEmail = `org.e2e.${stamp}@example.test`;
const staffEmail = `staff.e2e.${stamp}@example.test`;
const guestEmail = `guest.e2e.${stamp}@example.test`;

module.exports = { record, api, dataOf, results, getFailures: () => failures, pool, BASE, stamp };
