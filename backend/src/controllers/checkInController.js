const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const ticketTokens = require('../services/ticketTokenService');

const SCAN_RESULTS = {
  VALID: 'VALID',
  ALREADY_USED: 'ALREADY_USED',
  INVALID: 'INVALID',
  WRONG_EVENT: 'WRONG_EVENT',
  PAYMENT_REQUIRED: 'PAYMENT_REQUIRED',
};

const normalizeTicketStatus = (status) => {
  if (status === 'active') return 'valid';
  if (status === 'used') return 'checked_in';
  return status || 'unknown';
};

const assertScanPermission = async (eventId, user) => {
  const event = await getOne('SELECT id, created_by FROM events WHERE id = $1', [eventId]);
  if (!event) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (user.role === 'admin') return null;
  if (event.created_by === user.id) return null;

  const member = await getOne(
    'SELECT id FROM event_members WHERE event_id = $1 AND user_id = $2',
    [eventId, user.id]
  );
  if (!member) {
    const err = new Error('You are not a staff member of this event'); err.statusCode = 403; throw err;
  }

  const perms = await query(
    'SELECT permission FROM event_member_permissions WHERE event_member_id = $1',
    [member.id]
  );
  const hasPermission = (perms || []).some(
    (p) => p.permission === 'CHECK_IN_TICKET' || p.permission === 'SCAN_TICKET'
  );
  if (!hasPermission) {
    const err = new Error('You do not have check-in permission for this event'); err.statusCode = 403; throw err;
  }
  return member.id;
};

const assertMemberPermission = async (eventId, user, requiredPermissions = []) => {
  const event = await getOne('SELECT id, created_by FROM events WHERE id = $1', [eventId]);
  if (!event) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (user.role === 'admin') return null;
  if (event.created_by === user.id) return null;

  const member = await getOne(
    'SELECT id FROM event_members WHERE event_id = $1 AND user_id = $2',
    [eventId, user.id]
  );
  if (!member) {
    const err = new Error('You do not have access to this event'); err.statusCode = 403; throw err;
  }

  const perms = await query(
    'SELECT permission FROM event_member_permissions WHERE event_member_id = $1',
    [member.id]
  );
  const allowed = ['MANAGE_EVENT', ...requiredPermissions];
  const hasPermission = (perms || []).some((p) => allowed.includes(p.permission));
  if (!hasPermission) {
    const err = new Error('You do not have required permission for this event'); err.statusCode = 403; throw err;
  }
  return member.id;
};

const assertParticipantPermission = (eventId, user) =>
  assertMemberPermission(eventId, user, ['VIEW_PARTICIPANTS']);

const assertExportPermission = (eventId, user) =>
  assertMemberPermission(eventId, user, ['EXPORT_PARTICIPANTS']);

const assertOrderPermission = (eventId, user) =>
  assertMemberPermission(eventId, user, ['VIEW_ORDERS']);

const findTicketByToken = (rawToken) => ticketTokens.findTicketByRawToken(rawToken);

const orderOfTicket = async (ticket) => {
  if (!ticket || !ticket.attendee_order_item_id) return null;
  const item = await getOne('SELECT order_id FROM order_items WHERE id = $1', [ticket.attendee_order_item_id]);
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
  const rawToken = req.body.token || req.body.ticket_code;
  const { event_id } = req.body;
  if (!rawToken) {
    res.status(400);
    throw new Error('Ticket token is required');
  }

  const ticket = await findTicketByToken(rawToken);
  if (!ticket) {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.INVALID,
      message: 'Tiket tidak ditemukan atau token QR tidak valid.',
      ticket: null,
    });
  }

  // Validasi QR juga harus dibatasi ke petugas event terkait karena respons
  // memuat data peserta (nama/email/telepon).
  await assertScanPermission(ticket.event_id, req.user);

  if (event_id && ticket.event_id !== event_id) {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.WRONG_EVENT,
      message: 'Tiket tidak berlaku untuk event ini.',
      ticket: await presentScanTicket(ticket),
    });
  }

  if (ticket.status === 'used') {
    return res.json({
      success: true,
      valid: false,
      status: SCAN_RESULTS.ALREADY_USED,
      message: 'Tiket sudah digunakan untuk check-in sebelumnya.',
      ticket: await presentScanTicket(ticket),
    });
  }

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
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }

  const { ticket_id, ticket_code, token, event_id } = req.body;
  let ticket = null;
  if (token || ticket_code) {
    ticket = await findTicketByToken(token || ticket_code);
  } else if (ticket_id) {
    const row = await getOne(
      `SELECT t.*,
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
    res.status(409);
    throw new Error('Tiket sudah di-check-in');
  }

  const now = new Date().toISOString();
  const client = await pool.connect();
  let checkIn;
  try {
    await client.query('BEGIN');
    const locked = await client.query('SELECT status FROM tickets WHERE id = $1 FOR UPDATE', [ticket.id]);
    if (!locked.rows[0] || locked.rows[0].status === 'used') {
      const err = new Error('Tiket sudah di-check-in'); err.statusCode = 409; throw err;
    }
    const inserted = await client.query(
      `INSERT INTO check_ins (id, ticket_id, event_id, actor_user_id, event_member_id, source, checked_in_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, 'ONLINE', $5)
       ON CONFLICT (ticket_id) DO NOTHING
       RETURNING *`,
      [ticket.id, ticket.event_id, user.id, memberId, now]
    );
    if (!inserted.rows[0]) {
      const err = new Error('Tiket sudah di-check-in'); err.statusCode = 409; throw err;
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
const escapeCsvValue = (val) => {
  if (val === null || val === undefined) return '';
  let str = String(val);
  if (/^[=+\-@\t\r]/.test(str)) {
    str = `'${str}`;
  }
  if (/[",\n\r]/.test(str)) {
    str = `"${str.replace(/"/g, '""')}"`;
  }
  return str;
};

const listEventAttendees = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const eventId = req.params.eventId || req.params.id;
  await assertParticipantPermission(eventId, user);

  const { search, status, ticket_type } = req.query;

  const rows = await query(
    `WITH event_attendees AS (
      SELECT
        a.id AS attendee_id,
        a.order_item_id AS attendee_order_item_id,
        a.name AS attendee_name,
        a.email AS attendee_email,
        a.phone AS attendee_phone,
        a.organization,
        a.custom_fields,
        a.created_at AS attendee_created_at,
        tt.name AS ticket_type_name,
        tt.id AS ticket_type_id,
        t.id AS ticket_id,
        t.ticket_code,
        t.status AS ticket_status,
        t.purchased_at,
        t.used_at,
        ci.checked_in_at,
        eo.id AS order_id,
        eo.order_number,
        eo.status AS order_status,
        COALESCE(op.status::text, eo.status::text) AS payment_status
      FROM attendees a
      JOIN order_items oi ON oi.id = a.order_item_id
      JOIN event_orders eo ON eo.id = oi.order_id
      LEFT JOIN ticket_types tt ON tt.id = oi.ticket_type_id
      LEFT JOIN tickets t ON t.attendee_id = a.id
      LEFT JOIN LATERAL (
        SELECT status, paid_at FROM order_payments
        WHERE order_id = eo.id
        ORDER BY created_at DESC LIMIT 1
      ) op ON true
      LEFT JOIN LATERAL (
        SELECT checked_in_at FROM check_ins
        WHERE ticket_id = t.id
        ORDER BY checked_in_at DESC LIMIT 1
      ) ci ON true
      WHERE eo.event_id = $1

      UNION ALL

      SELECT
        COALESCE(a.id, t.id) AS attendee_id,
        COALESCE(a.order_item_id, t.id) AS attendee_order_item_id,
        COALESCE(a.name, p.name, 'Peserta') AS attendee_name,
        COALESCE(a.email, p.email) AS attendee_email,
        COALESCE(a.phone, p.phone) AS attendee_phone,
        a.organization,
        a.custom_fields,
        COALESCE(a.created_at, t.purchased_at) AS attendee_created_at,
        tt.name AS ticket_type_name,
        tt.id AS ticket_type_id,
        t.id AS ticket_id,
        t.ticket_code,
        t.status AS ticket_status,
        t.purchased_at,
        t.used_at,
        ci.checked_in_at,
        eo.id AS order_id,
        COALESCE(eo.order_number, t.ticket_code) AS order_number,
        COALESCE(eo.status::text, 'PAID') AS order_status,
        COALESCE(op.status::text, eo.status::text, 'PAID') AS payment_status
      FROM tickets t
      LEFT JOIN attendees a ON a.id = t.attendee_id
      LEFT JOIN profiles p ON p.id = t.user_id
      LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
      LEFT JOIN order_items oi ON oi.id = a.order_item_id
      LEFT JOIN event_orders eo ON eo.id = oi.order_id
      LEFT JOIN LATERAL (
        SELECT status, paid_at FROM order_payments
        WHERE order_id = eo.id
        ORDER BY created_at DESC LIMIT 1
      ) op ON true
      LEFT JOIN LATERAL (
        SELECT checked_in_at FROM check_ins
        WHERE ticket_id = t.id
        ORDER BY checked_in_at DESC LIMIT 1
      ) ci ON true
      WHERE t.event_id = $1 AND (a.id IS NULL OR oi.id IS NULL)
    )
    SELECT * FROM event_attendees
    ORDER BY
      CASE
        WHEN UPPER(COALESCE(payment_status, '')) = 'PAID' THEN 0
        WHEN UPPER(COALESCE(payment_status, '')) = 'PENDING' OR UPPER(COALESCE(order_status, '')) = 'PENDING_PAYMENT' THEN 1
        ELSE 2
      END ASC,
      order_number ASC,
      purchased_at DESC NULLS LAST,
      attendee_created_at ASC`,
    [eventId]
  );

  let filtered = rows;
  if (search && typeof search === 'string' && search.trim()) {
    const s = search.trim().toLowerCase();
    filtered = filtered.filter((r) =>
      (r.attendee_name && r.attendee_name.toLowerCase().includes(s)) ||
      (r.attendee_email && r.attendee_email.toLowerCase().includes(s)) ||
      (r.ticket_code && r.ticket_code.toLowerCase().includes(s)) ||
      (r.order_number && r.order_number.toLowerCase().includes(s))
    );
  }
  if (status && typeof status === 'string' && status.trim() && status.toLowerCase() !== 'all') {
    const st = status.trim().toLowerCase();
    filtered = filtered.filter((r) =>
      (r.ticket_status && r.ticket_status.toLowerCase() === st) ||
      (r.payment_status && r.payment_status.toLowerCase() === st) ||
      (st === 'checked_in' && (r.checked_in_at || r.used_at))
    );
  }
  if (ticket_type && typeof ticket_type === 'string' && ticket_type.trim()) {
    const tt = ticket_type.trim().toLowerCase();
    filtered = filtered.filter((r) =>
      (r.ticket_type_name && r.ticket_type_name.toLowerCase() === tt) ||
      r.ticket_type_id === ticket_type
    );
  }

  const attendees = filtered.map((t) => ({
    id: t.attendee_order_item_id ? t.attendee_order_item_id : (t.attendee_id || t.ticket_id || t.id),
    ticket_id: t.ticket_id || null,
    ticket_code: t.ticket_code || null,
    attendee_name: t.attendee_name || '-',
    attendee_email: t.attendee_email || '-',
    attendee_phone: t.attendee_phone || '-',
    ticket_type: t.ticket_type_name || '-',
    status: normalizeTicketStatus(t.ticket_status || (t.payment_status === 'PAID' ? 'active' : 'pending')),
    purchased_at: t.purchased_at || null,
    used_at: t.used_at || null,
    order_number: t.order_number || '-',
    payment_status: String(t.payment_status || 'PENDING').toUpperCase(),
    order_status: String(t.order_status || 'PENDING_PAYMENT').toUpperCase(),
    custom_fields: t.custom_fields || {},
    checked_in_at: t.checked_in_at || t.used_at || null,
  }));

  res.json({ success: true, count: attendees.length, attendees });
});

const exportEventAttendeesCsv = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const eventId = req.params.id || req.params.eventId;
  await assertExportPermission(eventId, user);

  const rows = await query(
    `WITH event_attendees AS (
      SELECT
        a.id AS attendee_id,
        a.order_item_id AS attendee_order_item_id,
        a.name AS attendee_name,
        a.email AS attendee_email,
        a.phone AS attendee_phone,
        a.organization,
        a.custom_fields,
        a.created_at AS attendee_created_at,
        tt.name AS ticket_type_name,
        t.id AS ticket_id,
        t.ticket_code,
        t.status AS ticket_status,
        t.purchased_at,
        t.used_at,
        ci.checked_in_at,
        eo.id AS order_id,
        eo.order_number,
        eo.status AS order_status,
        COALESCE(op.status::text, eo.status::text) AS payment_status
      FROM attendees a
      JOIN order_items oi ON oi.id = a.order_item_id
      JOIN event_orders eo ON eo.id = oi.order_id
      LEFT JOIN ticket_types tt ON tt.id = oi.ticket_type_id
      LEFT JOIN tickets t ON t.attendee_id = a.id
      LEFT JOIN LATERAL (
        SELECT status, paid_at FROM order_payments
        WHERE order_id = eo.id
        ORDER BY created_at DESC LIMIT 1
      ) op ON true
      LEFT JOIN LATERAL (
        SELECT checked_in_at FROM check_ins
        WHERE ticket_id = t.id
        ORDER BY checked_in_at DESC LIMIT 1
      ) ci ON true
      WHERE eo.event_id = $1

      UNION ALL

      SELECT
        COALESCE(a.id, t.id) AS attendee_id,
        COALESCE(a.order_item_id, t.id) AS attendee_order_item_id,
        COALESCE(a.name, p.name, 'Peserta') AS attendee_name,
        COALESCE(a.email, p.email) AS attendee_email,
        COALESCE(a.phone, p.phone) AS attendee_phone,
        a.organization,
        a.custom_fields,
        COALESCE(a.created_at, t.purchased_at) AS attendee_created_at,
        tt.name AS ticket_type_name,
        t.id AS ticket_id,
        t.ticket_code,
        t.status AS ticket_status,
        t.purchased_at,
        t.used_at,
        ci.checked_in_at,
        eo.id AS order_id,
        COALESCE(eo.order_number, t.ticket_code) AS order_number,
        COALESCE(eo.status::text, 'PAID') AS order_status,
        COALESCE(op.status::text, eo.status::text, 'PAID') AS payment_status
      FROM tickets t
      LEFT JOIN attendees a ON a.id = t.attendee_id
      LEFT JOIN profiles p ON p.id = t.user_id
      LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
      LEFT JOIN order_items oi ON oi.id = a.order_item_id
      LEFT JOIN event_orders eo ON eo.id = oi.order_id
      LEFT JOIN LATERAL (
        SELECT status, paid_at FROM order_payments
        WHERE order_id = eo.id
        ORDER BY created_at DESC LIMIT 1
      ) op ON true
      LEFT JOIN LATERAL (
        SELECT checked_in_at FROM check_ins
        WHERE ticket_id = t.id
        ORDER BY checked_in_at DESC LIMIT 1
      ) ci ON true
      WHERE t.event_id = $1 AND (a.id IS NULL OR oi.id IS NULL)
    )
    SELECT * FROM event_attendees
    ORDER BY
      CASE
        WHEN UPPER(COALESCE(payment_status, '')) = 'PAID' THEN 0
        WHEN UPPER(COALESCE(payment_status, '')) = 'PENDING' OR UPPER(COALESCE(order_status, '')) = 'PENDING_PAYMENT' THEN 1
        ELSE 2
      END ASC,
      order_number ASC,
      purchased_at DESC NULLS LAST,
      attendee_created_at ASC`,
    [eventId]
  );

  const headers = [
    'ID', 'Nama', 'Email', 'No_HP', 'Kategori_Tiket', 'Kode_Tiket',
    'No_Pesanan', 'Metode', 'Status_Tiket', 'Status_Pembayaran', 'CheckIn', 'Waktu_CheckIn'
  ];

  const lines = [headers.join(',')];
  for (const r of rows) {
    const isCheckedIn = Boolean(r.checked_in_at || r.used_at || r.ticket_status === 'used');
    const row = [
      escapeCsvValue(r.attendee_order_item_id || r.attendee_id || r.ticket_id),
      escapeCsvValue(r.attendee_name || '-'),
      escapeCsvValue(r.attendee_email || '-'),
      escapeCsvValue(r.attendee_phone || '-'),
      escapeCsvValue(r.ticket_type_name || '-'),
      escapeCsvValue(r.ticket_code || '-'),
      escapeCsvValue(r.order_number || '-'),
      escapeCsvValue('SELF_SERVICE'),
      escapeCsvValue(normalizeTicketStatus(r.ticket_status || 'active')),
      escapeCsvValue(String(r.payment_status || 'PENDING').toUpperCase()),
      isCheckedIn ? 'YA' : 'TIDAK',
      escapeCsvValue(r.checked_in_at ? new Date(r.checked_in_at).toISOString() : (r.used_at ? new Date(r.used_at).toISOString() : '-')),
    ];
    lines.push(row.join(','));
  }

  const csv = lines.join('\r\n');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="attendees-${eventId}.csv"`);
  res.status(200).send(csv);
});

const getEventOrders = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const eventId = req.params.id || req.params.eventId;
  await assertOrderPermission(eventId, user);

  const { status, from, to, limit = 20, offset = 0 } = req.query;
  const whereClauses = ['eo.event_id = $1'];
  const params = [eventId];

  if (status && status !== 'all') {
    params.push(status.toUpperCase());
    whereClauses.push(`(eo.status::text = $${params.length} OR op.status::text = $${params.length})`);
  }
  if (from) {
    params.push(new Date(from).toISOString());
    whereClauses.push(`eo.created_at >= $${params.length}`);
  }
  if (to) {
    params.push(new Date(to).toISOString());
    whereClauses.push(`eo.created_at <= $${params.length}`);
  }

  const whereStr = whereClauses.join(' AND ');
  const pageLimit = Math.min(Number(limit) || 20, 100);
  const pageOffset = Number(offset) || 0;

  const rows = await query(
    `SELECT
      eo.id, eo.order_number, eo.event_id, eo.purchaser_id, eo.status AS order_status,
      eo.subtotal, eo.service_fee, eo.guest_name, eo.guest_email, eo.guest_phone,
      eo.created_at,
      op.id AS payment_id, op.status AS payment_status, op.method AS payment_method,
      op.amount AS payment_amount, op.paid_at, op.virtual_account_bank, op.virtual_account_number
     FROM event_orders eo
     LEFT JOIN LATERAL (
       SELECT * FROM order_payments WHERE order_id = eo.id ORDER BY created_at DESC LIMIT 1
     ) op ON true
     WHERE ${whereStr}
     ORDER BY eo.created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, pageLimit, pageOffset]
  );

  const countRow = await getOne(
    `SELECT COUNT(DISTINCT eo.id)::bigint AS total
     FROM event_orders eo
     LEFT JOIN LATERAL (
       SELECT * FROM order_payments WHERE order_id = eo.id ORDER BY created_at DESC LIMIT 1
     ) op ON true
     WHERE ${whereStr}`,
    params
  );

  const orderIds = rows.map((r) => r.id);
  const itemsByOrder = {};
  const attendeesByOrder = {};

  if (orderIds.length > 0) {
    const items = await query(
      `SELECT oi.*, tt.name AS ticket_type_name
       FROM order_items oi
       LEFT JOIN ticket_types tt ON tt.id = oi.ticket_type_id
       WHERE oi.order_id = ANY($1::uuid[])`,
      [orderIds]
    );
    for (const it of items) {
      if (!itemsByOrder[it.order_id]) itemsByOrder[it.order_id] = [];
      itemsByOrder[it.order_id].push({
        id: it.id,
        ticket_type_id: it.ticket_type_id,
        ticket_type_name: it.ticket_type_name || '-',
        quantity: it.quantity,
        unit_price: Number(it.unit_price),
        subtotal: Number(it.subtotal),
      });
    }

    const attendees = await query(
      `SELECT a.*, oi.order_id
       FROM attendees a
       JOIN order_items oi ON oi.id = a.order_item_id
       WHERE oi.order_id = ANY($1::uuid[])`,
      [orderIds]
    );
    for (const att of attendees) {
      if (!attendeesByOrder[att.order_id]) attendeesByOrder[att.order_id] = [];
      attendeesByOrder[att.order_id].push({
        id: att.id,
        name: att.name,
        email: att.email,
        phone: att.phone,
        organization: att.organization,
        custom_fields: att.custom_fields || {},
      });
    }
  }

  const orders = rows.map((r) => {
    const subtotal = Number(r.subtotal) || 0;
    const fee = Number(r.service_fee) || 0;
    return {
      id: r.id,
      order_number: r.order_number,
      status: String(r.order_status).toUpperCase(),
      payment_status: String(r.payment_status || r.order_status || 'PENDING').toUpperCase(),
      payment_method: r.payment_method || 'SIMULATED_VIRTUAL_ACCOUNT',
      subtotal,
      service_fee: fee,
      total_amount: subtotal + fee,
      guest_name: r.guest_name,
      guest_email: r.guest_email,
      guest_phone: r.guest_phone,
      created_at: r.created_at,
      paid_at: r.paid_at,
      items: itemsByOrder[r.id] || [],
      attendees: attendeesByOrder[r.id] || [],
    };
  });

  res.json({
    success: true,
    count: orders.length,
    total: Number(countRow?.total) || orders.length,
    orders,
  });
});

const listEventCheckIns = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
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
      // Bila scanner mengirim token, pastikan token memang milik tiket ini
      // sehingga antrean offline tidak dapat dipakai untuk menandai tiket lain.
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
  assertParticipantPermission,
  assertExportPermission,
  assertOrderPermission,
  exportEventAttendeesCsv,
  getEventOrders,
  normalizeTicketStatus,
};
