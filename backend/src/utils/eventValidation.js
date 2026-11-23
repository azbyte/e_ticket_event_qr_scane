/**
 * Validasi domain event untuk auto-publish (PRD §3, §5, §10, AC-01).
 *
 * Seluruh fungsi di file ini murni (tanpa query database) agar aturan yang sama
 * dipakai controller, form Flutter (lewat response API), dan unit test tanpa
 * membutuhkan koneksi PostgreSQL.
 */

const ATTENDEE_FIELD_TYPES = Object.freeze([
  'text',
  'textarea',
  'number',
  'date',
  'select',
  'checkbox',
]);

/** Field legacy yang sudah punya kolom sendiri di tabel `attendees`. */
const LEGACY_ATTENDEE_FIELD_KEYS = Object.freeze([
  'name',
  'email',
  'phone',
  'organization',
]);

/** Field yang wajib ada dan selalu required (kolom `attendees.name/email`). */
const REQUIRED_ATTENDEE_FIELD_KEYS = Object.freeze(['name', 'email']);

/** Field yang disimpan sebagai kolom, bukan ke `attendees.custom_fields`. */
const ATTENDEE_COLUMN_KEYS = Object.freeze(['name', 'email', 'phone']);

const DEFAULT_ATTENDEE_LABELS = Object.freeze({
  name: 'Nama lengkap',
  email: 'Email',
  phone: 'Nomor telepon',
  organization: 'Instansi/organisasi',
});

const VALID_EVENT_FORMATS = Object.freeze(['OFFLINE', 'ONLINE', 'HYBRID']);

const toTrimmedString = (value) =>
  typeof value === 'string' ? value.trim() : '';

const isHttpUrl = (value) => /^https?:\/\/\S+$/i.test(value || '');

const isPlainObject = (value) =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const asJsonArray = (value) => {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string' && value.trim().startsWith('[')) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : null;
    } catch (_) {
      return null;
    }
  }
  return null;
};

const defaultAttendeeField = (key) => ({
  key,
  label: DEFAULT_ATTENDEE_LABELS[key] || key,
  type: 'text',
  required: REQUIRED_ATTENDEE_FIELD_KEYS.includes(key),
  options: [],
});

const normalizeAttendeeField = (raw) => {
  if (typeof raw === 'string') {
    const key = raw.trim();
    if (!key) return { error: 'Nama field peserta tidak boleh kosong' };
    if (!LEGACY_ATTENDEE_FIELD_KEYS.includes(key)) {
      return { error: `Field peserta tidak dikenal: ${key}` };
    }
    return { field: defaultAttendeeField(key) };
  }
  if (!isPlainObject(raw)) {
    return { error: 'Field peserta harus berupa string atau objek' };
  }
  const key = toTrimmedString(raw.key);
  if (!/^[a-z][a-z0-9_]{0,39}$/.test(key)) {
    return { error: `Kunci field peserta tidak valid: ${key || '(kosong)'}` };
  }
  const type = toTrimmedString(raw.type).toLowerCase() || 'text';
  if (!ATTENDEE_FIELD_TYPES.includes(type)) {
    return { error: `Tipe field peserta "${type}" tidak didukung (${key})` };
  }
  const options = Array.isArray(raw.options)
    ? raw.options.map((option) => toTrimmedString(option)).filter(Boolean)
    : [];
  if (type === 'select' && options.length === 0) {
    return { error: `Field pilihan "${key}" harus memiliki minimal satu opsi` };
  }
  return {
    field: {
      key,
      label: toTrimmedString(raw.label) || DEFAULT_ATTENDEE_LABELS[key] || key,
      type,
      required: REQUIRED_ATTENDEE_FIELD_KEYS.includes(key)
        ? true
        : raw.required === true,
      options: type === 'select' ? [...new Set(options)] : [],
    },
  };
};

/**
 * Normalisasi `attendee_fields` event menjadi array objek bertipe.
 *
 * Kompatibel mundur dengan array string legacy (`['name','email','phone']`).
 * `null`/`undefined` dianggap konfigurasi default (nama + email) agar event
 * lama tetap dapat menerima order.
 */
const normalizeAttendeeFields = (rawFields) => {
  if (rawFields === null || rawFields === undefined) {
    return {
      fields: [defaultAttendeeField('name'), defaultAttendeeField('email')],
      errors: [],
    };
  }
  const list = asJsonArray(rawFields);
  if (!list) {
    return { fields: [], errors: ['Data field peserta harus berupa array'] };
  }
  const errors = [];
  const byKey = new Map();
  for (const raw of list) {
    const result = normalizeAttendeeField(raw);
    if (result.error) {
      errors.push(result.error);
      continue;
    }
    byKey.set(result.field.key, result.field);
  }
  if (!byKey.has('name')) {
    errors.push('Field "name" wajib ada pada data peserta');
  }
  return { fields: [...byKey.values()], errors };
};

/** Daftar alasan bila konfigurasi `attendee_fields` tidak valid. */
const validateAttendeeFields = (rawFields) => {
  const { fields, errors } = normalizeAttendeeFields(rawFields);
  const reasons = [...errors];
  if (fields.length === 0) {
    reasons.push('Minimal satu field peserta harus diisi');
  }
  return [...new Set(reasons)];
};


/**
 * Validasi kelayakan publikasi sebuah event.
 *
 * @param {object} event baris tabel `events`
 * @param {Array<object>} ticketTypes baris `ticket_types` milik event
 * @param {{ now?: Date, enforceFutureStart?: boolean }} options
 * @returns {string[]} daftar alasan; array kosong berarti event valid
 */
const validateEventForPublish = (event, ticketTypes, options = {}) => {
  if (!isPlainObject(event)) return ['Data event tidak tersedia'];
  const now = options.now instanceof Date ? options.now : new Date();
  const enforceFutureStart = options.enforceFutureStart !== false;
  const errors = [];

  const title = toTrimmedString(event.title);
  if (title.length < 3) errors.push('Nama event minimal 3 karakter');

  const start = Date.parse(event.event_date || '');
  const end = Date.parse(event.end_date_time || '');
  if (!Number.isFinite(start)) errors.push('Tanggal mulai event tidak valid');
  if (!Number.isFinite(end)) errors.push('Tanggal selesai event tidak valid');
  if (Number.isFinite(start) && Number.isFinite(end) && end <= start) {
    errors.push('Waktu selesai harus setelah waktu mulai');
  }
  if (enforceFutureStart && Number.isFinite(start) && start < now.getTime()) {
    errors.push('Waktu mulai event sudah lewat');
  }

  const format = toTrimmedString(event.event_format).toUpperCase();
  if (!VALID_EVENT_FORMATS.includes(format)) {
    errors.push('Format event harus OFFLINE, ONLINE, atau HYBRID');
  }
  if (['OFFLINE', 'HYBRID'].includes(format) && !toTrimmedString(event.location)) {
    errors.push('Lokasi wajib diisi untuk event offline/hybrid');
  }
  if (
    ['ONLINE', 'HYBRID'].includes(format) &&
    !isHttpUrl(toTrimmedString(event.online_url))
  ) {
    errors.push('Tautan online wajib berupa URL http(s) untuk event online/hybrid');
  }

  if (!event.category_id) errors.push('Kategori event wajib dipilih');
  if (!toTrimmedString(event.organizer_name)) {
    errors.push('Nama penyelenggara wajib diisi');
  }
  if (!toTrimmedString(event.contact_info)) {
    errors.push('Kontak penyelenggara wajib diisi');
  }

  errors.push(...validateAttendeeFields(event.attendee_fields));

  const types = Array.isArray(ticketTypes) ? ticketTypes : [];
  const activeTypes = types.filter((type) => type && type.is_active !== false);
  if (activeTypes.length === 0) {
    errors.push('Minimal satu kategori tiket aktif diperlukan');
  }

  if (types.length > 0) {
    const prices = types.map((type) => Number(type.price));
    const allFree = prices.every((price) => price === 0);
    const allPaid = prices.every((price) => Number.isFinite(price) && price > 0);
    if (!allFree && !allPaid) {
      errors.push(
        'Semua kategori tiket harus sama-sama gratis atau sama-sama berbayar'
      );
    }
  }

  for (const type of types) {
    const name = toTrimmedString(type.name) || '(tanpa nama)';
    const price = Number(type.price);
    const quota = Number(type.quota);
    const sold = Number(type.sold) || 0;
    const held = Number(type.held) || 0;

    if (!Number.isFinite(price) || price < 0) {
      errors.push(`Harga kategori "${name}" tidak valid`);
    }
    if (!Number.isInteger(quota) || quota < 1) {
      errors.push(`Kuota kategori "${name}" minimal 1`);
    } else if (quota < sold + held) {
      errors.push(
        `Kuota kategori "${name}" lebih kecil dari tiket terjual + tertahan`
      );
    }

    const salesStart = type.sales_start ? Date.parse(type.sales_start) : null;
    const salesEnd = type.sales_end ? Date.parse(type.sales_end) : null;
    if (type.sales_start && !Number.isFinite(salesStart)) {
      errors.push(`Awal periode penjualan kategori "${name}" tidak valid`);
    }
    if (type.sales_end && !Number.isFinite(salesEnd)) {
      errors.push(`Akhir periode penjualan kategori "${name}" tidak valid`);
    }
    if (
      Number.isFinite(salesStart) &&
      Number.isFinite(salesEnd) &&
      salesEnd <= salesStart
    ) {
      errors.push(
        `Akhir periode penjualan kategori "${name}" harus setelah awal`
      );
    }
  }

  return [...new Set(errors)];
};

/**
 * Hasil transisi status setelah validasi publikasi.
 *
 * Dipakai `POST /api/events/:id/publish`, alias `submit-review`, pembuatan
 * event baru, dan validasi ulang setelah edit. Objek ini deterministik sehingga
 * dapat diuji tanpa database (K1/K2/K4 D1-2).
 */
const resolvePublishTransition = (event, ticketTypes, options = {}) => {
  const errors = validateEventForPublish(event, ticketTypes, options);
  if (errors.length === 0) {
    return {
      valid: true,
      errors: [],
      status: 'PUBLISHED',
      isPublic: true,
      reviewNote: null,
    };
  }
  return {
    valid: false,
    errors,
    status: 'DRAFT',
    isPublic: false,
    reviewNote: JSON.stringify(errors),
  };
};

/** Baca alasan validasi yang disimpan pada `events.review_note`. */
const parseValidationNote = (note) => {
  if (typeof note !== 'string') return [];
  const trimmed = note.trim();
  if (!trimmed.startsWith('[')) return [];
  try {
    const parsed = JSON.parse(trimmed);
    return Array.isArray(parsed)
      ? parsed.filter((item) => typeof item === 'string')
      : [];
  } catch (_) {
    return [];
  }
};

/**
 * Validasi jawaban peserta terhadap definisi field event (D1-5).
 *
 * @returns {string[]} alasan penolakan; array kosong berarti jawaban valid
 */
const validateAttendeeAnswers = (fields, answers = {}) => {
  const definitions = Array.isArray(fields) ? fields : [];
  const errors = [];
  const allowed = new Set(definitions.map((field) => field.key));
  const values = answers === undefined || answers === null ? {} : answers;

  if (!isPlainObject(values)) {
    return ['Jawaban field peserta harus berupa objek'];
  }

  for (const key of Object.keys(values)) {
    if (!allowed.has(key)) {
      errors.push(`Field peserta "${key}" tidak dikenali pada event ini`);
    }
  }

  for (const field of definitions) {
    const raw = values[field.key];
    const required = field.required === true;
    switch (field.type) {
      case 'checkbox': {
        const checked = raw === true || raw === 'true';
        if (required && !checked) {
          errors.push(`"${field.label}" wajib dicentang`);
        }
        break;
      }
      case 'number': {
        const text = typeof raw === 'number' ? String(raw) : toTrimmedString(raw);
        if (!text) {
          if (required) errors.push(`"${field.label}" wajib diisi`);
          break;
        }
        if (!Number.isFinite(Number(text))) {
          errors.push(`"${field.label}" harus berupa angka`);
        }
        break;
      }
      case 'date': {
        const text = toTrimmedString(raw);
        if (!text) {
          if (required) errors.push(`"${field.label}" wajib diisi`);
          break;
        }
        if (!Number.isFinite(Date.parse(text))) {
          errors.push(`"${field.label}" harus berupa tanggal yang valid`);
        }
        break;
      }
      case 'select': {
        const text = toTrimmedString(raw);
        if (!text) {
          if (required) errors.push(`"${field.label}" wajib dipilih`);
          break;
        }
        const options = Array.isArray(field.options) ? field.options : [];
        if (options.length > 0 && !options.includes(text)) {
          errors.push(
            `"${field.label}" harus salah satu dari: ${options.join(', ')}`
          );
        }
        break;
      }
      default: {
        const text = toTrimmedString(raw);
        if (!text && required) errors.push(`"${field.label}" wajib diisi`);
        break;
      }
    }
  }

  return [...new Set(errors)];
};

/**
 * Pisahkan jawaban peserta: kolom `attendees` versus `custom_fields` (JSON).
 */
const splitCustomFieldAnswers = (fields, answers = {}) => {
  const definitions = Array.isArray(fields) ? fields : [];
  const columns = {};
  const customFields = {};
  if (!isPlainObject(answers)) return { columns, customFields };
  for (const field of definitions) {
    if (!Object.prototype.hasOwnProperty.call(answers, field.key)) continue;
    const value = answers[field.key];
    if (ATTENDEE_COLUMN_KEYS.includes(field.key)) {
      columns[field.key] = typeof value === 'string' ? value.trim() : value;
    } else {
      customFields[field.key] = value;
    }
  }
  return { columns, customFields };
};

module.exports = {
  ATTENDEE_FIELD_TYPES,
  LEGACY_ATTENDEE_FIELD_KEYS,
  REQUIRED_ATTENDEE_FIELD_KEYS,
  ATTENDEE_COLUMN_KEYS,
  VALID_EVENT_FORMATS,
  normalizeAttendeeFields,
  validateAttendeeFields,
  validateEventForPublish,
  resolvePublishTransition,
  parseValidationNote,
  validateAttendeeAnswers,
  splitCustomFieldAnswers,
};

