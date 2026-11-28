const { parseValidationNote, normalizeAttendeeFields } = require('./eventValidation');

/**
 * Status yang dianggap tayang. `APPROVED` dipertahankan demi kompatibilitas
 * data lama (alur moderasi sebelum auto-publish).
 */
const PUBLIC_EVENT_STATUSES = Object.freeze(['APPROVED', 'PUBLISHED']);

/**
 * Basis URL aplikasi untuk tautan publik. Dibaca langsung dari environment agar
 * modul ini tetap dapat diuji tanpa memuat `config/env` (yang mensyaratkan
 * DATABASE_URL/JWT_SECRET).
 */
const appPublicUrl = () =>
  String(process.env.APP_PUBLIC_URL || 'http://localhost:5000').replace(/\/$/, '');

/** Tautan pendaftaran publik event: `{APP_PUBLIC_URL}/e/{eventId}`. */
const buildPublicUrl = (eventId) => `${appPublicUrl()}/e/${eventId}`;

/** Tautan undangan panitia: `{APP_PUBLIC_URL}/invite/{rawToken}`. */
const buildInviteUrl = (rawToken) => `${appPublicUrl()}/invite/${rawToken}`;

/**
 * Tautan undangan staf berbasis kode akses:
 * `{APP_PUBLIC_URL}/staff-access/{invitationId}`.
 *
 * Tautan ini hanya mengidentifikasi undangan; tautan TIDAK memberi akses ke
 * scanner. Staf tetap harus memasukkan kode akses yang divalidasi backend.
 * Identifier yang dipakai adalah id undangan (bukan kode akses), sehingga kode
 * rahasia tidak pernah muncul di URL, riwayat browser, atau log server.
 */
const buildStaffAccessUrl = (invitationId) =>
  `${appPublicUrl()}/staff-access/${invitationId}`;

const isPubliclyVisible = (event) =>
  Boolean(event && event.is_public) &&
  PUBLIC_EVENT_STATUSES.includes(String(event.status || '').toUpperCase());

/**
 * `public_url` hanya terisi untuk event yang benar-benar tayang.
 * Event DRAFT/REJECTED/REVISION_REQUIRED/SUSPENDED mengembalikan `null`.
 */
const publicUrlFor = (event) =>
  isPubliclyVisible(event) ? buildPublicUrl(event.id) : null;

/**
 * Serialisasi event untuk response API.
 *
 * `attendee_fields` dapat tersimpan sebagai JSONB (objek/array) atau teks JSON
 * tergantung jalur penulisan (insert vs update). Tanpa normalisasi, kolom teks
 * terkirim sebagai string sehingga klien tidak dapat membaca konfigurasi form
 * peserta — form publik jatuh ke form default. Di sini nilai selalu diubah ke
 * array bertipe dan `email` (media pengiriman e-ticket) selalu disertakan serta
 * wajib, agar kontrak API konsisten dan formulir tidak pernah kehilangan email.
 */
const parseAttendeeFields = (value) => {
  if (value === null || value === undefined) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_error) {
      return [];
    }
  }
  return [];
};

/** `attendee_fields` yang dipakai response API (selalu memuat email wajib). */
const normalizedAttendeeFields = (value) => {
  const parsed = parseAttendeeFields(value);
  if (parsed.length === 0) return normalizeAttendeeFields(null).fields;
  return normalizeAttendeeFields(parsed).fields;
};

const serializeEvent = (event) => {
  if (typeof event.status !== 'string' || typeof event.event_format !== 'string') {
    throw new TypeError('Event status and format are required by the API contract');
  }
  const category = Array.isArray(event.event_categories)
    ? event.event_categories[0]
    : event.event_categories;
  return {
    ...event,
    organizer_id: event.created_by,
    start_date_time: event.event_date,
    event_type: event.event_format.toLowerCase(),
    category: category?.name || null,
    attendee_fields: normalizedAttendeeFields(event.attendee_fields),
    status: event.status.toLowerCase(),
    public_url: publicUrlFor(event),
    validation_errors: parseValidationNote(event.review_note),
  };
};

module.exports = {
  serializeEvent,
  parseAttendeeFields,
  normalizedAttendeeFields,
  appPublicUrl,
  buildPublicUrl,
  buildInviteUrl,
  buildStaffAccessUrl,
  publicUrlFor,
  isPubliclyVisible,
  PUBLIC_EVENT_STATUSES,
};
