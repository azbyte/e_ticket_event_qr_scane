const asyncHandler = require('express-async-handler');
const { createHash, randomUUID } = require('node:crypto');
const { query, getOne } = require('../config/db');
const staffAccess = require('../services/staffAccessService');
const { buildStaffAccessUrl } = require('../utils/eventResponse');
const logger = require('../utils/logger');

/**
 * Undangan staf berbasis NAMA + KODE AKSES (PRD §6.2 revisi).
 *
 * Alur:
 *  1. Organizer memasukkan nama staf → backend membuat kode akses acak unik
 *     (global, dijaga indeks unik `access_code_hash`) dan tautan undangan.
 *  2. Tautan (`/staff-access/:invitationId`) hanya mengidentifikasi undangan;
 *     membukanya TIDAK memberi akses scanner.
 *  3. Staf mengetik kode akses pada halaman tersebut → backend memvalidasi kode,
 *     status undangan, masa berlaku, dan event undangan, lalu menerbitkan sesi
 *     staf (JWT) yang terikat pada undangan + event.
 *  4. Endpoint scanner hanya menerima sesi staf yang masih aktif; permintaan
 *     untuk event lain ditolak (lihat `staffAuthMiddleware` dan
 *     `assertScanPermission`).
 *
 * Kode akses tidak pernah disimpan sebagai plaintext: `access_code_hash`
 * (SHA-256, dipakai verifikasi) dan `access_code_cipher` (AES-256-GCM, hanya
 * untuk ditampilkan kembali kepada Organizer pemilik event).
 */

const DEFAULT_EXPIRY_DAYS = 7;
const MAX_EXPIRY_DAYS = 90;
const DEFAULT_PERMISSIONS = ['VIEW_EVENT', 'SCAN_TICKET', 'CHECK_IN_TICKET'];
const PERMISSION_CODES = new Set([
  'VIEW_EVENT', 'VIEW_PARTICIPANTS', 'ASSIST_REGISTRATION', 'VIEW_ORDERS', 'SCAN_TICKET',
  'CHECK_IN_TICKET', 'VIEW_SCAN_HISTORY', 'VIEW_REPORTS', 'EXPORT_PARTICIPANTS',
]);

const httpError = (message, statusCode) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

/**
 * Fitur kode akses staf membutuhkan kolom dari migration
 * `20261201000000_staff_access_codes`. Bila database belum dimigrasikan,
 * query akan gagal dengan error SQL `42703` (undefined_column) yang tidak
 * informatif bagi Organizer. Periksa sekali di awal request agar pengguna
 * mendapat pesan yang dapat ditindaklanjuti alih-alih "Internal Server Error".
 *
 * Status 424 (Failed Dependency) dipakai—bukan 503—karena middleware error
 * menyamarkan pesan untuk status >= 500.
 */
const assertStaffSchemaReady = async () => {
  const ready = await getOne(
    `SELECT 1 AS ready
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'event_invitations'
       AND column_name = 'access_code_hash'`
  );
  if (!ready) {
    logger.error('staff_invitation_schema_missing', {
      migration: '20261201000000_staff_access_codes',
    });
    throw httpError(
      'Fitur staf belum siap di server: skema database undangan staf belum dimigrasikan. Hubungi Admin untuk menerapkan migration.',
      424
    );
  }
};

/** Event harus milik Organizer (atau Admin). */
const getEventForOwner = async (eventId, user) => {
  const event = await getOne(
    'SELECT id, created_by, title, status, event_date, end_date_time, location, event_format FROM events WHERE id = $1',
    [eventId]
  );
  if (!event) throw httpError('Event not found', 404);
  if (user.role !== 'admin' && event.created_by !== user.id) {
    throw httpError('You do not own this event', 403);
  }
  return event;
};

const normalizePermissions = (permissions) => {
  let list = Array.isArray(permissions) ? permissions : [...DEFAULT_PERMISSIONS];
  list = list.filter((code) => PERMISSION_CODES.has(code));
  if (list.length === 0) list = [...DEFAULT_PERMISSIONS];
  return [...new Set(list)];
};

const parseExpiryDays = (value, fallback = DEFAULT_EXPIRY_DAYS) => {
  const days = Number(value);
  if (!Number.isFinite(days) || days <= 0) return fallback;
  return Math.min(Math.ceil(days), MAX_EXPIRY_DAYS);
};

/**
 * `event_invitations.token_hash` masih NOT NULL dan unik pada schema lama.
 * Undangan berbasis kode tidak memakai tautan bertoken rahasia, sehingga kolom
 * itu diisi hash deterministik dari id undangan (bukan rahasia, tidak pernah
 * cocok dengan masukan pengguna). Dengan begitu alur undangan email lama tidak
 * dapat dipakai untuk membuka undangan baru.
 */
const disabledLinkTokenHash = (invitationId) =>
  createHash('sha256').update(`staff-invitation:${invitationId}`, 'utf8').digest('hex');

const insertPermissions = async (invitationId, permissions) => {
  if (permissions.length === 0) return;
  const placeholders = permissions
    .map((_, index) => `(gen_random_uuid(), $1, $${index + 2})`)
    .join(', ');
  await query(
    `INSERT INTO event_invitation_permissions (id, event_invitation_id, permission)
     VALUES ${placeholders}
     ON CONFLICT (event_invitation_id, permission) DO NOTHING`,
    [invitationId, ...permissions]
  );
};

const readPermissions = async (invitationId) => {
  const rows = await query(
    'SELECT permission FROM event_invitation_permissions WHERE event_invitation_id = $1',
    [invitationId]
  );
  return (rows || []).map((row) => row.permission);
};

/** Status efektif: undangan yang lewat masa berlaku tampil sebagai EXPIRED. */
const effectiveStatus = (row) => {
  if (row.status === 'PENDING' || row.status === 'ACCEPTED') {
    if (row.expires_at && new Date(row.expires_at) <= new Date()) return 'EXPIRED';
  }
  return row.status;
};

/** Bentuk undangan untuk response Organizer (memuat kode akses milik event). */
const presentInvitation = (row, permissions) => {
  const code = staffAccess.decryptAccessCode(row.access_code_cipher);
  return {
    id: row.id,
    event_id: row.event_id,
    staff_name: row.staff_name || 'Staf',
    status: effectiveStatus(row),
    permissions,
    expires_at: row.expires_at,
    accepted_at: row.accepted_at,
    revoked_at: row.revoked_at,
    created_at: row.created_at,
    has_access_code: Boolean(row.access_code_hash),
    // Undangan email lama (belum punya nama/kode) tetap ditampilkan agar
    // Organizer dapat menerbitkan kode akses dan memigrasikannya.
    is_legacy: !row.staff_name && !row.access_code_hash,
    // Hanya Organizer pemilik event yang menerima endpoint ini.
    access_code: code ? staffAccess.formatAccessCode(code) : null,
    access_code_masked: code ? staffAccess.maskAccessCode(code) : null,
    invite_url: buildStaffAccessUrl(row.id),
  };
};

/** Buat undangan baru (nama staf + kode akses unik global). */
const createStaffInvitation = asyncHandler(async (req, res) => {
  const eventId = req.params.eventId;
  await getEventForOwner(eventId, req.user);
  await assertStaffSchemaReady();

  const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  if (name.length < 2) {
    res.status(400);
    throw httpError('Nama staf wajib diisi (minimal 2 karakter)', 400);
  }
  if (name.length > 80) {
    res.status(400);
    throw httpError('Nama staf maksimal 80 karakter', 400);
  }

  const permissions = normalizePermissions(req.body.permissions);
  const expiryDays = parseExpiryDays(req.body.expiryDays ?? req.body.expiry_days);
  const expiresAt = new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000);

  let invitation = null;
  let accessCode = null;
  for (let attempt = 0; attempt < staffAccess.MAX_CODE_ATTEMPTS && !invitation; attempt += 1) {
    const invitationId = randomUUID();
    const candidate = staffAccess.generateAccessCode();
    try {
      const inserted = await query(
        `INSERT INTO event_invitations
           (id, event_id, invited_by_id, email, token_hash, staff_name,
            access_code_hash, access_code_cipher, access_code_issued_at, status, expires_at)
         VALUES ($1, $2, $3, NULL, $4, $5, $6, $7, NOW(), 'PENDING', $8)
         RETURNING *`,
        [
          invitationId,
          eventId,
          req.user.id,
          disabledLinkTokenHash(invitationId),
          name,
          staffAccess.hashAccessCode(candidate),
          staffAccess.encryptAccessCode(candidate),
          expiresAt.toISOString(),
        ]
      );
      invitation = inserted[0];
      accessCode = candidate;
    } catch (error) {
      // 23505 = unique_violation. Kode akses unik global; buat kode baru.
      if (error.code === '23505') continue;
      throw error;
    }
  }

  if (!invitation) {
    res.status(503);
    throw httpError('Gagal membuat kode akses unik. Silakan coba lagi.', 503);
  }

  await insertPermissions(invitation.id, permissions);
  logger.info('staff_invitation_created', {
    eventId,
    invitationId: invitation.id,
    invitedBy: req.user.id,
  });

  res.status(201).json({
    success: true,
    message: 'Undangan staf dibuat. Bagikan tautan dan kode akses kepada staf.',
    invitation: {
      ...presentInvitation(invitation, permissions),
      // Kode plaintext hanya dikirim pada respons pembuatan (dan saat
      // regenerate) agar Organizer dapat membagikannya. Database menyimpan
      // hash + ciphertext, bukan plaintext.
      access_code: staffAccess.formatAccessCode(accessCode),
    },
  });
});

/** Daftar undangan staf pada satu event (khusus Organizer pemilik/Admin). */
const listStaffInvitations = asyncHandler(async (req, res) => {
  const eventId = req.params.eventId;
  await getEventForOwner(eventId, req.user);
  await assertStaffSchemaReady();

  const rows = await query(
    `SELECT * FROM event_invitations
     WHERE event_id = $1
       AND (staff_name IS NOT NULL OR access_code_hash IS NOT NULL OR status = 'PENDING')
     ORDER BY created_at DESC`,
    [eventId]
  );
  const invitationIds = rows.map((row) => row.id);
  const permissionsByInvitation = {};
  if (invitationIds.length > 0) {
    const permissionRows = await query(
      `SELECT event_invitation_id, permission
       FROM event_invitation_permissions
       WHERE event_invitation_id = ANY($1::uuid[])`,
      [invitationIds]
    );
    for (const row of permissionRows) {
      if (!permissionsByInvitation[row.event_invitation_id]) {
        permissionsByInvitation[row.event_invitation_id] = [];
      }
      permissionsByInvitation[row.event_invitation_id].push(row.permission);
    }
  }

  const invitations = rows.map((row) =>
    presentInvitation(row, permissionsByInvitation[row.id] || [])
  );
  res.json({ success: true, count: invitations.length, invitations });
});

/**
 * Terbitkan kode akses baru untuk undangan yang sudah ada.
 *
 * Dipakai saat kode hilang/bocor dan untuk memigrasikan undangan lama
 * (email-based) agar dapat dipakai pada mekanisme kode akses. Kode lama
 * langsung tidak berlaku karena hash-nya ditimpa.
 */
const regenerateStaffAccessCode = asyncHandler(async (req, res) => {
  const { eventId, invitationId } = req.params;
  await getEventForOwner(eventId, req.user);
  await assertStaffSchemaReady();

  const invitation = await getOne(
    'SELECT * FROM event_invitations WHERE id = $1 AND event_id = $2',
    [invitationId, eventId]
  );
  if (!invitation) throw httpError('Undangan staf tidak ditemukan', 404);

  const expiryDays = parseExpiryDays(
    req.body?.expiryDays ?? req.body?.expiry_days,
    DEFAULT_EXPIRY_DAYS
  );
  const expiresAt = new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000);
  // Nama dapat diperbarui sekaligus (dipakai saat memigrasikan undangan email
  // lama yang belum memiliki nama staf).
  const requestedName =
    typeof req.body?.name === 'string' ? req.body.name.trim() : '';
  if (requestedName.length > 80) {
    res.status(400);
    throw httpError('Nama staf maksimal 80 karakter', 400);
  }
  const staffName = requestedName.length >= 2 ? requestedName : null;

  let updated = null;
  let accessCode = null;
  for (let attempt = 0; attempt < staffAccess.MAX_CODE_ATTEMPTS && !updated; attempt += 1) {
    const candidate = staffAccess.generateAccessCode();
    try {
      const rows = await query(
        `UPDATE event_invitations
         SET access_code_hash = $1,
             access_code_cipher = $2,
             access_code_issued_at = NOW(),
             staff_name = COALESCE($3, staff_name),
             status = 'PENDING',
             accepted_at = NULL,
             revoked_at = NULL,
             expires_at = $4
         WHERE id = $5 AND event_id = $6
         RETURNING *`,
        [
          staffAccess.hashAccessCode(candidate),
          staffAccess.encryptAccessCode(candidate),
          staffName,
          expiresAt.toISOString(),
          invitationId,
          eventId,
        ]
      );
      updated = rows[0] || null;
      accessCode = candidate;
    } catch (error) {
      if (error.code === '23505') continue;
      throw error;
    }
  }

  if (!updated) {
    res.status(503);
    throw httpError('Gagal membuat kode akses unik. Silakan coba lagi.', 503);
  }

  const permissions = await readPermissions(invitationId);
  logger.info('staff_invitation_code_regenerated', {
    eventId,
    invitationId,
    by: req.user.id,
  });

  res.json({
    success: true,
    message: 'Kode akses baru dibuat. Kode sebelumnya tidak berlaku.',
    invitation: {
      ...presentInvitation(updated, permissions),
      access_code: staffAccess.formatAccessCode(accessCode),
    },
  });
});

/** Cabut undangan staf; sesi staf yang masih aktif langsung ditolak. */
const revokeStaffInvitation = asyncHandler(async (req, res) => {
  const { eventId, invitationId } = req.params;
  await getEventForOwner(eventId, req.user);
  await assertStaffSchemaReady();

  const rows = await query(
    `UPDATE event_invitations
     SET status = 'REVOKED', revoked_at = NOW()
     WHERE id = $1 AND event_id = $2
     RETURNING *`,
    [invitationId, eventId]
  );
  if (!rows[0]) throw httpError('Undangan staf tidak ditemukan', 404);

  logger.info('staff_invitation_revoked', {
    eventId,
    invitationId,
    by: req.user.id,
  });
  res.json({
    success: true,
    message: 'Undangan staf dicabut. Kode akses tidak dapat dipakai lagi.',
    invitation: presentInvitation(rows[0], await readPermissions(invitationId)),
  });
});

/**
 * Pratinjau undangan publik (`GET /api/staff-invitations/:invitationId`).
 *
 * Hanya memuat data yang dibutuhkan halaman autentikasi staf: nama event,
 * jadwal/lokasi, nama staf, status, dan masa berlaku. Kode akses TIDAK pernah
 * dikembalikan di sini. Tautan undangan lama (token) tetap dikenali agar
 * pengguna mendapat pesan yang jelas bahwa kode akses perlu dibuat ulang.
 */
const getStaffInvitationPreview = asyncHandler(async (req, res) => {
  await assertStaffSchemaReady();
  const identifier = String(req.params.invitationId || '').trim();
  if (!identifier) throw httpError('Undangan staf tidak valid', 400);

  let invitation = null;
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(identifier)) {
    invitation = await getOne(
      `SELECT i.*, e.title AS event_title, e.status AS event_status, e.event_date,
              e.end_date_time, e.location, e.event_format
       FROM event_invitations i
       JOIN events e ON e.id = i.event_id
       WHERE i.id = $1`,
      [identifier]
    );
  }

  if (!invitation) {
    // Kompatibilitas tautan lama: `token_hash` dari undangan email-based.
    const legacyHash = createHash('sha256').update(identifier, 'utf8').digest('hex');
    invitation = await getOne(
      `SELECT i.*, e.title AS event_title, e.status AS event_status, e.event_date,
              e.end_date_time, e.location, e.event_format
       FROM event_invitations i
       JOIN events e ON e.id = i.event_id
       WHERE i.token_hash = $1 AND i.staff_name IS NULL`,
      [legacyHash]
    );
  }

  if (!invitation) throw httpError('Undangan staf tidak ditemukan atau tidak valid', 404);

  const status = effectiveStatus(invitation);
  res.json({
    success: true,
    invitation: {
      id: invitation.id,
      staff_name: invitation.staff_name || 'Staf',
      status,
      expires_at: invitation.expires_at,
      requires_new_code: !invitation.access_code_hash,
      event: {
        id: invitation.event_id,
        title: invitation.event_title,
        status: invitation.event_status,
        event_date: invitation.event_date,
        end_date_time: invitation.end_date_time,
        location: invitation.location,
        event_format: invitation.event_format,
      },
    },
  });
});

/**
 * Validasi kode akses staf (publik, dibatasi rate limit).
 *
 * Ini satu-satunya pintu masuk ke scanner: kode diverifikasi ke database
 * (hash + status + masa berlaku + event undangan), bukan di frontend. Respons
 * sukses memuat sesi staf yang terikat pada undangan dan event tersebut.
 */
const validateStaffAccess = asyncHandler(async (req, res) => {
  await assertStaffSchemaReady();
  const invitationId = String(
    req.body.invitation_id || req.body.invitationId || ''
  ).trim();
  const submitted = req.body.access_code ?? req.body.accessCode;

  if (!invitationId) throw httpError('Undangan staf tidak valid', 400);
  const normalizedCode = staffAccess.normalizeAccessCode(submitted);
  if (!normalizedCode) {
    res.status(400);
    throw httpError('Kode akses wajib diisi dengan format XXXX-XXXX', 400);
  }

  const invitation = await getOne(
    `SELECT i.*, e.title AS event_title, e.status AS event_status
     FROM event_invitations i
     JOIN events e ON e.id = i.event_id
     WHERE i.id = $1`,
    [invitationId]
  );
  if (!invitation) {
    logger.warn('staff_access_unknown_invitation', { invitationId });
    res.status(404);
    throw httpError('Undangan staf tidak ditemukan atau tidak valid', 404);
  }

  if (invitation.status === 'REVOKED') {
    logger.warn('staff_access_revoked_invitation', { invitationId });
    res.status(403);
    throw httpError('Undangan staf ini sudah dicabut oleh Organizer', 403);
  }

  if (!invitation.access_code_hash) {
    res.status(409);
    throw httpError(
      'Undangan ini belum memiliki kode akses. Minta Organizer membuat kode akses baru.',
      409
    );
  }

  if (effectiveStatus(invitation) === 'EXPIRED') {
    res.status(410);
    throw httpError('Undangan staf sudah kedaluwarsa. Minta Organizer memperbarui undangan.', 410);
  }

  const submittedHash = staffAccess.hashAccessCode(normalizedCode);
  if (!staffAccess.safeEqualHex(invitation.access_code_hash, submittedHash)) {
    logger.warn('staff_access_invalid_code', { invitationId });
    res.status(401);
    throw httpError('Kode akses salah. Periksa kembali kode dari Organizer.', 401);
  }

  if (invitation.status === 'PENDING') {
    await query(
      `UPDATE event_invitations
       SET status = 'ACCEPTED', accepted_at = NOW()
       WHERE id = $1 AND status = 'PENDING'`,
      [invitation.id]
    );
  }

  const staffName = invitation.staff_name || 'Staf';
  const session = staffAccess.issueStaffSession({
    invitationId: invitation.id,
    eventId: invitation.event_id,
    staffName,
  });

  logger.info('staff_access_granted', {
    invitationId: invitation.id,
    eventId: invitation.event_id,
  });

  res.json({
    success: true,
    message: `Akses diberikan. Selamat bertugas, ${staffName}.`,
    session,
    staff: {
      invitation_id: invitation.id,
      name: staffName,
      event_id: invitation.event_id,
    },
    event: {
      id: invitation.event_id,
      title: invitation.event_title,
      status: invitation.event_status,
    },
  });
});

/** Info sesi staf aktif (dipakai klien untuk memulihkan sesi setelah reload). */
const getStaffSession = asyncHandler(async (req, res) => {
  res.json({
    success: true,
    staff: {
      invitation_id: req.staff.invitationId,
      name: req.staff.name,
      event_id: req.staff.eventId,
    },
    event: {
      id: req.staff.eventId,
      title: req.staff.eventTitle,
    },
    expires_at: req.staff.expiresAt,
  });
});

/** Akhiri sesi staf: token dicabut sehingga tidak dapat dipakai lagi. */
const logoutStaffSession = asyncHandler(async (req, res) => {
  await query(
    `INSERT INTO revoked_tokens (token_hash, expires_at)
     VALUES ($1, $2)
     ON CONFLICT (token_hash) DO NOTHING`,
    [
      staffAccess.hashSessionToken(req.staff.rawToken),
      req.staff.expiresAt || new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
    ]
  );
  res.json({ success: true, message: 'Sesi staf diakhiri.' });
});

module.exports = {
  createStaffInvitation,
  listStaffInvitations,
  regenerateStaffAccessCode,
  revokeStaffInvitation,
  getStaffInvitationPreview,
  validateStaffAccess,
  getStaffSession,
  logoutStaffSession,
  normalizePermissions,
  PERMISSION_CODES,
};
