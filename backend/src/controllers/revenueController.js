const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');

const toNumber = (value) => Number(value || 0);
const range = (req) => {
  const to = req.query.to ? new Date(req.query.to) : new Date();
  const from = req.query.from ? new Date(req.query.from) : new Date(to.getTime() - 29 * 86400000);
  if (!Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) || from > to) {
    const err = new Error('Rentang tanggal tidak valid'); err.statusCode = 400; throw err;
  }
  return { from: from.toISOString(), to: to.toISOString() };
};

const getAdminRevenueSummary = asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const totals = await getOne(
    `SELECT COALESCE(SUM(gross_amount),0) AS gross_amount,
            COALESCE(SUM(commission_amount),0) AS commission_amount,
            COALESCE(SUM(service_fee),0) AS service_fee,
            COALESCE(SUM(platform_revenue),0) AS platform_revenue,
            COALESCE(SUM(organizer_net_amount),0) AS organizer_net_amount,
            COUNT(*)::int AS transaction_count
     FROM platform_transactions WHERE created_at BETWEEN $1 AND $2`, [from, to]
  );
  const bySource = await query(
    `SELECT CASE WHEN order_payment_id IS NOT NULL THEN 'ORDER' ELSE 'SUBSCRIPTION' END AS source,
            COUNT(*)::int AS transaction_count,
            COALESCE(SUM(gross_amount),0) AS gross_amount,
            COALESCE(SUM(platform_revenue),0) AS platform_revenue
     FROM platform_transactions WHERE created_at BETWEEN $1 AND $2
     GROUP BY source ORDER BY source`, [from, to]
  );
  const daily = await query(
    `SELECT date_trunc('day', created_at)::date AS date,
            COALESCE(SUM(gross_amount),0) AS gross_amount,
            COALESCE(SUM(platform_revenue),0) AS platform_revenue
     FROM platform_transactions WHERE created_at BETWEEN $1 AND $2
     GROUP BY 1 ORDER BY 1`, [from, to]
  );
  res.json({
    success: true,
    range: { from, to },
    summary: Object.fromEntries(Object.entries(totals).map(([key, value]) => [key, toNumber(value)])),
    by_source: bySource.map((row) => Object.fromEntries(Object.entries(row).map(([k,v]) => [k,toNumber(v)]))),
    daily: daily.map((row) => ({ date: row.date, gross_amount: toNumber(row.gross_amount), platform_revenue: toNumber(row.platform_revenue) })),
  });
});

const listAdminTransactions = asyncHandler(async (req, res) => {
  const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
  const offset = Math.max(Number(req.query.offset) || 0, 0);
  const rows = await query(
    `SELECT pt.*, eo.order_number, e.title AS event_title, sp.invoice_number
     FROM platform_transactions pt
     LEFT JOIN order_payments op ON op.id=pt.order_payment_id
     LEFT JOIN event_orders eo ON eo.id=op.order_id
     LEFT JOIN events e ON e.id=eo.event_id
     LEFT JOIN subscription_payments sp ON sp.id=pt.subscription_payment_id
     ORDER BY pt.created_at DESC LIMIT $1 OFFSET $2`, [limit, offset]
  );
  res.json({ success: true, count: rows.length, limit, offset, transactions: rows });
});

const getOrganizerRevenue = asyncHandler(async (req, res) => {
  const { from, to } = range(req);
  const summary = await getOne(
    `SELECT COALESCE(SUM(pt.gross_amount),0) AS gross_amount,
            COALESCE(SUM(pt.commission_amount),0) AS commission_amount,
            COALESCE(SUM(pt.service_fee),0) AS service_fee,
            COALESCE(SUM(pt.organizer_net_amount),0) AS net_amount,
            COUNT(pt.id)::int AS transaction_count
     FROM platform_transactions pt JOIN order_payments op ON op.id=pt.order_payment_id
     JOIN event_orders eo ON eo.id=op.order_id JOIN events e ON e.id=eo.event_id
     WHERE e.created_by=$1 AND pt.created_at BETWEEN $2 AND $3`, [req.user.id, from, to]
  );
  const events = await query(
    `SELECT e.id, e.title, COALESCE(SUM(pt.gross_amount),0) AS gross_amount,
            COALESCE(SUM(pt.organizer_net_amount),0) AS net_amount, COUNT(pt.id)::int AS transaction_count
     FROM events e LEFT JOIN event_orders eo ON eo.event_id=e.id AND eo.status='PAID'
     LEFT JOIN order_payments op ON op.order_id=eo.id AND op.status='PAID'
     LEFT JOIN platform_transactions pt ON pt.order_payment_id=op.id
     WHERE e.created_by=$1 GROUP BY e.id,e.title ORDER BY gross_amount DESC`, [req.user.id]
  );
  res.json({ success: true, range: { from, to }, summary, events });
});

module.exports = { getAdminRevenueSummary, listAdminTransactions, getOrganizerRevenue };
