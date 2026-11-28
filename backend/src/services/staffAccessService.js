const {
  createCipheriv, createDecipheriv, createHash, randomBytes, randomInt, timingSafeEqual,
} = require('node:crypto');
const jwt = require('jsonwebtoken');
const config = require('../config/env');

/**
 * Kode akses staf (undangan berbasis nama).
 *
 * Aturan keamanan yang diterapkan di sini:
 *  - kode dibuat acak kriptografis (bukan Math.random) dengan alfabet tanpa
 *    karakter ambigu (0/O, 1/I/L) agar mudah diketik ulang;
 *  - database TIDAK menyimpan plaintext: `access_code_hash` (SHA-256) dipakai
 *    untuk verifikasi constant-time, sedangkan `access_code_cipher`
 *    (AES-256-GCM) hanya agar Organizer dapat menampilkan kembali kode milik
 *    event-nya pada halaman pengelolaan staf;
 *  - keunikan global ditegakkan indeks unik `event_invitations.access_code_hash`
 *    (lihat migration `20261201000000_staff_access_codes`).
 */

/** Alfabet kode akses: tanpa 0/O/1/I/L agar tidak salah baca. */
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 8;

/** Jumlah percobaan pembuatan kode saat terjadi tabrakan unik. */
const MAX_CODE_ATTEMPTS = 8;

/** `typ` klaim JWT sesi staf; membedakannya dari JWT akun Organizer/Admin. */
const STAFF_SESSION_TYPE = 'staff_access';

/** Normalisasi kode akses: huruf besar, hanya alfanumerik. */
const normalizeAccessCode = (raw) => {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (cleaned.length !== CODE_LENGTH) return null;
  for (const char of cleaned) {
    if (!CODE_ALPHABET.includes(char)) return null;
  }
  return cleaned;
};

/** Bentuk tampilan kode akses: `ABCD-EFGH`. */
const formatAccessCode = (code) => {
  const normalized = normalizeAccessCode(code);
  if (!normalized) return null;
  return `${normalized.slice(0, 4)}-${normalized.slice(4)}`;
};

/** Buat kode akses baru (8 karakter acak kriptografis). */
const generateAccessCode = () => {
  let code = '';
  for (let index = 0; index < CODE_LENGTH; index += 1) {
    code += CODE_ALPHABET[randomInt(0, CODE_ALPHABET.length)];
  }
  return code;
};

/** Hash kode akses untuk verifikasi & constraint unik. */
const hashAccessCode = (code) => {
  const normalized = normalizeAccessCode(code);
  if (!normalized) return null;
  return createHash('sha256').update(`staff-access:${normalized}`, 'utf8').digest('hex');
};

/** Perbandingan constant-time antara hash tersimpan dan hash masukan. */
const safeEqualHex = (left, right) => {
  const a = Buffer.from(String(left || ''), 'utf8');
  const b = Buffer.from(String(right || ''), 'utf8');
  if (a.length === 0 || a.length !== b.length) return false;
  return timingSafeEqual(a, b);
};

/** Kunci AES-256 diturunkan dari secret konfigurasi. */
const encryptionKey = () =>
  createHash('sha256')
    .update(`staff-access-cipher:${config.staffAccessSecret}`, 'utf8')
    .digest();

/**
 * Enkripsi kode akses agar Organizer dapat melihatnya lagi setelah reload.
 * Format: `v1.<iv>.<tag>.<ciphertext>` (base64url).
 */
const encryptAccessCode = (code) => {
  const normalized = normalizeAccessCode(code);
  if (!normalized) return null;
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const encrypted = Buffer.concat([cipher.update(normalized, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [
    'v1',
    iv.toString('base64url'),
    tag.toString('base64url'),
    encrypted.toString('base64url'),
  ].join('.');
};

/** Dekripsi kode akses; `null` bila ciphertext rusak/format tidak dikenal. */
const decryptAccessCode = (payload) => {
  if (typeof payload !== 'string') return null;
  const parts = payload.split('.');
  if (parts.length !== 4 || parts[0] !== 'v1') return null;
  try {
    const iv = Buffer.from(parts[1], 'base64url');
    const tag = Buffer.from(parts[2], 'base64url');
    const data = Buffer.from(parts[3], 'base64url');
    const decipher = createDecipheriv('aes-256-gcm', encryptionKey(), iv);
    decipher.setAuthTag(tag);
    const decrypted = Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
    return normalizeAccessCode(decrypted);
  } catch (_error) {
    return null;
  }
};

/** Samarkan kode untuk fallback tampilan (mis. `••••-••GH`). */
const maskAccessCode = (code) => {
  const normalized = normalizeAccessCode(code);
  if (!normalized) return null;
  return `••••-••${normalized.slice(-2)}`;
};

/**
 * Terbitkan sesi staf (JWT) yang terikat pada undangan + event.
 *
 * Klaim `sid` (invitation id) dan `event_id` adalah sumber otorisasi: setiap
 * request memverifikasi ulang undangan masih aktif dan event-nya sama, sehingga
 * staf tidak dapat memakai sesi untuk event lain.
 */
const issueStaffSession = ({ invitationId, eventId, staffName }) => {
  const token = jwt.sign(
    {
      typ: STAFF_SESSION_TYPE,
      sid: invitationId,
      event_id: eventId,
      name: staffName,
    },
    config.jwtSecret,
    { expiresIn: config.staffSessionTtl },
  );
  const decoded = jwt.decode(token);
  return {
    token,
    expires_at: decoded?.exp ? new Date(decoded.exp * 1000).toISOString() : null,
  };
};

/** Verifikasi tanda tangan & tipe token sesi staf. */
const verifyStaffSession = (token) => {
  if (typeof token !== 'string' || token.trim().length === 0) return null;
  try {
    const decoded = jwt.verify(token.trim(), config.jwtSecret);
    if (decoded?.typ !== STAFF_SESSION_TYPE) return null;
    if (!decoded.sid || !decoded.event_id) return null;
    return decoded;
  } catch (_error) {
    return null;
  }
};

/** Apakah token adalah sesi staf (dipakai untuk memilih middleware). */
const isStaffSessionToken = (token) => verifyStaffSession(token) !== null;

/** Hash token sesi untuk daftar pencabutan (`revoked_tokens`). */
const hashSessionToken = (token) =>
  createHash('sha256').update(String(token), 'utf8').digest('hex');

module.exports = {
  CODE_ALPHABET,
  CODE_LENGTH,
  MAX_CODE_ATTEMPTS,
  STAFF_SESSION_TYPE,
  normalizeAccessCode,
  formatAccessCode,
  generateAccessCode,
  hashAccessCode,
  safeEqualHex,
  encryptAccessCode,
  decryptAccessCode,
  maskAccessCode,
  issueStaffSession,
  verifyStaffSession,
  isStaffSessionToken,
  hashSessionToken,
};
