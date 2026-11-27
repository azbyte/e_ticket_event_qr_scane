#!/usr/bin/env node
/*
 * Bukti bahwa pendaftaran/pembayaran TIDAK menunggu SMTP.
 *
 * Skrip menyalakan SMTP sink lokal yang sengaja LAMBAT (setiap balasan
 * ditunda), lalu:
 *   1. menjadwalkan pengiriman lewat emailQueue (jalur yang dipakai controller),
 *   2. mengukur waktu penjadwalan (harus jauh lebih cepat dari SMTP),
 *   3. menunggu antrean selesai dan memastikan email benar-benar terkirim,
 *   4. memastikan penjadwalan ganda tidak menghasilkan dua email.
 *
 * Jalankan dari `backend/`: node scripts/verify-async-email-queue.js
 */
const net = require('node:net');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const SMTP_PORT = 2527;
const RESPONSE_DELAY_MS = 300;
const EVENT_TITLE = 'Konser Verifikasi Antrean Email';

let failures = 0;
const check = (passed, name, detail = '') => {
  if (passed) console.log(`PASS  ${name}${detail ? ` :: ${detail}` : ''}`);
  else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? ` :: ${detail}` : ''}`);
  }
};

const startSlowSink = () => new Promise((resolve) => {
  const captured = [];
  const server = net.createServer((socket) => {
    let inData = false;
    let buffer = '';
    let message = '';
    const reply = (text) => setTimeout(() => socket.write(text), RESPONSE_DELAY_MS);
    reply('220 localhost ESMTP slow sink\r\n');
    socket.on('data', (chunk) => {
      buffer += chunk.toString('utf8');
      let index = buffer.indexOf('\r\n');
      while (index !== -1) {
        const line = buffer.slice(0, index);
        buffer = buffer.slice(index + 2);
        if (inData) {
          if (line === '.') {
            inData = false;
            captured.push(message);
            message = '';
            reply('250 OK queued\r\n');
          } else {
            message += `${line}\r\n`;
          }
        } else {
          const upper = line.toUpperCase();
          if (upper.startsWith('EHLO') || upper.startsWith('HELO')) {
            reply('250-localhost\r\n250 SIZE 10485760\r\n');
          } else if (upper.startsWith('DATA')) {
            inData = true;
            reply('354 End data with <CR><LF>.<CR><LF>\r\n');
          } else if (upper.startsWith('QUIT')) {
            reply('221 Bye\r\n');
            setTimeout(() => socket.end(), RESPONSE_DELAY_MS);
          } else {
            reply('250 OK\r\n');
          }
        }
        index = buffer.indexOf('\r\n');
      }
    });
    socket.on('error', () => { /* koneksi uji ditutup */ });
  });
  server.listen(SMTP_PORT, '127.0.0.1', () => resolve({ server, captured }));
});

const cleanup = async (query) => {
  await query(
    `DELETE FROM ticket_email_deliveries WHERE ticket_id IN (
       SELECT t.id FROM tickets t JOIN events e ON e.id = t.event_id WHERE e.title = $1)`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM tickets WHERE event_id IN (SELECT id FROM events WHERE title = $1)`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM attendees WHERE order_item_id IN (
       SELECT oi.id FROM order_items oi JOIN event_orders eo ON eo.id = oi.order_id
        WHERE eo.event_id IN (SELECT id FROM events WHERE title = $1))`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM order_items WHERE order_id IN (
       SELECT id FROM event_orders WHERE event_id IN (
         SELECT id FROM events WHERE title = $1))`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM order_payments WHERE order_id IN (
       SELECT id FROM event_orders WHERE event_id IN (
         SELECT id FROM events WHERE title = $1))`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM event_orders WHERE event_id IN (SELECT id FROM events WHERE title = $1)`,
    [EVENT_TITLE],
  );
  await query(
    `DELETE FROM ticket_types WHERE event_id IN (SELECT id FROM events WHERE title = $1)`,
    [EVENT_TITLE],
  );
  await query('DELETE FROM events WHERE title = $1', [EVENT_TITLE]);
};

(async () => {
  process.env.EMAIL_PROVIDER = 'smtp';
  process.env.SMTP_HOST = '127.0.0.1';
  process.env.SMTP_PORT = String(SMTP_PORT);
  process.env.SMTP_SECURE = 'false';
  // Sink lokal tidak menyediakan STARTTLS; jangan paksa TLS pada pengujian.
  process.env.SMTP_REQUIRE_TLS = 'false';
  process.env.SMTP_USER = '';
  process.env.SMTP_PASS = '';
  process.env.EMAIL_FROM = 'no-reply@eticket.test';

  const { query, getOne, pool } = require('../src/config/db');
  const emailService = require('../src/services/emailService');
  const emailQueue = require('../src/services/emailQueue');

  await cleanup(query);
  check(emailService.smtpStatus().mode === 'smtp', 'transport SMTP nyata aktif');

  const event = await getOne(
    `INSERT INTO events (title, event_date, location, status, is_public, event_format)
     VALUES ($1, NOW() + INTERVAL '30 days', 'Jakarta', 'PUBLISHED', true, 'OFFLINE')
     RETURNING id`,
    [EVENT_TITLE],
  );
  const ticketType = await getOne(
    `INSERT INTO ticket_types (event_id, name, price, quota)
     VALUES ($1, 'Reguler', 0, 10) RETURNING id`,
    [event.id],
  );
  const order = await getOne(
    `INSERT INTO event_orders (order_number, event_id, status, subtotal, service_fee,
       commission_rate, commission_amount, grand_total, guest_name, guest_email)
     VALUES ($1, $2, 'PAID', 0, 0, 0.05, 0, 0, 'Peserta Antre', $3)
     RETURNING id`,
    [`ORD-VERIFY-QUEUE-${Date.now()}`, event.id, 'antrean@example.test'],
  );
  const item = await getOne(
    `INSERT INTO order_items (order_id, ticket_type_id, quantity, unit_price, subtotal)
     VALUES ($1, $2, 1, 0, 0) RETURNING id`,
    [order.id, ticketType.id],
  );
  const attendee = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Antre', $2) RETURNING id`,
    [item.id, 'antrean@example.test'],
  );
  const ticket = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW()) RETURNING id`,
    [`TKT-QUEUE-${Date.now()}`, event.id, ticketType.id, attendee.id],
  );

  const { server, captured } = await startSlowSink();

  // --- 1..2: penjadwalan tidak menunggu SMTP ---
  const startedAt = Date.now();
  const first = await emailQueue.enqueueOrder(order.id);
  const enqueueMs = Date.now() - startedAt;
  check(
    first.length === 1 && first[0].status === 'QUEUED',
    'status respons adalah QUEUED (bukan klaim SENT)',
    JSON.stringify(first),
  );
  const pendingRow = await getOne(
    'SELECT status::text AS status FROM ticket_email_deliveries WHERE ticket_id=$1',
    [ticket.id],
  );
  check(pendingRow?.status === 'PENDING', 'delivery dicatat PENDING saat antre', pendingRow?.status);

  // --- 3: penjadwalan ganda tidak menggandakan email ---
  const second = await emailQueue.enqueueOrder(order.id);
  check(second.length === 1 && second[0].duplicate === true,
    'penjadwalan ganda ditolak (in-flight guard)');

  // --- 4: antrean selesai -> benar-benar terkirim ---
  const drainStartedAt = Date.now();
  await emailQueue.drain();
  const drainMs = Date.now() - drainStartedAt;
  check(
    drainMs >= RESPONSE_DELAY_MS * 3,
    'pengiriman latar benar-benar melewati SMTP lambat',
    `${drainMs} ms`,
  );
  // Pembanding RELATIF (bukan ambang absolut) karena database remote menambah
  // latency pada penjadwalan; yang dibuktikan adalah penjadwalan tidak
  // menunggu percakapan SMTP.
  check(
    enqueueMs < drainMs / 2,
    'penjadwalan email tidak menunggu SMTP lambat',
    `enqueue ${enqueueMs} ms vs kirim ${drainMs} ms`,
  );
  check(captured.length === 1, 'SMTP sink menerima tepat 1 pesan', `jumlah=${captured.length}`);
  const sentRow = await getOne(
    'SELECT status::text AS status, sent_at FROM ticket_email_deliveries WHERE ticket_id=$1',
    [ticket.id],
  );
  check(sentRow?.status === 'SENT' && Boolean(sentRow?.sent_at),
    'delivery berubah SENT setelah antrean selesai', sentRow?.status);

  await new Promise((resolve) => server.close(resolve));
  emailService.resetTransport();
  await cleanup(query);
  await pool.end();

  console.log(
    failures === 0 ? '\nANTREAN EMAIL ASINKRON TERVERIFIKASI' : `\n${failures} PEMERIKSAAN GAGAL`,
  );
  if (failures > 0) process.exitCode = 1;
})().catch((error) => {
  console.error('Verifikasi antrean email gagal:', error);
  process.exitCode = 1;
});
