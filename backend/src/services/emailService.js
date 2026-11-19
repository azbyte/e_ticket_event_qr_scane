const nodemailer = require('nodemailer');
const config = require('../config/env');
const { query, getOne, pool } = require('../config/db');
const logger = require('../utils/logger');

/*
 * Email e-ticket. SMTP_HOST=json memakai Nodemailer jsonTransport (tidak mengirim
 * jaringan); SMTP kosong mencatat PENDING (tidak diklaim terkirim); SMTP nyata
 * hanya aktif bila SMTP_HOST dikonfigurasi. Token QR tidak pernah di-email.
 */
const transportMode = () => {
  if (process.env.SMTP_HOST === 'json') return 'json';
  return config.smtp.host ? 'smtp' : 'disabled';
};

let transport;
const getTransport = () => {
  const mode = transportMode();
  if (mode === 'disabled') return null;
  if (transport) return transport;
  transport = mode === 'json'
    ? nodemailer.createTransport({ jsonTransport: true })
    : nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.secure,
      ...(config.smtp.user ? { auth: { user: config.smtp.user, pass: config.smtp.pass } } : {}),
    });
  return transport;
};

const escapeHtml = (value) => String(value ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const loadTicketContext = (ticketId) => getOne(
  `SELECT t.id, t.ticket_code, t.status, a.name AS attendee_name,
          a.email AS attendee_email, tt.name AS ticket_type_name,
          e.title AS event_title, e.event_date, e.location, e.online_url,
          e.organizer_name, e.contact_info
   FROM tickets t JOIN events e ON e.id=t.event_id
   LEFT JOIN attendees a ON a.id=t.attendee_id
   LEFT JOIN ticket_types tt ON tt.id=t.ticket_type_id
   WHERE t.id=$1`,
  [ticketId]
);

const buildMessage = (ticket, recipient) => {
  const date = ticket.event_date ? new Date(ticket.event_date).toISOString() : '-';
  const url = `${config.appPublicUrl}/tickets/${ticket.id}`;
  const text = [
    `Halo ${ticket.attendee_name || 'Peserta'},`,
    `Tiket ${ticket.ticket_code} untuk ${ticket.event_title} telah terbit.`,
    `Jenis: ${ticket.ticket_type_name || '-'} | Jadwal: ${date}`,
    `Lokasi: ${ticket.location || ticket.online_url || '-'}`,
    `Buka e-ticket dan QR di aplikasi: ${url}`,
    'QR tidak dikirim lewat email demi keamanan. Jangan bagikan QR Anda.',
  ].join('\n');
  const html = `<p>Halo ${escapeHtml(ticket.attendee_name || 'Peserta')},</p>
<p>Tiket untuk <strong>${escapeHtml(ticket.event_title)}</strong> telah terbit.</p>
<ul><li>Kode: ${escapeHtml(ticket.ticket_code)}</li>
<li>Jenis: ${escapeHtml(ticket.ticket_type_name || '-')}</li>
<li>Jadwal: ${escapeHtml(date)}</li>
<li>Lokasi: ${escapeHtml(ticket.location || ticket.online_url || '-')}</li></ul>
<p><a href="${escapeHtml(url)}">Buka e-ticket di aplikasi</a>.</p>
<p>QR tidak dikirim lewat email demi keamanan. Jangan bagikan QR Anda.</p>`;
  return { from: config.smtp.from, to: recipient, subject: `E-Ticket ${ticket.event_title}`, text, html };
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
      result = await client.query(
        `UPDATE ticket_email_deliveries
         SET status=$3::"EmailDeliveryStatus",
             attempt_count=attempt_count+$4,
             last_error=$5,
             sent_at=CASE WHEN $3::"EmailDeliveryStatus"='SENT' THEN NOW() ELSE sent_at END,
             next_attempt_at=CASE WHEN $3::"EmailDeliveryStatus"='FAILED' THEN $6::timestamptz ELSE NULL END
         WHERE id=$1
         RETURNING *`,
        [existing.rows[0].id, recipient, status, incrementAttempt ? 1 : 0, error, retryAt],
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

const sendTicketEmail = async (ticketId, { recipient, force = false } = {}) => {
  try {
    const ticket = await loadTicketContext(ticketId);
    if (!ticket) return { status: 'SKIPPED', reason: 'ticket_not_found' };
    const to = String(recipient || ticket.attendee_email || '').trim();
    if (!to) return { status: 'SKIPPED', reason: 'no_recipient' };

    if (!force) {
      const existing = await getOne(
        'SELECT status FROM ticket_email_deliveries WHERE ticket_id=$1 AND recipient=$2',
        [ticketId, to]
      );
      if (existing?.status === 'SENT') return { status: 'SKIPPED', reason: 'already_sent' };
    }

    const mode = transportMode();
    const mailTransport = getTransport();
    if (!mailTransport) {
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'PENDING',
        error: 'SMTP_HOST belum dikonfigurasi; email BELUM dikirim.',
      });
      logger.warn('ticket_email_not_configured', { ticketId });
      return { status: 'NOT_CONFIGURED', delivery };
    }

    const info = await mailTransport.sendMail(buildMessage(ticket, to));
    const note = mode === 'json'
      ? 'json transport: dirender lokal, TIDAK dikirim ke jaringan.'
      : null;
    const delivery = await upsertDelivery({ ticketId, recipient: to, status: 'SENT', error: note });
    logger.info('ticket_email_accepted', { ticketId, mode, messageId: info.messageId });
    return { status: 'SENT', mode, delivery };
  } catch (error) {
    logger.error('ticket_email_failed', { ticketId, error: error.message });
    try {
      const ticket = await loadTicketContext(ticketId);
      const to = String(recipient || ticket?.attendee_email || 'unknown').trim();
      const delivery = await upsertDelivery({ ticketId, recipient: to, status: 'FAILED', error: error.message.slice(0, 500) });
      return { status: 'FAILED', delivery };
    } catch (_) {
      return { status: 'FAILED', reason: 'delivery_record_failed' };
    }
  }
};

const sendOrderTicketEmails = async (orderId) => {
  const rows = await query(
    `SELECT t.id FROM tickets t JOIN attendees a ON a.id=t.attendee_id
     JOIN order_items oi ON oi.id=a.order_item_id WHERE oi.order_id=$1`,
    [orderId]
  );
  const results = [];
  for (const row of rows) results.push({ ticketId: row.id, ...(await sendTicketEmail(row.id)) });
  return results;
};

const retryPendingDeliveries = async (limit = 20) => {
  const rows = await query(
    `SELECT ticket_id,recipient FROM ticket_email_deliveries
     WHERE status IN ('PENDING','FAILED') ORDER BY created_at ASC LIMIT $1`,
    [limit]
  );
  const results = [];
  for (const row of rows) {
    results.push(await sendTicketEmail(row.ticket_id, { recipient: row.recipient, force: true }));
  }
  return results;
};

module.exports = { transportMode, buildMessage, sendTicketEmail, sendOrderTicketEmails, retryPendingDeliveries };
