const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { serializeEvent } = require('../utils/eventResponse');
const { serializeEventSummary } = require('../utils/eventSummary');
const { writeAuditLog } = require('../utils/auditLog');

const getOwnedEvent = async (eventId, user) => {
  const event = await getOne('SELECT id, created_by, status FROM events WHERE id = $1', [eventId]);
  if (!event) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (user.role !== 'admin' && event.created_by !== user.id) {
    const err = new Error('You do not own this event'); err.statusCode = 403; throw err;
  }
  return event;
};

const countForEvent = async (table, eventId) => {
  const row = await getOne(`SELECT COUNT(*)::bigint AS cnt FROM ${table} WHERE event_id = $1`, [eventId]);
  return Number(row.cnt) || 0;
};

const buildSummary = async (event) => {
  const [ticketTypes, pendingOrders, participants, checkedIn] = await Promise.all([
    query('SELECT price, quota, sold, held FROM ticket_types WHERE event_id = $1', [event.id]),
    query('SELECT id FROM event_orders WHERE event_id = $1 AND status = $2', [event.id, 'PENDING_PAYMENT']),
    countForEvent('tickets', event.id),
    countForEvent('check_ins', event.id),
  ]);
  let totalTicketsSold = 0;
  let totalTicketsRemaining = 0;
  let grossSales = 0;
  for (const tt of ticketTypes) {
    const sold = Number(tt.sold) || 0;
    const held = Number(tt.held) || 0;
    totalTicketsSold += sold;
    totalTicketsRemaining += Math.max(0, Number(tt.quota) - sold - held);
    grossSales += Number(tt.price) * sold;
  }
  return serializeEventSummary(
    event,
    { ticketsSold: totalTicketsSold, ticketsRemaining: totalTicketsRemaining, grossSales },
    pendingOrders.length,
    participants,
    checkedIn,
  );
};

const getEventSummary = asyncHandler(async (req, res) => {
  const event = await getOwnedEvent(req.params.id, req.user);
  const summary = await buildSummary(event);
  res.json({ success: true, summary });
});

const getEventSummaries = asyncHandler(async (req, res) => {
  const rows = await query('SELECT id, status FROM events WHERE created_by = $1', [req.user.id]);
  const summaries = await Promise.all(rows.map(buildSummary));
  res.json({ success: true, summaries });
});

const getOrganizerOverview = asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT e.*, ec.name AS category_name
     FROM events e LEFT JOIN event_categories ec ON ec.id = e.category_id
     WHERE e.created_by = $1 ORDER BY e.updated_at DESC`,
    [req.user.id]
  );
  const overview = {
    draft_count: 0, pending_review_count: 0, revision_count: 0, published_count: 0,
    tickets_sold: 0, pending_orders: 0, participants: 0, checked_in: 0, gross_sales: 0,
    recent_events: [],
  };
  for (const event of rows) {
    const summary = await buildSummary(event);
    if (summary.status === 'draft') overview.draft_count += 1;
    if (summary.status === 'pending_review') overview.pending_review_count += 1;
    if (summary.status === 'revision_requested') overview.revision_count += 1;
    if (summary.status === 'approved' || summary.status === 'published') overview.published_count += 1;
    overview.tickets_sold += summary.tickets_sold;
    overview.pending_orders += summary.pending_orders;
    overview.participants += summary.participants;
    overview.checked_in += summary.checked_in;
    overview.gross_sales += summary.gross_sales;
  }
  overview.recent_events = rows.slice(0, 5).map((event) => serializeEvent({
    ...event,
    event_categories: event.category_name ? [{ name: event.category_name }] : [],
  }));
  res.json({ success: true, overview });
});

const getEventSalesPoints = asyncHandler(async (req, res) => {
  await getOwnedEvent(req.params.id, req.user);
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);
  start.setUTCDate(start.getUTCDate() - 6);
  const startIso = start.toISOString();
  const [tickets, checkIns] = await Promise.all([
    query('SELECT purchased_at FROM tickets WHERE event_id = $1 AND purchased_at >= $2', [req.params.id, startIso]),
    query('SELECT checked_in_at FROM check_ins WHERE event_id = $1 AND checked_in_at >= $2', [req.params.id, startIso]),
  ]);
  const byDate = {};
  for (let offset = 0; offset < 7; offset += 1) {
    const date = new Date(start);
    date.setUTCDate(start.getUTCDate() + offset);
    const key = date.toISOString().slice(0, 10);
    byDate[key] = { tickets: 0, check_ins: 0 };
  }
  for (const ticket of tickets) {
    const key = String(ticket.purchased_at).slice(0, 10);
    if (byDate[key]) byDate[key].tickets += 1;
  }
  for (const checkIn of checkIns) {
    const key = String(checkIn.checked_in_at).slice(0, 10);
    if (byDate[key]) byDate[key].check_ins += 1;
  }
  res.json({ success: true, points: Object.entries(byDate).map(([date, counts]) => ({ date, ...counts })) });
});

const moderateEvent = asyncHandler(async (req, res) => {
  const status = String(req.body.status || '').toUpperCase();
  const allowed = ['APPROVED', 'REVISION_REQUESTED', 'REJECTED', 'SUSPENDED', 'PUBLISHED'];
  const note = typeof req.body.note === 'string'
    ? req.body.note.trim()
    : (typeof req.body.reason === 'string' ? req.body.reason.trim() : '');
  if (!allowed.includes(status)) {
    res.status(400);
    throw new Error('Invalid moderation decision');
  }
  if (status !== 'APPROVED' && note.length === 0) {
    res.status(400);
    throw new Error('A moderation note is required for this decision');
  }
  const rpc = await query(
    `SELECT public.moderate_event($1, $2, $3, $4, $5)`,
    [req.params.id, req.user.id, req.user.email, status, note || null]
  );
  if (!rpc.length) {
    res.status(404);
    throw new Error('Event not found');
  }

  await writeAuditLog({
    actor: req.user,
    action: status === 'SUSPENDED' ? 'SUSPEND_EVENT' : (status === 'PUBLISHED' || status === 'APPROVED' ? 'RESTORE_EVENT' : `MODERATE_EVENT_${status}`),
    entityType: 'EVENT',
    entityId: req.params.id,
    reason: note || null,
    details: `Moderation decision: ${status}${note ? ` - ${note}` : ''}`,
    metadata: { status, note },
  });

  // Function mengembalikan composite SETOF events; ambil ulang baris agar
  // response berbentuk objek konsisten dengan endpoint event lain.
  const updated = await getOne(
    `SELECT e.*, c.name AS category_name
     FROM events e LEFT JOIN event_categories c ON c.id = e.category_id
     WHERE e.id = $1`,
    [req.params.id]
  );
  if (!updated) {
    res.status(404);
    throw new Error('Event not found');
  }
  res.json({
    success: true,
    event: serializeEvent({
      ...updated,
      event_categories: updated.category_name ? [{ name: updated.category_name }] : null,
    }),
  });
});

module.exports = {
  getEventSummary,
  getEventSummaries,
  getOrganizerOverview,
  getEventSalesPoints,
  moderateEvent,
};
