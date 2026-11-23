const asyncHandler = require('express-async-handler');
const { createHash, randomBytes } = require('node:crypto');
const { query, getOne } = require('../config/db');
const { buildInviteUrl } = require('../utils/eventResponse');

const DEFAULT_EXPIRY_DAYS = 7;
const DEFAULT_PERMISSIONS = ['VIEW_EVENT', 'SCAN_TICKET', 'CHECK_IN_TICKET'];
const PERMISSION_CODES = new Set([
  'VIEW_EVENT', 'VIEW_PARTICIPANTS', 'ASSIST_REGISTRATION', 'VIEW_ORDERS', 'SCAN_TICKET',
  'CHECK_IN_TICKET', 'VIEW_SCAN_HISTORY', 'VIEW_REPORTS', 'EXPORT_PARTICIPANTS',
]);

const hashToken = (token) => createHash('sha256').update(token).digest('hex');

const getEventForOrganizer = async (eventId, user) => {
  const event = await getOne('SELECT id, created_by, status FROM events WHERE id = $1', [eventId]);
  if (!event) {
    const err = new Error('Event not found'); err.statusCode = 404; throw err;
  }
  if (user.role !== 'admin' && event.created_by !== user.id) {
    const err = new Error('You do not own this event'); err.statusCode = 403; throw err;
  }
  return event;
};

const normalizePermissions = (permissions) => {
  let perms = Array.isArray(permissions) ? permissions : [...DEFAULT_PERMISSIONS];
  perms = perms.filter((p) => PERMISSION_CODES.has(p));
  if (perms.length === 0) perms = [...DEFAULT_PERMISSIONS];
  return [...new Set(perms)];
};

const createInvitation = asyncHandler(async (req, res) => {
  const user = req.user;
  const eventId = req.params.eventId;
  await getEventForOrganizer(eventId, user);

  const { email, name, permissions, expiresAt } = req.body;
  if (!email || typeof email !== 'string' || email.trim().length === 0) {
    res.status(400);
    throw new Error('Email staff diperlukan');
  }
  const normalizedEmail = email.trim().toLowerCase();
  const perms = normalizePermissions(permissions);
  const expires = expiresAt
    ? new Date(expiresAt)
    : new Date(Date.now() + DEFAULT_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  const rawToken = randomBytes(32).toString('base64url');
  const tokenHash = hashToken(rawToken);
  const inviteeName = typeof name === 'string' && name.trim().length > 0 ? name.trim() : null;

  const inserted = await query(
    `INSERT INTO event_invitations (id, event_id, invited_by_id, email, token_hash, status, expires_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, 'PENDING', $5)
     RETURNING *`,
    [eventId, user.id, normalizedEmail, tokenHash, expires.toISOString()]
  );
  const invitation = inserted[0];

  if (perms.length > 0) {
    const placeholders = perms
      .map((_, index) => `(gen_random_uuid(), $1, $${index + 2})`)
      .join(', ');
    await query(
      `INSERT INTO event_invitation_permissions (id, event_invitation_id, permission)
       VALUES ${placeholders}
       ON CONFLICT (event_invitation_id, permission) DO NOTHING`,
      [invitation.id, ...perms]
    );
  }

  const origin = String(req.get('origin') || '').replace(/\/$/, '');
  res.status(201).json({
    success: true,
    invitation: {
      ...invitation,
      name: inviteeName,
      token: rawToken,
      invitation_link: origin ? `${origin}/invite/${rawToken}` : null,
      // Tautan undangan kanonik dari APP_PUBLIC_URL (aditif; tidak mengubah
      // `invitation_link` lama agar klien lain tetap kompatibel).
      invite_url: buildInviteUrl(rawToken),
      permissions: perms,
    },
  });
});

const listInvitations = asyncHandler(async (req, res) => {
  const user = req.user;
  await getEventForOrganizer(req.params.eventId, user);
  const rows = await query(
    `SELECT i.*, e.title AS event_title, e.status AS event_status,
            ep.permission
     FROM event_invitations i
     LEFT JOIN events e ON e.id = i.event_id
     LEFT JOIN event_invitation_permissions ep ON ep.event_invitation_id = i.id
     WHERE i.event_id = $1
     ORDER BY i.created_at DESC`,
    [req.params.eventId]
  );
  const grouped = {};
  for (const row of rows) {
    if (!grouped[row.id]) {
      grouped[row.id] = {
        id: row.id, event_id: row.event_id, invited_by_id: row.invited_by_id,
        email: row.email, status: row.status, expires_at: row.expires_at,
        accepted_at: row.accepted_at, revoked_at: row.revoked_at,
        created_at: row.created_at, event_title: row.event_title, event_status: row.event_status,
        permissions: [],
      };
    }
    if (row.permission) grouped[row.id].permissions.push(row.permission);
  }
  res.json({ success: true, count: Object.keys(grouped).length, invitations: Object.values(grouped) });
});
const revokeInvitation = asyncHandler(async (req, res) => {
  const user = req.user;
  const invitation = await getOne(
    `SELECT i.*, e.created_by AS event_owner FROM event_invitations i
     JOIN events e ON e.id = i.event_id
     WHERE i.id = $1`,
    [req.params.invitationId]
  );
  if (!invitation) {
    res.status(404);
    throw new Error('Undangan tidak ditemukan');
  }
  if (invitation.event_owner !== user.id && user.role !== 'admin') {
    res.status(403);
    throw new Error('Anda tidak memiliki akses ke undangan ini');
  }
  const updated = await query(
    `UPDATE event_invitations SET status = 'REVOKED', revoked_at = NOW() WHERE id = $1 RETURNING *`,
    [req.params.invitationId]
  );
  res.json({ success: true, message: 'Undangan dicabut', invitation: updated[0] });
});

const acceptInvitation = asyncHandler(async (req, res) => {
  const user = req.user;
  const token = req.params.token;
  if (!token) {
    res.status(400);
    throw new Error('Token undangan diperlukan');
  }

  const tokenHash = hashToken(token);
  const invitation = await getOne(
    `SELECT * FROM event_invitations WHERE token_hash = $1`,
    [tokenHash]
  );
  if (!invitation) {
    res.status(404);
    throw new Error('Undangan tidak valid atau tidak ditemukan');
  }
  if (invitation.status !== 'PENDING') {
    res.status(409);
    throw new Error('Undangan tidak aktif atau sudah dipakai');
  }
  if (new Date(invitation.expires_at) <= new Date()) {
    res.status(410);
    throw new Error('Undangan sudah kedaluwarsa');
  }
  if (invitation.email !== String(user.email).toLowerCase()) {
    res.status(403);
    throw new Error('Undangan ini bukan untuk akun Anda');
  }

  const updated = await query(
    `UPDATE event_invitations SET status = 'ACCEPTED', accepted_by_id = $1, accepted_at = NOW() WHERE id = $2 RETURNING *`,
    [user.id, invitation.id]
  );
  const invitationRow = updated[0];

  await query(
    `INSERT INTO event_members (id, event_id, user_id, role, created_at)
     VALUES (gen_random_uuid(), $1, $2, 'staff', NOW())
     ON CONFLICT (event_id, user_id) DO UPDATE SET role = 'staff', created_at = NOW()
     RETURNING *`,
    [invitation.event_id, user.id]
  );
  const member = await getOne(
    `SELECT em.id AS member_id, em.role AS role, em.created_at AS created_at
     FROM event_members em
     WHERE em.event_id = $1 AND em.user_id = $2
     ORDER BY em.created_at DESC LIMIT 1`,
    [invitation.event_id, user.id]
  );

  const perms = await query(
    'SELECT permission FROM event_invitation_permissions WHERE event_invitation_id = $1',
    [invitation.id]
  );
  const permRows = (perms || []).map((p) => p.permission);
  if (permRows.length > 0) {
    const placeholders = permRows
      .map((_, index) => `(gen_random_uuid(), $1, $${index + 2})`)
      .join(', ');
    await query(
      `INSERT INTO event_member_permissions (id, event_member_id, permission)
       VALUES ${placeholders}
       ON CONFLICT (event_member_id, permission) DO NOTHING`,
      [member.member_id, ...permRows]
    );
  }

  res.json({
    success: true,
    message: 'Undangan diterima. Anda adalah staf pada event ini.',
    member,
    invitation: invitationRow,
  });
});

const myInvitations = asyncHandler(async (req, res) => {
  const user = req.user;
  const rows = await query(
    `SELECT i.*, e.id AS event_id, e.title AS event_title, e.status AS event_status,
            ep.permission
     FROM event_invitations i
     LEFT JOIN events e ON e.id = i.event_id
     LEFT JOIN event_invitation_permissions ep ON ep.event_invitation_id = i.id
     WHERE i.email = $1 AND i.status = 'PENDING'
     ORDER BY i.created_at DESC`,
    [String(user.email).toLowerCase()]
  );
  const grouped = {};
  for (const row of rows) {
    if (!grouped[row.id]) {
      grouped[row.id] = {
        id: row.id, event_id: row.event_id, email: row.email,
        status: row.status, expires_at: row.expires_at,
        accepted_at: row.accepted_at, revoked_at: row.revoked_at,
        created_at: row.created_at, event_title: row.event_title,
        event_status: row.event_status, permissions: [],
      };
    }
    if (row.permission) grouped[row.id].permissions.push(row.permission);
  }
  res.json({ success: true, count: Object.keys(grouped).length, invitations: Object.values(grouped) });
});

module.exports = {
  createInvitation,
  listInvitations,
  revokeInvitation,
  acceptInvitation,
  myInvitations,
};
