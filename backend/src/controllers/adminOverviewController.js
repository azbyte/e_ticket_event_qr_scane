const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');

/**
 * GET /api/admin/overview
 * Real statistics for Admin Dashboard:
 * - Event counts per status
 * - Active organizers count
 * - Total orders, tickets sold, participants, check-ins
 * - Financials: gross, commission, service fee, platform revenue, organizer net
 */
const getAdminOverview = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const txParams = [];
  const txConditions = [];

  if (from) {
    txParams.push(new Date(from).toISOString());
    txConditions.push(`created_at >= $${txParams.length}`);
  }
  if (to) {
    txParams.push(new Date(to).toISOString());
    txConditions.push(`created_at <= $${txParams.length}`);
  }

  const txWhere = txConditions.length > 0 ? `WHERE ${txConditions.join(' AND ')}` : '';

  const [
    eventsByStatus,
    activeOrganizersRow,
    totalOrdersRow,
    ticketsSoldRow,
    participantsRow,
    checkInsRow,
    finRow,
    weeklyTrends,
  ] = await Promise.all([
    query(`SELECT status, COUNT(*)::bigint AS count FROM events GROUP BY status`),
    getOne(`SELECT COUNT(DISTINCT created_by)::bigint AS count FROM events`),
    getOne(`SELECT COUNT(*)::bigint AS count FROM event_orders`),
    getOne(`SELECT COUNT(*)::bigint AS count FROM tickets`),
    getOne(`SELECT COUNT(*)::bigint AS count FROM attendees`),
    getOne(`SELECT COUNT(*)::bigint AS count FROM check_ins`),
    getOne(`
      SELECT
        COALESCE(SUM(gross_amount), 0)::numeric AS gross_amount,
        COALESCE(SUM(commission_amount), 0)::numeric AS commission_amount,
        COALESCE(SUM(service_fee), 0)::numeric AS service_fee,
        COALESCE(SUM(platform_revenue), 0)::numeric AS platform_revenue,
        COALESCE(SUM(organizer_net_amount), 0)::numeric AS organizer_net_amount
      FROM platform_transactions
      ${txWhere}
    `, txParams),
    query(`
      SELECT
        DATE_TRUNC('week', created_at) AS week_start,
        COALESCE(SUM(gross_amount), 0)::numeric AS gross,
        COALESCE(SUM(platform_revenue), 0)::numeric AS revenue,
        COUNT(*)::bigint AS tx_count
      FROM platform_transactions
      GROUP BY week_start
      ORDER BY week_start DESC
      LIMIT 5
    `),
  ]);

  const eventStats = {
    total: 0,
    published: 0,
    pending_review: 0,
    revision_requested: 0,
    rejected: 0,
    suspended: 0,
    draft: 0,
  };

  for (const row of eventsByStatus) {
    const st = String(row.status).toLowerCase();
    const c = Number(row.count) || 0;
    eventStats.total += c;
    if (st === 'published' || st === 'approved') eventStats.published += c;
    else if (st === 'pending_review') eventStats.pending_review += c;
    else if (st === 'revision_requested') eventStats.revision_requested += c;
    else if (st === 'rejected') eventStats.rejected += c;
    else if (st === 'suspended') eventStats.suspended += c;
    else if (st === 'draft') eventStats.draft += c;
  }

  res.json({
    success: true,
    overview: {
      events: eventStats,
      active_organizers: Number(activeOrganizersRow?.count) || 0,
      total_orders: Number(totalOrdersRow?.count) || 0,
      tickets_sold: Number(ticketsSoldRow?.count) || 0,
      total_participants: Number(participantsRow?.count) || 0,
      total_check_ins: Number(checkInsRow?.count) || 0,
      financials: {
        gross_amount: Number(finRow?.gross_amount) || 0,
        commission_amount: Number(finRow?.commission_amount) || 0,
        service_fee: Number(finRow?.service_fee) || 0,
        platform_revenue: Number(finRow?.platform_revenue) || 0,
        organizer_net_amount: Number(finRow?.organizer_net_amount) || 0,
      },
      trends: weeklyTrends.map((w) => ({
        week: w.week_start,
        gross: Number(w.gross),
        revenue: Number(w.revenue),
        transactions: Number(w.tx_count),
      })),
    },
  });
});

module.exports = { getAdminOverview };
