const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const ticketTokens = require('../services/ticketTokenService');

const SCAN_RESULTS = {
  VALID: 'VALID',
  ALREADY_USED: 'ALREADY_USED',
  INVALID: 'INVALID',
  WRONG_EVENT: 'WRONG_EVENT',
  PAYMENT_REQUIRED: 'PAYMENT_REQUIRED',
  CANCELLED: 'CANCELLED',
  REVOKED: 'REVOKED',
};

const normalizeTicketStatus = (status) => {
  if (status === 'active') return 'valid';
  if (status === 'used') return 'checked_in';
  return status || 'unknown';
};

const assertScanPermission = async (eventId, user) => {
  if (!user || !user.id) {
    const err = new Error('Authentication required');
    err.statusCode = 401;
    throw err;
  }
  const event = await getOne('SELECT id, created_by FROM events WHERE id = $1', [eventId]);
  if (!event) {
    const err = new Error('Event not found');
    err.statusCode = 404;
    throw err;
  }
  if (user.role === 'admin') return null;
  if (event.created_by === user.id) return null;

  const member = await getOne(
    'SELECT id, status FROM event_members WHERE event_id = $1 AND user_id = $2',
    [eventId, user.id]
  );
  if (!member || (member.status && member.status !== 'ACTIVE' && member.status !== 'active')) {
    const err = new Error('You are not an active staff member of this event');
    err.statusCode = 403;
    throw err;
  }

  const perms = await query(
    'SELECT permission FROM event_member_permissions WHERE event_member_id = $1',
    [member.id]
  );
  const hasPermission = (perms || []).some(
    (p) => p.permission === 'CHECK_IN_TICKET' || p.permission === 'SCAN_TICKET'
  );
  if (!hasPermission) {
    const err = new Error('You do not have check-in permission for this event');
    err.statusCode = 403;
    throw err;
  }
  return member.id;
};

const findTicketByIdentifier = async (rawTokenOrCode) => {
  if (typeof rawTokenOrCode !== 'string' || !rawTokenOrCode.trim()) return null;
  const trimmed = rawTokenOrCode.trim();

  // 1. Coba cari via hash token QR (HMAC-SHA256)
  const byToken = await ticketTokens.findTicketByRawToken(trimmed);
  if (byToken) return byToken;

  // 2. Coba cari via kode tiket human-readable (entri manual oleh staf)
  const byCode = await getOne(
    `SELECT t.*,
            a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
            a.order_item_id AS attendee_order_item_id,
            tt.name AS ticket_type_name
     FROM tickets t
     LEFT JOIN attendees a ON a.id = t.attendee_id
     LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
     WHERE t.ticket_code = $1`,
    [trimmed]
  );
  return byCode;
};

const orderOfTicket = async (ticket) => {
  if (!ticket) return null;
  let orderItemId = ticket.attendee_order_item_id;
  if (!orderItemId && ticket.attendee_id) {
    const attendee = await getOne('SELECT order_item_id FROM attendees WHERE id = $1', [ticket.attendee_id]);
    orderItemId = attendee?.order_item_id;
  }
  if (!orderItemId) return null;
  const item = await getOne('SELECT order_id FROM order_items WHERE id = $1', [orderItemId]);
  if (!item) return null;
  const order = await getOne('SELECT id, status FROM event_orders WHERE id = $1', [item.order_id]);
  return order;
};

/** Bentuk tiket untuk hasil scan: tanpa token_hash, status dinormalisasi. */
const presentScanTicket = async (ticket) => ({
  ...(await ticketTokens.presentTicket(ticket)),
  status: normalizeTicketStatus(ticket.status),
});

const validateTicket = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user || !user.id) {
    const err = new Error('Authentication required');
    err.statusCode = 401;
    res.status(401);
    throw err;
  }

  const rawToken = req.body.token || req.body.ticket_code;
  const { event_id } = req.body;
  if (!rawToken || typeof rawToken !== 'string' || !rawToken.trim()) {
    const err = new Error('Ticket token is required');
    err.statusCode = 400;
    res.status(400);
    throw err;
  }

  // 1. Jika event_id pos pemindaian dikirimkan, pastikan staf memiliki izin di pos tersebut
  if (event_id) {
    await assertScanPermission(event_id, user);
  }

  const ticket = await findTicketByIdentifier(rawToken);
  if (!ticket) {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.INVALID,
      message: 'Tiket tidak ditemukan atau token QR tidak valid.',
      ticket: null,
    });
  }

  // 2. Jika event_id pos pemindaian tidak dikirimkan, periksa izin staf pada event tiket
  if (!event_id) {
    await assertScanPermission(ticket.event_id, user);
  }

  // 3. Verifikasi apakah tiket berlaku untuk event pada pos pemindaian
  if (event_id && ticket.event_id !== event_id) {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.WRONG_EVENT,
      message: 'Tiket tidak berlaku untuk event ini.',
      ticket: await presentScanTicket(ticket),
    });
  }

  // 4. Verifikasi status tiket: apakah sudah pernah digunakan
  if (ticket.status === 'used') {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.ALREADY_USED,
      message: 'Tiket sudah digunakan untuk check-in sebelumnya.',
      ticket: await presentScanTicket(ticket),
    });
  }

  // 5. Verifikasi status tiket: apakah dibatalkan, dicabut, dsb.
  if (ticket.status === 'cancelled') {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.CANCELLED,
      message: 'Tiket telah dibatalkan.',
      ticket: await presentScanTicket(ticket),
    });
  }
  if (ticket.status === 'revoked') {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.REVOKED,
      message: 'Tiket telah dicabut oleh penyelenggara.',
      ticket: await presentScanTicket(ticket),
    });
  }
  if (ticket.status !== 'active') {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.INVALID,
      message: `Tiket tidak valid (${ticket.status}).`,
      ticket: await presentScanTicket(ticket),
    });
  }

  // 6. Verifikasi pembayaran server-authoritative
  let paymentRequired = false;
  try {
    const order = await orderOfTicket(ticket);
    if (!order || order.status !== 'PAID') paymentRequired = true;
  } catch (_) {
    paymentRequired = true;
  }
  if (paymentRequired) {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.PAYMENT_REQUIRED,
      message: 'Pembayaran belum terkonfirmasi. Tiket belum dapat check-in.',
      ticket: await presentScanTicket(ticket),
    });
  }

  return res.json({
    success: true,
    valid: true,
    status: SCAN_RESULTS.VALID,
    message: 'Tiket valid. Siap untuk check-in.',
    ticket: await presentScanTicket(ticket),
  });
});

const recordCheckIn = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user || !user.id) {
    res.status(401);
    throw new Error('Authentication required');
  }

  const { ticket_id, ticket_code, token, event_id } = req.body;
  let ticket = null;
  if (token || ticket_code) {
    ticket = await findTicketByIdentifier(token || ticket_code);
  } else if (ticket_id) {
    const row = await getOne(
      `SELECT t.*,
              a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
              a.order_item_id AS attendee_order_item_id,
              tt.name AS ticket_type_name
       FROM tickets t
       LEFT JOIN attendees a ON a.id = t.attendee_id
       LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
       WHERE t.id = $1`,
      [ticket_id]
    );
    ticket = row;
  }
  if (!ticket) {
    res.status(404);
    throw new Error('Tiket tidak ditemukan');
  }

  const targetEventId = event_id || ticket.event_id;
  const memberId = await assertScanPermission(targetEventId, user);

  if (targetEventId && ticket.event_id !== targetEventId) {
    res.status(400);
    throw new Error('Tiket tidak berlaku untuk event ini');
  }
  if (ticket.status === 'used') {
    res.status(400);
    throw new Error('Tiket sudah digunakan untuk check-in sebelumnya');
  }
  if (ticket.status !== 'active') {
    res.status(400);
    throw new Error(`Tiket tidak valid (${ticket.status})`);
  }

  const order = await orderOfTicket(ticket);
  if (!order || order.status !== 'PAID') {
    res.status(400);
    throw new Error('Pembayaran belum terkonfirmasi. Tiket belum dapat check-in.');
  }

  const existingCheckIn = await getOne(
    'SELECT id FROM check_ins WHERE ticket_id = $1',
    [ticket.id]
  );
  if (existingCheckIn) {
    const err = new Error('Tiket sudah di-check-in');
    err.statusCode = 409;
    res.status(409);
    throw err;
  }

  const now = new Date().toISOString();
  const client = await pool.connect();
  let checkIn;
  try {
    await client.query('BEGIN');
    const locked = await client.query('SELECT status FROM tickets WHERE id = $1 FOR UPDATE', [ticket.id]);
    if (!locked.rows[0] || locked.rows[0].status !== 'active') {
      const err = new Error('Tiket sudah di-check-in');
      err.statusCode = 409;
      throw err;
    }
    const inserted = await client.query(
      `INSERT INTO check_ins (id, ticket_id, event_id, actor_user_id, event_member_id, source, checked_in_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, 'ONLINE', $5)
       ON CONFLICT (ticket_id) DO NOTHING
       RETURNING *`,
      [ticket.id, ticket.event_id, user.id, memberId, now]
    );
    if (!inserted.rows[0]) {
      const err = new Error('Tiket sudah di-check-in');
      err.statusCode = 409;
      throw err;
    }
    checkIn = inserted.rows[0];

    await client.query('UPDATE tickets SET status = $1, used_at = $2 WHERE id = $3', ['used', now, ticket.id]);
    await client.query(
      `INSERT INTO scan_logs (id, event_id, ticket_id, scanned_by_user_id, event_member_id, result, is_offline, scanned_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, 'VALID', false, $5)`,
      [ticket.event_id, ticket.id, user.id, memberId, now]
    );
    await client.query('COMMIT');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* transaksi sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }

  res.status(201).json({
    success: true,
    message: 'Check-in berhasil dicatat.',
    check_in: checkIn,
    ticket: { ...(await ticketTokens.presentTicket(ticket)), status: 'checked_in', checked_in_at: now },
  });
});

const listEventAttendees = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user || !user.id) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const eventId = req.params.eventId;
  await assertScanPermission(eventId, user);

  const rows = await query(
    `SELECT t.*,
            a.name AS attendee_name, a.email AS attendee_email, a.phone AS attendee_phone,
            a.order_item_id AS attendee_order_item_id,
            tt.name AS ticket_type_name,
            eo.id AS order_id, eo.order_number, eo.status AS payment_status
     FROM tickets t
     LEFT JOIN attendees a ON a.id = t.attendee_id
     LEFT JOIN order_items oi ON oi.id = a.order_item_id
     LEFT JOIN event_orders eo ON eo.id = oi.order_id
     LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
     WHERE t.event_id = $1
     ORDER BY (CASE WHEN eo.status = 'PAID' THEN 0 ELSE 1 END), t.purchased_at DESC`,
    [eventId]
  );

  const attendees = rows.map((t) => ({
    id: t.attendee_order_item_id ? t.attendee_order_item_id : t.id,
    ticket_id: t.id,
    ticket_code: t.ticket_code,
    registration_number: t.order_number || t.ticket_code || `REG-${t.id.slice(0, 8)}`,
    order_number: t.order_number || null,
    order_id: t.order_id || null,
    payment_status: t.payment_status || (t.status === 'used' || t.status === 'active' ? 'PAID' : 'PENDING'),
    attendee_name: t.attendee_name,
    attendee_email: t.attendee_email,
    attendee_phone: t.attendee_phone,
    ticket_type: t.ticket_type_name,
    status: normalizeTicketStatus(t.status),
    purchased_at: t.purchased_at,
    used_at: t.used_at,
  }));
  res.json({ success: true, count: attendees.length, attendees });
});

const listEventCheckIns = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user || !user.id) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const eventId = req.params.eventId;
  await assertScanPermission(eventId, user);

  const rows = await query(
    `SELECT ci.*,
            t.ticket_code, t.status AS ticket_status,
            a.id AS actor_id, a.name AS actor_name, a.email AS actor_email
     FROM check_ins ci
     LEFT JOIN tickets t ON t.id = ci.ticket_id
     LEFT JOIN profiles a ON a.id = ci.actor_user_id
     WHERE ci.event_id = $1
     ORDER BY ci.checked_in_at DESC`,
    [eventId]
  );
  res.json({ success: true, count: rows.length, check_ins: rows });
});

const syncCheckIns = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user || !user.id) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const { pending } = req.body;
  const items = Array.isArray(pending) ? pending : [];
  if (items.length === 0) {
    return res.json({ success: true, synced_count: 0, failed_count: 0, results: [] });
  }

  const permissionCache = new Map();
  const results = [];
  let synced = 0;
  let failed = 0;

  for (const item of items) {
    const clientScanId = typeof item?.id === 'string' ? item.id : (item?.client_scan_id || null);
    try {
      const ticketId = item?.ticket_id;
      const eventId = item?.event_id;
      if (!clientScanId || !ticketId || !eventId) {
        const err = new Error('Data check-in offline tidak lengkap'); err.statusCode = 400; throw err;
      }
      if (!permissionCache.has(eventId)) {
        permissionCache.set(eventId, await assertScanPermission(eventId, user));
      }
      const memberId = permissionCache.get(eventId);

      const ticket = await getOne(
        `SELECT t.*, a.order_item_id AS attendee_order_item_id
         FROM tickets t
         LEFT JOIN attendees a ON a.id = t.attendee_id
         WHERE t.id = $1`,
        [ticketId]
      );
      if (!ticket || ticket.event_id !== eventId) {
        const err = new Error('Tiket tidak ditemukan pada event ini'); err.statusCode = 404; throw err;
      }
      if (item.token) {
        const expected = ticketTokens.hashToken(String(item.token).trim());
        if (!ticket.token_hash || !ticketTokens.safeEqual(ticket.token_hash, expected)) {
          const err = new Error('Token QR tidak cocok dengan tiket'); err.statusCode = 409; throw err;
        }
      }
      const order = await orderOfTicket(ticket);
      if (!order || order.status !== 'PAID') {
        const err = new Error('Pembayaran belum terkonfirmasi'); err.statusCode = 400; throw err;
      }

      const checkedInAt = item.checked_in_at || item.checkedInAt || new Date().toISOString();
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const locked = await client.query('SELECT status FROM tickets WHERE id = $1 FOR UPDATE', [ticketId]);
        if (!locked.rows[0] || locked.rows[0].status === 'used') {
          const err = new Error('Tiket sudah digunakan'); err.statusCode = 409; throw err;
        }
        const inserted = await client.query(
          `INSERT INTO check_ins
             (id, ticket_id, event_id, actor_user_id, event_member_id, source, checked_in_at, synced_at, client_scan_id)
           VALUES (gen_random_uuid(), $1, $2, $3, $4, 'OFFLINE_SYNC', $5, NOW(), $6)
           ON CONFLICT (ticket_id) DO NOTHING
           RETURNING *`,
          [ticketId, eventId, user.id, memberId, checkedInAt, clientScanId]
        );
        if (!inserted.rows[0]) {
          const err = new Error('Tiket sudah di-check-in'); err.statusCode = 409; throw err;
        }
        await client.query(
          "UPDATE tickets SET status = 'used', used_at = $1 WHERE id = $2",
          [checkedInAt, ticketId]
        );
        await client.query(
          `INSERT INTO scan_logs
             (id, event_id, ticket_id, scanned_by_user_id, event_member_id, client_scan_id, result, is_offline, scanned_at)
           VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, 'VALID', true, $6)
           ON CONFLICT (event_id, client_scan_id) DO NOTHING`,
          [eventId, ticketId, user.id, memberId, clientScanId, checkedInAt]
        );
        await client.query('COMMIT');
        synced += 1;
        results.push({ id: clientScanId, status: 'SYNCED' });
      } catch (error) {
        try { await client.query('ROLLBACK'); } catch (_) { /* transaksi sudah berakhir */ }
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      failed += 1;
      results.push({ id: clientScanId, status: 'FAILED', message: error.message });
    }
  }

  res.json({ success: true, synced_count: synced, failed_count: failed, results });
});

module.exports = {
  validateTicket,
  recordCheckIn,
  listEventAttendees,
  listEventCheckIns,
  syncCheckIns,
  assertScanPermission,
  findTicketByIdentifier,
  orderOfTicket,
  presentScanTicket,
  normalizeTicketStatus,
  SCAN_RESULTS,
};
