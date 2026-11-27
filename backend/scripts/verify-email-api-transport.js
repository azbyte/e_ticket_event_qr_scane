#!/usr/bin/env node
/*
 * Verifikasi jalur transport HTTPS API (Resend) untuk pengiriman e-ticket.
 *
 * Latar belakang: pada banyak jaringan/hosting, port SMTP (25/465/587) diblokir
 * sehingga transport SMTP tidak pernah bisa mengirim. Transport HTTPS API
 * memakai port 443 yang biasanya terbuka.
 *
 * Skrip ini menjalankan server HTTP lokal sebagai pengganti endpoint penyedia,
 * lalu memeriksa permintaan yang benar-benar dikirim aplikasi:
 *
 *  1. mode transport menjadi `resend` dan dianggap terkonfigurasi,
 *  2. permintaan POST dikirim ke endpoint penyedia dengan Bearer token,
 *  3. penerima = email peserta pada database,
 *  4. lampiran PDF tiket ikut terkirim sebagai base64,
 *  5. status delivery dicatat SENT,
 *  6. pengiriman ulang otomatis tidak memanggil API dua kali (tanpa email ganda),
 *  7. tombol kirim ulang eksplisit (`force`) benar-benar mengirim lagi dengan
 *     nomor tiket yang sama dan tetap satu catatan delivery,
 *  8. email penyelenggara dipakai sebagai From saat domainnya diizinkan,
 *  9. alamat penerima tidak valid ditolak tanpa memanggil API,
 * 10. kegagalan API dicatat FAILED beserta alasannya, tiket tetap ada.
 *
 * Ini membuktikan jalur kode transport, BUKAN bahwa email masuk ke inbox nyata.
 *
 * Jalankan dari `backend/`: node scripts/verify-email-api-transport.js
 */
const http = require('node:http');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const API_PORT = 2527;
const RECIPIENT = 'uji-api-tiket@example.test';
const EVENT_TITLE = 'Konser Verifikasi Transport API';
const API_KEY = 'uji-kunci-api-lokal-tidak-rahasia';

let failures = 0;
const check = (passed, name, detail = '') => {
  if (passed) {
    console.log(`PASS  ${name}${detail ? ` :: ${detail}` : ''}`);
  } else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? ` :: ${detail}` : ''}`);
  }
};

/** Server HTTP pengganti endpoint penyedia email. */
const startApiStub = () => new Promise((resolve) => {
  const requests = [];
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      let parsed = null;
      try { parsed = body ? JSON.parse(body) : null; } catch (_e) { parsed = null; }
      requests.push({
        method: req.method,
        url: req.url,
        authorization: req.headers.authorization || '',
        body: parsed,
      });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: `msg-${requests.length}`, data: [] }));
    });
  });
  server.listen(API_PORT, '127.0.0.1', () => resolve({ server, requests }));
});

/** Bersihkan data uji berdasarkan awalan email/event yang dipakai. */
const cleanup = async (db) => {
  const patterns = ['uji-api-tiket@%', 'bukan-email%'];
  for (const pattern of patterns) {
    await db.query(
      'DELETE FROM ticket_email_deliveries WHERE lower(recipient) LIKE lower($1)',
      [pattern],
    );
    await db.query(
      `DELETE FROM tickets WHERE id IN (
         SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
         WHERE lower(a.email) LIKE lower($1))`,
      [pattern],
    );
    await db.query('DELETE FROM attendees WHERE lower(email) LIKE lower($1)', [pattern]);
  }
  await db.query(
    `DELETE FROM order_items WHERE order_id IN (
       SELECT id FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-API-%')`,
  );
  await db.query(
    `DELETE FROM order_payments WHERE order_id IN (
       SELECT id FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-API-%')`,
  );
  await db.query("DELETE FROM event_orders WHERE order_number LIKE 'ORD-VERIFY-API-%'");
  await db.query(
    'DELETE FROM ticket_types WHERE event_id IN (SELECT id FROM events WHERE title = $1)',
    [EVENT_TITLE],
  );
  await db.query('DELETE FROM events WHERE title = $1', [EVENT_TITLE]);
  await db.query("DELETE FROM profiles WHERE lower(email) LIKE 'org.api.%@event.test'");
};


(async () => {
  // Arahkan konfigurasi ke stub SEBELUM service dimuat.
  process.env.EMAIL_PROVIDER = 'resend';
  process.env.RESEND_API_KEY = API_KEY;
  process.env.RESEND_API_URL = `http://127.0.0.1:${API_PORT}`;
  process.env.EMAIL_FROM = 'no-reply@eticket.test';
  process.env.EMAIL_FROM_NAME = 'E-Ticket Event';
  // Domain penyelenggara dianggap sudah diverifikasi di penyedia -> From
  // memakai email penyelenggara dari database.
  process.env.EMAIL_ORGANIZER_FROM_DOMAINS = 'event.test';
  // Kirim ulang eksplisit tidak perlu menunggu cooldown pada pengujian.
  process.env.EMAIL_RESEND_COOLDOWN_SECONDS = '0';
  // Pastikan tidak ada sisa konfigurasi SMTP yang mengalahkan transport API.
  process.env.SMTP_HOST = '';
  process.env.SMTP_USER = '';
  process.env.SMTP_PASS = '';
  process.env.NODE_ENV = 'development';

  const { query, getOne, pool } = require('../src/config/db');
  const emailService = require('../src/services/emailService');
  const ticketDesignService = require('../src/services/ticketDesignService');

  const status = emailService.smtpStatus();
  check(status.mode === 'resend', 'mode transport menjadi resend', status.mode);
  check(status.configured === true, 'transport API dianggap terkonfigurasi');

  await cleanup({ query });

  const organizer = await getOne(
    `INSERT INTO profiles (id, name, email, role)
     VALUES (gen_random_uuid(), 'Organizer Uji API', $1, 'organizer')
     RETURNING id, email`,
    [`org.api.${Date.now()}@event.test`],
  );
  const event = await getOne(
    `INSERT INTO events (title, event_date, location, status, is_public, event_format,
       organizer_name, created_by)
     VALUES ($1, NOW() + INTERVAL '30 days', 'Jakarta', 'PUBLISHED', true, 'OFFLINE',
       'Organizer Uji API', $2)
     RETURNING id, title`,
    [EVENT_TITLE, organizer.id],
  );
  const ticketType = await getOne(
    `INSERT INTO ticket_types (event_id, name, price, quota)
     VALUES ($1, 'Reguler', 0, 50) RETURNING id, name`,
    [event.id],
  );
  const order = await getOne(
    `INSERT INTO event_orders (order_number, event_id, status, subtotal, service_fee,
       commission_rate, commission_amount, grand_total, guest_name, guest_email)
     VALUES ($1, $2, 'PAID', 0, 0, 0.05, 0, 0, 'Peserta Uji API', $3)
     RETURNING id, order_number`,
    [`ORD-VERIFY-API-${Date.now()}`, event.id, RECIPIENT],
  );
  const item = await getOne(
    `INSERT INTO order_items (order_id, ticket_type_id, quantity, unit_price, subtotal)
     VALUES ($1, $2, 1, 0, 0) RETURNING id`,
    [order.id, ticketType.id],
  );
  const attendee = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Uji API', $2) RETURNING id, email`,
    [item.id, RECIPIENT],
  );
  const ticket = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
     RETURNING id, ticket_code`,
    [`TKT-VERIFY-API-${Date.now()}`, event.id, ticketType.id, attendee.id],
  );

  const { server, requests } = await startApiStub();
  const apiCalls = () => requests.filter((r) => r.url === '/emails' && r.method === 'POST');


  // --- 1..5: pengiriman pertama ---
  const first = await emailService.sendTicketEmail(ticket.id);
  check(first?.status === 'SENT', 'pengiriman pertama tercatat SENT', String(first?.status));
  check(apiCalls().length === 1, 'endpoint penyedia dipanggil tepat 1 kali',
    `jumlah=${apiCalls().length}`);

  const payload = apiCalls()[0]?.body || {};
  check(
    apiCalls()[0]?.authorization === `Bearer ${API_KEY}`,
    'permintaan memakai Bearer token dari environment',
  );
  check(
    Array.isArray(payload.to) && payload.to[0] === RECIPIENT,
    'penerima adalah email peserta pada database',
    JSON.stringify(payload.to),
  );
  check(/E-Ticket/i.test(String(payload.subject || '')), 'subjek email adalah E-Ticket',
    String(payload.subject || ''));
  check(String(payload.html || '').includes(EVENT_TITLE),
    'isi email memuat nama event dari database');
  check(String(payload.from || '').includes(organizer.email),
    'From memakai email penyelenggara dari database', String(payload.from || ''));
  check(String(payload.reply_to || '') === organizer.email,
    'Reply-To menunjuk email penyelenggara', String(payload.reply_to || ''));

  const attachment = Array.isArray(payload.attachments) ? payload.attachments[0] : null;
  check(Boolean(attachment), 'lampiran tiket ikut dikirim');
  check(String(attachment?.content_type || '') === 'application/pdf',
    'lampiran bertipe application/pdf', String(attachment?.content_type || ''));
  const attachmentBytes = attachment?.content
    ? Buffer.from(String(attachment.content), 'base64')
    : Buffer.alloc(0);
  check(attachmentBytes.subarray(0, 5).toString() === '%PDF-',
    'isi lampiran adalah PDF yang sah', `${attachmentBytes.length} byte`);

  const delivery = await getOne(
    `SELECT status, recipient, sent_at FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [ticket.id],
  );
  check(delivery?.status === 'SENT', 'baris delivery tercatat SENT', String(delivery?.status));
  check(delivery?.recipient?.toLowerCase() === RECIPIENT,
    'penerima pada catatan delivery benar', delivery?.recipient);


  // --- 6: tidak ada pengiriman ganda ---
  const second = await emailService.sendTicketEmail(ticket.id);
  check(second?.status === 'SKIPPED' && second?.reason === 'already_sent',
    'kirim ulang tidak mengirim email ganda', `${second?.status}/${second?.reason}`);
  check(apiCalls().length === 1, 'endpoint penyedia tetap dipanggil 1 kali',
    `jumlah=${apiCalls().length}`);

  // --- 7: tombol kirim ulang eksplisit (`force`) benar-benar mengirim lagi ---
  const beforeResend = await getOne('SELECT ticket_code FROM tickets WHERE id = $1', [ticket.id]);
  const resend = await emailService.sendTicketEmail(ticket.id, { force: true });
  check(resend?.status === 'SENT', 'kirim ulang eksplisit mengirim email lagi',
    String(resend?.status));
  check(apiCalls().length === 2, 'kirim ulang memanggil penyedia tepat satu kali tambahan',
    `jumlah=${apiCalls().length}`);

  const resendPayload = apiCalls()[1]?.body || {};
  check(String(resendPayload.subject || '') === String(payload.subject || ''),
    'subjek & nomor tiket tidak berubah pada kirim ulang',
    String(resendPayload.subject || ''));
  check(
    Buffer.from(String(resendPayload.attachments?.[0]?.content || ''), 'base64')
      .subarray(0, 5).toString() === '%PDF-',
    'kirim ulang tetap melampirkan PDF tiket yang sah',
  );
  const afterResend = await getOne('SELECT ticket_code FROM tickets WHERE id = $1', [ticket.id]);
  check(afterResend?.ticket_code === beforeResend?.ticket_code,
    'nomor tiket tidak berubah setelah kirim ulang', String(afterResend?.ticket_code || ''));
  const ticketCount = await query(
    'SELECT count(*)::int AS total FROM tickets WHERE attendee_id = $1', [attendee.id],
  );
  check(ticketCount[0].total === 1, 'kirim ulang tidak membuat tiket duplikat',
    `jumlah=${ticketCount[0].total}`);
  const deliveryRows = await query(
    'SELECT count(*)::int AS total FROM ticket_email_deliveries WHERE ticket_id = $1',
    [ticket.id],
  );
  check(deliveryRows[0].total === 1, 'kirim ulang tetap satu catatan delivery',
    `jumlah=${deliveryRows[0].total}`);
  const resendRow = await getOne(
    `SELECT status, attempt_count FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [ticket.id],
  );
  check(resendRow?.status === 'SENT' && Number(resendRow?.attempt_count) >= 2,
    'status SENT diperbarui dengan jumlah percobaan sebenarnya',
    `status=${resendRow?.status} attempt=${resendRow?.attempt_count}`);

  // --- 8: alamat penerima tidak valid ditolak tanpa memanggil API ---
  const badAttendee = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Email Salah', 'bukan-email') RETURNING id`,
    [item.id],
  );
  const badTicket = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
     RETURNING id`,
    [`TKT-VERIFY-API-BAD-${Date.now()}`, event.id, ticketType.id, badAttendee.id],
  );
  const callsBeforeBad = apiCalls().length;
  const invalid = await emailService.sendTicketEmail(badTicket.id);
  check(invalid?.status === 'FAILED' && invalid?.reason === 'invalid_recipient',
    'alamat penerima tidak valid ditolak', `${invalid?.status}/${invalid?.reason}`);
  check(apiCalls().length === callsBeforeBad,
    'alamat tidak valid tidak memanggil penyedia email',
    `jumlah=${apiCalls().length}`);
  const badRow = await getOne(
    `SELECT status, last_error FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [badTicket.id],
  );
  check(badRow?.status === 'FAILED' && /tidak valid/i.test(String(badRow?.last_error || '')),
    'alasan alamat tidak valid tersimpan pada last_error',
    String(badRow?.last_error || '').slice(0, 60));

  // --- 7: pengiriman PARALEL tidak menghasilkan email ganda ---
  // Meniru klik ganda / retry bersamaan: hanya satu yang boleh menang klaim.
  const attendee3 = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Uji Paralel', $2) RETURNING id, email`,
    [item.id, RECIPIENT],
  );
  const ticket3 = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
     RETURNING id, ticket_code`,
    [`TKT-VERIFY-API-PAR-${Date.now()}`, event.id, ticketType.id, attendee3.id],
  );
  const callsBefore = apiCalls().length;
  const parallel = await Promise.all([
    emailService.sendTicketEmail(ticket3.id),
    emailService.sendTicketEmail(ticket3.id),
    emailService.sendTicketEmail(ticket3.id),
  ]);
  const sentCount = parallel.filter((r) => r.status === 'SENT').length;
  check(sentCount === 1, 'hanya satu pengiriman paralel yang benar-benar mengirim',
    `sent=${sentCount} status=${parallel.map((r) => r.status).join(',')}`);
  check(apiCalls().length === callsBefore + 1,
    'pengiriman paralel hanya memanggil API sekali',
    `tambahan=${apiCalls().length - callsBefore}`);
  const parallelRows = await query(
    `SELECT count(*)::int AS total FROM ticket_email_deliveries WHERE ticket_id = $1`,
    [ticket3.id],
  );
  check(parallelRows[0].total === 1, 'pengiriman paralel tidak membuat catatan ganda',
    `jumlah=${parallelRows[0].total}`);

  // --- 8: kegagalan transport dicatat jujur (tiket baru + endpoint mati) ---
  const attendee2 = await getOne(
    `INSERT INTO attendees (order_item_id, name, email)
     VALUES ($1, 'Peserta Uji API Gagal', $2) RETURNING id, email`,
    [item.id, RECIPIENT],
  );
  const ticket2 = await getOne(
    `INSERT INTO tickets (ticket_code, event_id, ticket_type_id, attendee_id,
       qr_code_data, status, purchased_at, issued_at)
     VALUES ($1, $2, $3, $4, $1, 'active', NOW(), NOW())
     RETURNING id, ticket_code`,
    [`TKT-VERIFY-API-FAIL-${Date.now()}`, event.id, ticketType.id, attendee2.id],
  );
  await new Promise((resolve) => server.close(resolve));
  const failed = await emailService.sendTicketEmail(ticket2.id);
  check(failed?.status === 'FAILED', 'kegagalan transport API dicatat FAILED',
    `${failed?.status}/${String(failed?.reason || '').slice(0, 40)}`);
  const failedRow = await getOne(
    `SELECT status, last_error FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [ticket2.id],
  );
  check(failedRow?.status === 'FAILED' && Boolean(failedRow?.last_error),
    'alasan kegagalan transport API tersimpan',
    String(failedRow?.last_error || '').slice(0, 60));

  const stillSent = await getOne(
    `SELECT status FROM ticket_email_deliveries
      WHERE ticket_id = $1 ORDER BY created_at DESC LIMIT 1`,
    [ticket.id],
  );
  check(stillSent?.status === 'SENT', 'catatan SENT tidak diturunkan oleh kegagalan berikutnya',
    String(stillSent?.status || ''));
  const ticketStillThere = await getOne('SELECT id FROM tickets WHERE id = $1', [ticket.id]);
  check(Boolean(ticketStillThere?.id), 'tiket tetap terbit walau email gagal');

  const pdfTicket = await ticketDesignService.loadTicketForPdf(ticket.id);
  const pdf = await ticketDesignService.buildTicketPdf(pdfTicket);
  check(pdf.subarray(0, 5).toString() === '%PDF-', 'PDF tiket terbentuk dari data database');
  check(String(pdfTicket?.attendee_email || '').toLowerCase() === RECIPIENT,
    'data PDF memuat email peserta yang benar', String(pdfTicket?.attendee_email || ''));

  await cleanup({ query });
  await pool.end();

  console.log('');
  if (failures > 0) {
    console.error(`TRANSPORT API: ${failures} PEMERIKSAAN GAGAL`);
    process.exitCode = 1;
  } else {
    console.log('TRANSPORT HTTPS API TERVERIFIKASI (lokal; inbox nyata perlu kredensial)');
  }
})().catch((error) => {
  console.error('Verifikasi transport API gagal:', error.message);
  process.exitCode = 1;
});
