const asyncHandler = require('express-async-handler');
const { getOne } = require('../config/db');
const { authMiddleware } = require('./authMiddleware');
const staffAccess = require('../services/staffAccessService');

/**
 * Autentikasi staf berbasis sesi undangan (nama + kode akses).
 *
 * Berbeda dari JWT akun Organizer/Admin:
 *  - klaim `typ` = `staff_access`, `sid` = id undangan, `event_id` = event;
 *  - TIDAK memakai tabel `profiles` (staf tidak wajib punya akun);
 *  - setiap request memuat ulang undangan dari database sehingga pencabutan
 *    (`REVOKED`) dan kedaluwarsa langsung berlaku tanpa menunggu token habis;
 *  - event pada token wajib sama dengan event undangan (tidak ada akses lintas
 *    event, walaupun token dipakai pada URL event lain).
 */
const readStaffToken = (req) => {
  const header = req.headers['x-staff-session'];
  if (typeof header === 'string' && header.trim()) return header.trim();
  const authorization = req.headers.authorization;
  if (typeof authorization === 'string' && authorization.startsWith('Bearer')) {
    const token = authorization.split(' ')[1];
    if (token && staffAccess.isStaffSessionToken(token)) return token.trim();
  }
  return null;
};

const staffAuthMiddleware = asyncHandler(async (req, res, next) => {
  const token = readStaffToken(req);
  if (!token) {
    res.status(401);
    const error = new Error('Sesi staf tidak ditemukan. Masukkan kode akses undangan.');
    error.statusCode = 401;
    throw error;
  }

  const claims = staffAccess.verifyStaffSession(token);
  if (!claims) {
    res.status(401);
    const error = new Error('Sesi staf tidak valid atau sudah kedaluwarsa');
    error.statusCode = 401;
    throw error;
  }

  const revoked = await getOne(
    'SELECT token_hash FROM revoked_tokens WHERE token_hash = $1',
    [staffAccess.hashSessionToken(token)]
  );
  if (revoked) {
    res.status(401);
    const error = new Error('Sesi staf sudah diakhiri');
    error.statusCode = 401;
    throw error;
  }

  const invitation = await getOne(
    `SELECT i.id, i.event_id, i.status, i.expires_at, i.staff_name,
            e.title AS event_title
     FROM event_invitations i
     JOIN events e ON e.id = i.event_id
     WHERE i.id = $1`,
    [claims.sid]
  );
  if (!invitation) {
    res.status(401);
    const error = new Error('Undangan staf tidak ditemukan');
    error.statusCode = 401;
    throw error;
  }
  if (invitation.event_id !== claims.event_id) {
    res.status(403);
    const error = new Error('Sesi staf tidak berlaku untuk event ini');
    error.statusCode = 403;
    throw error;
  }
  if (invitation.status === 'REVOKED') {
    res.status(403);
    const error = new Error('Akses staf untuk event ini sudah dicabut');
    error.statusCode = 403;
    throw error;
  }
  if (invitation.expires_at && new Date(invitation.expires_at) <= new Date()) {
    res.status(403);
    const error = new Error('Undangan staf sudah kedaluwarsa');
    error.statusCode = 403;
    throw error;
  }

  const staffName = invitation.staff_name || claims.name || 'Staf';
  req.staff = {
    invitationId: invitation.id,
    eventId: invitation.event_id,
    eventTitle: invitation.event_title,
    name: staffName,
    expiresAt: claims.exp ? new Date(claims.exp * 1000).toISOString() : null,
    rawToken: token,
  };
  // `req.user` diisi agar controller/role middleware yang sudah ada tetap
  // bekerja. `id` sintetis berawalan `staff:` tidak pernah cocok dengan
  // `profiles.id`, sehingga tidak memberi hak kepemilikan data akun.
  req.user = {
    id: `staff:${invitation.id}`,
    name: staffName,
    email: null,
    role: 'staff',
    staffInvitationId: invitation.id,
    staffEventId: invitation.event_id,
  };
  return next();
});

/**
 * Middleware gabungan untuk endpoint scanner.
 *
 * Sesi staf (`X-Staff-Session`) diproses lebih dulu agar staf tanpa akun dapat
 * memindai. Bila tidak ada sesi staf, perilaku lama (JWT Organizer/Admin)
 * dipertahankan apa adanya.
 */
const staffOrUserAuth = (req, res, next) => {
  if (readStaffToken(req)) return staffAuthMiddleware(req, res, next);
  return authMiddleware(req, res, next);
};

module.exports = { staffAuthMiddleware, staffOrUserAuth, readStaffToken };
