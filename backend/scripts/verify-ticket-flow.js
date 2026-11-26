#!/usr/bin/env node
/*
 * Verifikasi alur tiket end-to-end melalui HTTP API + database nyata.
 *
 * Fokus pada masalah yang dilaporkan:
 *  1. nama event pada tiket sama dengan nama event yang dibuat penyelenggara
 *     (bukan kosong/null/UUID/event lain),
 *  2. tiket terbit untuk event gratis setelah pendaftaran,
 *  3. status email dicatat jujur (tidak diklaim terkirim bila SMTP mati),
 *  4. kirim ulang email tidak membuat email ganda,
 *  5. orientasi landscape/portrait tersimpan dan dipakai template/PDF.
 *
 * Aplikasi Express dijalankan in-process pada port sementara sehingga tidak
 * perlu menyalakan server terpisah. Data uji memakai domain `.test` dan
 * dihapus kembali di akhir.
 *
 * Jalankan dari `backend/`: node scripts/verify-ticket-flow.js
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const PORT = 5099;
const BASE = `http://127.0.0.1:${PORT}`;
const stamp = Date.now();
const ORGANIZER_EMAIL = `org.verify.${stamp}@example.test`;
const ATTENDEE_EMAIL = `peserta.verify.${stamp}@example.test`;
const PASSWORD = 'Rahasia12345';

let failures = 0;
const check = (passed, name, detail = '') => {
  if (passed) {
    console.log(`PASS  ${name}${detail ? ` :: ${detail}` : ''}`);
  } else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? ` :: ${detail}` : ''}`);
  }
};

const request = async (
  method, route, { token, orderToken, body, raw = false } = {},
) => {
  const response = await fetch(`${BASE}${route}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(orderToken ? { 'X-Order-Access-Token': orderToken } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const buffer = Buffer.from(await response.arrayBuffer());
  if (raw) return { status: response.status, buffer, headers: response.headers };
  let json = null;
  try { json = JSON.parse(buffer.toString('utf8')); } catch (_e) { json = null; }
  return { status: response.status, json, text: buffer.toString('utf8') };
};

const cleanup = async (query) => {
  await query(
    `DELETE FROM ticket_email_deliveries WHERE ticket_id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
        WHERE lower(a.email) LIKE 'peserta.verify.%')`,
  );
  await query(
    `DELETE FROM tickets WHERE id IN (
       SELECT t.id FROM tickets t JOIN attendees a ON a.id = t.attendee_id
        WHERE lower(a.email) LIKE 'peserta.verify.%')`,
  );
  await query(`DELETE FROM attendees WHERE lower(email) LIKE 'peserta.verify.%'`);
  await query(
    `DELETE FROM order_items WHERE order_id IN (
       SELECT eo.id FROM event_orders eo JOIN events e ON e.id = eo.event_id
        WHERE e.title LIKE 'Event Verifikasi Tiket%')`,
  );
  await query(
    `DELETE FROM platform_transactions WHERE order_payment_id IN (
       SELECT op.id FROM order_payments op JOIN event_orders eo ON eo.id = op.order_id
        WHERE eo.event_id IN (SELECT id FROM events WHERE title LIKE 'Event Verifikasi Tiket%'))`,
  );
  await query(
    `DELETE FROM order_payments WHERE order_id IN (
       SELECT eo.id FROM event_orders eo JOIN events e ON e.id = eo.event_id
        WHERE e.title LIKE 'Event Verifikasi Tiket%')`,
  );
  await query(
    `DELETE FROM event_orders WHERE event_id IN (
       SELECT id FROM events WHERE title LIKE 'Event Verifikasi Tiket%')`,
  );
  await query(
    `DELETE FROM ticket_types WHERE event_id IN (
       SELECT id FROM events WHERE title LIKE 'Event Verifikasi Tiket%')`,
  );
  await query(`DELETE FROM events WHERE title LIKE 'Event Verifikasi Tiket%'`);
  await query(`DELETE FROM profiles WHERE lower(email) LIKE 'org.verify.%'`);
};

(async () => {
  const { query, pool } = require('../src/config/db');
  const app = require('../src/app');
  const emailService = require('../src/services/emailService');
  const emailQueue = require('../src/services/emailQueue');

  await cleanup(query);

  const server = await new Promise((resolve) => {
    const s = app.listen(PORT, '127.0.0.1', () => resolve(s));
  });
  console.log(`Backend uji berjalan di ${BASE}`);
  console.log(`Mode transport email: ${emailService.transportMode()}`);

  try {
    // ---------- Organizer + event gratis landscape ----------
    const register = await request('POST', '/api/auth/register', {
      body: {
        name: 'Organizer Verifikasi',
        email: ORGANIZER_EMAIL,
        password: PASSWORD,
        role: 'organizer',
      },
    });
    check([200, 201].includes(register.status), 'registrasi organizer',
      `status=${register.status}`);
    const organizerToken = register.json?.token ?? register.json?.data?.token;

    const eventTitle = `Event Verifikasi Tiket ${stamp}`;
    const start = new Date(Date.now() + 7 * 24 * 3600 * 1000);
    const createEvent = await request('POST', '/api/events', {
      token: organizerToken,
      body: {
        title: eventTitle,
        description: 'Event uji verifikasi tiket',
        category: 'Musik',
        event_format: 'OFFLINE',
        location: 'Jakarta',
        organizer_name: 'Organizer Verifikasi',
        contact_info: 'org@example.test',
        start_date_time: start.toISOString(),
        end_date_time: new Date(start.getTime() + 3 * 3600 * 1000).toISOString(),
        attendee_fields: [
          { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
          { key: 'email', label: 'Email', type: 'text', required: true },
        ],
      },
    });
    check([200, 201].includes(createEvent.status), 'pembuatan event',
      `status=${createEvent.status} ${createEvent.text.slice(0, 160)}`);
    const eventId = createEvent.json?.event?.id;

    const ticketType = await request('POST', `/api/events/${eventId}/ticket-types`, {
      token: organizerToken,
      body: { name: 'Reguler', price: 0, quota: 20, max_per_order: 1 },
    });
    const typeId = ticketType.json?.ticket_type?.id ?? ticketType.json?.data?.id;
    check(Boolean(typeId), 'kategori tiket gratis dibuat', `status=${ticketType.status}`);

    const publish = await request('POST', `/api/events/${eventId}/publish`, {
      token: organizerToken,
    });
    check(publish.status === 200, 'event dipublikasikan', `status=${publish.status}`);

    // ---------- Orientasi tersimpan ----------
    const saveOrientation = await request('PUT', `/api/events/${eventId}/ticket-design`, {
      token: organizerToken,
      body: {
        scope: 'ticket_type',
        ticket_type_id: typeId,
        orientation_only: true,
        orientation: 'portrait',
      },
    });
    check(
      saveOrientation.status === 200 &&
        saveOrientation.json?.design?.orientation === 'portrait',
      'orientasi portrait tersimpan per kategori',
      `status=${saveOrientation.status} orientation=${saveOrientation.json?.design?.orientation}`,
    );

    const designState = await request('GET', `/api/events/${eventId}/ticket-design`, {
      token: organizerToken,
    });
    const typeRow = (designState.json?.ticket_types ?? [])
      .find((row) => row.id === typeId);
    check(typeRow?.orientation === 'portrait',
      'orientasi terbaca kembali dari database', String(typeRow?.orientation));

    // Template mengikuti orientasi.
    const tplPortrait = await request(
      'GET', '/api/ticket-design-template?format=pdf&orientation=portrait', { raw: true },
    );
    const tplLandscape = await request(
      'GET', '/api/ticket-design-template?format=pdf&orientation=landscape', { raw: true },
    );
    const pageSize = (buffer) => {
      const m = buffer.toString('latin1')
        .match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
      return m ? { w: Number(m[1]), h: Number(m[2]) } : null;
    };
    const portraitSize = pageSize(tplPortrait.buffer);
    const landscapeSize = pageSize(tplLandscape.buffer);
    check(portraitSize && portraitSize.h > portraitSize.w,
      'template portrait vertikal', JSON.stringify(portraitSize));
    check(landscapeSize && landscapeSize.w > landscapeSize.h,
      'template landscape horizontal', JSON.stringify(landscapeSize));


    // ---------- Pendaftaran peserta (event gratis) ----------
    const order = await request('POST', '/api/orders', {
      body: {
        event_id: eventId,
        items: { [typeId]: 1 },
        attendees: [{
          ticket_type_id: typeId,
          name: 'Peserta Verifikasi',
          email: ATTENDEE_EMAIL,
        }],
        idempotency_key: `verify-${stamp}`,
      },
    });
    check([200, 201].includes(order.status), 'pendaftaran peserta tersimpan',
      `status=${order.status} ${order.text.slice(0, 160)}`);
    const orderId = order.json?.order?.id;
    const accessToken = order.json?.order_access_token;
    check(String(order.json?.order?.status).toUpperCase() === 'PAID',
      'event gratis langsung PAID', String(order.json?.order?.status));

    // Status email pada respons pendaftaran harus jujur.
    const signupEmail = order.json?.email_delivery;
    check(signupEmail != null, 'respons pendaftaran menyertakan status email');
    check(signupEmail?.delivered !== true,
      'email tidak diklaim terkirim saat SMTP tidak aktif',
      `transport=${signupEmail?.transport} delivered=${signupEmail?.delivered}`);

    // ---------- Tiket terbit dengan nama event yang benar ----------
    const myTickets = await request(
      'GET', `/api/tickets/my-tickets?order_id=${orderId}`, { orderToken: accessToken },
    );
    const tickets = myTickets.json?.tickets ?? [];
    check(tickets.length === 1, 'tepat satu tiket terbit', `jumlah=${tickets.length}`);
    const ticket = tickets[0] ?? {};
    check(ticket.event_title === eventTitle,
      'nama event pada tiket sama dengan nama event dibuat',
      `"${ticket.event_title}" vs "${eventTitle}"`);
    check(ticket.ticket_type_name === 'Reguler',
      'nama kategori tiket pada tiket benar', String(ticket.ticket_type_name));
    check(ticket.attendee_email?.toLowerCase() === ATTENDEE_EMAIL,
      'email peserta pada tiket benar', String(ticket.attendee_email));
    check(Boolean(ticket.token), 'token QR unik tersedia untuk pemilik');

    // Detail tiket juga membawa nama event + status email.
    const detail = await request(
      'GET', `/api/tickets/${ticket.id}?order_id=${orderId}`, { orderToken: accessToken },
    );
    check(detail.json?.ticket?.event_title === eventTitle,
      'detail tiket membawa nama event yang benar');
    check(detail.json?.email_delivery != null,
      'detail tiket menyertakan status email',
      String(detail.json?.email_delivery?.status));

    // ---------- PDF tiket ----------
    const pdf = await request(
      'GET', `/api/tickets/${ticket.id}/pdf`, { orderToken: accessToken, raw: true },
    );
    check(pdf.status === 200 && pdf.buffer.subarray(0, 5).toString() === '%PDF-',
      'PDF tiket dapat diunduh', `status=${pdf.status} bytes=${pdf.buffer.length}`);
    const ticketPage = pageSize(pdf.buffer);
    check(ticketPage && ticketPage.h > ticketPage.w,
      'PDF tiket mengikuti orientasi portrait kategori',
      JSON.stringify(ticketPage));

    // ---------- Kirim ulang email (tidak menggandakan) ----------
    const resendFirst = await request(
      'POST', `/api/tickets/${ticket.id}/email`, {
        orderToken: accessToken,
        body: { order_id: orderId },
      },
    );
    check(resendFirst.status === 200, 'endpoint kirim ulang email merespons',
      `status=${resendFirst.status}`);
    check(resendFirst.json?.delivered !== true,
      'kirim ulang tidak mengklaim terkirim saat SMTP mati',
      `status=${resendFirst.json?.delivery_status}`);

    const deliveries = await query(
      'SELECT status FROM ticket_email_deliveries WHERE ticket_id = $1',
      [ticket.id],
    );
    check(deliveries.length === 1,
      'hanya satu catatan delivery (tanpa duplikasi)', `jumlah=${deliveries.length}`);
    check(['PENDING', 'FAILED'].includes(deliveries[0]?.status),
      'status delivery mencatat belum terkirim', String(deliveries[0]?.status));

    const resendSecond = await request(
      'POST', `/api/tickets/${ticket.id}/email`, {
        orderToken: accessToken,
        body: { order_id: orderId },
      },
    );
    check(resendSecond.json?.delivered !== true,
      'kirim ulang berulang tetap tidak mengklaim terkirim');
    const deliveriesAfter = await query(
      'SELECT count(*)::int AS total FROM ticket_email_deliveries WHERE ticket_id = $1',
      [ticket.id],
    );
    check(deliveriesAfter[0]?.total === 1,
      'tidak ada catatan delivery ganda setelah kirim ulang',
      `jumlah=${deliveriesAfter[0]?.total}`);

    // ---------- Akses peserta lain ditolak ----------
    const unauthorized = await request(
      'GET', `/api/tickets/${ticket.id}?order_id=${orderId}`,
    );
    check([401, 403, 404].includes(unauthorized.status),
      'tiket tidak dapat dibaca tanpa kredensial', `status=${unauthorized.status}`);

    // ---------- Skenario B: event berbayar (portrait) ----------
    const paidTitle = `Event Verifikasi Tiket Berbayar ${stamp}`;
    const paidEvent = await request('POST', '/api/events', {
      token: organizerToken,
      body: {
        title: paidTitle,
        description: 'Event berbayar uji verifikasi',
        category: 'Musik',
        event_format: 'OFFLINE',
        location: 'Bandung',
        organizer_name: 'Organizer Verifikasi',
        contact_info: 'org@example.test',
        start_date_time: start.toISOString(),
        end_date_time: new Date(start.getTime() + 3 * 3600 * 1000).toISOString(),
        attendee_fields: [
          { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
          { key: 'email', label: 'Email', type: 'text', required: true },
        ],
      },
    });
    const paidEventId = paidEvent.json?.event?.id;
    const paidType = await request('POST', `/api/events/${paidEventId}/ticket-types`, {
      token: organizerToken,
      body: { name: 'VIP', price: 50000, quota: 10, max_per_order: 1 },
    });
    const paidTypeId = paidType.json?.ticket_type?.id ?? paidType.json?.data?.id;
    await request('POST', `/api/events/${paidEventId}/publish`, { token: organizerToken });
    // Orientasi portrait pada level event (tanpa unggah desain).
    const paidOrientation = await request(
      'PUT', `/api/events/${paidEventId}/ticket-design`, {
        token: organizerToken,
        body: { scope: 'event', orientation_only: true, orientation: 'portrait' },
      },
    );
    check(paidOrientation.json?.design?.orientation === 'portrait',
      'orientasi portrait event berbayar tersimpan');

    const paidAttendee = `peserta.verify.paid.${stamp}@example.test`;
    const paidOrder = await request('POST', '/api/orders', {
      body: {
        event_id: paidEventId,
        items: { [paidTypeId]: 1 },
        attendees: [{
          ticket_type_id: paidTypeId,
          name: 'Peserta Berbayar',
          email: paidAttendee,
        }],
        idempotency_key: `verify-paid-${stamp}`,
      },
    });
    const paidOrderId = paidOrder.json?.order?.id;
    const paidToken = paidOrder.json?.order_access_token;
    check(String(paidOrder.json?.order?.status).toUpperCase() === 'PENDING_PAYMENT',
      'event berbayar menunggu pembayaran', String(paidOrder.json?.order?.status));

    // Sebelum bayar: belum ada tiket.
    const beforePay = await query(
      `SELECT count(*)::int AS total FROM tickets t
         JOIN attendees a ON a.id = t.attendee_id
        WHERE lower(a.email) = lower($1)`,
      [paidAttendee],
    );
    check(beforePay[0]?.total === 0,
      'tiket BELUM terbit sebelum pembayaran berhasil', `jumlah=${beforePay[0]?.total}`);

    const payment = await request('POST', '/api/payments/simulate', {
      orderToken: paidToken,
      body: { order_id: paidOrderId, simulate_success: true },
    });
    check(
      payment.status === 200 &&
        String(payment.json?.payment?.status).toUpperCase() === 'PAID',
      'simulasi pembayaran berhasil',
      `status=${payment.json?.payment?.status}`,
    );
    check(payment.json?.email_delivery?.delivered !== true,
      'status email pembayaran tidak diklaim terkirim saat SMTP mati',
      `transport=${payment.json?.email_delivery?.transport}`);

    const afterPay = await request(
      'GET', `/api/tickets/my-tickets?order_id=${paidOrderId}`, { orderToken: paidToken },
    );
    const paidTickets = afterPay.json?.tickets ?? [];
    check(paidTickets.length === 1,
      'tiket terbit SETELAH pembayaran berhasil', `jumlah=${paidTickets.length}`);
    const paidTicket = paidTickets[0] ?? {};
    check(paidTicket.event_title === paidTitle,
      'nama event pada tiket berbayar benar', String(paidTicket.event_title));
    check(paidTicket.ticket_type_name === 'VIP',
      'kategori tiket berbayar benar', String(paidTicket.ticket_type_name));

    const paidPdf = await request(
      'GET', `/api/tickets/${paidTicket.id}/pdf`,
      { orderToken: paidToken, raw: true },
    );
    const paidPage = pageSize(paidPdf.buffer);
    check(paidPdf.status === 200 && paidPage && paidPage.h > paidPage.w,
      'PDF tiket berbayar portrait', JSON.stringify(paidPage));

    const paidDeliveries = await query(
      `SELECT status FROM ticket_email_deliveries WHERE ticket_id = $1`,
      [paidTicket.id],
    );
    check(paidDeliveries.length === 1 && paidDeliveries[0]?.status === 'PENDING',
      'delivery email tiket berbayar dicatat jujur',
      `${paidDeliveries.length} catatan status=${paidDeliveries[0]?.status}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    // Tunggu antrean email selesai sebelum koneksi database ditutup.
    await emailQueue.drain();
    await cleanup(query);
    await pool.end();
  }

  console.log(
    failures === 0 ? '\nSEMUA PEMERIKSAAN ALUR TIKET LULUS' : `\n${failures} PEMERIKSAAN GAGAL`,
  );
  if (failures > 0) process.exitCode = 1;
})().catch((error) => {
  console.error('Verifikasi alur tiket gagal:', error);
  process.exitCode = 1;
});

