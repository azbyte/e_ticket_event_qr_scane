const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { getAuthorizedOrder, loadOrderById, hashAccessToken } = require('./orderController');
const { serializePayment } = require('../utils/orderResponse');
const { ensureOrderTokenHashes } = require('../services/ticketTokenService');
const { ensureOrderPublicTicketCodes } = require('../services/ticketCodeService');
const emailQueue = require('../services/emailQueue');
const { notify } = require('../services/notificationService');
const config = require('../config/env');
const logger = require('../utils/logger');

/**
 * Jalankan efek samping "best-effort" setelah pembayaran tersimpan.
 *
 * Kegagalan hanya dicatat pada log dan TIDAK membatalkan pembayaran/tiket yang
 * sudah terbit di database. Dikumpulkan dalam satu helper agar blok `try/catch`
 * berulang tidak lagi ditulis manual (sumber kesalahan kurung/try yang hilang)
 * sementara perilaku, label log, dan urutan eksekusi tetap sama.
 *
 * @param {string} label nama event log saat tugas gagal
 * @param {() => Promise<any>} task tugas yang dijalankan
 * @param {object} context field tambahan pada log (mis. `{ orderId }`)
 * @returns {Promise<any|null>} hasil `task`, atau `null` bila gagal
 */
const runBestEffort = async (label, task, context = {}) => {
  try {
    return await task();
  } catch (error) {
    logger.error(label, { ...context, error: error.message });
    return null;
  }
};

const getPayment = asyncHandler(async (req, res) => {
  const accessToken = req.get('X-Order-Access-Token') || req.body?.order_access_token;
  const order = await getAuthorizedOrder(
    req.params.orderId,
    req.user,
    accessToken,
  );
  if (!order) {
    res.status(404);
    throw new Error('Payment not found');
  }
  const payment = order.order_payments?.[0];
  if (!payment) {
    res.status(404);
    throw new Error('Payment not found');
  }
  res.json({ success: true, payment: serializePayment(payment) });
});

/**
 * Simulasi pembayaran VA (non-produksi).
 *
 * Setelah pembayaran sukses: token QR tiket disiapkan (hash), email e-ticket
 * dicoba dikirim ke tiket masing-masing, dan notifikasi dibuat untuk pembeli.
 * Semua efek samping ini bersifat best-effort dan tidak membatalkan pembayaran.
 */
const simulatePayment = asyncHandler(async (req, res) => {
  // Izinkan simulasi di luar produksi secara default agar demo/dev lokal tidak
  // terblokir saat env belum menyetel flag; di produksi wajib eksplisit true.
  if (config.nodeEnv === 'production' && !config.simulatedPaymentsEnabled) {
    res.status(404);
    throw new Error('Simulated payments are disabled');
  }
  const { order_id: orderId, simulate_success: simulateSuccess } = req.body;
  if (!orderId || typeof simulateSuccess !== 'boolean') {
    res.status(400);
    throw new Error('Order ID and a boolean simulation result are required');
  }
  const accessToken = req.get('X-Order-Access-Token') || req.body.order_access_token;
  const order = await getAuthorizedOrder(orderId, req.user, accessToken);
  if (!order) {
    res.status(404);
    throw new Error('Order not found');
  }

  const currentStatus = String(order.status).toUpperCase();
  if (currentStatus === 'PAID') {
    res.status(400);
    throw new Error('Order has already been paid');
  }
  if (currentStatus === 'CANCELLED') {
    res.status(400);
    throw new Error('Order has been cancelled');
  }
  if (order.expires_at && new Date(order.expires_at) < new Date()) {
    res.status(400);
    throw new Error('Order has expired');
  }

  const rpc = await query(
    `SELECT public.simulate_event_payment($1, $2, $3, $4)`,
    [orderId, req.user ? req.user.id : null, accessToken ? hashAccessToken(accessToken) : null, simulateSuccess]
  );
  const paymentId = rpc[0]?.simulate_event_payment;
  if (!paymentId) throw new Error('Payment simulation failed');

  const payment = await getOne('SELECT * FROM order_payments WHERE id = $1', [paymentId]);
  if (!payment) throw new Error('Payment not found');

  let emailResults = [];
  if (payment.status === 'PAID') {
    // Token QR (hash) disiapkan lebih dulu agar email/PDF memakai token final.
    await runBestEffort(
      'ticket_token_backfill_failed',
      () => ensureOrderTokenHashes(orderId),
      { orderId },
    );
    // ID publik ringkas (`ETK-XXXXXX`) ditetapkan sebelum email/PDF dibuat.
    await runBestEffort(
      'ticket_public_code_backfill_failed',
      () => ensureOrderPublicTicketCodes(orderId),
      { orderId },
    );
    // Dijadwalkan, bukan ditunggu: respons pembayaran tidak boleh menunggu
    // SMTP. Tiket sudah terbit pada transaksi pembayaran di database.
    emailResults = await runBestEffort(
      'ticket_email_dispatch_failed',
      () => emailQueue.enqueueOrder(orderId),
      { orderId },
    ) ?? [];
    const latest = await loadOrderById(orderId);
    if (latest?.purchaser_id) {
      await notify({
        userId: latest.purchaser_id,
        category: 'PAYMENT_PAID',
        title: 'Pembayaran berhasil',
        body: `Pembayaran untuk order ${latest.order_number} berhasil. E-ticket Anda sudah tersedia.`,
        targetUrl: `/orders/${latest.id}`,
        metadata: { orderId: latest.id },
        dedupeKey: `payment-paid:${payment.id}`,
      });
    }
  } else if (payment.status === 'FAILED') {
    const latest = await loadOrderById(orderId);
    if (latest?.purchaser_id) {
      await notify({
        userId: latest.purchaser_id,
        category: 'PAYMENT_FAILED',
        title: 'Pembayaran gagal',
        body: `Pembayaran untuk order ${latest.order_number} gagal. Silakan coba lagi.`,
        targetUrl: `/orders/${latest.id}`,
        metadata: { orderId: latest.id },
        dedupeKey: `payment-failed:${payment.id}`,
      });
    }
  }

  res.json({
    success: true,
    payment: serializePayment(payment),
    // `delivered` hanya true bila seluruh tiket order sudah benar-benar
    // terkirim; `queued` berarti pengiriman masih diproses di latar.
    email_delivery: emailQueue.summarize(emailResults),
  });
});

module.exports = { getPayment, simulatePayment };
