const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { getAuthorizedOrder } = require('./orderController');
const { assertScanPermission, normalizeTicketStatus, commitCheckIn } = require('./checkInController');
const tokens = require('../services/ticketTokenService');
const emailService = require('../services/emailService');
const ticketDesignService = require('../services/ticketDesignService');
const logger = require('../utils/logger');

const EVENT_SELECT = `t.*, e.id AS events_id, e.title AS events_title,
 e.description AS events_description, e.event_date AS events_event_date,
 e.end_date_time AS events_end_date_time, e.time_zone AS events_time_zone,
 e.location AS events_location, e.online_url AS events_online_url,
 e.event_format AS events_event_format, e.contact_info AS events_contact_info,
 e.organizer_name AS events_organizer_name, e.public_info AS events_public_info,
 e.status AS events_status, e.is_public AS events_is_public,
 e.created_by AS events_created_by, e.category_id AS events_category_id,
 e.created_at AS events_created_at, e.updated_at AS events_updated_at`;

const mapTicket = (row) => ({
  ...row,
  events: {
    id: row.events_id, title: row.events_title, description: row.events_description,
    event_date: row.events_event_date, end_date_time: row.events_end_date_time,
    time_zone: row.events_time_zone, location: row.events_location,
    online_url: row.events_online_url, event_format: row.events_event_format,
    contact_info: row.events_contact_info, organizer_name: row.events_organizer_name,
    public_info: row.events_public_info, status: row.events_status,
    is_public: row.events_is_public, created_by: row.events_created_by,
    category_id: row.events_category_id, created_at: row.events_created_at,
    updated_at: row.events_updated_at,
  },
});

/**
 * Bentuk tiket untuk response klien Flutter.
 *
 * Kontrak `TicketModel` memakai status `valid`/`checked_in` dan field
 * `attendee_name`/`attendee_email`/`order_id`, sedangkan kolom legacy menyimpan
 * `active`/`used` dan tidak memiliki `order_id`. Normalisasi dilakukan di layer
 * presentasi tanpa mengubah nilai di database.
 */
const presentTicketForClient = async (row, { includeToken = false } = {}) => ({
  ...(await tokens.presentTicket(mapTicket(row), { includeToken })),
  status: normalizeTicketStatus(row.status),
});

const belongsToOrder = async (ticket, order) => {
  if (!order || !ticket.attendee_id) return false;
  const rows = await query(
    `SELECT 1 FROM attendees a JOIN order_items oi ON oi.id = a.order_item_id
     WHERE a.id = $1 AND oi.order_id = $2`, [ticket.attendee_id, order.id]
  );
  return rows.length > 0;
};

const resolveAccess = async (req, ticket) => {
  if (req.user?.role === 'admin') return { allowed: true, owner: false };
  if (req.user && ticket.user_id === req.user.id) return { allowed: true, owner: true };
  // order_id dari query diutamakan; bila tidak ada, pakai order milik tiket
  // (dipakai jalur unduh PDF agar tautannya bisa dipakai langsung).
  const orderIdFromQuery = typeof req.query.order_id === 'string' ? req.query.order_id : null;
  const orderId = orderIdFromQuery || ticket.order_id || null;
  if (orderId) {
    const order = await getAuthorizedOrder(orderId, req.user, req.get('X-Order-Access-Token'));
    if (await belongsToOrder(ticket, order)) return { allowed: true, owner: true };
  }
  return { allowed: false, owner: false };
};

const getMyTickets = asyncHandler(async (req, res) => {
  const orderId = typeof req.query.order_id === 'string' ? req.query.order_id : null;
  let rows;
  if (!req.user) {
    if (!orderId) { res.status(401); throw new Error('Authentication or order access token required'); }
    const order = await getAuthorizedOrder(orderId, null, req.get('X-Order-Access-Token'));
    if (!order) { res.status(404); throw new Error('Order not found'); }
    rows = await query(
      `SELECT ${EVENT_SELECT},
              a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
              oi.order_id AS order_id
       FROM tickets t JOIN events e ON e.id=t.event_id
       JOIN attendees a ON a.id=t.attendee_id JOIN order_items oi ON oi.id=a.order_item_id
       WHERE oi.order_id=$1 ORDER BY t.purchased_at DESC`, [orderId]
    );
  } else {
    rows = await query(
      `SELECT ${EVENT_SELECT},
              a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
              oi.order_id AS order_id
       FROM tickets t JOIN events e ON e.id=t.event_id
       LEFT JOIN attendees a ON a.id=t.attendee_id
       LEFT JOIN order_items oi ON oi.id=a.order_item_id
       WHERE t.user_id=$1 ORDER BY t.purchased_at DESC`, [req.user.id]
    );
  }
  const tickets = [];
  for (const row of rows) tickets.push(await presentTicketForClient(row, { includeToken: true }));
  res.json({ success: true, count: tickets.length, tickets });
});

const getTicketById = asyncHandler(async (req, res) => {
  const ticket = await getOne(
    `SELECT ${EVENT_SELECT},
            a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
            oi.order_id AS order_id
     FROM tickets t JOIN events e ON e.id=t.event_id
     LEFT JOIN attendees a ON a.id=t.attendee_id
     LEFT JOIN order_items oi ON oi.id=a.order_item_id
     WHERE t.id=$1`,
    [req.params.id]
  );
  if (!ticket) { res.status(404); throw new Error('Ticket not found'); }
  const access = await resolveAccess(req, ticket);
  if (!access.allowed) { res.status(404); throw new Error('Ticket not found'); }
  const presented = await presentTicketForClient(ticket, { includeToken: access.owner });
  res.json({ success: true, ticket: presented, data: presented });
});

const verifyTicket = asyncHandler(async (req, res) => {
  const rawToken = req.body.token || req.body.ticket_code;
  if (!rawToken) { res.status(400); throw new Error('Ticket token is required'); }
  const ticket = await tokens.findTicketByRawToken(rawToken);
  if (!ticket) { res.status(404); throw new Error('Ticket not found or QR token is invalid'); }
  if (req.body.event_id && ticket.event_id !== req.body.event_id) {
    res.status(400); throw new Error('Ticket does not belong to this event');
  }
  const memberId = await assertScanPermission(ticket.event_id, req.user);
  if (ticket.status === 'used') {
    return res.status(409).json({ success: false, message: 'Ticket already used', ticket: await tokens.presentTicket(ticket) });
  }

  // D2-4 K3: verifikasi harus membuat baris check_ins (bukan hanya mengubah
  // status tiket) supaya riwayat dan audit tetap lengkap. Jalur ini memakai
  // transaksi atomik yang sama dengan POST /api/check-ins.
  const { checkIn, checkedInAt } = await commitCheckIn({ ticket, user: req.user, memberId });

  logger.info('ticket_verified', { ticketId: ticket.id, eventId: ticket.event_id });
  res.json({
    success: true,
    message: 'Ticket verified successfully',
    check_in: checkIn,
    checked_in_at: checkedInAt,
    ticket: await tokens.presentTicket({ ...ticket, status: 'used', used_at: checkedInAt }),
  });
});

/**
 * Tiket final dalam format PDF, memakai desain tiket yang dipilih Organizer
 * (kategori lebih dulu, lalu desain default event, lalu desain default sistem).
 *
 * Otorisasi memakai jalur yang sama dengan detail tiket: pemilik tiket, Admin,
 * atau pemegang token akses order untuk tiket pada order tersebut. Berbeda
 * dengan detail tiket, `order_id` tidak wajib dikirim sebagai query karena
 * order tiket sudah diketahui dari baris tiket; ini membuat tautan unduh PDF
 * dapat dipakai langsung (mis. dari halaman tiket/email).
 */
const getTicketPdf = asyncHandler(async (req, res) => {
  const ticket = await getOne(
    `SELECT t.*, oi.order_id AS order_id
       FROM tickets t
       LEFT JOIN attendees a ON a.id = t.attendee_id
       LEFT JOIN order_items oi ON oi.id = a.order_item_id
      WHERE t.id = $1`,
    [req.params.id],
  );
  if (!ticket) { res.status(404); throw new Error('Ticket not found'); }
  const access = await resolveAccess(req, ticket);
  if (!access.allowed) { res.status(404); throw new Error('Ticket not found'); }

  const full = await ticketDesignService.loadTicketForPdf(ticket.id);
  if (!full) { res.status(404); throw new Error('Ticket not found'); }
  const pdf = await ticketDesignService.buildTicketPdf(full);

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="tiket-${full.ticket_code || full.id}.pdf"`,
  );
  res.status(200).send(pdf);
});

const resendTicketEmail = asyncHandler(async (req, res) => {
  const ticket = await getOne('SELECT * FROM tickets WHERE id=$1', [req.params.id]);
  if (!ticket) { res.status(404); throw new Error('Ticket not found'); }
  const access = await resolveAccess(req, ticket);
  if (!access.allowed) { res.status(404); throw new Error('Ticket not found'); }
  const result = await emailService.sendTicketEmail(ticket.id, { force: true });
  res.json({
    success: true,
    delivered: result.status === 'SENT',
    delivery_status: result.status,
    reason: result.reason || result.delivery?.last_error || null,
  });
});

module.exports = { getMyTickets, getTicketById, getTicketPdf, verifyTicket, resendTicketEmail };
