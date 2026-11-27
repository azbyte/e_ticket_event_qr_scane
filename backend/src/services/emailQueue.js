/**
 * Antrean pengiriman e-ticket di dalam proses (tanpa dependensi runtime baru).
 *
 * Tujuan:
 *  - Respons pendaftaran/pembayaran TIDAK menunggu SMTP. Tiket sudah terbit dan
 *    tercatat; pengiriman email dijadwalkan pada tick berikutnya.
 *  - Status langsung dicatat `PENDING` ("belum dikirim"/"sedang dikirim")
 *    sehingga UI tidak pernah mengklaim email terkirim sebelum benar-benar
 *    diterima transport.
 *  - Satu tiket tidak pernah dikirim ganda: ada penjaga in-flight per tiket dan
 *    `sendTicketEmail` menolak mengirim ulang catatan yang sudah `SENT`.
 *  - Kegagalan dicatat `FAILED` beserta alasannya dan dapat dicoba ulang lewat
 *    worker periodik atau endpoint kirim ulang.
 *
 * Catatan arsitektur: antrean ini hidup di memori proses. Bila proses restart
 * saat pengiriman berjalan, catatan tetap `PENDING` di database dan akan
 * diambil worker retry berikutnya — tidak ada email yang hilang diam-diam.
 */
const { query } = require('../config/db');
const emailService = require('./emailService');
const logger = require('../utils/logger');

/** ticketId -> Promise hasil pengiriman (penjaga anti kirim ganda). */
const inFlight = new Map();

const QUEUED_REASON = 'Menunggu pengiriman email oleh server.';

const isSending = (ticketId) => inFlight.has(String(ticketId || ''));

const stats = () => ({
  in_flight: inFlight.size,
  transport: emailService.smtpStatus().mode,
});

/** Jalankan pengiriman satu tiket pada tick berikutnya. */
const runTicket = (ticketId, options) => {
  const key = String(ticketId);
  if (inFlight.has(key)) return inFlight.get(key);
  const job = new Promise((resolve) => {
    setImmediate(async () => {
      try {
        resolve(await emailService.sendTicketEmail(ticketId, options));
      } catch (error) {
        // sendTicketEmail sudah menangani error internal; ini hanya jaring
        // pengaman agar antrean tidak pernah menghasilkan unhandled rejection.
        logger.error('ticket_email_queue_job_failed', {
          ticketId, error: error.message,
        });
        resolve({ status: 'FAILED', reason: error.message });
      } finally {
        inFlight.delete(key);
      }
    });
  });
  inFlight.set(key, job);
  return job;
};

/**
 * Jadwalkan pengiriman e-ticket untuk satu tiket.
 *
 * @returns {Promise<{ticketId: string, recipient: string|null, status: string,
 *   reason?: string, duplicate?: boolean}>}
 */
const enqueueTicket = async (ticketId, { recipient, force = false, reason } = {}) => {
  const key = String(ticketId);
  if (inFlight.has(key)) {
    return { ticketId: key, recipient: recipient || null, status: 'QUEUED', duplicate: true };
  }

  const status = emailService.smtpStatus();
  let to = String(recipient || '').trim();
  if (!to) {
    const ticket = await emailService.loadTicketContext(ticketId);
    to = String(ticket?.attendee_email || '').trim();
  }

  // SMTP/penyedia belum siap: catat status belum terkirim tanpa mencoba jaringan.
  if (!status.configured) {
    await emailService.markQueued(ticketId, to, reason || status.reason);
    return {
      ticketId: key,
      recipient: to || null,
      status: 'NOT_CONFIGURED',
      reason: status.reason,
    };
  }

  await emailService.markQueued(ticketId, to, reason || QUEUED_REASON);
  runTicket(ticketId, { recipient: to || undefined, force });
  return { ticketId: key, recipient: to || null, status: 'QUEUED' };
};

/** Daftar tiket pada satu order (sumber penerima = email peserta). */
const listOrderTickets = (orderId) => query(
  `SELECT t.id, a.email AS attendee_email
     FROM tickets t
     JOIN attendees a ON a.id = t.attendee_id
     JOIN order_items oi ON oi.id = a.order_item_id
    WHERE oi.order_id = $1
    ORDER BY a.name ASC`,
  [orderId],
);

/**
 * Jadwalkan pengiriman semua tiket pada satu order TANPA menunggu SMTP.
 * Pemanggilan berulang idempoten (yang sudah SENT tidak dikirim lagi).
 */
const enqueueOrder = async (orderId) => {
  const rows = await listOrderTickets(orderId);
  const results = [];
  for (const row of rows) {
    const outcome = await enqueueTicket(row.id, {
      recipient: row.attendee_email || undefined,
    });
    results.push(outcome);
  }
  return results;
};

/** Tunggu seluruh pekerjaan antrean selesai (dipakai test/script/verifikasi). */
const drain = async () => {
  if (inFlight.size === 0) return [];
  return Promise.allSettled([...inFlight.values()]);
};

/**
 * Ambil catatan PENDING/FAILED yang sudah waktunya dicoba ulang dan masukkan
 * ke antrean. Tidak pernah membuat tiket baru dan tidak mengirim yang SENT.
 */
const retryPending = async (limit = 20) => {
  const rows = await query(
    `SELECT ticket_id, recipient FROM ticket_email_deliveries
      WHERE status IN ('PENDING','FAILED')
        AND attempt_count < 5
        AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
      ORDER BY created_at ASC LIMIT $1`,
    [limit],
  );
  const results = [];
  for (const row of rows) {
    results.push(await enqueueTicket(row.ticket_id, { recipient: row.recipient }));
  }
  return results;
};

/**
 * Worker retry periodik untuk proses server. Interval di-unref agar tidak
 * menahan proses tetap hidup (mis. saat test/CLI).
 */
const startRetryWorker = ({ intervalMs = 5 * 60 * 1000 } = {}) => {
  const status = emailService.smtpStatus();
  // Worker hanya berguna bila ada transport yang benar-benar mengirim email.
  if (!status.configured || status.mode === 'json') {
    logger.warn('ticket_email_retry_worker_skipped', {
      transport: status.mode,
      reason: status.reason,
    });
    return null;
  }
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const queued = await retryPending(20);
      if (queued.length > 0) {
        logger.info('ticket_email_retry_scheduled', { count: queued.length });
      }
      await drain();
    } catch (error) {
      logger.error('ticket_email_retry_failed', { error: error.message });
    } finally {
      running = false;
    }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
};

/**
 * Ringkasan status pengiriman untuk respons API.
 *
 * `delivered` hanya true bila seluruh tiket order benar-benar `SENT` (atau
 * memang sudah pernah terkirim). `queued` menandakan pekerjaan masih berjalan
 * di antrean, sehingga klien menampilkan "sedang/belum dikirim" — bukan sukses.
 */
const summarize = (results = []) => {
  const status = emailService.smtpStatus();
  const delivered = results.length > 0 && results.every(
    (item) => item.status === 'SENT' || item.reason === 'already_sent',
  );
  const queued = results.some((item) => item.status === 'QUEUED');
  const notConfigured = results.some((item) => item.status === 'NOT_CONFIGURED');
  const failed = results.some((item) => item.status === 'FAILED');
  return {
    configured: status.configured && status.mode !== 'json',
    transport: status.mode,
    delivered,
    queued,
    status: delivered
      ? 'SENT'
      : failed
        ? 'FAILED'
        : notConfigured
          ? 'NOT_CONFIGURED'
          : queued
            ? 'QUEUED'
            : 'PENDING',
    reason: status.reason,
    results: results.map((item) => ({
      ticket_id: item.ticketId || item.ticket_id || null,
      recipient: item.recipient || null,
      status: item.status || 'PENDING',
      reason: item.reason || null,
    })),
  };
};

module.exports = {
  isSending,
  stats,
  summarize,
  enqueueTicket,
  enqueueOrder,
  retryPending,
  drain,
  startRetryWorker,
};
