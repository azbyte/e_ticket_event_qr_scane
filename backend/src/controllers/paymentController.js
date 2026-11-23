const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { getAuthorizedOrder, loadOrderById, hashAccessToken } = require('./orderController');
const { serializePayment } = require('../utils/orderResponse');
const { ensureOrderTokenHashes } = require('../services/ticketTokenService');
const emailService = require('../services/emailService');
const { notify } = require('../services/notificationService');
const config = require('../config/env');
const logger = require('../utils/logger');

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
  if (config.nodeEnv !== 'test' && !config.simulatedPaymentsEnabled) {
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
    try {
      await ensureOrderTokenHashes(orderId);
    } catch (error) {
      logger.error('ticket_token_backfill_failed', { orderId, error: error.message });
    }
    try {
      emailResults = await emailService.sendOrderTicketEmails(orderId);
    } catch (error) {
      logger.error('ticket_email_dispatch_failed', { orderId, error: error.message });
    }
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
    email_delivery: {
      configured: emailService.transportMode() !== 'disabled',
      transport: emailService.transportMode(),
      results: emailResults.map((item) => ({ ticket_id: item.ticketId, status: item.status })),
    },
  });
});

module.exports = { getPayment, simulatePayment };
