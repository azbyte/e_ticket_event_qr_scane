const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const { notify } = require('../services/notificationService');

const BILLING_INTERVALS = new Set(['MONTHLY', 'YEARLY']);

const addInterval = (date, interval) => {
  const next = new Date(date);
  if (interval === 'YEARLY') next.setUTCFullYear(next.getUTCFullYear() + 1);
  else next.setUTCMonth(next.getUTCMonth() + 1);
  return next;
};

const priceFor = (plan, interval) => {
  if (plan.is_free) return 0;
  return Number(interval === 'YEARLY' ? plan.price_yearly : plan.price_monthly) || 0;
};

const loadPlanWithFeatures = async (planId) => {
  const plan = await getOne('SELECT * FROM plans WHERE id = $1', [planId]);
  if (!plan) return null;
  const features = await query('SELECT key, value FROM plan_features WHERE plan_id = $1', [planId]);
  return {
    id: plan.id,
    name: plan.name,
    description: plan.description,
    status: String(plan.status).toLowerCase(),
    is_free: plan.is_free,
    price_monthly: plan.price_monthly === null ? null : Number(plan.price_monthly),
    price_yearly: plan.price_yearly === null ? null : Number(plan.price_yearly),
    max_active_events: plan.max_active_events,
    max_tickets_per_event: plan.max_tickets_per_event,
    max_staff_per_event: plan.max_staff_per_event,
    features: Object.fromEntries(features.map((f) => [f.key, f.value])),
  };
};

const toSubscriptionDto = (row, plan, payment) => ({
  id: row.id,
  organizer_id: row.organizer_id,
  plan_id: row.plan_id,
  status: String(row.status).toLowerCase(),
  billing_interval: row.billing_interval ? row.billing_interval.toLowerCase() : null,
  starts_at: row.starts_at,
  ends_at: row.ends_at,
  auto_renew: row.auto_renew,
  plan,
  latest_payment: payment
    ? {
      id: payment.id,
      invoice_number: payment.invoice_number,
      amount: Number(payment.amount),
      status: String(payment.status).toLowerCase(),
      payment_reference: payment.payment_reference,
      paid_at: payment.paid_at,
      expires_at: payment.expires_at,
    }
    : null,
});

const getCurrentSubscription = async (organizerId) => {
  const row = await getOne(
    `SELECT * FROM subscriptions
     WHERE organizer_id = $1 AND status IN ('ACTIVE', 'PENDING_PAYMENT')
     ORDER BY created_at DESC LIMIT 1`,
    [organizerId]
  );
  if (!row) return null;
  const plan = await loadPlanWithFeatures(row.plan_id);
  const payment = await getOne(
    'SELECT * FROM subscription_payments WHERE subscription_id = $1 ORDER BY created_at DESC LIMIT 1',
    [row.id]
  );
  return { row, plan, payment };
};


const getMySubscription = asyncHandler(async (req, res) => {
  const current = await getCurrentSubscription(req.user.id);
  if (!current) return res.json({ success: true, subscription: null });
  res.json({ success: true, subscription: toSubscriptionDto(current.row, current.plan, current.payment) });
});


/**
 * POST /api/organizer/subscription
 * Berlangganan atau mengganti paket. Paket gratis langsung aktif; paket berbayar
 * membuat invoice PENDING_PAYMENT.
 */
const subscribe = asyncHandler(async (req, res) => {
  const { planId } = req.body;
  const interval = String(req.body.billingInterval || 'MONTHLY').toUpperCase();
  if (!planId) {
    res.status(400);
    throw new Error('planId wajib diisi');
  }
  if (!BILLING_INTERVALS.has(interval)) {
    res.status(400);
    throw new Error('billingInterval harus MONTHLY atau YEARLY');
  }

  const plan = await getOne('SELECT * FROM plans WHERE id = $1', [planId]);
  if (!plan) {
    res.status(404);
    throw new Error('Paket tidak ditemukan');
  }
  if (String(plan.status) !== 'ACTIVE') {
    res.status(409);
    throw new Error('Paket tidak aktif');
  }

  const amount = priceFor(plan, interval);
  if (!plan.is_free && amount <= 0) {
    res.status(409);
    throw new Error('Harga paket untuk interval ini belum ditetapkan');
  }

  const current = await getCurrentSubscription(req.user.id);
  if (current && current.row.plan_id === plan.id && String(current.row.status) === 'ACTIVE') {
    res.status(409);
    throw new Error('Anda sudah berlangganan paket ini');
  }

  const now = new Date();
  const endsAt = addInterval(now, interval);
  const subscriptionStatus = amount === 0 ? 'ACTIVE' : 'PENDING_PAYMENT';
  const client = await pool.connect();
  let subscriptionId;
  let paymentId;
  try {
    await client.query('BEGIN');
    if (current) {
      const updated = await client.query(
        `UPDATE subscriptions
         SET plan_id = $1, status = $2, billing_interval = $3,
             starts_at = $4, ends_at = $5, updated_at = NOW()
         WHERE id = $6
         RETURNING id`,
        [plan.id, subscriptionStatus, interval, now.toISOString(), endsAt.toISOString(), current.row.id]
      );
      subscriptionId = updated.rows[0].id;
      await client.query(
        `INSERT INTO subscription_history
           (id, subscription_id, from_plan_id, to_plan_id, changed_by_id, reason, created_at)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())`,
        [subscriptionId, current.row.plan_id, plan.id, req.user.id, `Ganti paket ke ${plan.name} (${interval})`]
      );
    } else {
      const inserted = await client.query(
        `INSERT INTO subscriptions
           (id, organizer_id, plan_id, status, billing_interval, starts_at, ends_at, auto_renew, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, false, NOW(), NOW())
         RETURNING id`,
        [req.user.id, plan.id, subscriptionStatus, interval, now.toISOString(), endsAt.toISOString()]
      );
      subscriptionId = inserted.rows[0].id;
      await client.query(
        `INSERT INTO subscription_history
           (id, subscription_id, to_plan_id, changed_by_id, reason, created_at)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, NOW())`,
        [subscriptionId, plan.id, req.user.id, `Langganan baru ${plan.name} (${interval})`]
      );
    }

    const invoiceNumber = `INV-SUB-${now.getTime()}-${String(Math.floor(Math.random() * 1e4)).padStart(4, '0')}`;
    const payment = await client.query(
      `INSERT INTO subscription_payments
         (id, subscription_id, invoice_number, amount, method, status, payment_reference, paid_at, expires_at, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, NOW())
       RETURNING id`,
      [
        subscriptionId,
        invoiceNumber,
        amount,
        'SIMULATED_VIRTUAL_ACCOUNT',
        amount === 0 ? 'PAID' : 'PENDING',
        `SUB-${invoiceNumber}`,
        amount === 0 ? now.toISOString() : null,
        amount === 0 ? null : addInterval(now, 'MONTHLY').toISOString(),
      ]
    );
    paymentId = payment.rows[0].id;

    if (amount === 0) {
      await client.query(
        `INSERT INTO platform_transactions
           (id, subscription_payment_id, gross_amount, commission_rate, commission_amount,
            service_fee, platform_revenue, organizer_net_amount, created_at)
         VALUES (gen_random_uuid(), $1, 0, 0, 0, 0, 0, 0, NOW())
         ON CONFLICT (subscription_payment_id) DO NOTHING`,
        [paymentId]
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }

  await notify({
    userId: req.user.id,
    category: 'SUBSCRIPTION',
    title: amount === 0 ? 'Langganan aktif' : 'Invoice langganan dibuat',
    body: amount === 0
      ? `Paket ${plan.name} sudah aktif.`
      : `Invoice paket ${plan.name} sebesar ${amount} menunggu pembayaran.`,
    targetUrl: '/organizer/subscription',
    metadata: { subscriptionId },
    dedupeKey: `subscription:${subscriptionId}:${paymentId}`,
  });
  const refreshed = await getCurrentSubscription(req.user.id);
  res.status(201).json({
    success: true,
    subscription: toSubscriptionDto(refreshed.row, refreshed.plan, refreshed.payment),
    payment_status: amount === 0 ? 'paid' : 'pending_payment',
  });
});


const cancelSubscription = asyncHandler(async (req, res) => {
  const current = await getCurrentSubscription(req.user.id);
  if (!current) {
    res.status(404);
    throw new Error('Tidak ada langganan aktif');
  }
  await query(
    "UPDATE subscriptions SET status = 'CANCELLED', auto_renew = false, updated_at = NOW() WHERE id = $1",
    [current.row.id]
  );
  await query(
    `INSERT INTO subscription_history
       (id, subscription_id, from_plan_id, changed_by_id, reason, created_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, NOW())`,
    [current.row.id, current.row.plan_id, req.user.id, 'Langganan dibatalkan oleh organizer']
  );
  await notify({
    userId: req.user.id,
    category: 'SUBSCRIPTION',
    title: 'Langganan dibatalkan',
    body: 'Langganan Anda telah dibatalkan.',
    targetUrl: '/organizer/subscription',
    metadata: { subscriptionId: current.row.id },
    dedupeKey: `subscription-cancel:${current.row.id}`,
  });
  res.json({ success: true, message: 'Langganan dibatalkan' });
});

const listMyPayments = asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT sp.* FROM subscription_payments sp
     JOIN subscriptions s ON s.id = sp.subscription_id
     WHERE s.organizer_id = $1
     ORDER BY sp.created_at DESC LIMIT 50`,
    [req.user.id]
  );
  res.json({
    success: true,
    count: rows.length,
    payments: rows.map((row) => ({
      id: row.id,
      subscription_id: row.subscription_id,
      invoice_number: row.invoice_number,
      amount: Number(row.amount),
      status: String(row.status).toLowerCase(),
      payment_reference: row.payment_reference,
      paid_at: row.paid_at,
      expires_at: row.expires_at,
      created_at: row.created_at,
    })),
  });
});

const listAdminSubscriptions = asyncHandler(async (req, res) => {
  const { status, plan_id, search, limit = 50, offset = 0 } = req.query;
  const whereClauses = [];
  const params = [];

  if (status && status !== 'all') {
    params.push(status.toUpperCase());
    whereClauses.push(`s.status = $${params.length}`);
  }
  if (plan_id) {
    params.push(plan_id);
    whereClauses.push(`s.plan_id = $${params.length}`);
  }
  if (search && search.trim()) {
    params.push(`%${search.trim().toLowerCase()}%`);
    whereClauses.push(`(LOWER(p.name) LIKE $${params.length} OR LOWER(p.email) LIKE $${params.length})`);
  }

  const whereStr = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
  const pageLimit = Math.min(Number(limit) || 50, 100);
  const pageOffset = Number(offset) || 0;

  const rows = await query(
    `SELECT s.*, p.name AS organizer_name, p.email AS organizer_email, pl.name AS plan_name, pl.price_monthly, pl.price_yearly
     FROM subscriptions s
     LEFT JOIN profiles p ON p.id = s.organizer_id
     LEFT JOIN plans pl ON pl.id = s.plan_id
     ${whereStr}
     ORDER BY s.created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, pageLimit, pageOffset]
  );

  const countRow = await getOne(
    `SELECT COUNT(*)::bigint AS total
     FROM subscriptions s
     LEFT JOIN profiles p ON p.id = s.organizer_id
     ${whereStr}`,
    params
  );

  res.json({
    success: true,
    count: rows.length,
    total: Number(countRow?.total) || rows.length,
    subscriptions: rows.map((r) => ({
      id: r.id,
      organizer_id: r.organizer_id,
      organizer_name: r.organizer_name || '-',
      organizer_email: r.organizer_email || '-',
      plan_id: r.plan_id,
      plan_name: r.plan_name || '-',
      status: String(r.status).toLowerCase(),
      billing_interval: r.billing_interval ? r.billing_interval.toLowerCase() : null,
      starts_at: r.starts_at,
      ends_at: r.ends_at,
      auto_renew: r.auto_renew,
      created_at: r.created_at,
    })),
  });
});

module.exports = {
  getMySubscription,
  subscribe,
  cancelSubscription,
  listMyPayments,
  listAdminSubscriptions,
  loadPlanWithFeatures,
  toSubscriptionDto,
};
