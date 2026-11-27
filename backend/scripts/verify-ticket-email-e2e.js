#!/usr/bin/env node
/*
 * Uji END-TO-END penerbitan + pengiriman tiket melalui HTTP nyata:
 * pendaftaran peserta -> tiket terbit -> PDF+QR -> email berisi lampiran PDF.
 *
 * Skrip ini menjalankan backend sungguhan (proses `server.js`) dan sebuah
 * server HTTP lokal sebagai pengganti endpoint penyedia email. Jadi yang diuji
 * adalah kode aplikasi yang sebenarnya: controller, database, rendering PDF,
 * QR, antrean email, dan transport HTTPS.
 *
 * Yang diperiksa:
 *  1. event GRATIS   -> order PAID, tiket terbit, email terkirim otomatis,
 *  2. event BERBAYAR -> belum ada tiket/email; setelah simulasi pembayaran
 *     tiket terbit dan email terkirim,
 *  3. email berisi lampiran PDF sah dengan data peserta/event/kategori/kode,
 *  4. QR terhubung ke data tiket yang benar (endpoint verify),
 *  5. pemanggilan berulang tidak mengirim email ganda,
 *  6. data pendaftaran tetap utuh.
 *
 * CATATAN PENTING: ini membuktikan seluruh rantai aplikasi, TAPI endpoint
 * penyedia email digantikan server lokal. Bukti "masuk ke inbox nyata" hanya
 * bisa dihasilkan dengan kredensial asli (lihat `npm run verify:email-api`).
 *
 * Jalankan dari `backend/`: node scripts/verify-ticket-email-e2e.js
 */
const http = require('node:http');
const path = require('node:path');
const { spawn } = require('node:child_process');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const API_PORT = 2528;
const SERVER_PORT = Number(process.env.E2E_SERVER_PORT || 5055);
const BASE = `http://127.0.0.1:${SERVER_PORT}`;
const stamp = Date.now();
const API_KEY = 'kunci-uji-e2e-lokal';

let failures = 0;
const check = (passed, name, detail = '') => {
  if (passed) {
    console.log(`PASS  ${name}${detail ? ` :: ${detail}` : ''}`);
  } else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? ` :: ${detail}` : ''}`);
  }
};

/** Endpoint penyedia email pengganti (mencatat setiap pesan yang dikirim). */
const startApiStub = () => new Promise((resolve) => {
  const messages = [];
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      if (req.method === 'POST' && req.url === '/emails') {
        let parsed = null;
        try { parsed = JSON.parse(body); } catch (_e) { parsed = null; }
        messages.push(parsed || {});
      }
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: `msg-${messages.length}`, data: [] }));
    });
  });
  server.listen(API_PORT, '127.0.0.1', () => resolve({ server, messages }));
});

/** Panggilan HTTP ke backend. */
const request = async (method, urlPath, { token, orderToken, body } = {}) => {
  const response = await fetch(`${BASE}${urlPath}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(orderToken ? { 'X-Order-Access-Token': orderToken } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const buffer = Buffer.from(await response.arrayBuffer());
  const text = buffer.toString('utf8');
  let json = null;
  try { json = JSON.parse(text); } catch (_e) { json = null; }
  return { status: response.status, json, text, buffer };
};

const waitForServer = async (timeoutMs = 40000) => {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const res = await fetch(`${BASE}/health`);
      if (res.ok) return true;
    } catch (_e) { /* belum siap */ }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return false;
};

/** Buat event + kategori tiket, lalu terbitkan. */
const createPublishedEvent = async (organizerToken, { title, price }) => {
  const start = new Date(Date.now() + 5 * 24 * 3600 * 1000);
  const end = new Date(start.getTime() + 4 * 3600 * 1000);
  const created = await request('POST', '/api/events', {
    token: organizerToken,
    body: {
      title,
      description: 'Event uji pengiriman tiket',
      category: 'Seminar',
      event_format: 'OFFLINE',
      location: 'Jakarta',
      organizer_name: 'Organizer E2E Email',
      contact_info: 'hubungi@example.test',
      start_date_time: start.toISOString(),
      end_date_time: end.toISOString(),
      attendee_fields: [
        { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
        { key: 'email', label: 'Email', type: 'text', required: true },
      ],
    },
  });
  const event = created.json?.event;
  if (!event?.id) return { event: null, typeId: null };

  const type = await request('POST', `/api/events/${event.id}/ticket-types`, {
    token: organizerToken,
    body: { name: price > 0 ? 'VIP' : 'Reguler', price, quota: 20, max_per_order: 1 },
  });
  const typeId = type.json?.ticketType?.id || type.json?.ticket_type?.id || type.json?.data?.id;

  await request('POST', `/api/events/${event.id}/publish`, { token: organizerToken });
  return { event, typeId };
};

/** Tunggu sampai email untuk tiket tertentu tercatat SENT (atau FAILED). */
const waitForDelivery = async (getOne, ticketIds, timeoutMs = 25000) => {
  const started = Date.now();
  let rows = [];
  while (Date.now() - started < timeoutMs) {
    rows = [];
    for (const id of ticketIds) {
      const row = await getOne(
        `SELECT ticket_id, recipient, status::text AS status, last_error, sent_at
           FROM ticket_email_deliveries WHERE ticket_id = $1
           ORDER BY created_at DESC LIMIT 1`,
        [id],
      );
      if (row) rows.push(row);
    }
    if (rows.length === ticketIds.length
        && rows.every((r) => r.status === 'SENT' || r.status === 'FAILED')) {
      return rows;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return rows;
};

/**
 * Ambil teks yang dapat dibaca dari PDF.
 *
 * PDFKit menulis teks sebagai string hex di dalam operator `TJ`
 * (mis. `<452d5449434b4554> 0] TJ`), dan stream-nya dikompresi FlateDecode.
 * Karena itu teks tidak dapat dicari langsung pada byte PDF: stream harus
 * didekompresi, lalu setiap string hex di dalam blok `BT ... ET` didekode.
 */
const pdfExtractText = (buffer) => {
  const zlib = require('node:zlib');
  const raw = buffer.toString('latin1');
  const parts = [raw];
  const streamRe = /stream\r?\n([\s\S]*?)endstream/g;
  let match;
  while ((match = streamRe.exec(raw)) !== null) {
    const chunk = Buffer.from(match[1], 'latin1');
    try {
      parts.push(zlib.inflateSync(chunk).toString('latin1'));
    } catch (_e) {
      parts.push(chunk.toString('latin1'));
    }
  }

  const texts = [];
  for (const part of parts) {
    const blocks = part.match(/BT[\s\S]*?ET/g) || [];
    for (const block of blocks) {
      // Satu blok teks dapat dipecah menjadi beberapa string hex karena
      // kerning (mis. `<50657365> -20 <727461>`); potongan itu harus
      // disambung tanpa pemisah agar kata kembali utuh.
      const hexStrings = block.match(/<([0-9A-Fa-f\s]+)>/g) || [];
      let line = '';
      for (const hex of hexStrings) {
        const clean = hex.slice(1, -1).replace(/\s+/g, '');
        if (clean.length % 2 !== 0) continue;
        line += Buffer.from(clean, 'hex').toString('latin1');
      }
      if (line) texts.push(line);
    }
  }
  return texts.join(' ');
};

/** True bila teks PDF memuat potongan teks tertentu. */
const pdfContainsText = (buffer, needle) => pdfExtractText(buffer).includes(needle);

/** Ukuran halaman pertama PDF (pt) dari MediaBox. */
const pdfPageSize = (buffer) => {
  const match = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
  return match ? { width: Number(match[1]), height: Number(match[2]) } : null;
};

/** Hapus seluruh data uji E2E email berdasarkan pola khusus. */
const cleanup = async (query) => {
  const emailPattern = '%.e2e.email.%@example.test';
  const titlePattern = 'Event % E2E Email %';
  await query(
    `DELETE FROM ticket_email_deliveries WHERE ticket_id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
       WHERE lower(a.email) LIKE lower($1))`, [emailPattern],
  );
  await query(
    `DELETE FROM check_ins WHERE ticket_id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
       WHERE lower(a.email) LIKE lower($1))`, [emailPattern],
  );
  await query(
    `DELETE FROM scan_logs WHERE ticket_id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
       WHERE lower(a.email) LIKE lower($1))`, [emailPattern],
  );
  await query(
    `DELETE FROM tickets WHERE id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
       WHERE lower(a.email) LIKE lower($1))`, [emailPattern],
  );
  await query('DELETE FROM attendees WHERE lower(email) LIKE lower($1)', [emailPattern]);
  const orderFilter = `SELECT id FROM event_orders WHERE event_id IN (
     SELECT id FROM events WHERE title LIKE $1)`;
  // Urutan penting: platform_transactions -> order_payments (FK), lalu items.
  await query(`DELETE FROM platform_transactions WHERE order_payment_id IN (
     SELECT id FROM order_payments WHERE order_id IN (${orderFilter}))`, [titlePattern]);
  await query(`DELETE FROM order_payments WHERE order_id IN (${orderFilter})`, [titlePattern]);
  await query(`DELETE FROM order_items WHERE order_id IN (${orderFilter})`, [titlePattern]);
  await query(`DELETE FROM event_orders WHERE event_id IN (
     SELECT id FROM events WHERE title LIKE $1)`, [titlePattern]);
  await query(`DELETE FROM ticket_types WHERE event_id IN (
     SELECT id FROM events WHERE title LIKE $1)`, [titlePattern]);
  await query('DELETE FROM events WHERE title LIKE $1', [titlePattern]);
  await query('DELETE FROM profiles WHERE lower(email) LIKE lower($1)', [emailPattern]);
};

(async () => {
  const { server: apiStub, messages } = await startApiStub();

  // Backend dijalankan dengan konfigurasi email mengarah ke stub. Kredensial
  // asli pada backend/.env tidak dipakai/diubah oleh skrip ini.
  const child = spawn(process.execPath, ['server.js'], {
    cwd: path.join(__dirname, '..'),
    env: {
      ...process.env,
      PORT: String(SERVER_PORT),
      HOST: '127.0.0.1',
      NODE_ENV: 'development',
      EMAIL_PROVIDER: 'resend',
      RESEND_API_KEY: API_KEY,
      RESEND_API_URL: `http://127.0.0.1:${API_PORT}`,
      EMAIL_FROM: 'no-reply@eticket.test',
      EMAIL_FROM_NAME: 'E-Ticket Event',
      // Domain penyelenggara uji dianggap terverifikasi di penyedia.
      EMAIL_ORGANIZER_FROM_DOMAINS: 'example.test',
      // Kirim ulang eksplisit tidak menunggu cooldown pada pengujian.
      EMAIL_RESEND_COOLDOWN_SECONDS: '0',
      SMTP_HOST: '',
      SMTP_USER: '',
      SMTP_PASS: '',
      SIMULATED_PAYMENTS_ENABLED: 'true',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const serverLog = [];
  child.stdout.on('data', (chunk) => serverLog.push(chunk.toString()));
  child.stderr.on('data', (chunk) => serverLog.push(chunk.toString()));

  const shutdown = () => {
    try { child.kill(); } catch (_e) { /* sudah berhenti */ }
    try { apiStub.close(); } catch (_e) { /* sudah tertutup */ }
  };

  try {
    const ready = await waitForServer();
    check(ready, 'backend uji berjalan', BASE);
    if (!ready) {
      console.error(serverLog.join('').slice(-2000));
      shutdown();
      process.exitCode = 1;
      return;
    }

    const { getOne, query, pool } = require('../src/config/db');
    const organizerEmail = `org.e2e.email.${stamp}@example.test`;
    const register = await request('POST', '/api/auth/register', {
      body: {
        name: 'Organizer E2E Email',
        email: organizerEmail,
        password: 'Rahasia12345',
        role: 'organizer',
      },
    });
    const organizerToken = register.json?.token || register.json?.data?.token;
    check(Boolean(organizerToken), 'organizer uji terdaftar', `status=${register.status}`);

    // ---------- A. EVENT GRATIS ----------
    const freeTitle = `Event Gratis E2E Email ${stamp}`;
    const free = await createPublishedEvent(organizerToken, { title: freeTitle, price: 0 });
    check(Boolean(free.typeId), 'event gratis + kategori siap', freeTitle);

    const freeEmail = `peserta.gratis.e2e.email.${stamp}@example.test`;
    const freeOrder = await request('POST', '/api/orders', {
      body: {
        event_id: free.event?.id,
        items: { [free.typeId]: 1 },
        attendees: [{
          ticket_type_id: free.typeId,
          name: 'Peserta Gratis E2E',
          email: freeEmail,
        }],
        idempotency_key: `e2e-email-free-${stamp}`,
      },
    });
    check(freeOrder.status === 201, 'pendaftaran event gratis diterima',
      `status=${freeOrder.status}`);
    check(String(freeOrder.json?.order?.status || '').toUpperCase() === 'PAID',
      'event gratis langsung PAID', String(freeOrder.json?.order?.status));

    const freeOrderId = freeOrder.json?.order?.id;
    const freeAccess = freeOrder.json?.order_access_token;

    const freeTicketsRes = await request(
      'GET', `/api/tickets/my-tickets?order_id=${freeOrderId}`, { orderToken: freeAccess },
    );
    const freeTickets = freeTicketsRes.json?.tickets ?? [];
    check(freeTickets.length === 1, 'tiket event gratis terbit', `count=${freeTickets.length}`);

    const freeTicket = freeTickets[0];
    const freeDelivery = await waitForDelivery(getOne, [freeTicket.id]);
    check(freeDelivery[0]?.status === 'SENT', 'email tiket gratis terkirim otomatis',
      `${freeDelivery[0]?.status} ${String(freeDelivery[0]?.last_error || '').slice(0, 60)}`);
    check(
      String(freeDelivery[0]?.recipient || '').toLowerCase() === freeEmail,
      'penerima email = email yang didaftarkan',
      String(freeDelivery[0]?.recipient || ''),
    );

    // Isi pesan yang benar-benar dikirim ke penyedia email.
    const freeMessage = messages.find(
      (m) => Array.isArray(m.to) && m.to.includes(freeEmail),
    );
    check(Boolean(freeMessage), 'penyedia email menerima pesan untuk peserta');
    check(
      String(freeMessage?.from || '').includes(organizerEmail),
      'identitas pengirim = email penyelenggara dari database',
      String(freeMessage?.from || ''),
    );
    check(
      String(freeMessage?.reply_to || '') === organizerEmail,
      'Reply-To menunjuk email penyelenggara',
      String(freeMessage?.reply_to || ''),
    );
    check(
      !String(freeMessage?.from || '').includes(freeEmail),
      'email peserta tidak dipakai sebagai pengirim',
    );
    check(
      String(freeMessage?.html || '').includes(freeTitle),
      'email memuat nama event yang benar',
      freeTitle,
    );
    check(
      String(freeMessage?.subject || '').includes(freeTicket.ticket_code),
      'subjek email memuat kode tiket',
      String(freeMessage?.subject || ''),
    );

    const attachment = Array.isArray(freeMessage?.attachments)
      ? freeMessage.attachments[0] : null;
    const attachmentPdf = attachment?.content
      ? Buffer.from(String(attachment.content), 'base64') : Buffer.alloc(0);
    check(
      attachmentPdf.subarray(0, 5).toString() === '%PDF-',
      'email berisi lampiran PDF yang sah',
      `${attachmentPdf.length} byte`,
    );

    // Nama lampiran WAJIB `E-TIKET Nama Peserta.pdf` (spasi biasa, tanpa prefix
    // lain). Diambil dari nama peserta di database, bukan kode tiket.
    check(
      String(attachment?.filename || '') === 'E-TIKET Peserta Gratis E2E.pdf',
      'nama lampiran memakai format E-TIKET Nama Peserta.pdf',
      String(attachment?.filename || ''),
    );

    // Dimensi halaman PDF: tiket default landscape = 842 x 594 pt.
    const attachmentPage = pdfPageSize(attachmentPdf);
    check(
      attachmentPage?.width === 842 && attachmentPage?.height === 594,
      'lampiran PDF berukuran 842x594 pt (landscape)',
      `${attachmentPage?.width}x${attachmentPage?.height}`,
    );

    const attachmentText = attachmentPdf;
    check(pdfContainsText(attachmentText, 'Peserta Gratis E2E'), 'PDF memuat nama peserta');
    check(pdfContainsText(attachmentText, freeTicket.ticket_code),
      'PDF memuat kode tiket unik', freeTicket.ticket_code);
    check(pdfContainsText(attachmentText, 'Reguler'), 'PDF memuat kategori tiket', 'Reguler');

    // ---------- QR terhubung ke data tiket yang benar ----------
    check(typeof freeTicket.token === 'string' && freeTicket.token.length > 20,
      'tiket memiliki token QR unik', `len=${String(freeTicket.token).length}`);
    const verify = await request('POST', '/api/tickets/verify', {
      token: organizerToken,
      body: { token: freeTicket.token, event_id: free.event?.id },
    });
    const verifiedTicket = verify.json?.ticket || verify.json?.data || null;
    check(
      verify.status === 200 && String(verifiedTicket?.id || '') === freeTicket.id,
      'QR dapat dipindai dan terhubung ke tiket yang benar',
      `status=${verify.status}`,
    );
    check(
      String(verifiedTicket?.attendee_email || '').toLowerCase() === freeEmail,
      'data tiket dari QR memuat email peserta yang benar',
      String(verifiedTicket?.attendee_email || ''),
    );

    // ---------- Tombol kirim ulang: benar-benar mengirim lagi ----------
    const messagesBefore = messages.length;
    const codeBefore = freeTicket.ticket_code;
    const resend = await request('POST', `/api/tickets/${freeTicket.id}/email`, {
      orderToken: freeAccess,
      body: { order_id: freeOrderId },
    });
    check(resend.status === 200, 'permintaan kirim ulang diproses', `status=${resend.status}`);
    check(resend.json?.delivered === true,
      'kirim ulang dilaporkan terkirim setelah penyedia menerima pesan',
      String(resend.json?.delivery_status));
    check(
      String(resend.json?.sender?.from || '') === organizerEmail,
      'kirim ulang memakai email penyelenggara sebagai pengirim',
      String(resend.json?.sender?.from || ''),
    );
    check(messages.length === messagesBefore + 1, 'kirim ulang mengirim email baru',
      `sebelum=${messagesBefore} sesudah=${messages.length}`);

    const resendMessage = messages[messages.length - 1];
    check(
      String(resendMessage?.subject || '') === String(freeMessage?.subject || ''),
      'nomor tiket pada subjek tidak berubah',
      String(resendMessage?.subject || ''),
    );
    const resendPdf = Buffer.from(
      String(resendMessage?.attachments?.[0]?.content || ''), 'base64',
    );
    check(resendPdf.subarray(0, 5).toString() === '%PDF-',
      'kirim ulang tetap melampirkan PDF tiket', `${resendPdf.length} byte`);

    const deliveryRows = await query(
      'SELECT count(*)::int AS total FROM ticket_email_deliveries WHERE ticket_id = $1',
      [freeTicket.id],
    );
    check(deliveryRows[0].total === 1, 'tidak ada catatan delivery ganda',
      `jumlah=${deliveryRows[0].total}`);

    const ticketRows = await query(
      'SELECT count(*)::int AS total FROM tickets WHERE event_id = $1', [free.event.id],
    );
    check(ticketRows[0].total === 1, 'kirim ulang tidak menerbitkan tiket duplikat',
      `jumlah=${ticketRows[0].total}`);
    const ticketCodeRow = await getOne(
      'SELECT ticket_code FROM tickets WHERE id = $1', [freeTicket.id],
    );
    check(ticketCodeRow?.ticket_code === codeBefore, 'nomor tiket tidak berubah',
      String(ticketCodeRow?.ticket_code || ''));

    // ---------- B. EVENT BERBAYAR ----------
    const paidTitle = `Event Berbayar E2E Email ${stamp}`;
    const paid = await createPublishedEvent(organizerToken, { title: paidTitle, price: 150000 });
    check(Boolean(paid.typeId), 'event berbayar + kategori siap', paidTitle);

    const paidEmail = `peserta.bayar.e2e.email.${stamp}@example.test`;
    const paidOrder = await request('POST', '/api/orders', {
      body: {
        event_id: paid.event?.id,
        items: { [paid.typeId]: 1 },
        attendees: [{
          ticket_type_id: paid.typeId,
          name: 'Peserta Bayar E2E',
          email: paidEmail,
        }],
        idempotency_key: `e2e-email-paid-${stamp}`,
      },
    });
    check(/pending/i.test(String(paidOrder.json?.order?.status || '')),
      'event berbayar menunggu pembayaran', String(paidOrder.json?.order?.status));

    const paidOrderId = paidOrder.json?.order?.id;
    const paidAccess = paidOrder.json?.order_access_token;

    const beforePay = await request(
      'GET', `/api/tickets/my-tickets?order_id=${paidOrderId}`, { orderToken: paidAccess },
    );
    const beforeTickets = beforePay.json?.tickets ?? [];
    check(beforeTickets.length === 0, 'tiket BELUM terbit sebelum pembayaran',
      `count=${beforeTickets.length}`);
    check(!messages.some((m) => Array.isArray(m.to) && m.to.includes(paidEmail)),
      'email tiket belum dikirim sebelum pembayaran');

    const simulate = await request('POST', '/api/payments/simulate', {
      body: {
        order_id: paidOrderId,
        simulate_success: true,
        order_access_token: paidAccess,
      },
    });
    check(simulate.status === 200, 'pembayaran simulasi berhasil', `status=${simulate.status}`);

    const afterPay = await request(
      'GET', `/api/tickets/my-tickets?order_id=${paidOrderId}`, { orderToken: paidAccess },
    );
    const paidTickets = afterPay.json?.tickets ?? [];
    check(paidTickets.length === 1, 'tiket terbit setelah pembayaran dikonfirmasi backend',
      `count=${paidTickets.length}`);

    const paidTicket = paidTickets[0];
    const paidDelivery = await waitForDelivery(getOne, [paidTicket.id]);
    check(paidDelivery[0]?.status === 'SENT', 'email tiket berbayar terkirim setelah lunas',
      `${paidDelivery[0]?.status} ${String(paidDelivery[0]?.last_error || '').slice(0, 60)}`);
    check(
      String(paidDelivery[0]?.recipient || '').toLowerCase() === paidEmail,
      'penerima email berbayar = email pendaftaran',
      String(paidDelivery[0]?.recipient || ''),
    );

    const paidMessage = messages.find(
      (m) => Array.isArray(m.to) && m.to.includes(paidEmail),
    );
    const paidAttachment = Array.isArray(paidMessage?.attachments)
      ? paidMessage.attachments[0] : null;
    const paidPdf = paidAttachment?.content
      ? Buffer.from(String(paidAttachment.content), 'base64') : Buffer.alloc(0);
    check(paidPdf.subarray(0, 5).toString() === '%PDF-',
      'lampiran PDF tiket berbayar sah', `${paidPdf.length} byte`);
    check(
      String(paidAttachment?.filename || '') === 'E-TIKET Peserta Bayar E2E.pdf',
      'nama lampiran tiket berbayar memakai format wajib',
      String(paidAttachment?.filename || ''),
    );
    const paidPage = pdfPageSize(paidPdf);
    check(paidPage?.width === 842 && paidPage?.height === 594,
      'lampiran PDF berbayar 842x594 pt', `${paidPage?.width}x${paidPage?.height}`);
    const paidText = paidPdf;
    check(pdfContainsText(paidText, 'Peserta Bayar E2E'), 'PDF berbayar memuat nama peserta');
    // Judul panjang dipotong/ dibungkus oleh tata letak tiket, sehingga yang
    // diperiksa adalah awal judul yang pasti tampil.
    check(pdfContainsText(paidText, paidTitle.slice(0, 14)),
      'PDF berbayar memuat nama event', paidTitle.slice(0, 14));
    check(pdfContainsText(paidText, 'VIP'), 'PDF berbayar memuat kategori tiket', 'VIP');
    check(pdfContainsText(paidText, paidTicket.ticket_code), 'PDF berbayar memuat kode tiket');

    // ---------- C. Data pendaftaran tetap utuh ----------
    const attendeeRow = await getOne(
      `SELECT a.name, a.email FROM attendees a
         JOIN order_items oi ON oi.id = a.order_item_id
        WHERE oi.order_id = $1`,
      [paidOrderId],
    );
    check(String(attendeeRow?.email || '').toLowerCase() === paidEmail,
      'data peserta tersimpan benar di database', String(attendeeRow?.email || ''));
    check(String(attendeeRow?.name || '') === 'Peserta Bayar E2E',
      'nama peserta tersimpan benar', String(attendeeRow?.name || ''));

    await cleanup(query);
    await pool.end();
  } finally {
    shutdown();
  }

  console.log('');
  if (failures > 0) {
    console.error(`E2E TIKET+EMAIL: ${failures} PEMERIKSAAN GAGAL`);
    process.exitCode = 1;
  } else {
    console.log('E2E TIKET+EMAIL LULUS (endpoint penyedia email = stub lokal)');
  }
})().catch((error) => {
  console.error('E2E tiket+email gagal:', error.message);
  process.exitCode = 1;
});
