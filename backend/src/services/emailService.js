const nodemailer = require('nodemailer');
const config = require('../config/env');
const { query, getOne, pool } = require('../config/db');
const ticketDesignService = require('./ticketDesignService');
const logger = require('../utils/logger');

/*
 * Email e-ticket.
 *
 * Mode transport ditentukan HANYA dari environment (tidak ada kredensial di
 * dalam kode):
 *  - `smtp`  : SMTP_HOST berisi host nyata dan konfigurasi valid -> email
 *              benar-benar dikirim.
 *  - `json`  : transport uji lokal (tanpa jaringan). Hanya diizinkan saat
 *              NODE_ENV=test; status pengiriman TIDAK pernah dilaporkan SENT
 *              karena tidak ada email yang keluar dari server.
 *  - `disabled`: SMTP_HOST kosong/`json` di luar test, atau konfigurasi belum
 *              lengkap -> delivery dicatat PENDING secara jujur, tidak pernah
 *              diklaim terkirim.
 *
 * Token QR tidak pernah di-email; QR hanya ada di lampiran PDF.
 */
const isTestEnv = () => String(process.env.NODE_ENV || config.nodeEnv).toLowerCase() === 'test';

/** Alamat pengirim valid: `alamat@domain` atau `Nama <alamat@domain>`. */
const EMAIL_FROM_PATTERN = /^(?:[^<>]*<)?[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+>?$/;

/*
 * Konfigurasi SMTP dibaca ulang dari environment setiap kali dipakai agar
 * perubahan .env (atau kegagalan konfigurasi) tidak "nyangkut" pada nilai yang
 * sudah di-cache saat proses pertama kali start.
 */
const smtpConfig = () => ({
  host: String(process.env.SMTP_HOST || '').trim(),
  port: Number(process.env.SMTP_PORT || 587),
  secure: process.env.SMTP_SECURE === 'true',
  user: String(process.env.SMTP_USER || '').trim(),
  pass: String(process.env.SMTP_PASS || ''),
  from: String(process.env.EMAIL_FROM || '').trim(),
});

/**
 * Status konfigurasi SMTP tanpa membocorkan nilai rahasia.
 *
 * @returns {{
 *   mode: 'smtp'|'json'|'disabled',
 *   configured: boolean,
 *   auth: boolean,
 *   port: number,
 *   from: string|null,
 *   missing: string[],
 *   reason: string|null
 * }}
 */
const smtpStatus = () => {
  const smtp = smtpConfig();
  const missing = [];
  const base = {
    mode: 'disabled',
    configured: false,
    auth: false,
    port: smtp.port,
    from: smtp.from || null,
    missing,
    reason: null,
  };

  if (smtp.host === 'json') {
    if (isTestEnv()) {
      return { ...base, mode: 'json', configured: true };
    }
    return {
      ...base,
      reason: 'SMTP_HOST=json hanya untuk pengujian otomatis; email BELUM dikirim ke jaringan.',
    };
  }

  if (!smtp.host) {
    missing.push('SMTP_HOST');
    return {
      ...base,
      reason: 'SMTP_HOST belum dikonfigurasi; email BELUM dikirim.',
    };
  }

  if (!Number.isInteger(smtp.port) || smtp.port < 1 || smtp.port > 65535) {
    missing.push('SMTP_PORT');
    return {
      ...base,
      reason: 'SMTP_PORT tidak valid (harus 1-65535); email BELUM dikirim.',
    };
  }

  // Autentikasi opsional (relay lokal), tetapi bila salah satu diisi maka
  // pasangannya wajib ada. Nilai password tidak pernah dilaporkan.
  if (smtp.user && !smtp.pass) {
    missing.push('SMTP_PASS');
    return {
      ...base,
      reason: 'SMTP_USER diisi tetapi SMTP_PASS kosong; email BELUM dikirim.',
    };
  }
  if (!smtp.user && smtp.pass) {
    missing.push('SMTP_USER');
    return {
      ...base,
      reason: 'SMTP_PASS diisi tetapi SMTP_USER kosong; email BELUM dikirim.',
    };
  }

  if (!smtp.from || !EMAIL_FROM_PATTERN.test(smtp.from)) {
    missing.push('EMAIL_FROM');
    return {
      ...base,
      reason: 'EMAIL_FROM belum diisi atau bukan alamat email yang valid; email BELUM dikirim.',
    };
  }

  return {
    ...base,
    mode: 'smtp',
    configured: true,
    auth: Boolean(smtp.user),
    from: smtp.from,
  };
};

const transportMode = () => smtpStatus().mode;

/** Pesan alasan saat transport tidak tersedia (disimpan sebagai last_error). */
const unavailableReason = () =>
  smtpStatus().reason || 'Layanan email belum dikonfigurasi; email BELUM dikirim.';

let transport;
let transportKey = '';
const getTransport = () => {
  const status = smtpStatus();
  if (status.mode === 'disabled') return null;
  const smtp = smtpConfig();
  const key = status.mode === 'json'
    ? 'json'
    : `${smtp.host}:${smtp.port}:${smtp.secure}:${smtp.user}:${smtp.from}`;
  if (transport && key === transportKey) return transport;
  transportKey = key;
  transport = status.mode === 'json'
    ? nodemailer.createTransport({ jsonTransport: true })
    : nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.secure,
      ...(smtp.user ? { auth: { user: smtp.user, pass: smtp.pass } } : {}),
    });
  return transport;
};

/** Buang transport dari cache agar konfigurasi/kegagalan tidak "nyangkut". */
const resetTransport = () => { transport = null; transportKey = ''; };

const escapeHtml = (value) => String(value ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/**
 * Data minimal yang dibutuhkan email + lampiran tiket.
 *
 * Nama event SELALU diambil dari tabel `events` melalui relasi
 * `tickets.event_id` (bukan dari payload/order), sehingga tidak mungkin
 * tertukar dengan event lain atau bernilai null/undefined.
 */
const loadTicketContext = (ticketId) => getOne(
  `SELECT t.id, t.ticket_code, t.status, t.event_id, t.ticket_type_id,
          t.attendee_id, a.name AS attendee_name, a.email AS attendee_email,
          tt.name AS ticket_type_name,
          e.title AS event_title, e.event_date, e.end_date_time, e.location,
          e.online_url, e.organizer_name, e.contact_info
   FROM tickets t
   JOIN events e ON e.id = t.event_id
   LEFT JOIN attendees a ON a.id = t.attendee_id
   LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
   WHERE t.id = $1`,
  [ticketId]
);

const formatEventDate = (value) => {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'long',
    timeStyle: 'short',
    timeZone: 'Asia/Jakarta',
  }).format(date);
};

/** Label nama event: selalu nilai dari DB; '-' hanya bila data benar-benar kosong. */
const eventTitleOf = (ticket) => {
  const title = String(ticket?.event_title ?? '').trim();
  return title.length > 0 ? title : '(nama event tidak tersedia)';
};

const buildMessage = (ticket, recipient, { attachment = null } = {}) => {
  const date = formatEventDate(ticket.event_date);
  const eventTitle = eventTitleOf(ticket);
  const location = String(ticket?.location || ticket?.online_url || '').trim() || '-';
  // Tautan menuju halaman tiket publik; token akses guest tidak pernah
  // ditempatkan pada URL (PRD §8.2 / C-02).
  const url = ticket.event_id
    ? `${config.appPublicUrl}/e/${ticket.event_id}/ticket/${ticket.id}`
    : `${config.appPublicUrl}/tickets/${ticket.id}`;
  const attendeeName = String(ticket?.attendee_name || '').trim() || 'Peserta';
  const ticketType = String(ticket?.ticket_type_name || '').trim() || '-';
  const text = [
    `Halo ${attendeeName},`,
    `Tiket ${ticket.ticket_code} untuk ${eventTitle} telah terbit.`,
    `Jenis: ${ticketType} | Jadwal: ${date}`,
    `Lokasi: ${location}`,
    `Buka e-ticket dan QR dari perangkat yang dipakai saat memesan: ${url}`,
    attachment
      ? 'E-ticket PDF dengan QR unik terlampir pada email ini. Jangan bagikan QR Anda.'
      : 'Buka e-ticket di aplikasi untuk melihat QR unik. Jangan bagikan QR Anda.',
  ].join('\n');
  const html = `<p>Halo ${escapeHtml(attendeeName)},</p>
<p>Tiket untuk <strong>${escapeHtml(eventTitle)}</strong> telah terbit.</p>
<ul><li>Kode: ${escapeHtml(ticket.ticket_code || '-')}</li>
<li>Jenis: ${escapeHtml(ticketType)}</li>
<li>Jadwal: ${escapeHtml(date)}</li>
<li>Lokasi: ${escapeHtml(location)}</li></ul>
<p><a href="${escapeHtml(url)}">Buka e-ticket di aplikasi</a>.</p>
${attachment ? '<p>E-ticket PDF dengan QR unik terlampir pada email ini.</p>' : '<p>Buka e-ticket di aplikasi untuk melihat QR unik.</p>'}`;
  return {
    from: smtpConfig().from,
    to: recipient,
    subject: `E-Ticket ${eventTitle} - ${ticket.ticket_code || ''}`.trim(),
    text,
    html,
    ...(attachment ? { attachments: [attachment] } : {}),
  };
};

const upsertDelivery = async ({ ticketId, recipient, status, error, incrementAttempt = true }) => {
  const retryAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT pg_catalog.pg_advisory_xact_lock(
         pg_catalog.hashtextextended($1::uuid::text || ':' || $2::varchar(320), 0)
       )`,
      [ticketId, recipient],
    );
    const existing = await client.query(
      'SELECT id FROM ticket_email_deliveries WHERE ticket_id=$1 AND recipient=$2 FOR UPDATE',
      [ticketId, recipient],
    );
    let result;
    if (existing.rows[0]) {
      // Catatan: parameter penerima ($2) tidak dipakai pada UPDATE. Parameter
      // yang dikirim tetapi tidak dirujuk membuat PostgreSQL menolak query
      // ("could not determine data type of parameter"), sehingga catatan
      // kegagalan/percobaan ulang tidak pernah tersimpan.
      result = await client.query(
        `UPDATE ticket_email_deliveries
         SET status=$2::"EmailDeliveryStatus",
             attempt_count=attempt_count+$3,
             last_error=$4,
             sent_at=CASE WHEN $2::"EmailDeliveryStatus"='SENT' THEN NOW() ELSE sent_at END,
             next_attempt_at=CASE WHEN $2::"EmailDeliveryStatus"='FAILED' THEN $5::timestamptz ELSE NULL END
         WHERE id=$1
         RETURNING *`,
        [existing.rows[0].id, status, incrementAttempt ? 1 : 0, error, retryAt],
      );
    } else {
      result = await client.query(
        `INSERT INTO ticket_email_deliveries
           (id,ticket_id,recipient,status,attempt_count,last_error,sent_at,next_attempt_at,created_at)
         VALUES (gen_random_uuid(),$1::uuid,$2::varchar(320),$3::"EmailDeliveryStatus",$4,$5,
                 CASE WHEN $3::"EmailDeliveryStatus"='SENT' THEN NOW() ELSE NULL END,
                 CASE WHEN $3::"EmailDeliveryStatus"='FAILED' THEN $6::timestamptz ELSE NULL END,NOW())
         RETURNING *`,
        [ticketId, recipient, status, incrementAttempt ? 1 : 0, error, retryAt],
      );
    }
    await client.query('COMMIT');
    return result.rows[0];
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* transaction already ended */ }
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Tandai tiket sedang menunggu pengiriman (status belum terkirim) tanpa
 * menunggu SMTP. Dipakai oleh antrean pengiriman agar peserta/klien dapat
 * melihat status jujur segera setelah tiket terbit.
 *
 * Catatan: catatan yang sudah `SENT` tidak pernah diturunkan kembali.
 */
const markQueued = async (ticketId, recipient, reason) => {
  const to = String(recipient || '').trim();
  if (!to) return null;
  const existing = await getOne(
    `SELECT status FROM ticket_email_deliveries
      WHERE ticket_id=$1 AND lower(recipient)=lower($2)
      ORDER BY created_at DESC LIMIT 1`,
    [ticketId, to],
  );
  if (existing?.status === 'SENT') return null;
  return upsertDelivery({
    ticketId,
    recipient: to,
    status: 'PENDING',
    error: reason || 'Menunggu pengiriman email.',
    incrementAttempt: false,
  });
};

/**
 * Lampiran e-ticket PDF (desain Organizer + QR unik).
 *
 * Mengembalikan `{ attachment, error }`. Tiket adalah lampiran WAJIB: bila
 * rendering gagal, email tidak dikirim dan kegagalan dicatat apa adanya
 * (lebih baik gagal jujur daripada mengirim email tanpa tiket).
 */
const buildPdfAttachment = async (ticketId) => {
  try {
    const ticket = await ticketDesignService.loadTicketForPdf(ticketId);
    if (!ticket) return { attachment: null, error: 'data_tiket_tidak_ditemukan' };
    const buffer = await ticketDesignService.buildTicketPdf(ticket);
    if (!buffer || buffer.length === 0) {
      return { attachment: null, error: 'pdf_tiket_kosong' };
    }
    return {
      attachment: {
        filename: `tiket-${ticket.ticket_code || ticketId}.pdf`,
        content: buffer,
        contentType: 'application/pdf',
      },
      error: null,
    };
  } catch (error) {
    logger.error('ticket_pdf_render_failed', { ticketId, error: error.message });
    return { attachment: null, error: `pdf_tiket_gagal: ${error.message}` };
  }
};

/**
 * Kirim e-ticket (PDF lampiran wajib) ke email peserta.
 *
 * Aturan penting:
 *  - Penerima SELALU email pada data peserta tiket (`attendees.email`);
 *    `recipient` hanya boleh menunjuk email yang sama (mis. saat retry).
 *  - Satu tiket hanya dikirim sekali per penerima. Pengiriman ulang cukup
 *    mengembalikan status `SKIPPED/already_sent` (tidak ada email ganda),
 *    kecuali `force` dipakai saat penerima berbeda.
 *  - Status `SENT` hanya dicatat setelah transport menerima pesan. Transport
 *    uji (json) dicatat `PENDING` karena tidak ada email yang keluar.
 */
const sendTicketEmail = async (ticketId, { recipient, force = false } = {}) => {
  try {
    const ticket = await loadTicketContext(ticketId);
    if (!ticket) return { status: 'SKIPPED', reason: 'ticket_not_found' };

    const attendeeEmail = String(ticket.attendee_email || '').trim();
    const requested = String(recipient || '').trim();
    // Email peserta adalah sumber kebenaran; alamat lain tidak pernah dipakai.
    const to = attendeeEmail || requested;
    if (!to) {
      const delivery = await upsertDelivery({
        ticketId, recipient: 'unknown', status: 'FAILED',
        error: 'Email peserta kosong pada data pendaftaran.',
      });
      return { status: 'FAILED', reason: 'no_recipient', delivery };
    }
    if (attendeeEmail && requested && requested.toLowerCase() !== attendeeEmail.toLowerCase()) {
      return { status: 'SKIPPED', reason: 'recipient_mismatch' };
    }

    const existing = await getOne(
      `SELECT status, attempt_count FROM ticket_email_deliveries
        WHERE ticket_id=$1 AND lower(recipient)=lower($2)
        ORDER BY created_at DESC LIMIT 1`,
      [ticketId, to]
    );
    if (existing?.status === 'SENT' && !force) {
      return { status: 'SKIPPED', reason: 'already_sent' };
    }

    const mode = transportMode();
    const mailTransport = getTransport();
    if (!mailTransport) {
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'PENDING', error: unavailableReason(),
      });
      logger.warn('ticket_email_not_configured', { ticketId, mode });
      return { status: 'NOT_CONFIGURED', reason: unavailableReason(), delivery };
    }

    const { attachment, error: pdfError } = await buildPdfAttachment(ticketId);
    if (!attachment) {
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'FAILED',
        error: `Lampiran tiket gagal dibuat (${pdfError || 'unknown'}).`,
      });
      logger.error('ticket_email_attachment_failed', { ticketId, pdfError });
      return { status: 'FAILED', reason: 'attachment_failed', error: pdfError, delivery };
    }

    const info = await mailTransport.sendMail(buildMessage(ticket, to, { attachment }));
    if (mode === 'json') {
      // Tidak ada email yang keluar dari server pada transport uji.
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'PENDING',
        error: 'Transport uji (SMTP_HOST=json): email TIDAK dikirim.',
      });
      logger.warn('ticket_email_test_transport', { ticketId, messageId: info.messageId });
      return { status: 'NOT_SENT_TEST_TRANSPORT', mode, delivery };
    }

    const delivery = await upsertDelivery({ ticketId, recipient: to, status: 'SENT', error: null });
    logger.info('ticket_email_accepted', {
      ticketId, mode, messageId: info.messageId, accepted: info.accepted, rejected: info.rejected,
    });
    return { status: 'SENT', mode, messageId: info.messageId, delivery };
  } catch (error) {
    logger.error('ticket_email_failed', { ticketId, error: error.message });
    // Transport yang gagal (mis. kredensial/timeout) di-cache jangan dipakai lagi.
    resetTransport();
    try {
      const ticket = await loadTicketContext(ticketId);
      const to = String(recipient || ticket?.attendee_email || '').trim() || 'unknown';
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'FAILED', error: String(error.message).slice(0, 500),
      });
      return { status: 'FAILED', reason: error.message, delivery };
    } catch (recordError) {
      // Pencatatan gagal juga tidak boleh disembunyikan.
      logger.error('ticket_email_failure_record_failed', {
        ticketId, error: recordError.message,
      });
      return { status: 'FAILED', reason: error.message, recordError: recordError.message };
    }
  }
};

/**
 * Kirim tiket untuk satu order (setelah pembayaran lunas / event gratis).
 *
 * Mengembalikan array hasil per tiket. Kegagalan email TIDAK membatalkan
 * penerbitan tiket: tiket tetap ada di database dan dapat dikirim ulang.
 * Idempoten: pemanggilan berulang tidak membuat email ganda.
 */
const sendOrderTicketEmails = async (orderId) => {
  const rows = await query(
    `SELECT t.id, a.email AS attendee_email
       FROM tickets t
       JOIN attendees a ON a.id = t.attendee_id
       JOIN order_items oi ON oi.id = a.order_item_id
      WHERE oi.order_id = $1
      ORDER BY a.name ASC`,
    [orderId]
  );
  const results = [];
  for (const row of rows) {
    const outcome = await sendTicketEmail(row.id);
    results.push({ ticketId: row.id, recipient: row.attendee_email || null, ...outcome });
  }
  return results;
};

/**
 * Kirim ulang tiket yang belum terkirim (PENDING/FAILED).
 *
 * Retry tidak pernah membuat tiket baru dan tidak pernah mengirim ganda:
 * pengiriman yang sudah `SENT` tidak ikut terpilih.
 */
const retryPendingDeliveries = async (limit = 20) => {
  const rows = await query(
    `SELECT ticket_id, recipient FROM ticket_email_deliveries
     WHERE status IN ('PENDING','FAILED')
       AND attempt_count < 5
       AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
     ORDER BY created_at ASC LIMIT $1`,
    [limit]
  );
  const results = [];
  for (const row of rows) {
    const outcome = await sendTicketEmail(row.ticket_id, { recipient: row.recipient });
    results.push({ ticketId: row.ticket_id, recipient: row.recipient, ...outcome });
  }
  return results;
};

/** Status email tiket untuk ditampilkan (tanpa kredensial). */
const emailDeliveryStatusForTicket = (ticketId) => getOne(
  `SELECT id, recipient, status, attempt_count, last_error, sent_at, next_attempt_at
     FROM ticket_email_deliveries WHERE ticket_id = $1
     ORDER BY created_at DESC LIMIT 1`,
  [ticketId]
);

module.exports = {
  smtpStatus,
  transportMode,
  resetTransport,
  buildMessage,
  loadTicketContext,
  markQueued,
  sendTicketEmail,
  sendOrderTicketEmails,
  retryPendingDeliveries,
  emailDeliveryStatusForTicket,
};

