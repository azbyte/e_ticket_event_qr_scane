const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');

const EDITABLE_EVENT_STATUSES = [
  'DRAFT',
];

const toTicketTypeDto = (row) => ({
  ...row,
  price: Number(row.price),
});

const getEvent = async (eventId) => {
  const event = await getOne(
    'SELECT id, created_by, status, is_public FROM events WHERE id = $1',
    [eventId]
  );
  return event;
};

const assertEventAccess = async (eventId, user, { requireOwner = false } = {}) => {
  const event = await getEvent(eventId);
  if (!event) {
    const err = new Error('Event not found');
    err.statusCode = 404;
    throw err;
  }
  const isOwner = user && event.created_by === user.id;
  const isAdmin = user && user.role === 'admin';
  const isPublic = event.is_public && ['APPROVED', 'PUBLISHED'].includes(event.status);
  if (requireOwner ? (!isOwner && !isAdmin) : (!isPublic && !isOwner && !isAdmin)) {
    const err = new Error('Event not found');
    err.statusCode = 404;
    throw err;
  }
  if (requireOwner && !isAdmin && !EDITABLE_EVENT_STATUSES.includes(event.status)) {
    const err = new Error('Event status does not allow ticket type changes');
    err.statusCode = 409;
    throw err;
  }
  return event;
};

const validateDraft = (body, { partial = false, existing = null } = {}) => {
  const value = { ...existing, ...body };
  const errors = [];
  if (!partial || body.name !== undefined) {
    if (typeof value.name !== 'string' || value.name.trim().length === 0) {
      errors.push('Ticket type name is required');
    }
  }
  if (!partial || body.price !== undefined) {
    if (!Number.isFinite(Number(value.price)) || Number(value.price) < 0) {
      errors.push('Ticket price must be zero or greater');
    }
  }
  if (!partial || body.quota !== undefined) {
    if (!Number.isInteger(Number(value.quota)) || Number(value.quota) <= 0) {
      errors.push('Ticket quota must be a positive integer');
    }
    if (Number(value.quota) < Number(value.sold || 0) + Number(value.held || 0)) {
      errors.push('Ticket quota cannot be lower than sold plus held tickets');
    }
  }
  if (value.max_per_order !== null && value.max_per_order !== undefined) {
    const maxPerOrder = Number(value.max_per_order);
    if (!Number.isInteger(maxPerOrder) || maxPerOrder <= 0 || maxPerOrder > Number(value.quota)) {
      errors.push('Maximum per order must be a positive integer no greater than quota');
    }
  }
  if (value.sales_start && !Number.isFinite(Date.parse(value.sales_start))) {
    errors.push('Sales start must be a valid date');
  }
  if (value.sales_end && !Number.isFinite(Date.parse(value.sales_end))) {
    errors.push('Sales end must be a valid date');
  }
  if (value.sales_start && value.sales_end && Date.parse(value.sales_end) <= Date.parse(value.sales_start)) {
    errors.push('Sales end must be later than sales start');
  }
  return errors;
};

const validateTicketTypeUpdate = (updates, existing) => {
  const errors = validateDraft(updates, { partial: true, existing });
  if (updates.price !== undefined && Number(updates.price) !== Number(existing.price)) {
    errors.push('Ticket price cannot be changed after creation');
  }
  if (updates.quota !== undefined && Number(updates.quota) < Number(existing.quota)) {
    errors.push('Ticket quota can only be increased');
  }
  return errors;
};

const buildTicketTypeUpdate = (updates, ticketTypeId, eventId) => {
  const setParts = [];
  const params = [];
  let paramIndex = 1;
  for (const [field, val] of Object.entries(updates)) {
    setParts.push(`${field} = $${paramIndex}`);
    params.push(val);
    paramIndex += 1;
  }
  setParts.push('updated_at = NOW()');
  params.push(ticketTypeId);
  const eventParam = paramIndex + 1;
  params.push(eventId);

  // Include current invariant values in the UPDATE predicate to reject stale
  // concurrent changes while checkout updates held/sold quota.
  const where = [
    `id = $${paramIndex}`,
    `event_id = $${eventParam}`,
  ];
  if (updates.price !== undefined) {
    params.push(updates.price);
    where.push(`price = $${params.length}`);
  }
  if (updates.quota !== undefined) {
    params.push(updates.quota);
    where.push(`quota <= $${params.length}`);
    where.push(`$${params.length} >= sold + held`);
  }

  return {
    sql: `UPDATE ticket_types SET ${setParts.join(', ')} WHERE ${where.join(' AND ')} RETURNING *`,
    params,
  };
};

const listEventTicketTypes = asyncHandler(async (req, res) => {
  const event = await assertEventAccess(req.params.eventId, req.user);
  const rows = await query(
    'SELECT * FROM ticket_types WHERE event_id = $1 ORDER BY created_at ASC',
    [req.params.eventId]
  );
  res.json({ success: true, ticketTypes: rows.map(toTicketTypeDto), ticket_types: rows.map(toTicketTypeDto) });
});
const getTicketType = asyncHandler(async (req, res) => {
  const ticketTypeId = req.params.ticketTypeId || req.params.id;
  const row = await getOne('SELECT * FROM ticket_types WHERE id = $1', [ticketTypeId]);
  if (!row) {
    res.status(404);
    throw new Error('Ticket type not found');
  }
  await assertEventAccess(row.event_id, req.user);
  res.json({ success: true, ticketType: toTicketTypeDto(row), ticket_type: toTicketTypeDto(row) });
});

const createTicketType = asyncHandler(async (req, res) => {
  await assertEventAccess(req.params.eventId, req.user, { requireOwner: true });
  const errors = validateDraft(req.body);
  if (errors.length) {
    res.status(400);
    throw new Error(errors.join('; '));
  }
  const row = await getOne(
    `INSERT INTO ticket_types (id, event_id, name, description, price, quota, max_per_order, sales_start, sales_end, is_active, created_at, updated_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
     RETURNING *`,
    [
      req.params.eventId,
      String(req.body.name).trim(),
      req.body.description || null,
      Number(req.body.price),
      Number(req.body.quota),
      req.body.max_per_order !== null && req.body.max_per_order !== undefined ? Number(req.body.max_per_order) : null,
      req.body.sales_start || null,
      req.body.sales_end || null,
      req.body.is_active !== false,
    ]
  );
  res.status(201).json({ success: true, ticketType: toTicketTypeDto(row), ticket_type: toTicketTypeDto(row) });
});

const updateTicketType = asyncHandler(async (req, res) => {
  await assertEventAccess(req.params.eventId, req.user, { requireOwner: true });
  const existing = await getOne(
    'SELECT * FROM ticket_types WHERE id = $1 AND event_id = $2',
    [req.params.ticketTypeId, req.params.eventId]
  );
  if (!existing) {
    res.status(404);
    throw new Error('Ticket type not found');
  }
  const allowedFields = [
    'name', 'description', 'price', 'quota', 'max_per_order', 'sales_start', 'sales_end', 'is_active',
  ];
  const updates = Object.fromEntries(
    allowedFields.filter((field) => req.body[field] !== undefined)
      .map((field) => [field, req.body[field]])
  );
  if (!Object.keys(updates).length) {
    res.status(400);
    throw new Error('Provide ticket type fields to update');
  }
  const errors = validateTicketTypeUpdate(updates, existing);
  if (errors.length) {
    res.status(400);
    throw new Error(errors.join('; '));
  }
  if (updates.name !== undefined) updates.name = String(updates.name).trim();
  if (updates.price !== undefined) updates.price = Number(updates.price);
  if (updates.quota !== undefined) updates.quota = Number(updates.quota);
  if (updates.max_per_order !== undefined && updates.max_per_order !== null) {
    updates.max_per_order = Number(updates.max_per_order);
  }

  const update = buildTicketTypeUpdate(updates, req.params.ticketTypeId, req.params.eventId);
  const row = await getOne(
    update.sql,
    update.params
  );
  if (!row) {
    const stillExists = await getOne(
      'SELECT id FROM ticket_types WHERE id = $1 AND event_id = $2',
      [req.params.ticketTypeId, req.params.eventId]
    );
    if (!stillExists) {
      res.status(404);
      throw new Error('Ticket type not found');
    }
    res.status(409);
    throw new Error('Ticket type changed concurrently; reload and retry');
  }
  res.json({ success: true, ticketType: toTicketTypeDto(row), ticket_type: toTicketTypeDto(row) });
});

const deleteTicketType = asyncHandler(async (req, res) => {
  await assertEventAccess(req.params.eventId, req.user, { requireOwner: true });
  const existing = await getOne(
    'SELECT id, sold, held FROM ticket_types WHERE id = $1 AND event_id = $2',
    [req.params.ticketTypeId, req.params.eventId]
  );
  if (!existing) {
    res.status(404);
    throw new Error('Ticket type not found');
  }
  const orderItemRows = await query(
    'SELECT id FROM order_items WHERE ticket_type_id = $1',
    [req.params.ticketTypeId]
  );
  if (existing.sold > 0 || existing.held > 0 || orderItemRows.length > 0) {
    res.status(409);
    throw new Error('Ticket type with sales or orders cannot be deleted');
  }
  const deleted = await getOne(
    'DELETE FROM ticket_types WHERE id = $1 AND event_id = $2 RETURNING id',
    [req.params.ticketTypeId, req.params.eventId]
  );
  if (!deleted) {
    res.status(404);
    throw new Error('Ticket type not found');
  }
  res.json({ success: true, message: 'Ticket type deleted' });
});

module.exports = {
  listEventTicketTypes,
  getTicketType,
  createTicketType,
  updateTicketType,
  deleteTicketType,
  validateDraft,
  validateTicketTypeUpdate,
  buildTicketTypeUpdate,
};
