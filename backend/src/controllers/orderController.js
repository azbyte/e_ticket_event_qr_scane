const { createHash, randomBytes, randomUUID, timingSafeEqual } = require('node:crypto');
const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { serializeOrder } = require('../utils/orderResponse');

const ORDER_BASE_SELECT = `
  eo.id, eo.order_number, eo.event_id, eo.purchaser_id, eo.assisted_by_member_id,
  eo.registration_method, eo.guest_name, eo.guest_email, eo.guest_phone,
  eo.guest_access_token_hash, eo.idempotency_key, eo.idempotency_fingerprint,
  eo.status, eo.subtotal, eo.service_fee, eo.commission_rate, eo.commission_amount,
  eo.grand_total, eo.expires_at, eo.created_at, eo.updated_at,
  e.title AS event_title
`;
const hashAccessToken = (token) => createHash('sha256').update(token).digest('hex');

const safeHashEqual = (a, b) => {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length || bufA.length === 0) return false;
  return timingSafeEqual(bufA, bufB);
};

/** Muat order lengkap tanpa memeriksa otorisasi (dipakai setelah otorisasi). */
const loadOrderById = async (orderId) => {
  const order = await getOne(
    `SELECT ${ORDER_BASE_SELECT} FROM event_orders eo JOIN events e ON e.id = eo.event_id WHERE eo.id = $1`,
    [orderId]
  );
  if (!order) return null;

  const itemRows = await query(
    `SELECT oi.id, oi.order_id, oi.ticket_type_id, oi.quantity, oi.unit_price, oi.subtotal,
            tt.name AS ticket_type_name
     FROM order_items oi
     JOIN ticket_types tt ON tt.id = oi.ticket_type_id
     WHERE oi.order_id = $1`,
    [orderId]
  );
  const paymentRows = await query('SELECT * FROM order_payments WHERE order_id = $1', [orderId]);

  return {
    ...order,
    events: { title: order.event_title },
    order_items: itemRows.map((i) => ({
      id: i.id, order_id: i.order_id, ticket_type_id: i.ticket_type_id,
      quantity: i.quantity, unit_price: i.unit_price, subtotal: i.subtotal,
      ticket_types: { name: i.ticket_type_name },
    })),
    order_payments: paymentRows,
  };
};

const getAuthorizedOrder = async (orderId, user, accessToken) => {
  const order = await getOne(
    `SELECT ${ORDER_BASE_SELECT} FROM event_orders eo JOIN events e ON e.id = eo.event_id WHERE eo.id = $1`,
    [orderId]
  );
  if (!order) return null;

  if (order.purchaser_id) {
    if (!user || (user.id !== order.purchaser_id && user.role !== 'admin')) {
      return null;
    }
  } else if (typeof accessToken !== 'string' || !order.guest_access_token_hash
      || !safeHashEqual(hashAccessToken(accessToken), order.guest_access_token_hash)) {
    return null;
  }
  return loadOrderById(orderId);
};

module.exports.getAuthorizedOrder = getAuthorizedOrder;
module.exports.hashAccessToken = hashAccessToken;
module.exports.loadOrderById = loadOrderById;
const createOrder = asyncHandler(async (req, res) => {
  if (req.body.assisted_by_member_id || req.body.assisted) {
    res.status(400);
    throw new Error('Assisted registration is not supported in public order checkout');
  }

  const { event_id: eventId, items } = req.body;
  const isUuid = (value) =>
    typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  if (!isUuid(eventId) || !items || typeof items !== 'object' ||
      Array.isArray(items) || Object.keys(items).length === 0) {
    res.status(400);
    throw new Error('Provide valid ticket selections and attendee contact details');
  }

  const totalQuantity = Object.values(items).reduce(
    (sum, quantity) => sum + (Number.isInteger(quantity) ? quantity : 0),
    0
  );
  if (totalQuantity !== 1 || Object.keys(items).length !== 1 ||
      !Array.isArray(req.body.attendees) || req.body.attendees.length !== 1) {
    res.status(400);
    throw new Error('Orders in Tahap 1 must contain exactly one ticket and one attendee');
  }

  if (Object.entries(items).some(([id, quantity]) => !isUuid(id) || quantity !== 1)) {
    res.status(400);
    throw new Error('Provide valid ticket selections and attendee contact details');
  }
  const normalizedItems = Object.fromEntries(
    Object.entries(items).map(([id, quantity]) => [id.toLowerCase(), quantity]),
  );
  const groupedAttendees = {};
  for (const attendee of req.body.attendees) {
    const ticketTypeId = typeof attendee?.ticket_type_id === 'string'
      ? attendee.ticket_type_id.toLowerCase() : '';
    const name = typeof attendee?.name === 'string' ? attendee.name.trim() : '';
    const email = typeof attendee?.email === 'string'
      ? attendee.email.trim().toLowerCase() : '';
    const phone = typeof attendee?.phone === 'string' ? attendee.phone.trim() : '';
    if (!isUuid(ticketTypeId) || !normalizedItems[ticketTypeId] ||
        name.length < 2 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      res.status(400);
      throw new Error('Every selected ticket must have valid attendee details');
    }
    if (!groupedAttendees[ticketTypeId]) groupedAttendees[ticketTypeId] = [];
    groupedAttendees[ticketTypeId].push({ name, email, phone: phone || null });
  }
  for (const [ticketTypeId, quantity] of Object.entries(normalizedItems)) {
    if (groupedAttendees[ticketTypeId]?.length !== quantity) {
      res.status(400);
      throw new Error('Attendee count must match selected ticket quantities');
    }
  }

  const accessToken = randomBytes(32).toString('base64url');
  const fingerprint = createHash('sha256')
    .update(JSON.stringify({
      eventId,
      items: Object.fromEntries(
        Object.entries(normalizedItems).sort(([left], [right]) => left.localeCompare(right)),
      ),
      attendees: Object.fromEntries(
        Object.entries(groupedAttendees).sort(([left], [right]) => left.localeCompare(right)),
      ),
    }))
    .digest('hex');
  const idempotencyKey = req.get('Idempotency-Key') || req.body.idempotency_key || randomUUID();
  if (typeof idempotencyKey !== 'string' || idempotencyKey.length < 16 || idempotencyKey.length > 200) {
    res.status(400);
    throw new Error('Invalid idempotency key');
  }
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString();
  const primaryAttendee = req.body.attendees[0];

  // Replay idempotency harus mengembalikan order yang sama TANPA merotasi
  // access token. Token dari respons pertama tetap berlaku.
  const existing = await getOne(
    `SELECT id, idempotency_fingerprint, purchaser_id FROM event_orders WHERE idempotency_key = $1`,
    [idempotencyKey]
  );
  if (existing) {
    if (existing.idempotency_fingerprint !== fingerprint) {
      res.status(409);
      throw new Error('Idempotency key was reused with different order data');
    }
    if (existing.purchaser_id) {
      if (!req.user || req.user.id !== existing.purchaser_id) {
        res.status(403);
        throw new Error('This order belongs to another account');
      }
    }
    const replay = await loadOrderById(existing.id);
    return res.status(201).json({
      success: true,
      idempotent_replay: true,
      message: 'Checkout ini sudah diproses sebelumnya. Gunakan token akses dari respons pertama.',
      order: serializeOrder(replay),
      order_access_token: null,
    });
  }

  await query(
    `SELECT public.create_event_order(
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
    )`,
    [
      eventId, normalizedItems, groupedAttendees,
      primaryAttendee.name.trim(), primaryAttendee.email.trim().toLowerCase(),
      typeof primaryAttendee.phone === 'string' && primaryAttendee.phone.trim()
        ? primaryAttendee.phone.trim() : null,
      req.user ? req.user.id : null,
      `ORD-${now.getTime()}-${randomUUID().slice(0, 8)}`,
      idempotencyKey, fingerprint, hashAccessToken(accessToken),
      expiresAt, `88${randomBytes(8).toString('hex').slice(0, 14)}`,
    ]
  );

  const orderRow = await getOne(
    'SELECT id, guest_access_token_hash, purchaser_id FROM event_orders WHERE idempotency_key = $1',
    [idempotencyKey]
  );
  if (!orderRow) throw new Error('Created order could not be located');

  // Bila request paralel dengan key yang sama lebih dulu commit, token yang
  // tersimpan adalah milik request tersebut. Jangan menimpa atau mengklaimnya.
  const tokenMatches = !orderRow.purchaser_id && orderRow.guest_access_token_hash
    && hashAccessToken(accessToken) === orderRow.guest_access_token_hash;
  const order = await loadOrderById(orderRow.id);
  if (!order) throw new Error('Created order could not be loaded');

  res.status(201).json({
    success: true,
    order: serializeOrder(order),
    order_access_token: tokenMatches ? accessToken : null,
    ...(tokenMatches ? {} : { idempotent_replay: true }),
  });
});
const getOrder = asyncHandler(async (req, res) => {
  const order = await getAuthorizedOrder(
    req.params.id,
    req.user,
    req.get('X-Order-Access-Token'),
  );
  if (!order) {
    res.status(404);
    throw new Error('Order not found');
  }
  const serialized = serializeOrder(order);
  res.json({ success: true, order: serialized, data: serialized });
});

const listMyOrders = asyncHandler(async (req, res) => {
  const orderRows = await query(
    `SELECT ${ORDER_BASE_SELECT} FROM event_orders eo JOIN events e ON e.id = eo.event_id
     WHERE eo.purchaser_id = $1 ORDER BY eo.created_at DESC`,
    [req.user.id]
  );
  if (orderRows.length === 0) {
    return res.json({ success: true, orders: [] });
  }
  const orderIds = orderRows.map((o) => o.id);
  const itemRows = await query(
    `SELECT oi.id, oi.order_id, oi.ticket_type_id, oi.quantity, oi.unit_price, oi.subtotal,
            tt.name AS ticket_type_name
     FROM order_items oi
     JOIN ticket_types tt ON tt.id = oi.ticket_type_id
     WHERE oi.order_id = ANY($1::uuid[])`,
    [orderIds]
  );
  const paymentRows = await query(
    'SELECT * FROM order_payments WHERE order_id = ANY($1::uuid[])',
    [orderIds]
  );
  const itemsByOrder = {};
  for (const i of itemRows) {
    if (!itemsByOrder[i.order_id]) itemsByOrder[i.order_id] = [];
    itemsByOrder[i.order_id].push({
      id: i.id, order_id: i.order_id, ticket_type_id: i.ticket_type_id,
      quantity: i.quantity, unit_price: i.unit_price, subtotal: i.subtotal,
      ticket_types: { name: i.ticket_type_name },
    });
  }
  const paymentsByOrder = {};
  for (const p of paymentRows) {
    if (!paymentsByOrder[p.order_id]) paymentsByOrder[p.order_id] = [];
    paymentsByOrder[p.order_id].push(p);
  }

  const orders = orderRows.map((order) => serializeOrder({
    ...order,
    events: { title: order.event_title },
    order_items: itemsByOrder[order.id] || [],
    order_payments: paymentsByOrder[order.id] || [],
  }));
  res.json({ success: true, orders, data: orders });
});

module.exports.createOrder = createOrder;
module.exports.getOrder = getOrder;
module.exports.listMyOrders = listMyOrders;
