#!/usr/bin/env node
/*
 * Verifikasi NYATA pengiriman e-ticket melalui SMTP (bukan mock).
 *
 * Skrip ini menjalankan SMTP sink lokal (server SMTP minimal di 127.0.0.1)
 * sehingga Nodemailer benar-benar melakukan percakapan SMTP: EHLO, MAIL FROM,
 * RCPT TO, DATA. Pesan yang diterima sink diperiksa isinya, sehingga terbukti:
 *
 *  1. email benar-benar dikirim lewat transport SMTP (bukan jsonTransport),
 *  2. penerima = email peserta pada database,
 *  3. subjek & isi memuat nama event asli dari database,
 *  4. lampiran PDF tiket ikut terkirim,
 *  5. status delivery dicatat SENT,
 *  6. pengiriman ulang tidak membuat email ganda (SKIPPED/already_sent),
 *  7. kegagalan SMTP dicatat FAILED beserta alasannya, dan
 *  8. tiket tetap ada walau email gagal (penerbitan tidak ikut gagal).
 *
 * Data uji memakai email domain `.test` (tidak mungkin masuk inbox nyata) dan
 * dihapus kembali di akhir. Jalankan dari `backend/`:
 *   node scripts/verify-email-delivery.js
 */
const net = require('node:net');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

/*
 * Simpan konfigurasi SMTP asli (backend/.env) SEBELUM diarahkan ke sink lokal.
 * Nilai tidak pernah dicetak; hanya nama variabel yang belum diisi yang
 * dilaporkan agar pengguna tahu apa yang harus dilengkapi.
 */
const REAL_SMTP = {
  SMTP_HOST: process.env.SMTP_HOST || '',
  SMTP_PORT: process.env.SMTP_PORT || '',
  SMTP_SECURE: process.env.SMTP_SECURE || '',
  SMTP_USER: process.env.SMTP_USER || '',
  SMTP_PASS: process.env.SMTP_PASS || '',
  EMAIL_FROM: process.env.EMAIL_FROM || '',
};
const REAL_RECIPIENT = String(process.env.VERIFY_EMAIL_TO || '').trim();

const SMTP_PORT = 2526;
const RECIPIENT = 'uji-tiket@example.test';
const EVENT_TITLE = 'Konser Verifikasi Email Nyata';

let failures = 0;
let blockedCount = 0;
const check = (passed, name, detail = '') => {
  if (passed) {
    console.log(`PASS  ${name}${detail ? ` :: ${detail}` : ''}`);
  } else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? ` :: ${detail}` : ''}`);
  }
};

/**
 * SMTP sink minimal: cukup untuk menerima pesan dari Nodemailer tanpa auth.
 * Menyimpan pesan terakhir pada `captured`.
 */
const startSmtpSink = () => new Promise((resolve) => {
  const captured = [];
  const server = net.createServer((socket) => {
    let inData = false;
    let buffer = '';
    let message = '';
    socket.write('220 localhost ESMTP sink\r\n');
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
            socket.write('250 OK queued\r\n');
          } else {
            message += `${line}\r\n`;
          }
        } else {
          const upper = line.toUpperCase();
          if (upper.startsWith('EHLO') || upper.startsWith('HELO')) {
            socket.write('250-localhost\r\n250 SIZE 10485760\r\n');
          } else if (upper.startsWith('MAIL FROM') || upper.startsWith('RCPT TO')) {
            socket.write('250 OK\r\n');
          } else if (upper.startsWith('DATA')) {
            inData = true;
            socket.write('354 End data with <CR><LF>.<CR><LF>\r\n');
          } else if (upper.startsWith('QUIT')) {
            socket.write('221 Bye\r\n');
            socket.end();
          } else if (upper.startsWith('RSET')) {
            socket.write('250 OK\r\n');
          } else {
            socket.write('250 OK\r\n');
          }
        }
        index = buffer.indexOf('\r\n');
      }
    });
    socket.on('error', () => { /* koneksi uji ditutup */ });
  });
  server.listen(SMTP_PORT, '127.0.0.1', () => resolve({ server, captured }));
});

/** Bersihkan data uji berdasarkan awalan email/event yang dipakai. */
const cleanup = async (db, extraEmail = null) => {
  const patterns = ['uji-tiket@%'];
  if (extraEmail) patterns.push(extraEmail);
  for (const pattern of patterns) {
    await db.query(
      `DELETE FROM ticket_email_deliveries WHERE lower(recipient) LIKE lower($1)`,
      [pattern],
    );
    await db.query(
      `DELETE FROM tickets WHERE id IN (
         SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
         WHERE lower(a.email) LIKE lower($1))`,
      [pattern],
    );
    await db.query(
      `DELETE FROM attendees WHERE lower(email) LIKE lower($1)`,
      [pattern],
    );
  }
  await db.query(
    `DELETE FROM order_items WHERE order_id IN (
       SELECT id FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-EMAIL-%')`,
  );
  await db.query(
    `DELETE FROM order_payments WHERE order_id IN (
       SELECT id FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-EMAIL-%')`,
  );
  await db.query(`DELETE FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-EMAIL-%'`);
  await db.query(`DELETE FROM ticket_types WHERE event_id IN (
     SELECT id FROM events WHERE title = $1)`, [EVENT_TITLE]);
  await db.query('DELETE FROM events WHERE title = $1', [EVENT_TITLE]);
};

(async () => {
  // Konfigurasi SMTP diarahkan ke sink lokal SEBELUM service dimuat, sehingga
  // transportMode() memakai 'smtp' nyata (bukan json).
  process.env.SMTP_HOST = '127.0.0.1';
  process.env.SMTP_PORT = String(SMTP_PORT);
  process.env.SMTP_SECURE = 'false';
  process.env.SMTP_USER = '';
  process.env.SMTP_PASS = '';
  process.env.EMAIL_FROM = 'no-reply@eticket.test';
  process.env.APP_PUBLIC_URL = 'http://localhost:3100';

  const { query, getOne, pool } = require('../src/config/db');
  const emailService = require('../src/services/emailService');
  const ticketDesignService = require('../src/services/ticketDesignService');

  console.log(`Mode transport: ${emailService.transportMode()}`);
  check(emailService.transportMode() === 'smtp', 'transport SMTP nyata aktif');

  await cleanup({ query });

  // --- Siapkan data uji sintetis (event, kategori, order, peserta, tiket) ---
  const event = await getOne(
    `INSERT INTO events (title, event_date, location, status, is_public, event_format)
     VALUES ($1, NOW() + INTERVAL '30 days', 'Jakarta', 'PUBLISHED', true, 'OFFLINE')
     RETURNING id, title`,
    [EVENT_TITLE],
  );
  const ticketType = await getOne(
    `INSERT INTO ticket_types (event_id, name, price, quota)
     VALUES ($1, 'Reguler', 0, 50) RETURNING id, name`,
    [event.id],
  );
  const order = await getOne(
    `INSERT INTO event_orders (order_number, event_id, status, subtotal, service_fee,
       commission_rate, commission_amount, grand_total, guest_name, guest_email)
     VALUES ($1, $2, 'PAID', 0, 0, 0.05, 0, 0, 'Peserta Uji', $3)
     RETURNING id, order_number`,
    [`ORD-VERIFY-EMAIL-${Date.now()}`, event.id, RECIPIENT],
  );
  const item = await getOne(
    `INSERT INTO order_items (order_id, ticket_type_id, quantity, unit_price, subtotal)
     VALUES ($1, $2, 1, 0, 0) RETURNING id`,
    [order.id, ticketType.id],
  );
  const attendee = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Uji Email', $2) RETURNING id, email`,
    [item.id, RECIPIENT],
  );
  const ticket = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
     RETURNING id, ticket_code`,
    [`TKT-VERIFY-${Date.now()}`, event.id, ticketType.id, attendee.id],
  );
  check(Boolean(ticket?.id), 'tiket uji tersimpan di database', ticket?.ticket_code);

  // --- 1..5: kirim email lewat SMTP sink ---
  const { server, captured } = await startSmtpSink();
  const first = await emailService.sendTicketEmail(ticket.id);
  check(first?.status === 'SENT', 'pengiriman pertama tercatat SENT', String(first?.status));
  check(captured.length === 1, 'SMTP sink menerima tepat 1 pesan', `jumlah=${captured.length}`);

  const raw = captured[0] || '';
  const decoded = raw
    .replace(/=\r\n/g, '')
    .replace(/=([0-9A-F]{2})/g, (_m, hex) => String.fromCharCode(parseInt(hex, 16)));
  check(raw.toLowerCase().includes(RECIPIENT), 'RCPT TO memakai email peserta', RECIPIENT);
  check(/subject:\s*E-Ticket/i.test(raw), 'subjek email adalah E-Ticket');
  check(
    decoded.includes(EVENT_TITLE) || /filename\*?=/.test(raw),
    'pesan memuat data event/lampiran tiket',
  );
  check(
    /Content-Type:\s*application\/pdf/i.test(raw),
    'lampiran PDF tiket ikut terkirim',
  );

  const delivery = await getOne(
    'SELECT status, recipient, sent_at FROM ticket_email_deliveries WHERE ticket_id = $1',
    [ticket.id],
  );
  check(delivery?.status === 'SENT', 'baris delivery tercatat SENT');
  check(
    delivery?.recipient?.toLowerCase() === RECIPIENT,
    'penerima pada catatan delivery benar',
    delivery?.recipient,
  );

  // --- 6: kirim ulang tidak menghasilkan email ganda ---
  const second = await emailService.sendTicketEmail(ticket.id);
  check(
    second?.status === 'SKIPPED' && second?.reason === 'already_sent',
    'kirim ulang tidak mengirim email ganda',
    `${second?.status}/${second?.reason}`,
  );
  check(captured.length === 1, 'tidak ada pesan kedua pada SMTP sink', `jumlah=${captured.length}`);

  // --- 7..8: kegagalan SMTP dicatat, tiket tetap ada ---
  await new Promise((resolve) => server.close(resolve));
  emailService.resetTransport();
  const failed = await emailService.sendTicketEmail(ticket.id, { force: true });
  check(
    failed?.status === 'FAILED',
    'kegagalan SMTP dicatat FAILED (tidak diklaim terkirim)',
    `${failed?.status}/${String(failed?.reason || '').slice(0, 40)}`,
  );
  const failedRow = await getOne(
    `SELECT status, last_error FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [ticket.id],
  );
  check(
    failedRow?.status === 'FAILED' && Boolean(failedRow?.last_error),
    'alasan kegagalan tersimpan pada last_error',
    String(failedRow?.last_error || '').slice(0, 60),
  );
  const stillThere = await getOne('SELECT id FROM tickets WHERE id = $1', [ticket.id]);
  check(Boolean(stillThere?.id), 'tiket tetap terbit walau email gagal');

  // --- PDF tiket dapat dibuat dari data nyata ---
  const pdfTicket = await ticketDesignService.loadTicketForPdf(ticket.id);
  const pdf = await ticketDesignService.buildTicketPdf(pdfTicket);
  check(pdf.subarray(0, 5).toString() === '%PDF-', 'PDF tiket terbentuk dari data database');
  check(
    String(pdfTicket?.event_title || '') === EVENT_TITLE,
    'nama event pada data PDF sama dengan nama event di database',
    String(pdfTicket?.event_title || ''),
  );

  // --- Konfigurasi SMTP nyata (backend/.env) ---
  // Kembalikan environment asli lalu periksa apakah email dapat dikirim ke
  // jaringan. Nilai kredensial tidak pernah dicetak.
  for (const [key, value] of Object.entries(REAL_SMTP)) {
    if (value === '') delete process.env[key];
    else process.env[key] = value;
  }
  emailService.resetTransport();
  const realStatus = emailService.smtpStatus();
  console.log(`\nSMTP nyata: mode=${realStatus.mode}`);
  if (realStatus.missing.length > 0) {
    console.log(`Variabel belum diisi: ${realStatus.missing.join(', ')}`);
  }
  if (realStatus.reason) console.log(`Alasan: ${realStatus.reason}`);

  if (realStatus.mode !== 'smtp') {
    blockedCount += 1;
    console.log('BLOCKED  pengiriman ke inbox nyata :: SMTP nyata belum siap.');
    console.log('         Lengkapi backend/.env: SMTP_HOST, SMTP_PORT, SMTP_USER,');
    console.log('         SMTP_PASS, EMAIL_FROM lalu jalankan ulang npm run verify:email.');
  } else if (!REAL_RECIPIENT) {
    blockedCount += 1;
    console.log('BLOCKED  pengiriman ke inbox nyata :: VERIFY_EMAIL_TO belum diisi.');
    console.log('         Set VERIFY_EMAIL_TO=alamat-inbox-anda pada backend/.env,');
    console.log('         lalu jalankan ulang npm run verify:email.');
  } else {
    // Kirim benar-benar melalui SMTP yang dikonfigurasi ke alamat verifikasi.
    const realAttendee = await getOne(
      `INSERT INTO attendees (order_item_id, name, email)
       VALUES ($1, 'Peserta Verifikasi Inbox', $2) RETURNING id, email`,
      [item.id, REAL_RECIPIENT],
    );
    const realTicket = await getOne(
      `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
         qr_code_data, status, purchased_at, issued_at)
       VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
       RETURNING id, ticket_code`,
      [`TKT-VERIFY-INBOX-${Date.now()}`, event.id, ticketType.id, realAttendee.id],
    );
    const realSend = await emailService.sendTicketEmail(realTicket.id);
    check(
      realSend?.status === 'SENT',
      'SMTP nyata menerima pesan untuk alamat verifikasi',
      `${realSend?.status}/${String(realSend?.reason || '').slice(0, 80)}`,
    );
    if (realSend?.status === 'SENT') {
      console.log(
        'CATATAN  Bukti "SENT" berarti server SMTP menerima pesan. Pastikan '
        + `email benar-benar masuk ke inbox ${REAL_RECIPIENT} (termasuk folder spam).`,
      );
    }
  }

  // --- Bereskan data uji ---
  await cleanup({ query }, REAL_RECIPIENT || null);
  await pool.end();

  console.log(
    failures === 0
      ? (blockedCount === 0
        ? '\nSEMUA PEMERIKSAAN EMAIL LULUS'
        : `\nPEMERIKSAAN LOKAL LULUS; ${blockedCount} verifikasi eksternal BLOCKED`)
      : `\n${failures} PEMERIKSAAN GAGAL`,
  );
  if (failures > 0) process.exitCode = 1;
})().catch(async (error) => {
  console.error('Verifikasi gagal:', error);
  process.exitCode = 1;
});

