const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const { serializeEvent } = require('../utils/eventResponse');

const EVENT_PERMISSION_CODES = new Set([
  'VIEW_EVENT', 'VIEW_PARTICIPANTS', 'ASSIST_REGISTRATION', 'VIEW_ORDERS', 'SCAN_TICKET',
  'CHECK_IN_TICKET', 'VIEW_SCAN_HISTORY', 'VIEW_REPORTS', 'EXPORT_PARTICIPANTS',
]);

const normalizePermissions = (permissions) => {
  if (!Array.isArray(permissions)) return [];
  return [...new Set(permissions.filter((p) => EVENT_PERMISSION_CODES.has(p)))];
};

const EVENT_SELECT_ALIAS = `
  e.*,
  c.name AS category_name
`;
const EVENT_FROM = `FROM events e LEFT JOIN event_categories c ON e.category_id = c.id`;
const EDITABLE_EVENT_STATUSES = [
  'DRAFT',
  'PENDING_REVIEW',
  'REVISION_REQUESTED',
  'REJECTED',
  'APPROVED',
  'PUBLISHED',
];

const attachCategory = (row) => {
  if (row && row.category_name && !row.event_categories) {
    row.event_categories = [{ name: row.category_name }];
  }
  return row;
};

const getCategory = async (name) => {
  if (!name) return null;
  const row = await getOne('SELECT id, name FROM event_categories WHERE name = $1', [String(name).trim()]);
  if (!row) {
    const err = new Error('Event category is not available');
    err.statusCode = 400;
    throw err;
  }
  return row;
};

const getEventForOwner = async (eventId, user) => {
  const event = await getOne(`SELECT * FROM events WHERE id = $1`, [eventId]);
  if (!event) {
    const err = new Error('Event not found');
    err.statusCode = 404;
    throw err;
  }
  if (user.role !== 'admin' && event.created_by !== user.id) {
    const err = new Error('You do not own this event');
    err.statusCode = 403;
    throw err;
  }
  return event;
};

const getEvents = asyncHandler(async (req, res) => {
  const params = [];
  let conditions = ['e.is_public = true', "e.status IN ('APPROVED', 'PUBLISHED')"];
  let paramIndex = 1;

  if (req.query.q) {
    conditions.push(`e.title ILIKE $${paramIndex}`);
    params.push(`%${String(req.query.q).trim()}%`);
    paramIndex += 1;
  }
  const category = String(req.query.category || '').trim();
  if (category && category.toLowerCase() !== 'semua') {
    const cat = await getCategory(category);
    conditions.push(`e.category_id = $${paramIndex}`);
    params.push(cat.id);
    paramIndex += 1;
  }

  const rows = await query(
    `SELECT ${EVENT_SELECT_ALIAS} ${EVENT_FROM} WHERE ${conditions.join(' AND ')} ORDER BY e.created_at DESC`,
    params
  );
  const events = rows.map((r) => serializeEvent(attachCategory(r)));

  res.json({ success: true, count: events.length, events });
});

const getEventById = asyncHandler(async (req, res) => {
  const event = await getOne(
    `SELECT ${EVENT_SELECT_ALIAS} ${EVENT_FROM} WHERE e.id = $1`,
    [req.params.id]
  );

  if (!event) {
    res.status(404);
    throw new Error('Event not found');
  }
  const visible = event.is_public && ['APPROVED', 'PUBLISHED'].includes(event.status);
  const permitted = req.user && (req.user.role === 'admin' || req.user.id === event.created_by);
  if (!visible && !permitted) {
    res.status(404);
    throw new Error('Event not found');
  }

  res.json({ success: true, event: serializeEvent(attachCategory(event)) });
});

const getAllEvents = asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT ${EVENT_SELECT_ALIAS} ${EVENT_FROM} ORDER BY e.created_at DESC`
  );
  const events = rows.map((r) => serializeEvent(attachCategory(r)));
  res.json({ success: true, count: events.length, events });
});

const getMyEvents = asyncHandler(async (req, res) => {
  const params = [req.user.id];
  let conditions = ['e.created_by = $1'];
  let paramIndex = 2;

  if (req.query.q) {
    conditions.push(`e.title ILIKE $${paramIndex}`);
    params.push(`%${String(req.query.q).trim()}%`);
    paramIndex += 1;
  }

  const rows = await query(
    `SELECT ${EVENT_SELECT_ALIAS} ${EVENT_FROM} WHERE ${conditions.join(' AND ')} ORDER BY e.updated_at DESC`,
    params
  );
  const events = rows.map((r) => serializeEvent(attachCategory(r)));
  res.json({ success: true, count: events.length, events });
});
const validateEventInput = (body) => {
  if (!body || typeof body !== 'object') return false;
  const { title, date, event_date, start_date_time } = body;
  const eventDate = event_date || start_date_time || date;
  const normalizedTitle = String(title || '').trim();
  const eventFormat = String(body.event_format || body.event_type || 'OFFLINE').toUpperCase();
  const validFormats = ['OFFLINE', 'ONLINE', 'HYBRID'];
  const parsedStart = Date.parse(eventDate || '');
  const parsedEnd = Date.parse(body.end_date_time || '');
  const location = String(body.location || '').trim();
  const onlineUrl = String(body.online_url || '').trim();
  const organizerName = String(body.organizer_name || '').trim();
  const contactInfo = String(body.contact_info || '').trim();
  const validOnlineUrl = /^https?:\/\/\S+$/i.test(onlineUrl);
  const attendeeFields = body.attendee_fields;

  if (normalizedTitle.length < 3 || !Number.isFinite(parsedStart) || !Number.isFinite(parsedEnd) ||
      parsedEnd <= parsedStart || !validFormats.includes(eventFormat) || !organizerName || !contactInfo ||
      (['OFFLINE', 'HYBRID'].includes(eventFormat) && !location) ||
      (['ONLINE', 'HYBRID'].includes(eventFormat) && !validOnlineUrl) ||
      !Array.isArray(attendeeFields) || attendeeFields.length === 0 ||
      !attendeeFields.includes('name') ||
      attendeeFields.some((field) => !['name', 'email', 'phone', 'organization'].includes(field))) {
    return false;
  }
  return true;
};

const createEvent = asyncHandler(async (req, res) => {
  const { title, description, date, event_date, start_date_time } = req.body;
  const eventDate = event_date || start_date_time || date;
  const normalizedTitle = String(title || '').trim();
  const eventFormat = String(req.body.event_format || req.body.event_type || 'OFFLINE').toUpperCase();
  const location = String(req.body.location || '').trim();
  const onlineUrl = String(req.body.online_url || '').trim();
  const organizerName = String(req.body.organizer_name || '').trim();
  const contactInfo = String(req.body.contact_info || '').trim();
  const attendeeFields = req.body.attendee_fields;

  if (!validateEventInput(req.body)) {
    res.status(400);
    throw new Error('Provide a valid title, date, event format, and date range');
  }

  const category = await getCategory(req.body.category);
  if (!category) {
    res.status(400);
    throw new Error('Event category is required');
  }

  const created = await getOne(
    `INSERT INTO events (
      title, description, poster_url, event_date, end_date_time, time_zone,
      event_format, location, online_url, contact_info, organizer_name, public_info,
      attendee_fields, category_id, status, is_public, total_tickets, price,
      created_by, created_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
      $14, $15, $16, $17, $18, $19, $20, $21
    ) RETURNING *`,
    [
      normalizedTitle,
      description ? String(description).trim() : null,
      req.body.poster_url || null,
      eventDate,
      req.body.end_date_time || null,
      req.body.time_zone || null,
      eventFormat,
      location || null,
      onlineUrl || null,
      contactInfo,
      organizerName,
      req.body.public_info || null,
      JSON.stringify(attendeeFields),
      category.id,
      'DRAFT',
      false,
      0,
      0,
      req.user.id,
      new Date().toISOString(),
      new Date().toISOString(),
    ]
  );
  created.event_categories = [{ name: category.name }];
  res.status(201).json({ success: true, event: serializeEvent(attachCategory(created)) });
});
const updateEvent = asyncHandler(async (req, res) => {
  const existing = await getEventForOwner(req.params.id, req.user);
  if (!EDITABLE_EVENT_STATUSES.includes(existing.status)) {
    res.status(409);
    throw new Error('Event status does not allow changes');
  }

  const setParts = [];
  const params = [];
  let paramIndex = 1;

  const add = (col, val) => {
    setParts.push(`${col} = $${paramIndex}`);
    params.push(val);
    paramIndex += 1;
  };

  if (req.body.title !== undefined) { add('title', String(req.body.title).trim()); }
  if (req.body.description !== undefined) { add('description', String(req.body.description).trim() || null); }
  if (req.body.poster_url !== undefined) { add('poster_url', req.body.poster_url || null); }
  if (req.body.event_date !== undefined || req.body.date !== undefined || req.body.start_date_time !== undefined) {
    const v = req.body.event_date || req.body.date || req.body.start_date_time;
    if (!Number.isFinite(Date.parse(v || ''))) {
      res.status(400);
      throw new Error('Event start date must be valid');
    }
    add('event_date', v);
  }
  if (req.body.end_date_time !== undefined) {
    if (!Number.isFinite(Date.parse(req.body.end_date_time || ''))) {
      res.status(400);
      throw new Error('Event end date must be valid');
    }
    add('end_date_time', req.body.end_date_time);
  }
  if (req.body.time_zone !== undefined) { add('time_zone', req.body.time_zone || null); }
  if (req.body.event_format !== undefined || req.body.event_type !== undefined) {
    add('event_format', String(req.body.event_format || req.body.event_type || 'OFFLINE').toUpperCase());
  }
  if (req.body.location !== undefined) { add('location', String(req.body.location || '').trim() || null); }
  if (req.body.online_url !== undefined) { add('online_url', String(req.body.online_url || '').trim() || null); }
  if (req.body.contact_info !== undefined) { add('contact_info', String(req.body.contact_info || '').trim()); }
  if (req.body.organizer_name !== undefined) { add('organizer_name', String(req.body.organizer_name || '').trim()); }
  if (req.body.public_info !== undefined) { add('public_info', req.body.public_info || null); }
  if (req.body.attendee_fields !== undefined) { add('attendee_fields', JSON.stringify(req.body.attendee_fields)); }
  if (req.body.category !== undefined) {
    const cat = await getCategory(req.body.category);
    add('category_id', cat.id);
    existing.category_name = cat.name;
  }

  const start = existing.event_date ? new Date(existing.event_date) : null;
  const endValue = existing.end_date_time ? new Date(existing.end_date_time) : null;
  if (req.body.event_date !== undefined || req.body.end_date_time !== undefined) {
    const startParsed = req.body.event_date !== undefined ? Date.parse(req.body.event_date) : (start ? start.getTime() : null);
    const endParsed = req.body.end_date_time !== undefined ? Date.parse(req.body.end_date_time) : (endValue ? endValue.getTime() : null);
    if (!startParsed || !endParsed || endParsed <= startParsed) {
      res.status(400);
      throw new Error('Event end date must be later than the start date');
    }
  }
  const format = (req.body.event_format || req.body.event_type || existing.event_format);
  const location = req.body.location !== undefined ? String(req.body.location).trim() : existing.location;
  const onlineUrl = req.body.online_url !== undefined ? String(req.body.online_url).trim() : existing.online_url;
  if ((['OFFLINE', 'HYBRID'].includes(format) && !location) ||
      (['ONLINE', 'HYBRID'].includes(format) && !/^https?:\/\/\S+$/i.test(onlineUrl))) {
    res.status(400);
    throw new Error('Event format requires a valid location or online URL');
  }
  if (setParts.length === 0) {
    res.status(400);
    throw new Error('Please provide event fields to update');
  }

  setParts.push('updated_at = NOW()');
  params.push(req.params.id);
  const row = await getOne(
    `UPDATE events SET ${setParts.join(', ')} WHERE id = $${paramIndex} AND ($${paramIndex + 1} = 'admin' OR created_by = $${paramIndex + 2})
     RETURNING *`,
    [...params, req.user.role, req.user.id]
  );

  if (!row) {
    res.status(404);
    throw new Error('Event not found or unauthorized');
  }
  row.event_categories = existing.event_categories || (row.category_name ? [{ name: row.category_name }] : null);
  res.json({ success: true, event: serializeEvent(attachCategory(row)) });
});
const deleteEvent = asyncHandler(async (req, res) => {
  const existing = await getEventForOwner(req.params.id, req.user);
  if (existing.status !== 'DRAFT') {
    res.status(409);
    throw new Error('Only draft events can be deleted');
  }

  const historyChecks = await Promise.all(
    ['event_orders', 'tickets', 'event_moderations', 'event_activity_logs'].map((table) =>
      query(`SELECT COUNT(*) AS cnt FROM ${table} WHERE event_id = $1`, [req.params.id])
    )
  );
  if (historyChecks.some((result) => Number(result[0].cnt) > 0)) {
    res.status(409);
    throw new Error('Draft event with orders, tickets, or history cannot be deleted');
  }

  const deleted = await getOne(
    `DELETE FROM events WHERE id = $1 AND ($2 = 'admin' OR created_by = $3) RETURNING id`,
    [req.params.id, req.user.role, req.user.id]
  );
  if (!deleted) {
    res.status(404);
    throw new Error('Event not found or unauthorized');
  }
  res.json({ success: true, message: 'Event deleted' });
});

const submitForReview = asyncHandler(async (req, res) => {
  const event = await getEventForOwner(req.params.id, req.user);
  if (!['DRAFT', 'REVISION_REQUESTED', 'REJECTED'].includes(event.status)) {
    res.status(409);
    throw new Error('Event is not eligible for moderation review');
  }
  const now = new Date().toISOString();
  const row = await getOne(
    `UPDATE events SET status = 'PENDING_REVIEW', submitted_at = $1, review_note = null
     WHERE id = $2 RETURNING *`,
    [now, req.params.id]
  );
  res.json({ success: true, event: serializeEvent(attachCategory(row)) });
});

const ensureEventOwner = async (eventId, userId) => {
  const data = await getOne('SELECT id, created_by FROM events WHERE id = $1', [eventId]);
  if (!data) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (data.created_by !== userId) {
    const err = new Error('You do not own this event'); err.statusCode = 403; throw err;
  }
  return data;
};

const getEventMembers = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  const rows = await query(
    `SELECT em.id AS member_id, em.user_id, em.role, em.created_at,
            p.id, p.name, p.email, p.username, p.avatar_url
     FROM event_members em
     JOIN profiles p ON p.id = em.user_id
     WHERE em.event_id = $1
     ORDER BY em.created_at ASC`,
    [req.params.id]
  );
  const permissionRows = await query(
    `SELECT emp.event_member_id, emp.permission
     FROM event_member_permissions emp
     JOIN event_members em ON em.id = emp.event_member_id
     WHERE em.event_id = $1`,
    [req.params.id]
  );
  const permissionsByMember = {};
  for (const row of permissionRows) {
    if (!permissionsByMember[row.event_member_id]) permissionsByMember[row.event_member_id] = [];
    permissionsByMember[row.event_member_id].push(row.permission);
  }
  const members = rows.map((row) => ({
    ...row,
    permissions: permissionsByMember[row.member_id] || [],
  }));
  res.json({ success: true, members });
});

const addEventMember = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  const identity = String(req.body.email || req.body.username || '').trim().toLowerCase();
  if (!identity) {
    res.status(400);
    throw new Error('Provide a member email or username');
  }
  if (identity === String(req.user.id) || identity === req.user.email) {
    res.status(400);
    throw new Error('The event owner cannot also be added as a member');
  }

  let account = await getOne('SELECT id, role FROM profiles WHERE email = $1', [identity]);
  if (!account && !identity.includes('@')) {
    account = await getOne('SELECT id, role FROM profiles WHERE username = $1', [identity]);
  }
  if (!account) {
    res.status(404);
    throw new Error('Account not found');
  }
  if (account.id === req.user.id) {
    res.status(400);
    throw new Error('The event owner cannot also be added as a member');
  }

  const existingMember = await getOne(
    'SELECT id FROM event_members WHERE event_id = $1 AND user_id = $2',
    [req.params.id, account.id]
  );
  if (existingMember) {
    res.status(409);
    throw new Error('Account is already a member of this event');
  }

  const permissions = normalizePermissions(req.body.permissions);
  const inserted = await getOne(
    `INSERT INTO event_members (id, event_id, user_id, role, created_at)
     VALUES (gen_random_uuid(), $1, $2, 'staff', NOW())
     RETURNING id, user_id, role, created_at`,
    [req.params.id, account.id]
  );
  if (permissions.length > 0) {
    const placeholders = permissions
      .map((_, index) => `(gen_random_uuid(), $1, $${index + 2})`)
      .join(', ');
    await query(
      `INSERT INTO event_member_permissions (id, event_member_id, permission)
       VALUES ${placeholders}
       ON CONFLICT (event_member_id, permission) DO NOTHING`,
      [inserted.id, ...permissions]
    );
  }

  const clean = await getOne(
    `SELECT em.id AS member_id, em.user_id, em.role, em.created_at,
            p.id, p.name, p.email, p.username, p.avatar_url
     FROM event_members em
     JOIN profiles p ON p.id = em.user_id
     WHERE em.event_id = $1 AND em.user_id = $2
     ORDER BY em.created_at DESC LIMIT 1`,
    [req.params.id, account.id]
  );
  res.status(201).json({ success: true, member: { ...clean, permissions } });
});

const updateEventMemberPermissions = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  const member = await getOne(
    'SELECT id FROM event_members WHERE event_id = $1 AND user_id = $2',
    [req.params.id, req.params.userId]
  );
  if (!member) {
    res.status(404);
    throw new Error('Event member not found');
  }
  const permissions = normalizePermissions(req.body.permissions);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM event_member_permissions WHERE event_member_id = $1', [member.id]);
    if (permissions.length > 0) {
      const placeholders = permissions
        .map((_, index) => `(gen_random_uuid(), $1, $${index + 2})`)
        .join(', ');
      await client.query(
        `INSERT INTO event_member_permissions (id, event_member_id, permission)
         VALUES ${placeholders}
         ON CONFLICT (event_member_id, permission) DO NOTHING`,
        [member.id, ...permissions]
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* transaksi sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }

  res.json({ success: true, message: 'Member permissions updated', permissions });
});

const removeEventMember = asyncHandler(async (req, res) => {
  await ensureEventOwner(req.params.id, req.user.id);
  if (req.params.userId === req.user.id) {
    res.status(400);
    throw new Error('The event owner is not an event member');
  }
  const deleted = await getOne(
    `DELETE FROM event_members WHERE event_id = $1 AND user_id = $2 RETURNING user_id`,
    [req.params.id, req.params.userId]
  );
  if (!deleted) {
    res.status(404);
    throw new Error('Event member not found');
  }
  res.json({ success: true, message: 'Event member removed' });
});

module.exports = {
  getEvents,
  getMyEvents,
  getAllEvents,
  getEventById,
  createEvent,
  updateEvent,
  deleteEvent,
  submitForReview,
  getEventMembers,
  addEventMember,
  updateEventMemberPermissions,
  removeEventMember,
  validateEventInput,
  normalizePermissions,
  EDITABLE_EVENT_STATUSES,
  EVENT_PERMISSION_CODES,
  getEventForOwner,
};
