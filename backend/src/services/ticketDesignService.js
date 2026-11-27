/**
 * Desain e-ticket (PRD §5).
 *
 * Tanggung jawab:
 *  - memvalidasi & menyimpan gambar desain yang diunggah Organizer,
 *  - menyediakan template PDF/PNG berukuran tetap dengan penanda posisi QR,
 *  - merender tiket final (PDF) memakai desain kategori/event atau desain
 *    default sistem, dengan QR unik pada posisi yang ditentukan.
 *
 * Prinsip desain: gambar yang diunggah Organizer adalah desain UTAMA tiket.
 * Sistem hanya menambahkan informasi dinamis yang sedikit (judul + ID tiket +
 * nama peserta + instruksi penukaran) di kiri atas dan QR Code tepat di
 * bawahnya. Tidak ada panel, kartu, atau latar tambahan di atas artwork, dan
 * kotak putih hanya dipakai sebagai alas QR Code.
 *
 * Posisi disimpan sebagai fraksi 0..1 terhadap kanvas tiket agar tidak
 * bergantung pada resolusi file yang diunggah:
 *   qr:   { x, y, size }  (x,y = sudut kiri-atas; size = fraksi tinggi kanvas)
 *   info: { x, y, width, height, color } (area teks informasi peserta)
 */
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const { getOne } = require('../config/db');
const { rawTokenFor } = require('./ticketTokenService');

const STORAGE_ROOT = path.join(__dirname, '..', '..', 'storage');
const DESIGN_DIR = path.join(STORAGE_ROOT, 'ticket-designs');
const DESIGN_URL_PREFIX = '/media/ticket-designs';
const TEMPLATE_DIR = path.join(__dirname, '..', '..', 'assets', 'ticket-templates');
const TEMPLATE_PNG = path.join(TEMPLATE_DIR, 'ticket-template.png');

const ALLOWED_CONTENT_TYPES = Object.freeze({
  'image/png': '.png',
  'image/jpeg': '.jpg',
});
const MAX_UPLOAD_BYTES = 2 * 1024 * 1024; // 2 MB
const MIN_UPLOAD_BYTES = 1024;
// Panjang string base64 untuk MAX_UPLOAD_BYTES (dibulatkan ke atas + padding).
// Dipakai untuk menolak payload raksasa SEBELUM di-decode menjadi Buffer.
const MAX_UPLOAD_BASE64_LENGTH = Math.ceil(MAX_UPLOAD_BYTES / 3) * 4 + 4;

/** Signature PNG 8 byte: dipakai untuk memeriksa isi file dan membaca IHDR. */
const PNG_SIGNATURE = Object.freeze([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const hasPngSignature = (buffer) =>
  Boolean(buffer) && buffer.length >= PNG_SIGNATURE.length
  && PNG_SIGNATURE.every((byte, index) => buffer[index] === byte);

/**
 * Ekstensi file untuk content type yang diizinkan, atau null bila tidak didukung.
 *
 * Memakai `hasOwnProperty` (bukan akses properti langsung) agar nama bawaan
 * objek seperti `constructor` atau `__proto__` tidak lolos sebagai format sah.
 */
const extensionFor = (contentType) => (
  Object.prototype.hasOwnProperty.call(ALLOWED_CONTENT_TYPES, contentType)
    ? ALLOWED_CONTENT_TYPES[contentType]
    : null
);

/**
 * Opsi tata letak tiket default.
 *
 * @typedef {object} TicketLayoutOptions
 * @property {boolean} [placeholder] true = pakai data contoh (template desain)
 * @property {string} [orientation] orientasi kanvas: `landscape` atau `portrait`
 * @property {object} [ticket] baris tiket untuk data dinamis
 */

/**
 * Tata letak kanvas tiket (satuan pt).
 *
 * Kanvas bersifat TETAP per orientasi sehingga ukuran halaman PDF tidak
 * bergantung pada file desain yang diunggah:
 *  - `landscape`: 842 x 594 pt (A4 landscape, rasio ~1.42:1),
 *  - `portrait` : 440 x 704 pt (rasio ~1:1.6).
 *
 * Tata letak mengikuti referensi desain (U-NITY): blok informasi di kiri atas,
 * QR Code ukuran medium tepat di bawahnya, dan sisa halaman dibiarkan untuk
 * artwork desain. Posisi QR & area teks disimpan sebagai fraksi 0..1 terhadap
 * kanvas agar desain kustom tetap kompatibel dengan resolusi file berapa pun.
 *
 * `textHeight` adalah tinggi area informasi yang disediakan tata letak default.
 * Nilainya mengikuti tipografi blok informasi (lihat `TICKET_TYPE`): teks yang
 * lebih besar membutuhkan area lebih tinggi, sehingga QR digeser ke bawah agar
 * keduanya tidak bertumpuk. Bila teks tetap lebih tinggi dari area (nama event
 * panjang), `drawTicketInfoLines` mengecilkan tipografi secara proporsional.
 */
const LANDSCAPE_CANVAS = Object.freeze({
  width: 842,
  height: 594,
  leftPanelWidth: 470,
  padding: 56,
  // Blok teks kiri atas: 52 + 208 = 260 pt, QR dimulai 284 pt (jarak 24 pt).
  textTop: 52,
  textHeight: 208,
  // 56 + 392 = 448 pt, masih 22 pt di kiri garis pemisah panel (470 pt).
  textWidth: 392,
  qrX: 56,
  // QR ukuran medium: cukup besar untuk dipindai, tidak mendominasi artwork.
  qrY: 284,
  qrSize: 220,
});

const PORTRAIT_CANVAS = Object.freeze({
  width: 440,
  height: 704,
  // Header menampung blok teks 40 + 200 = 240 pt; QR dimulai 266 pt.
  headerHeight: 252,
  padding: 36,
  textTop: 40,
  textHeight: 200,
  // 36 + 344 = 380 pt, menyisakan 60 pt di kanan header.
  textWidth: 344,
  // QR diletakkan di bawah header agar tidak memotong batas artwork.
  qrX: 36,
  qrY: 266,
  qrSize: 250,
});

/** QR default per orientasi (fraksi kanvas), diturunkan dari tata letak di atas. */
const DEFAULT_QR_BY_ORIENTATION = Object.freeze({
  landscape: Object.freeze({
    x: LANDSCAPE_CANVAS.qrX / LANDSCAPE_CANVAS.width,
    y: LANDSCAPE_CANVAS.qrY / LANDSCAPE_CANVAS.height,
    size: LANDSCAPE_CANVAS.qrSize / LANDSCAPE_CANVAS.height,
  }),
  portrait: Object.freeze({
    x: PORTRAIT_CANVAS.qrX / PORTRAIT_CANVAS.width,
    y: PORTRAIT_CANVAS.qrY / PORTRAIT_CANVAS.height,
    size: PORTRAIT_CANVAS.qrSize / PORTRAIT_CANVAS.height,
  }),
});

/**
 * Area teks default untuk desain kustom yang tidak menyertakan `info`
 * (fraksi kanvas). Selalu di kiri atas agar mengikuti referensi dan tidak
 * menutupi ilustrasi, logo, maupun motif desain.
 */
const DEFAULT_INFO_BY_ORIENTATION = Object.freeze({
  landscape: Object.freeze({
    x: LANDSCAPE_CANVAS.padding / LANDSCAPE_CANVAS.width,
    y: LANDSCAPE_CANVAS.textTop / LANDSCAPE_CANVAS.height,
    width: LANDSCAPE_CANVAS.textWidth / LANDSCAPE_CANVAS.width,
    // 0.350 x 594 = 208 pt: cukup untuk 6 baris informasi (judul 34 pt dst.)
    // sehingga tipografi tampil pada ukuran penuh, bukan dikecilkan.
    height: LANDSCAPE_CANVAS.textHeight / LANDSCAPE_CANVAS.height,
    color: '#1A1A1A',
  }),
  portrait: Object.freeze({
    x: PORTRAIT_CANVAS.padding / PORTRAIT_CANVAS.width,
    y: PORTRAIT_CANVAS.textTop / PORTRAIT_CANVAS.height,
    width: PORTRAIT_CANVAS.textWidth / PORTRAIT_CANVAS.width,
    // 0.284 x 704 = 200 pt untuk blok teks pada header portrait.
    height: PORTRAIT_CANVAS.textHeight / PORTRAIT_CANVAS.height,
    color: '#1A1A1A',
  }),
});

const DEFAULT_QR = DEFAULT_QR_BY_ORIENTATION.landscape;
const DEFAULT_INFO = DEFAULT_INFO_BY_ORIENTATION.landscape;

/**
 * Orientasi desain tiket.
 *
 * - `landscape`: kanvas horizontal 842 x 594 pt (rasio ~1.42:1).
 * - `portrait` : kanvas vertikal 440 x 704 pt (rasio ~1:1.6).
 *
 * Orientasi menentukan ukuran halaman PDF, rasio template, dan area penempatan
 * QR bawaan. Desain kustom yang diunggah WAJIB mengikuti rasio orientasi yang
 * dipilih agar tidak dipotong/diregangkan saat dirender.
 */
const ORIENTATIONS = Object.freeze(['landscape', 'portrait']);
const DEFAULT_ORIENTATION = 'landscape';

/**
 * Ukuran kanvas (lebar:tinggi) per orientasi + batas toleransi rasio unggahan.
 *
 * Toleransi menjaga agar desain kustom mengisi kanvas tanpa distorsi berarti:
 * landscape menerima rasio 1.25-1.62 (kanvas 1.4175), portrait 0.50-0.85
 * (kanvas 0.625). Desain lama di luar rentang ini tetap dapat DICETAK
 * (digambar `contain` tanpa distorsi) tetapi tidak dapat diunggah ulang.
 */
const ORIENTATION_SPEC = Object.freeze({
  landscape: Object.freeze({
    width: LANDSCAPE_CANVAS.width,
    height: LANDSCAPE_CANVAS.height,
    ratio: LANDSCAPE_CANVAS.width / LANDSCAPE_CANVAS.height,
    minRatio: 1.25,
    maxRatio: 1.62,
  }),
  portrait: Object.freeze({
    width: PORTRAIT_CANVAS.width,
    height: PORTRAIT_CANVAS.height,
    ratio: PORTRAIT_CANVAS.width / PORTRAIT_CANVAS.height,
    minRatio: 0.5,
    maxRatio: 0.85,
  }),
});

/** Normalisasi nilai orientasi dari request/DB; null bila tidak valid. */
const normalizeOrientation = (value) => {
  const raw = String(value ?? '').trim().toLowerCase();
  return ORIENTATIONS.includes(raw) ? raw : null;
};

const orientationOrDefault = (value) => normalizeOrientation(value) || DEFAULT_ORIENTATION;

/**
 * Orientasi dari objek desain mentah (tanpa mensyaratkan file desain ada).
 * Dipakai saat Organizer menyimpan orientasi lebih dulu, sebelum mengunggah
 * desain.
 */
const designOrientationOf = (raw) =>
  (raw && typeof raw === 'object' && !Array.isArray(raw))
    ? normalizeOrientation(raw.orientation)
    : null;

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
const isFiniteNumber = (value) =>
  typeof value === 'number' && Number.isFinite(value);

const parseFraction = (value, fallback) => {
  const parsed = typeof value === 'string' ? Number(value) : value;
  return isFiniteNumber(parsed) ? parsed : fallback;
};

/**
 * Normalisasi objek desain dari database/permintaan API.
 * Mengembalikan null bila tidak ada desain tersimpan.
 */
const normalizeDesign = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const filePath = typeof raw.file_path === 'string' ? raw.file_path.trim() : '';
  if (!filePath.startsWith(`${DESIGN_URL_PREFIX}/`)) return null;
  const orientation = orientationOrDefault(raw.orientation);
  const defaultQr = DEFAULT_QR_BY_ORIENTATION[orientation];
  const defaultInfo = DEFAULT_INFO_BY_ORIENTATION[orientation];
  const qrRaw = raw.qr && typeof raw.qr === 'object' ? raw.qr : {};
  const infoRaw = raw.info && typeof raw.info === 'object' ? raw.info : {};
  return {
    source: raw.source === 'upload' ? 'upload' : 'template',
    template: typeof raw.template === 'string' ? raw.template : 'classic',
    file_path: filePath,
    content_type: extensionFor(raw.content_type) ? raw.content_type : 'image/png',
    orientation,
    width: isFiniteNumber(raw.width) && raw.width > 0 ? Math.round(raw.width) : null,
    height: isFiniteNumber(raw.height) && raw.height > 0 ? Math.round(raw.height) : null,
    qr: {
      x: clamp(parseFraction(qrRaw.x, defaultQr.x), 0, 0.95),
      y: clamp(parseFraction(qrRaw.y, defaultQr.y), 0, 0.95),
      size: clamp(parseFraction(qrRaw.size, defaultQr.size), 0.15, 0.9),
    },
    info: {
      x: clamp(parseFraction(infoRaw.x, defaultInfo.x), 0, 0.95),
      y: clamp(parseFraction(infoRaw.y, defaultInfo.y), 0, 0.95),
      width: clamp(parseFraction(infoRaw.width, defaultInfo.width), 0.1, 0.95),
      height: clamp(parseFraction(infoRaw.height, defaultInfo.height), 0.1, 0.95),
      color:
        typeof infoRaw.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(infoRaw.color)
          ? infoRaw.color
          : defaultInfo.color,
    },
    updated_at: typeof raw.updated_at === 'string' ? raw.updated_at : null,
  };
};

/**
 * Batas posisi & ukuran QR yang boleh diatur Organizer (fraksi kanvas).
 * Nilai default sistem selalu berada di dalam rentang ini.
 *
 * Ukuran dibatasi 15%-60% tinggi kanvas: di bawah 15% QR terlalu kecil untuk
 * dipindai (dan tetap dinaikkan ke `QR_MIN_POINTS`), sedangkan di atas 60% QR
 * menutupi hampir seluruh desain tiket. Nilai lama yang tersimpan (hingga 90%)
 * tetap dapat dicetak — `normalizeDesign` hanya memotongnya ke halaman.
 */
const QR_PLACEMENT_LIMITS = Object.freeze({
  position: Object.freeze({ min: 0, max: 0.95 }),
  size: Object.freeze({ min: 0.15, max: 0.6 }),
});

/**
 * Validasi pengaturan posisi & ukuran QR dari request Organizer.
 *
 * Dipakai dua jalur: unggah desain (bersama payload file) dan penyimpanan
 * pengaturan QR saja (`qr_only`), sehingga keduanya memiliki aturan identik.
 *
 * @param {object} raw `{ x, y, size }` fraksi 0..1
 * @param {{orientation?: string}} [options] orientasi untuk nilai default
 * @returns {{errors: string[], value: {x: number, y: number, size: number}|null}}
 */
const validateQrPlacement = (raw, { orientation } = {}) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { errors: ['Pengaturan QR Code tidak valid.'], value: null };
  }
  const defaults = DEFAULT_QR_BY_ORIENTATION[orientationOrDefault(orientation)];
  const qr = {
    x: parseFraction(raw.x, defaults.x),
    y: parseFraction(raw.y, defaults.y),
    size: parseFraction(raw.size, defaults.size),
  };
  const errors = [];
  const { position, size } = QR_PLACEMENT_LIMITS;
  if (qr.x < position.min || qr.x > position.max) {
    errors.push(`Posisi X QR harus ${position.min}-${position.max * 100}%.`);
  }
  if (qr.y < position.min || qr.y > position.max) {
    errors.push(`Posisi Y QR harus ${position.min}-${position.max * 100}%.`);
  }
  if (qr.size < size.min || qr.size > size.max) {
    errors.push(`Ukuran QR harus ${size.min * 100}-${size.max * 100}% dari tinggi tiket.`);
  }
  return { errors, value: errors.length > 0 ? null : qr };
};

/**
 * Terapkan pengaturan QR baru pada desain yang sudah tersimpan tanpa mengubah
 * file desain maupun orientasinya.
 *
 * @param {object} previous desain ternormalisasi yang sudah ada
 * @param {{qr: object, info?: object}} placement pengaturan baru
 * @returns {object|null} desain siap disimpan (JSONB)
 */
const applyQrPlacement = (previous, { qr, info }) => {
  if (!previous) return null;
  return normalizeDesign({
    ...previous,
    qr,
    info: info ?? previous.info,
    updated_at: new Date().toISOString(),
  });
};

/**
 * Validasi payload unggah desain tiket.
 * @returns {{ errors: string[], value: object|null }}
 */
const validateUploadPayload = (body) => {
  const errors = [];
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { errors: ['Payload desain tiket tidak valid.'], value: null };
  }

  const orientation = normalizeOrientation(body.orientation) || null;
  if (!orientation) {
    errors.push('Orientasi desain tiket harus "landscape" atau "portrait".');
  }
  const spec = ORIENTATION_SPEC[orientation || DEFAULT_ORIENTATION];
  const defaultInfo = DEFAULT_INFO_BY_ORIENTATION[orientation || DEFAULT_ORIENTATION];

  const contentType = String(body.content_type || '').toLowerCase().trim();
  if (!extensionFor(contentType)) {
    errors.push('Format desain harus PNG atau JPEG.');
  }

  const base64 = typeof body.image_base64 === 'string'
    ? body.image_base64.replace(/^data:[^;]+;base64,/, '')
    : '';
  let buffer = null;
  if (!base64) {
    errors.push('File desain tiket wajib diunggah.');
  } else if (base64.length > MAX_UPLOAD_BASE64_LENGTH) {
    // Tolak sebelum decode: string base64 10 MB akan menjadi Buffer ±7,5 MB.
    errors.push('Ukuran desain tiket melebihi 2 MB.');
  } else {
    buffer = Buffer.from(base64, 'base64');
    if (buffer.length === 0) {
      errors.push('File desain tiket tidak dapat dibaca.');
    }
  }
  if (buffer && buffer.length > 0) {
    if (buffer.length < MIN_UPLOAD_BYTES) {
      errors.push('File desain tiket terlalu kecil (minimal 1 KB).');
    }
    if (buffer.length > MAX_UPLOAD_BYTES) {
      errors.push('Ukuran desain tiket melebihi 2 MB.');
    }
    if (!matchesSignature(buffer, contentType)) {
      errors.push('Isi file tidak sesuai dengan format PNG/JPEG yang diklaim.');
    }
    // Validasi orientasi: rasio gambar harus mendekati rasio kanvas orientasi
    // yang dipilih supaya hasil PDF mengisi halaman tanpa dipotong/diregangkan.
    const size = readImageSize(buffer);
    if (!size || !(size.width > 0) || !(size.height > 0)) {
      errors.push('Dimensi file desain tiket tidak dapat dibaca.');
    } else {
      const ratio = size.width / size.height;
      const fits = ratio >= spec.minRatio && ratio <= spec.maxRatio;
      if (!fits) {
        errors.push(
          orientation === 'portrait'
            ? 'Desain tidak sesuai orientasi portrait. Unggah gambar vertikal '
              + 'dengan rasio ~1:1.6 (mis. 880x1408 px atau 440x704 pt).'
            : 'Desain tidak sesuai orientasi landscape. Unggah gambar horizontal '
              + 'dengan rasio ~1.42:1 (mis. 1684x1188 px atau 842x594 pt).'
        );
      }
    }
  }

  const { errors: qrErrors, value: qr } = validateQrPlacement(
    body.qr && typeof body.qr === 'object' ? body.qr : {},
    { orientation: orientation || DEFAULT_ORIENTATION },
  );
  errors.push(...qrErrors);

  const infoRaw = body.info && typeof body.info === 'object' ? body.info : {};
  const info = {
    x: clamp(parseFraction(infoRaw.x, defaultInfo.x), 0, 0.95),
    y: clamp(parseFraction(infoRaw.y, defaultInfo.y), 0, 0.95),
    width: clamp(parseFraction(infoRaw.width, defaultInfo.width), 0.1, 0.95),
    height: clamp(parseFraction(infoRaw.height, defaultInfo.height), 0.1, 0.95),
    color:
      typeof infoRaw.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(infoRaw.color)
        ? infoRaw.color
        : defaultInfo.color,
  };

  const imageSize = buffer ? readImageSize(buffer) : null;

  return {
    errors,
    value: errors.length > 0 ? null : {
      contentType,
      buffer,
      orientation: orientation || DEFAULT_ORIENTATION,
      width: imageSize?.width ?? null,
      height: imageSize?.height ?? null,
      qr,
      info,
    },
  };
};

/** Cek magic number PNG/JPEG agar tipe file tidak hanya dipercaya dari klien. */
const matchesSignature = (buffer, contentType) => {
  if (!buffer || buffer.length < 8) return false;
  if (contentType === 'image/png') return hasPngSignature(buffer);
  if (contentType === 'image/jpeg') {
    return buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  }
  return false;
};

/**
 * Nama folder penyimpanan desain untuk satu event.
 *
 * Id event berupa UUID; hanya huruf, angka, `-`, dan `_` yang diterima sehingga
 * `..` maupun pemisah path tidak dapat mengarahkan penulisan file keluar dari
 * `DESIGN_DIR`. Mengembalikan null bila id tidak aman dipakai sebagai folder.
 */
const STORAGE_SEGMENT_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const storageSegmentFor = (eventId) => {
  const segment = String(eventId ?? '').trim();
  return STORAGE_SEGMENT_PATTERN.test(segment) ? segment : null;
};

/**
 * Simpan gambar desain ke penyimpanan server.
 * @returns {Promise<{ filePath: string, absolutePath: string }>}
 */
const saveDesignImage = async ({ eventId, buffer, contentType }) => {
  const extension = extensionFor(contentType);
  if (!extension) {
    throw new TypeError('Format desain tiket harus PNG atau JPEG.');
  }
  const eventSegment = storageSegmentFor(eventId);
  if (!eventSegment) {
    throw new TypeError('Id event tidak valid untuk menyimpan desain tiket.');
  }
  const directory = path.join(DESIGN_DIR, eventSegment);
  await fsp.mkdir(directory, { recursive: true });
  const filename = `${Date.now()}-${randomUUID()}${extension}`;
  const absolutePath = path.join(directory, filename);
  await fsp.writeFile(absolutePath, buffer);
  return {
    filePath: `${DESIGN_URL_PREFIX}/${eventSegment}/${filename}`,
    absolutePath,
  };
};

/** Path absolut file desain dari `file_path` tersimpan. */
const designAbsolutePath = (design) => {
  if (!design || typeof design.file_path !== 'string') return null;
  if (!design.file_path.startsWith(`${DESIGN_URL_PREFIX}/`)) return null;
  const relative = design.file_path.slice(DESIGN_URL_PREFIX.length + 1);
  const absolutePath = path.resolve(DESIGN_DIR, relative);
  const inside = path.relative(DESIGN_DIR, absolutePath);
  // `startsWith(DESIGN_DIR)` saja tidak cukup: folder saudara seperti
  // `ticket-designs-lama` juga lolos. Pastikan hasil resolve benar-benar berada
  // di dalam DESIGN_DIR dan bukan folder itu sendiri.
  const escapes = !inside
    || inside === '..'
    || inside.startsWith(`..${path.sep}`)
    || path.isAbsolute(inside);
  return escapes ? null : absolutePath;
};

/** Hapus file desain lama bila berada di dalam direktori penyimpanan. */
const removeDesignFile = async (filePath) => {
  const absolutePath = designAbsolutePath({ file_path: filePath });
  if (!absolutePath) return false;
  try {
    await fsp.unlink(absolutePath);
    return true;
  } catch (_error) {
    return false;
  }
};

/** Path template PNG bawaan sistem per orientasi (null bila belum digenerate). */
const templatePathFor = (format, orientation) => {
  const normalized = String(format || '').toLowerCase();
  if (normalized === 'png') {
    const orientationName = orientationOrDefault(orientation);
    const candidate = path.join(TEMPLATE_DIR, `ticket-template-${orientationName}.png`);
    if (fs.existsSync(candidate)) return candidate;
    // Fallback HANYA untuk landscape: `ticket-template.png` adalah salinan
    // template landscape, sehingga tidak boleh dikirim sebagai template portrait.
    if (orientationName === 'landscape' && fs.existsSync(TEMPLATE_PNG)) return TEMPLATE_PNG;
    return null;
  }
  return null; // PDF dirender dinamis agar konsisten dengan layout QR default.
};

/**
 * Ukuran halaman PDF tiket.
 *
 * Kanvas bersifat TETAP per orientasi (landscape 842x594 pt, portrait
 * 440x704 pt). Sebelumnya tinggi halaman diturunkan dari rasio file desain,
 * sehingga tiket landscape bisa menjadi sangat pipih dan QR terlihat kecil.
 * Gambar desain kustom kini digambar dengan skala seragam di dalam kanvas
 * tersebut (lihat `imageFrameFor`) sehingga rasio aslinya tetap utuh.
 *
 * @param {{width: number, height: number}|null} imageSize dipertahankan demi
 *   kompatibilitas pemanggil lama; ukuran halaman tidak lagi bergantung padanya.
 */
const pageSizeFor = (imageSize, orientation) => {
  const spec = ORIENTATION_SPEC[orientationOrDefault(orientation)];
  void imageSize;
  return { width: spec.width, height: spec.height };
};

/**
 * Persegi gambar desain kustom di dalam kanvas (contain-fit, tanpa distorsi).
 *
 * Bila rasio gambar sama dengan rasio kanvas, persegi ini menutup seluruh
 * halaman. Bila berbeda (mis. desain lama 2.5:1), gambar tetap utuh dan sisa
 * ruang menjadi mat berwarna ivory — tidak ada gambar yang dipotong/diregangkan.
 */
const imageFrameFor = (imageSize, { width, height }) => {
  const hasImage = imageSize && imageSize.width > 0 && imageSize.height > 0;
  if (!hasImage) return { x: 0, y: 0, width, height };
  const imageRatio = imageSize.width / imageSize.height;
  const pageRatio = width / height;
  if (Math.abs(imageRatio - pageRatio) < 0.005) return { x: 0, y: 0, width, height };
  if (imageRatio > pageRatio) {
    const frameHeight = width / imageRatio;
    return { x: 0, y: (height - frameHeight) / 2, width, height: frameHeight };
  }
  const frameWidth = height * imageRatio;
  return { x: (width - frameWidth) / 2, y: 0, width: frameWidth, height };
};

/**
 * Kotak QR dari fraksi desain, dihitung terhadap persegi gambar (bukan halaman)
 * agar desain yang sudah tersimpan tetap menempatkan QR di titik yang sama pada
 * ilustrasinya walau ukuran halaman berubah.
 *
 * Aturan (penting untuk pengaturan Organizer):
 *  - UKURAN yang disimpan Organizer dipakai apa adanya (`size` x tinggi kanvas).
 *  - Bila hasilnya di bawah `QR_MIN_POINTS`, QR dinaikkan ke batas minimum agar
 *    tetap dapat dipindai; bila melebihi halaman, dipotong ke sisi terpendek.
 *  - POSISI (x, y) digeser seperlunya bila QR akan keluar halaman, sehingga
 *    ukuran yang diminta tidak diam-diam diperkecil hanya karena posisinya dekat
 *    tepi kanan/bawah.
 */
const QR_MIN_POINTS = 100;
const qrRectFromFractions = (fractions, frame) => {
  const maxSide = Math.min(frame.width, frame.height);
  const requested = fractions.size * frame.height;
  const size = clamp(Math.max(requested, QR_MIN_POINTS), 1, maxSide);
  return {
    x: clamp(frame.x + fractions.x * frame.width, frame.x, frame.x + frame.width - size),
    y: clamp(frame.y + fractions.y * frame.height, frame.y, frame.y + frame.height - size),
    size,
  };
};

/** Marker SOF JPEG yang memuat dimensi (SOF0..SOF15, kecuali DHT/JPG/DAC). */
const isJpegSofMarker = (marker) =>
  marker >= 0xc0 && marker <= 0xcf
  && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;

/** Baca dimensi PNG/JPEG tanpa dependency gambar tambahan. */
const readImageSize = (buffer) => {
  if (!buffer || buffer.length < 26) return null;
  // PNG: signature 8 byte, lalu chunk IHDR (panjang 4 byte, tipe 4 byte, data).
  // Lebar/tinggi berada pada byte 16..23.
  if (hasPngSignature(buffer)) {
    if (buffer.subarray(12, 16).toString('latin1') !== 'IHDR') return null;
    return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  }
  // JPEG: cari marker SOF0/SOF2.
  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    let offset = 2;
    while (offset + 1 < buffer.length) {
      if (buffer[offset] !== 0xff) {
        offset += 1;
        continue;
      }
      const marker = buffer[offset + 1];
      // 0xFF berikutnya adalah fill byte, bukan awal marker.
      if (marker === 0xff) {
        offset += 1;
        continue;
      }
      // Marker tanpa field panjang: TEM (0x01), RSTn (0xD0-0xD7), SOI (0xD8).
      if (marker === 0x01 || marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7)) {
        offset += 2;
        continue;
      }
      // SOS/EOI: data scan dimulai sebelum SOF ditemukan, dimensi tidak terbaca.
      if (marker === 0xda || marker === 0xd9) return null;
      if (offset + 9 >= buffer.length) return null;
      const length = buffer.readUInt16BE(offset + 2);
      // Panjang segmen minimal 2 byte (field panjang itu sendiri); nilai lain
      // berarti berkas rusak dan offset tidak dapat dilanjutkan dengan aman.
      if (length < 2) return null;
      if (isJpegSofMarker(marker)) {
        return {
          height: buffer.readUInt16BE(offset + 5),
          width: buffer.readUInt16BE(offset + 7),
        };
      }
      offset += 2 + length;
    }
  }
  return null;
};

/* ------------------------------------------------------------------------- *
 * Palet, tipografi, dan primitif gambar
 * ------------------------------------------------------------------------- */

/**
 * Palet e-tiket: dusty pink + krem + putih gading. Dipakai untuk artwork
 * background default; teks informasi memakai `TICKET_TEXT_COLOR` (hitam).
 */
const PALETTE = Object.freeze({
  rose900: '#7A3B38',
  rose700: '#A85C58',
  rose500: '#C9837F',
  rose300: '#E7B6B0',
  rose100: '#F7E2DE',
  cream: '#FBF2E4',
  creamDeep: '#F2E2CA',
  ivory: '#FFFDF8',
  white: '#FFFFFF',
});

const FONT = Object.freeze({
  bold: 'Helvetica-Bold',
  regular: 'Helvetica',
});

/** Warna teks informasi tambahan: hitam netral agar kontras di atas artwork. */
const TICKET_TEXT_COLOR = '#1A1A1A';

/** Instruksi singkat penukaran tiket (satu-satunya teks instruksi di tiket). */
const EXCHANGE_INSTRUCTION = 'Silakan tukarkan tiket ini di meja registrasi.';

/** Tracking judul (pt per huruf) agar "E-TIKET" terbaca sebagai label. */
const TITLE_TRACKING = 0.9;

/** Lebar teks satu baris termasuk tracking (characterSpacing). */
const measureLineWidth = (doc, text, { size, font, tracking = 0 }) => {
  doc.font(font).fontSize(size);
  const base = doc.widthOfString(String(text ?? ''));
  return base + tracking * Math.max(0, String(text ?? '').length - 1);
};

/**
 * Ukuran font terbesar dari `sizes` yang membuat teks muat dalam satu baris.
 *
 * Dipakai untuk judul pada area teks yang sempit (desain kustom): judul tetap
 * satu baris penuh, bukan terpotong elipsis.
 */
const fitLineSize = (doc, text, { width, font, sizes, tracking = 0 }) => {
  for (const size of sizes) {
    if (measureLineWidth(doc, text, { size, font, tracking }) <= width) return size;
  }
  return sizes[sizes.length - 1];
};

/** Potong teks satu baris dengan elipsis bila melebihi lebar area. */
const truncateLine = (doc, text, { width, size, font, tracking = 0 }) => {
  const value = String(text ?? '');
  if (measureLineWidth(doc, value, { size, font, tracking }) <= width) return value;
  let cut = value;
  while (cut.length > 1 &&
    measureLineWidth(doc, `${cut}…`, { size, font, tracking }) > width) {
    cut = cut.slice(0, -1);
  }
  return `${cut.trimEnd()}…`;
};

/**
 * Skala tipografi blok informasi (pt) — hierarki keterbacaan:
 *   1. `E-TIKET [NAMA EVENT]` paling besar & menonjol (boleh 2 baris),
 *   2. nama peserta paling menonjol setelah judul,
 *   3. ID tiket, kategori, jadwal, dan lokasi pada ukuran baca yang sama,
 *   4. instruksi penukaran paling kecil tetapi tetap nyaman dibaca.
 *
 * Seluruh ukuran dinaikkan dari versi sebelumnya (31/17,5/15,5/13,5 pt) dan
 * jumlah baris bertambah (kategori, jadwal, dan lokasi ikut dicetak) sehingga
 * area informasi pada `LANDSCAPE_CANVAS.textHeight` / `PORTRAIT_CANVAS.textHeight`
 * ikut diperbesar. Tinggi alami blok dihitung dari teks yang benar-benar akan
 * dicetak (`infoBlockHeight`), lalu dipakai untuk mengecilkan tipografi secara
 * proporsional (tanpa mengubah hierarki) bila nama event panjang atau area teks
 * desain kustom lebih pendek — agar tidak ada teks yang terpotong atau menimpa QR.
 */
const TICKET_TYPE = Object.freeze({
  titleSizes: [34, 32, 30, 28, 26],
  titleLineGap: 1.18,
  titleMaxLines: 2,
  attendeeSize: 23,
  attendeeSizes: [23, 21, 19, 18, 17],
  attendeeLineGap: 1.34,
  metaSize: 16,
  metaLineGap: 1.55,
  instructionSize: 14,
  instructionLineGap: 2,
});

/**
 * Bungkus teks menjadi maksimal `maxLines` baris; baris terakhir dipotong dengan
 * elipsis bila masih ada sisa kata. Dipakai judul event agar nama panjang tetap
 * terbaca tanpa melewati area teks.
 */
const wrapToLines = (doc, text, { width, size, font, tracking = 0, maxLines = 1 }) => {
  const words = String(text ?? '').split(/\s+/).filter(Boolean);
  if (words.length === 0) return [''];
  const lines = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (measureLineWidth(doc, candidate, { size, font, tracking }) <= width) {
      current = candidate;
      continue;
    }
    if (current) {
      lines.push(current);
      current = word;
      continue;
    }
    // Satu kata lebih lebar dari area: potong agar tidak melewati batas.
    current = truncateLine(doc, word, { width, size, font, tracking });
  }
  if (current) lines.push(current);
  if (lines.length <= maxLines) return lines;
  const head = lines.slice(0, maxLines - 1);
  const tail = lines.slice(maxLines - 1).join(' ');
  head.push(truncateLine(doc, tail, { width, size, font, tracking }));
  return head;
};

/**
 * Susunan baris blok informasi tiket.
 *
 * Baris yang datanya tidak tersedia dilewati (mis. event tanpa lokasi), sehingga
 * tiket tetap rapi dan tidak mencetak label kosong.
 */
const infoBlockLines = (data, { titleSizes = TICKET_TYPE.titleSizes } = {}) => {
  const meta = { size: TICKET_TYPE.metaSize, font: FONT.regular, lineGap: TICKET_TYPE.metaLineGap };
  const lines = [
    {
      text: `E-TIKET ${String(data.eventTitle ?? '').trim()}`,
      size: titleSizes[0],
      sizes: titleSizes,
      font: FONT.bold,
      lineGap: TICKET_TYPE.titleLineGap,
      maxLines: TICKET_TYPE.titleMaxLines,
      tracking: TITLE_TRACKING,
    },
    {
      text: `Peserta: ${String(data.attendeeName ?? '').trim()}`,
      size: TICKET_TYPE.attendeeSize,
      // Nama peserta panjang dikecilkan bertahap agar tetap satu baris utuh
      // (nama peserta tidak boleh terpotong sebelum benar-benar tidak muat).
      sizes: TICKET_TYPE.attendeeSizes,
      font: FONT.bold,
      lineGap: TICKET_TYPE.attendeeLineGap,
      maxLines: 1,
    },
  ];
  const ticketId = String(data.ticketId ?? '').trim();
  if (ticketId) {
    lines.push({
      text: `ID TIKET: ${ticketId}`, size: meta.size, font: FONT.bold, lineGap: meta.lineGap, maxLines: 1,
    });
  }
  const ticketTypeName = String(data.ticketTypeName ?? '').trim();
  if (ticketTypeName) {
    lines.push({ text: `Kategori: ${ticketTypeName}`, ...meta, maxLines: 1 });
  }
  const schedule = String(data.scheduleText ?? '').trim();
  if (schedule) {
    lines.push({ text: `Jadwal: ${schedule}`, ...meta, maxLines: 1 });
  }
  const location = String(data.locationText ?? '').trim();
  if (location) {
    lines.push({ text: `Lokasi: ${location}`, ...meta, maxLines: 1 });
  }
  lines.push({
    text: EXCHANGE_INSTRUCTION,
    size: TICKET_TYPE.instructionSize,
    font: FONT.regular,
    lineGap: TICKET_TYPE.instructionLineGap,
    maxLines: 1,
  });
  return lines;
};

/**
 * Tinggi alami blok informasi pada skala 1 (pt), termasuk judul yang terbungkus
 * menjadi dua baris. Dipakai `drawTicketInfoLines` untuk menentukan skala.
 */
const infoBlockHeight = (doc, specs, { width }) => specs.reduce((total, spec) => {
  const lineCount = wrapToLines(doc, spec.text, {
    width,
    size: spec.size,
    font: spec.font,
    tracking: spec.tracking ?? 0,
    maxLines: spec.maxLines ?? 1,
  }).length;
  return total + Math.max(1, lineCount) * spec.size * spec.lineGap;
}, 0);

/**
 * Tentukan ukuran satu baris: ukuran terbesar dari `sizes` yang membuat teks
 * muat dalam SATU baris. Teks yang sangat panjang memakai ukuran terkecil lalu
 * dibungkus sesuai `maxLines` (judul: dua baris) agar tetap terbaca tanpa
 * memotong kata pertama.
 */
const fitTitleSize = (doc, text, { width, sizes, font, tracking = 0, maxLines = 1 }) => {
  const size = fitLineSize(doc, text, { width, font, sizes, tracking });
  const fitsOneLine = measureLineWidth(doc, text, { size, font, tracking }) <= width;
  return { size, maxLines: fitsOneLine ? 1 : maxLines };
};

/**
 * Hitung susunan baris, skala, dan tinggi total blok informasi TANPA menggambar.
 *
 * Dipakai `drawTicketInfoLines` (menggambar) dan `placeTicketInfoAndQr` (menentukan
 * posisi) agar keduanya memakai perhitungan tinggi yang sama.
 *
 * @returns {{specs: object[], scale: number, height: number}}
 */
const resolveInfoLayout = (doc, {
  width, maxHeight = null, titleSizes = TICKET_TYPE.titleSizes,
}, data) => {
  const specs = infoBlockLines(data, { titleSizes });
  // Judul & nama peserta: pilih ukuran yang muat satu baris sebelum mengecilkan
  // seluruh blok. Nama event boleh menjadi dua baris.
  for (const spec of specs) {
    if (!spec.sizes) continue;
    const fitted = fitTitleSize(doc, spec.text, {
      width,
      sizes: spec.sizes,
      font: spec.font,
      tracking: spec.tracking ?? 0,
      maxLines: spec.maxLines ?? 1,
    });
    spec.size = fitted.size;
    spec.maxLines = fitted.maxLines;
  }
  const naturalHeight = infoBlockHeight(doc, specs, { width });
  const scale = maxHeight && maxHeight < naturalHeight
    ? Math.max(0.62, maxHeight / naturalHeight)
    : 1;
  const height = specs.reduce((total, spec) => {
    const size = spec.size * scale;
    const lineCount = wrapToLines(doc, spec.text, {
      width, size, font: spec.font, tracking: (spec.tracking ?? 0) * scale,
      maxLines: spec.maxLines ?? 1,
    }).length;
    return total + Math.max(1, lineCount) * size * spec.lineGap;
  }, 0);
  return { specs, scale, height };
};

/**
 * Blok informasi tiket di atas desain (tanpa panel/latar):
 *   1. E-TIKET [NAMA EVENT]        (judul, paling menonjol, maks. 2 baris)
 *   2. Peserta: [NAMA PESERTA]
 *   3. ID TIKET: [ID TIKET]
 *   4. Kategori: [KATEGORI TIKET]
 *   5. Jadwal: [TANGGAL & WAKTU]
 *   6. Lokasi: [LOKASI]
 *   7. instruksi singkat penukaran tiket
 *
 * `maxHeight` (opsional) mengecilkan tipografi proporsional bila area teks
 * Organizer lebih pendek, agar blok tidak melewati area yang ditentukan dan
 * tidak menimpa QR Code. Hierarki ukuran tetap dipertahankan.
 *
 * @returns {number} posisi Y (pt) tepat di bawah blok teks.
 */
const drawTicketInfoLines = (doc, {
  x, y, width, color = TICKET_TEXT_COLOR, maxHeight = null,
  titleSizes = TICKET_TYPE.titleSizes,
}, data) => {
  const { specs, scale } = resolveInfoLayout(doc, { width, maxHeight, titleSizes }, data);

  let cursor = y;
  for (const spec of specs) {
    const size = spec.size * scale;
    const font = spec.font;
    const tracking = (spec.tracking ?? 0) * scale;
    const lines = wrapToLines(doc, spec.text, {
      width, size, font, tracking, maxLines: spec.maxLines ?? 1,
    });
    doc.font(font).fontSize(size).fillColor(color);
    for (const line of lines) {
      doc.text(line, x, cursor, {
        lineBreak: false,
        ...(tracking > 0 ? { characterSpacing: tracking } : {}),
      });
      cursor += size * spec.lineGap;
    }
  }
  return cursor;
};

/**
 * Alas putih QR Code: hanya seukuran QR ditambah quiet zone + margin kecil.
 *
 * QR PNG sudah membawa quiet zone 2 modul; padding 6 pt di sini adalah margin
 * tipis agar tepi QR tidak menempel artwork. Kotak putih TIDAK boleh lebih besar
 * dari ini supaya ilustrasi/logo desain tetap terlihat.
 */
const QR_BACKING_PAD = 6;
const QR_BACKING_RADIUS = 4;
const drawQrBacking = (doc, rect) => {
  doc.roundedRect(
    rect.x - QR_BACKING_PAD, rect.y - QR_BACKING_PAD,
    rect.size + QR_BACKING_PAD * 2, rect.size + QR_BACKING_PAD * 2,
    QR_BACKING_RADIUS,
  ).fill(PALETTE.white);
};

/* ------------------------------------------------------------------------- *
 * Data tampilan tiket
 * ------------------------------------------------------------------------- */

/**
 * Format tanggal + waktu event untuk tiket.
 *
 * Memakai zona waktu penyelenggaraan (WIB) seperti email tiket, sehingga jadwal
 * pada tiket dan email tidak berbeda. Tanggal tidak valid menghasilkan string
 * kosong agar baris "Jadwal" dilewati, bukan mencetak "Invalid Date".
 */
const TICKET_SCHEDULE_FORMAT = new Intl.DateTimeFormat('id-ID', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'Asia/Jakarta',
});

const formatTicketSchedule = (ticket) => {
  const raw = ticket?.event_date;
  if (!raw) return '';
  const date = raw instanceof Date ? raw : new Date(raw);
  if (Number.isNaN(date.getTime())) return '';
  return TICKET_SCHEDULE_FORMAT.format(date);
};

/**
 * Data tampilan tiket.
 *
 * Memuat nilai yang BENAR-BENAR dicetak pada tiket: nama event, nama peserta,
 * ID tiket, kategori, jadwal, dan lokasi. `placeholder` dipakai template desain
 * agar Organizer melihat tata letak tanpa memuat data peserta sungguhan; selain
 * itu semua nilai berasal dari baris tiket hasil JOIN database.
 */
const ticketDisplayData = (ticket = {}, placeholder = false) => {
  if (placeholder) {
    return {
      eventTitle: 'Nama Event',
      ticketId: 'ETK-7K4P9Q',
      attendeeName: 'Nama Peserta',
      ticketTypeName: 'Kategori Tiket',
      scheduleText: 'Selasa, 1 Desember 2026 19.00',
      locationText: 'Jakarta Convention Center',
    };
  }
  const eventTitle = String(ticket.event_title ?? '').trim();
  const location = String(ticket.location ?? '').trim();
  const onlineUrl = String(ticket.online_url ?? '').trim();
  return {
    eventTitle: eventTitle || 'Nama event tidak tersedia',
    ticketId: String(ticket.ticket_code ?? '').trim() || '-',
    attendeeName: String(ticket.attendee_name ?? '').trim() || 'Nama peserta tidak tersedia',
    ticketTypeName: String(ticket.ticket_type_name ?? '').trim(),
    scheduleText: formatTicketSchedule(ticket),
    // Event daring tanpa lokasi tetap menampilkan kanal aksesnya.
    locationText: location || (onlineUrl ? 'Online' : ''),
  };
};

/* ------------------------------------------------------------------------- *
 * Tiket landscape 842 x 594 pt
 * ------------------------------------------------------------------------- */

/**
 * Grid titik dekoratif (ornamen panel kiri).
 *
 * Dipisah menjadi helper bernama agar blok ornamen tidak lagi ditulis sebagai
 * loop bersarang di dalam `drawLandscapeTicket` — struktur blok ornamen jadi
 * jelas dan tidak bisa tertukar dengan blok lain saat berkas diedit. Hasil
 * gambarnya identik: 4 baris x 5 kolom titik radius 1,6 pt.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{x: number, y: number, rows?: number, cols?: number, step?: number}} grid
 *   `x`,`y` = titik pertama (kiri-atas grid); grid tumbuh ke kiri dan ke bawah.
 */
const drawDotGrid = (doc, { x, y, rows = 4, cols = 5, step = 13 }) => {
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      doc.circle(x - col * step, y + row * step, 1.6).fill();
    }
  }
};

/**
 * Tiket landscape 842 x 594 pt.
 *
 * Artwork sistem (panel pink + krem + ornamen) berperan sebagai background.
 * Di atasnya hanya digambar informasi tambahan minimal di kiri atas (lihat
 * `drawTicketInfoLines`). QR Code ukuran medium digambar pemanggil pada
 * `qrRect` yang dikembalikan, tepat di bawah blok teks.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{width: number, height: number}} page ukuran kanvas (pt)
 * @param {TicketLayoutOptions} [options]
 * @returns {{qrRect: {x: number, y: number, size: number}}}
 */
const drawLandscapeTicket = (doc, { width, height }, { placeholder = false, ticket = {} } = {}) => {
  const data = ticketDisplayData(ticket, placeholder);
  const geo = LANDSCAPE_CANVAS;
  const pad = geo.padding;
  const left = geo.leftPanelWidth;

  // --- panel kiri: dusty pink bergradasi + ornamen
  const pink = doc.linearGradient(0, 0, 0, height);
  pink.stop(0, '#F8E0DC').stop(0.55, '#EDC3BE').stop(1, '#DDA49E');
  doc.rect(0, 0, left, height).fill(pink);
  // Ornamen dibuat di dalam save/restore agar state grafis (termasuk opacity)
  // dipulihkan setelah blok ini.
  //
  // Catatan API: argumen kedua `fill()` adalah fill rule (`even-odd`/`non-zero`),
  // BUKAN opacity. Opacity wajib diatur lewat `fillOpacity()`; `fill(warna, 0.55)`
  // mengabaikan 0,55 sehingga ornamen tercetak solid.
  doc.save();
  doc.fillOpacity(0.55);
  doc.circle(left - 6, height - 6, 168).fill(PALETTE.rose300);
  doc.fillOpacity(0.75);
  doc.circle(left - 6, height - 6, 106).fill(PALETTE.rose100);
  doc.fillOpacity(1);
  for (const radius of [96, 130, 164]) {
    doc.circle(0, height, radius).lineWidth(1.2).strokeColor(PALETTE.rose900, 0.14).stroke();
  }
  // Grid titik dekoratif: diletakkan di bawah area QR (bukan di kanan atas)
  // karena blok informasi kini lebih lebar/tinggi sehingga ornamen di kanan
  // atas akan tertutup teks.
  doc.fillColor(PALETTE.rose900, 0.2);
  drawDotGrid(doc, { x: left - 26, y: height - 96 });
  doc.restore();

  // --- panel kanan: krem + ornamen
  doc.rect(left, 0, width - left, height).fill(PALETTE.cream);
  doc.save();
  doc.fillOpacity(0.9);
  doc.circle(width, 0, 150).fill(PALETTE.creamDeep);
  doc.fillOpacity(1);
  doc.circle(width, 0, 150).lineWidth(1).strokeColor(PALETTE.rose300, 0.9).stroke();
  doc.circle(left + 52, height, 120).lineWidth(1.2).strokeColor(PALETTE.rose300, 0.85).stroke();
  doc.circle(left + 52, height, 84).lineWidth(1).strokeColor(PALETTE.rose300, 0.6).stroke();
  doc.restore();

  // Garis perforasi pemisah panel (kesan tiket sobek)
  doc.save();
  doc.dash(4, { space: 6 }).lineWidth(1.4).strokeColor(PALETTE.rose500, 0.75)
    .moveTo(left, 26).lineTo(left, height - 26).stroke();
  doc.undash();
  doc.restore();
  doc.fillOpacity(1);

  // --- panel kanan: ornamen dekoratif saja (tanpa blok informasi tambahan)
  const rx = left + 34;
  doc.save();
  for (const radius of [14, 22, 30]) {
    doc.circle(rx + 26, 404, radius).lineWidth(1).strokeColor(PALETTE.rose500, 0.45).stroke();
  }
  doc.fillColor(PALETTE.rose700, 0.5);
  for (let index = 0; index < 5; index += 1) {
    doc.circle(rx + 78 + index * 12, 404, 2).fill();
  }
  doc.restore();

  // --- informasi tiket: kiri atas, tanpa panel/latar
  drawTicketInfoLines(doc, {
    x: pad,
    y: geo.textTop,
    width: geo.textWidth,
    maxHeight: geo.textHeight,
    color: TICKET_TEXT_COLOR,
  }, data);

  return { qrRect: { x: geo.qrX, y: geo.qrY, size: geo.qrSize } };
};

/* ------------------------------------------------------------------------- *
 * Tiket portrait 440 x 704 pt
 * ------------------------------------------------------------------------- */

/**
 * Tiket portrait 440 x 704 pt.
 *
 * Sama seperti landscape: artwork pink/krem berperan sebagai background,
 * informasi tambahan minimal di kiri atas header, dan QR ukuran medium di
 * bawahnya.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{width: number, height: number}} page ukuran kanvas (pt)
 * @param {TicketLayoutOptions} [options]
 * @returns {{qrRect: {x: number, y: number, size: number}}}
 */
const drawPortraitTicket = (doc, { width, height }, { placeholder = false, ticket = {} } = {}) => {
  const data = ticketDisplayData(ticket, placeholder);
  const geo = PORTRAIT_CANVAS;
  const pad = geo.padding;

  // Header dusty pink
  const pink = doc.linearGradient(0, 0, 0, geo.headerHeight);
  pink.stop(0, '#F8E0DC').stop(0.6, '#EDC3BE').stop(1, '#DDA49E');
  doc.rect(0, 0, width, geo.headerHeight).fill(pink);
  doc.save();
  // Ornamen memakai warna solid (bukan alpha putih) agar hasil cetak konsisten
  // di semua pembaca PDF.
  doc.circle(width - 4, 2, 104).fill(PALETTE.rose100);
  doc.circle(width - 4, 2, 104).lineWidth(1.2).strokeColor(PALETTE.rose300).stroke();
  doc.circle(width - 4, 2, 66).fill(PALETTE.cream);
  doc.fillColor(PALETTE.rose900, 0.2);
  for (let row = 0; row < 3; row += 1) {
    for (let col = 0; col < 4; col += 1) {
      doc.circle(width - 26 - col * 13, 150 + row * 13, 1.6).fill();
    }
  }
  doc.restore();

  // Badan krem + ornamen
  doc.rect(0, geo.headerHeight, width, height - geo.headerHeight).fill(PALETTE.cream);
  doc.save();
  doc.circle(0, height, 96).lineWidth(1.2).strokeColor(PALETTE.rose300, 0.8).stroke();
  doc.circle(width, height - 120, 74).fill(PALETTE.creamDeep);
  doc.restore();
  doc.fillOpacity(1);

  // --- informasi tiket: kiri atas header, tanpa panel/latar
  drawTicketInfoLines(doc, {
    x: pad,
    y: geo.textTop,
    width: geo.textWidth,
    maxHeight: geo.textHeight,
    color: TICKET_TEXT_COLOR,
  }, data);

  return { qrRect: { x: geo.qrX, y: geo.qrY, size: geo.qrSize } };
};

/* ------------------------------------------------------------------------- *
 * Renderer PDF
 * ------------------------------------------------------------------------- */

/**
 * Gambar layout tiket default (dipakai saat Organizer tidak mengunggah desain
 * dan sebagai dasar template PDF). Mengikuti orientasi yang dipilih.
 *
 * @param {object} doc dokumen PDFKit
 * @param {{width: number, height: number}} page ukuran kanvas (pt)
 * @param {TicketLayoutOptions} [options]
 * @returns {{qrRect: {x: number, y: number, size: number}}} posisi QR yang
 *   harus ditimpa gambar QR asli oleh pemanggil.
 */
const drawDefaultLayout = (doc, page, { placeholder = false, orientation, ticket = {} } = {}) => {
  const normalized = orientationOrDefault(orientation);
  return normalized === 'portrait'
    ? drawPortraitTicket(doc, page, { placeholder, ticket })
    : drawLandscapeTicket(doc, page, { placeholder, ticket });
};

/**
 * Render template PDF (ukuran kanvas & penanda posisi QR) sesuai orientasi.
 *
 * Penanda QR berupa garis putus-putus tipis TANPA alas putih dan TANPA teks di
 * dalamnya, agar Organizer melihat area QR tanpa menambahkan panel/area putih
 * berlebih pada desain yang diunggah. QR final digambar backend beserta alas
 * putihnya sendiri (`drawQrBacking`).
 *
 * @param {{title?: string, orientation?: string}} [options]
 * @returns {Promise<Buffer>}
 */
const buildTemplatePdf = async ({ title = 'Template Desain Tiket', orientation } = {}) => {
  const normalized = orientationOrDefault(orientation);
  const { width, height } = ORIENTATION_SPEC[normalized];
  const doc = new PDFDocument({
    size: [width, height],
    margin: 0,
    info: { Title: `${title} (${normalized})`, Creator: 'E-Ticket Event Platform' },
  });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  const { qrRect } = drawDefaultLayout(doc, { width, height }, {
    placeholder: true, orientation: normalized,
  });
  doc.save();
  doc.dash(4, { space: 4 }).lineWidth(1).strokeColor(PALETTE.rose700)
    .rect(qrRect.x, qrRect.y, qrRect.size, qrRect.size).stroke();
  doc.undash();
  doc.restore();
  const sizeLabel = normalized === 'portrait' ? 'Portrait 440 x 704 pt' : 'Landscape 842 x 594 pt';
  doc.font(FONT.bold).fontSize(7.5).fillColor(PALETTE.rose900)
    .text(`${title} • ${sizeLabel}`, 0, height - 22, { width, align: 'center' });
  doc.end();
  return done;
};

/**
 * Batas tepi halaman untuk QR (pt) dan jarak minimum QR ke blok teks.
 * Dipakai `placeTicketInfoAndQr`.
 */
const QR_PAGE_MARGIN = 8;
const QR_INFO_GAP = 14;

/**
 * Desain yang BENAR-BENAR dipakai untuk merender tiket.
 *
 * Aturan produk: bila Organizer sudah mengunggah desain, desain itulah yang
 * wajib dipakai. Karena itu kandidat dicoba berurutan (desain kategori ->
 * desain event) dan yang dipakai adalah kandidat PERTAMA yang file-nya benar
 * benar ada. Referensi JSON yang menunjuk file hilang (mis. storage
 * dibersihkan) dilewati, sehingga tiket memakai desain event — bukan langsung
 * jatuh ke desain default sistem. Desain default hanya dipakai bila tidak ada
 * file desain sama sekali.
 *
 * @param {Array<object|null>} candidates desain ternormalisasi, berurutan prioritas
 * @returns {Promise<{design: object|null, buffer: Buffer|null,
 *   imageSize: {width: number, height: number}|null}>}
 */
const resolveDesignAsset = async (candidates) => {
  for (const candidate of candidates) {
    if (!candidate) continue;
    const absolutePath = designAbsolutePath(candidate);
    if (!absolutePath) continue;
    try {
      const buffer = await fsp.readFile(absolutePath);
      return { design: candidate, buffer, imageSize: readImageSize(buffer) };
    } catch (_error) {
      // File hilang/tidak terbaca: lanjut ke kandidat berikutnya.
    }
  }
  return { design: null, buffer: null, imageSize: null };
};

/**
 * Tempatkan QR dan blok informasi agar keduanya tidak bertumpuk.
 *
 * Urutan upaya (posisi/ukuran QR Organizer diutamakan):
 *  1. posisi QR & teks dari Organizer (bila tidak bertumpuk),
 *  2. QR digeser ke bawah blok teks,
 *  3. teks di tepi atas + QR di tepi bawah (QR besar, keduanya masih muat),
 *  4. teks di bawah QR,
 *  5. teks di atas QR.
 * Bila tidak ada susunan yang muat (QR sangat besar), teks ditempatkan pada ruang
 * bebas terbesar dan dikecilkan agar tetap di dalam halaman — UKURAN QR tidak
 * pernah diubah sehingga pengaturan Organizer tetap diterapkan.
 *
 * @param {{x: number, y: number, size: number}} qrRect kotak QR
 * @param {{infoBox: {x: number, y: number, width: number, height: number},
 *   infoHeight: number, width: number, height: number}} layout
 * @returns {{qrRect: {x: number, y: number, size: number}, infoY: number,
 *   infoMaxHeight: number}}
 */
const placeTicketInfoAndQr = (qrRect, { infoBox, infoHeight, width, height }) => {
  const top = QR_PAGE_MARGIN;
  const bottom = height - QR_PAGE_MARGIN;
  const overlaps = (rect, infoY) => rect.x < infoBox.x + infoBox.width
    && rect.x + rect.size > infoBox.x
    && rect.y < infoY + infoHeight + QR_INFO_GAP
    && rect.y + rect.size > infoY - QR_INFO_GAP;

  const candidates = [
    // 1. Posisi Organizer dipertahankan.
    { qrY: qrRect.y, infoY: infoBox.y },
    // 2. QR di bawah blok teks.
    { qrY: infoBox.y + infoHeight + QR_INFO_GAP, infoY: infoBox.y },
    // 3. Teks di tepi atas, QR di tepi bawah.
    { qrY: bottom - qrRect.size, infoY: top },
    // 4. Teks di bawah QR.
    { qrY: qrRect.y, infoY: qrRect.y + qrRect.size + QR_INFO_GAP },
    // 5. Teks di atas QR.
    { qrY: qrRect.y, infoY: qrRect.y - QR_INFO_GAP - infoHeight },
  ];
  for (const candidate of candidates) {
    if (candidate.qrY < top || candidate.qrY + qrRect.size > bottom) continue;
    if (candidate.infoY < top || candidate.infoY + infoHeight > bottom) continue;
    const qr = { ...qrRect, y: candidate.qrY };
    if (!overlaps(qr, candidate.infoY)) {
      return { qrRect: qr, infoY: candidate.infoY, infoMaxHeight: infoBox.height };
    }
  }

  // Fallback: ruang bebas terbesar di atas/bawah QR; teks menyesuaikan tinggi.
  const spaceAbove = qrRect.y - QR_INFO_GAP - top;
  const spaceBelow = bottom - (qrRect.y + qrRect.size + QR_INFO_GAP);
  const useAbove = spaceAbove >= spaceBelow;
  const available = Math.max(0, useAbove ? spaceAbove : spaceBelow);
  return {
    qrRect,
    infoY: useAbove ? top : qrRect.y + qrRect.size + QR_INFO_GAP,
    infoMaxHeight: Math.max(40, Math.min(infoBox.height, available)),
  };
};

/**
 * Render tiket final (PDF) memakai desain terpilih.
 *
 * Prioritas desain: kategori tiket -> desain default event -> layout default
 * sistem. Orientasi diambil dari desain yang menang, lalu dari default event,
 * lalu dari parameter `orientation`.
 *
 * Ukuran halaman SELALU kanvas tetap orientasi (landscape 842x594 pt). Desain
 * kustom digambar `contain` (tanpa potong/regang) sebagai background utama; di
 * atasnya hanya dicetak informasi minimal (kiri atas) dan QR Code di bawahnya.
 * Alas putih hanya selebar QR + quiet zone + margin kecil (`drawQrBacking`).
 *
 * @param {object} ticket baris tiket lengkap (lihat [loadTicketForPdf])
 * @returns {Promise<Buffer>}
 */
const buildTicketPdf = async (ticket) => {
  const typeDesign = normalizeDesign(ticket.ticket_type_design);
  const eventDesign = normalizeDesign(ticket.event_ticket_design);
  // Desain untuk ORIENTASI boleh berasal dari JSON walau file belum ada.
  const preferredDesign = typeDesign || eventDesign;
  // Urutan orientasi: kolom kategori tiket -> kolom event -> JSON desain ->
  // default sistem. Kolom dibaca lebih dulu karena orientasi tetap tersimpan
  // walau Organizer belum mengunggah file desain; nilai NULL berarti
  // "belum diatur" sehingga mewarisi level di atasnya.
  const orientation = orientationOrDefault(
    ticket.ticket_type_orientation
      || ticket.event_ticket_orientation
      || designOrientationOf(ticket.ticket_type_design)
      || designOrientationOf(ticket.event_ticket_design)
      || preferredDesign?.orientation
      || ticket.orientation,
  );
  // Desain untuk RENDER: file yang benar-benar ada (kategori -> event).
  const {
    design, buffer: designBuffer, imageSize,
  } = await resolveDesignAsset([typeDesign, eventDesign]);
  const { width, height } = pageSizeFor(imageSize, orientation);

  const data = ticketDisplayData(ticket, false);
  const doc = new PDFDocument({
    size: [width, height],
    margin: 0,
    info: {
      Title: `E-Tiket ${data.eventTitle} - ${data.attendeeName}`,
      Author: 'E-Ticket Event Platform',
      Subject: `E-Tiket ${data.eventTitle} (${data.ticketId})`,
      Keywords: `${data.ticketId}, e-ticket, ${data.eventTitle}`,
    },
  });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  let qrRect;
  let infoBox = null;
  if (designBuffer) {
    // Kanvas tetap; gambar desain diskalakan seragam di dalamnya.
    const frame = imageFrameFor(imageSize, { width, height });
    doc.rect(0, 0, width, height).fill(PALETTE.ivory);
    doc.image(designBuffer, frame.x, frame.y, { width: frame.width, height: frame.height });
    if (frame.x > 1 || frame.y > 1) {
      // Mat dekoratif: menandai batas desain tanpa memotong/meregangkan gambar.
      doc.rect(frame.x, frame.y, frame.width, frame.height)
        .lineWidth(1).strokeColor(PALETTE.rose300).stroke();
    }
    qrRect = qrRectFromFractions(design.qr, frame);
    infoBox = {
      x: frame.x + design.info.x * frame.width,
      y: frame.y + design.info.y * frame.height,
      width: Math.max(80, design.info.width * frame.width),
      height: Math.max(40, design.info.height * frame.height),
      color: design.info.color,
    };
    // Teks digambar lebih dulu supaya QR (digambar sesudahnya) tidak pernah
    // tertutup teks. Posisi keduanya ditentukan lebih dulu: bila QR besar
    // menabrak blok teks dan tidak dapat digeser, BLOK TEKS yang dipindah
    // sehingga ukuran/posisi QR Organizer tetap dipakai.
    const infoOptions = {
      x: infoBox.x,
      width: infoBox.width,
      color: infoBox.color,
      maxHeight: infoBox.height,
      // Hierarki sama dengan tiket default. Area sempit memakai ukuran judul
      // yang lebih kecil agar tetap muat tanpa terpotong banyak.
      titleSizes: infoBox.width < 240 ? [26, 24, 22, 20, 18] : TICKET_TYPE.titleSizes,
    };
    const { height: infoHeight } = resolveInfoLayout(doc, infoOptions, data);
    const placement = placeTicketInfoAndQr(qrRect, {
      infoBox, infoHeight, width, height,
    });
    qrRect = placement.qrRect;
    drawTicketInfoLines(doc, {
      ...infoOptions,
      y: placement.infoY,
      // Fallback QR sangat besar: teks menyesuaikan ruang bebas yang tersisa.
      maxHeight: Math.min(infoOptions.maxHeight, placement.infoMaxHeight),
    }, data);
  } else {
    qrRect = drawDefaultLayout(doc, { width, height }, { orientation, ticket }).qrRect;
  }

  const token = rawTokenFor(ticket);
  const qrBuffer = await QRCode.toBuffer(token, {
    type: 'png',
    // Quiet zone 2 modul; margin tipis tambahan diberikan oleh alas putih.
    margin: 2,
    width: Math.max(640, Math.round(qrRect.size * 4)),
    errorCorrectionLevel: 'M',
    // Modul terang WAJIB opaque: PNG bawaan `qrcode` transparan sehingga
    // background berwarna bisa menurunkan kontras/keterbacaan saat dipindai.
    color: { dark: '#000000', light: '#FFFFFF' },
  });
  drawQrBacking(doc, qrRect);
  doc.image(qrBuffer, qrRect.x, qrRect.y, { width: qrRect.size, height: qrRect.size });

  doc.end();
  return done;
};

/** Muat data tiket + desain yang berlaku untuk penerbitan. */
const loadTicketForPdf = (ticketId) => getOne(
  `SELECT t.id, t.ticket_code, t.status, t.event_id, t.ticket_type_id,
          t.purchased_at, t.issued_at, t.qr_code_data,
          a.name AS attendee_name, a.email AS attendee_email,
          tt.name AS ticket_type_name, tt.ticket_design AS ticket_type_design,
          tt.ticket_design_orientation AS ticket_type_orientation,
          e.title AS event_title, e.event_date, e.end_date_time,
          e.location, e.online_url, e.organizer_name,
          e.ticket_design AS event_ticket_design,
          e.ticket_design_orientation AS event_ticket_orientation,
          eo.order_number
     FROM tickets t
     JOIN events e ON e.id = t.event_id
     LEFT JOIN attendees a ON a.id = t.attendee_id
     LEFT JOIN order_items oi ON oi.id = a.order_item_id
     LEFT JOIN event_orders eo ON eo.id = oi.order_id
     LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
    WHERE t.id = $1`,
  [ticketId],
);

module.exports = {
  ALLOWED_CONTENT_TYPES,
  MAX_UPLOAD_BYTES,
  DEFAULT_QR,
  DEFAULT_INFO,
  ORIENTATIONS,
  DEFAULT_ORIENTATION,
  ORIENTATION_SPEC,
  DEFAULT_QR_BY_ORIENTATION,
  DEFAULT_INFO_BY_ORIENTATION,
  LANDSCAPE_CANVAS,
  PORTRAIT_CANVAS,
  TICKET_TEXT_COLOR,
  EXCHANGE_INSTRUCTION,
  TICKET_TYPE,
  QR_BACKING_PAD,
  QR_MIN_POINTS,
  QR_PLACEMENT_LIMITS,
  STORAGE_ROOT,
  DESIGN_URL_PREFIX,
  normalizeOrientation,
  orientationOrDefault,
  designOrientationOf,
  normalizeDesign,
  validateUploadPayload,
  validateQrPlacement,
  applyQrPlacement,
  saveDesignImage,
  removeDesignFile,
  designAbsolutePath,
  templatePathFor,
  buildTemplatePdf,
  buildTicketPdf,
  loadTicketForPdf,
  readImageSize,
  pageSizeFor,
  qrRectFromFractions,
  placeTicketInfoAndQr,
  resolveInfoLayout,
  infoBlockLines,
  ticketDisplayData,
  resolveDesignAsset,
};
