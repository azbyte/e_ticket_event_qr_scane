/**
 * Application constants
 */

const TICKET_STATUS = {
  ACTIVE: 'active',
  USED: 'used',
  CANCELLED: 'cancelled',
  EXPIRED: 'expired',
};

const USER_ROLES = {
  // PRD §2: Admin (§2.1), Organizer (§2.2), Staff (§2.3). Participant (§2.4)
  // tidak memiliki akun, jadi tidak ada role yang dihasilkan registrasi publik;
  // registrasi selalu membuat Organizer (lihat authController.registerUser).
  ORGANIZER: 'organizer',
  ADMIN: 'admin',
  STAFF: 'staff',
  // Legacy: nilai lama yang mungkin masih tersimpan pada baris `profiles.role`.
  // Jangan dipakai untuk akun baru. Klien memetakannya ke role tanpa hak
  // istimewa (Participant) — lihat apps/lib/models/user/user_role.dart.
  CUSTOMER: 'customer',
};

const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  INTERNAL_SERVER_ERROR: 500,
};

module.exports = { TICKET_STATUS, USER_ROLES, HTTP_STATUS };