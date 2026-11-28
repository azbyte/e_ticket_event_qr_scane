/**
 * Desain e-ticket (PRD §5).
 *
 * Tanggung jawab:
 *  - memvalidasi & menyimpan gambar desain yang diunggah Organizer,
 *  - menyimpan konfigurasi tata letak (posisi/ukuran judul, ID tiket, instruksi,
 *    dan QR Code) yang dipakai bersama oleh editor, pratinjau, dan PDF,
 *  - menyediakan template PDF/PNG berukuran tetap dengan penanda posisi QR,
 *  - merender tiket final (PDF) memakai desain kategori/event atau desain
 *    default sistem, dengan QR unik pada posisi yang ditentukan.
 *
 * Prinsip desain: gambar yang diunggah Organizer adalah desain UTAMA tiket.
 * Sistem hanya menambahkan informasi dinamis yang sedikit (judul + ID tiket +
 * instruksi penukaran) di kiri atas dan QR Code tepat di bawahnya. Tidak ada
 * panel, kartu, atau latar tambahan di atas artwork, dan kotak putih hanya
 * dipakai sebagai alas QR Code.
 *
 * Seluruh geometri berasal dari `ticketDesignLayout` (satu sistem koordinat
 * fraksi kanvas + ukuran huruf pt) sehingga tata letak di editor, pratinjau,
 * template, dan PDF tidak dapat berbeda.
 */
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const { getOne } = require('../config/db');
const { rawTokenFor } = require('./ticketTokenService');
const layoutSpec = require('./ticketDesignLayout');
const ticketFonts = require('./ticketFontService');
const ticketPdf = require('./ticketPdfRenderer');


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
 * Kanvas tiket (satuan pt) — SAMA dengan ukuran halaman PDF sehingga satu
 * sistem koordinat dipakai editor, pratinjau, template, dan PDF:
 *  - `landscape`: 842 x 594 pt (A4 landscape; acuan desain referensi Canva),
 *  - `portrait` : 440 x 704 pt.
 *
 * Nilai berasal dari `ticketDesignLayout.CANVAS` agar tidak ada dua definisi
 * ukuran kanvas di aplikasi.
 */
const LANDSCAPE_CANVAS = Object.freeze({ ...layoutSpec.CANVAS.landscape });
const PORTRAIT_CANVAS = Object.freeze({ ...layoutSpec.CANVAS.portrait });

/** QR default per orientasi (fraksi kanvas), dari konfigurasi tata letak. */
const DEFAULT_QR_BY_ORIENTATION = Object.freeze({
  landscape: layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape.qr,
  portrait: layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.portrait.qr,
});

const DEFAULT_QR = DEFAULT_QR_BY_ORIENTATION.landscape;


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
/**
 * Content type efektif untuk desain tersimpan.
 *
 * Nilai dari klien hanya dipakai bila termasuk format yang didukung; selain itu
 * diturunkan dari ekstensi berkas agar metadata tidak kosong/aneh (mis.
 * `content_type: "constructor"`). Renderer tetap membaca isi berkas, bukan
 * metadata ini.
 */
const contentTypeFor = (raw, filePath) => {
  if (extensionFor(raw)) return raw;
  const extension = path.extname(String(filePath || '')).toLowerCase();
  if (extension === '.jpg' || extension === '.jpeg') return 'image/jpeg';
  return 'image/png';
};

const normalizeDesign = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const filePath = typeof raw.file_path === 'string' ? raw.file_path.trim() : '';
  const hasFile = filePath.startsWith(`${DESIGN_URL_PREFIX}/`);
  // Konfigurasi tata letak boleh disimpan TANPA berkas gambar (Organizer hanya
  // mengatur posisi/ukuran tulisan & QR pada desain default sistem).
  const hasLayoutConfig = raw.layout != null
    || raw.qr != null
    || raw.orientation != null
    || layoutSpec.TEXT_KEYS.some((key) => raw[key] != null);
  if (!hasFile && !hasLayoutConfig) return null;
  const orientation = orientationOrDefault(raw.orientation);
  const layout = layoutSpec.normalizeLayout(
    raw.layout && typeof raw.layout === 'object' ? raw.layout : raw,
    { orientation, legacyInfo: raw.info },
  );
  return {
    source: raw.source === 'upload' && hasFile ? 'upload' : 'template',
    template: typeof raw.template === 'string' ? raw.template : (hasFile ? 'custom' : 'default'),
    file_path: hasFile ? filePath : null,
    content_type: hasFile ? contentTypeFor(raw.content_type, filePath) : null,
    orientation,
    width: isFiniteNumber(raw.width) && raw.width > 0 ? Math.round(raw.width) : null,
    height: isFiniteNumber(raw.height) && raw.height > 0 ? Math.round(raw.height) : null,
    layout,
    // Cermin `layout.qr` dipertahankan agar kontrak lama (`design.qr`) tetap
    // berlaku untuk klien/desain yang sudah tersimpan.
    qr: { ...layout.qr },
    updated_at: typeof raw.updated_at === 'string' ? raw.updated_at : null,
  };
};


/**
 * Batas posisi & ukuran QR yang boleh diatur Organizer (fraksi kanvas).
 * Nilai default sistem selalu berada di dalam rentang ini.
 *
 * Ukuran dibatasi 15%-60% tinggi kanvas: di bawah 15% QR terlalu kecil untuk
 * dipindai (dan tetap dinaikkan ke `QR_MIN_POINTS`), sedangkan di atas 60% QR
 * menutupi hampir seluruh desain tiket.
 */
const QR_PLACEMENT_LIMITS = Object.freeze({
  position: Object.freeze({ min: 0, max: 0.95 }),
  size: Object.freeze({ min: layoutSpec.LIMITS.qrSize.min, max: layoutSpec.LIMITS.qrSize.max }),
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
 * Terapkan pengaturan tata letak baru pada desain yang sudah tersimpan tanpa
 * mengubah file desain maupun orientasinya.
 *
 * Bila belum ada desain sama sekali (Organizer baru mengatur tata letak pada
 * desain default sistem), konfigurasi tetap disimpan sebagai desain tanpa
 * berkas gambar — `normalizeDesign` mengizinkannya dan renderer memakai artwork
 * default.
 *
 * @param {object|null} previous desain ternormalisasi yang sudah ada
 * @param {{qr?: object, layout?: object, orientation?: string}} placement
 * @returns {object|null} desain siap disimpan (JSONB)
 */
const applyLayoutPlacement = (previous, { qr, layout, orientation } = {}) => {
  const merged = { ...(layout || previous?.layout || {}) };
  if (qr) merged.qr = qr;
  return normalizeDesign({
    ...(previous || {}),
    orientation: previous?.orientation || orientationOrDefault(orientation),
    layout: merged,
    updated_at: new Date().toISOString(),
  });
};

/** Kompatibilitas: pengaturan QR saja (dipakai jalur `qr_only`). */
const applyQrPlacement = (previous, placement) => applyLayoutPlacement(previous, placement);


/**
 * Validasi konfigurasi tata letak (judul, ID tiket, instruksi, QR) yang dikirim
 * editor: batas nilai, batas kanvas, dan TUMPANG TINDIH.
 *
 * Nilai di luar rentang ditolak (bukan diam-diam dipotong) agar hasil yang
 * dilihat Organizer di pratinjau sama dengan yang disimpan dan dicetak.
 *
 * @param {object} raw `{ panel_split, text_width, title, ticket_id, instruction, qr }`
 * @param {{orientation?: string, title?: string, ticketId?: string,
 *   instruction?: string}} [data] teks nyata untuk menghitung kotak
 * @returns {{errors: string[], value: object|null}}
 */
const validateLayoutPayload = (raw, data = {}) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { errors: ['Pengaturan tata letak tiket tidak valid.'], value: null };
  }
  const orientation = orientationOrDefault(data.orientation);
  const errors = [];
  const checkFraction = (value, min, max, label) => {
    const parsed = parseFraction(value, null);
    if (parsed != null && (parsed < min || parsed > max)) {
      errors.push(`${label} harus ${Math.round(min * 100)}%-${Math.round(max * 100)}%.`);
    }
  };
  checkFraction(raw.panel_split, layoutSpec.LIMITS.panelSplit.min,
    layoutSpec.LIMITS.panelSplit.max, 'Pembagian area desain');
  checkFraction(raw.text_width, layoutSpec.LIMITS.maxWidth.min,
    layoutSpec.LIMITS.maxWidth.max, 'Lebar area tulisan');
  for (const key of layoutSpec.TEXT_KEYS) {
    const element = raw[key];
    if (element == null) continue;
    if (typeof element !== 'object' || Array.isArray(element)) {
      errors.push(`Pengaturan ${layoutSpec.TEXT_LABELS[key]} tidak valid.`);
      continue;
    }
    const { position, fontSize } = layoutSpec.LIMITS;
    checkFraction(element.x, position.min, 0.95, `Posisi X ${layoutSpec.TEXT_LABELS[key]}`);
    checkFraction(element.y, position.min, 0.95, `Posisi Y ${layoutSpec.TEXT_LABELS[key]}`);
    const size = parseFraction(element.font_size, null);
    if (size != null && (size < fontSize.min || size > fontSize.max)) {
      errors.push(
        `Ukuran huruf ${layoutSpec.TEXT_LABELS[key]} harus `
        + `${fontSize.min}-${fontSize.max} pt.`,
      );
    }
  }
  if (raw.qr != null) {
    const { errors: qrErrors } = validateQrPlacement(raw.qr, { orientation });
    errors.push(...qrErrors);
  }

  const normalized = layoutSpec.normalizeLayout(raw, { orientation });
  const { errors: boxErrors } = layoutSpec.validateLayout(normalized, {
    orientation,
    title: data.title,
    ticketId: data.ticketId,
    instruction: data.instruction,
  });
  errors.push(...boxErrors);
  return { errors, value: errors.length > 0 ? null : normalized };
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

  // Tata letak: `body.layout` (bentuk bersarang) atau field datar pada `body`.
  const layoutSource = body.layout && typeof body.layout === 'object' ? body.layout : body;
  const { errors: layoutErrors, value: layout } = validateLayoutPayload(layoutSource, {
    orientation: orientation || DEFAULT_ORIENTATION,
    title: typeof body.title_text === 'string' ? body.title_text : undefined,
    ticketId: typeof body.ticket_id_text === 'string' ? body.ticket_id_text : undefined,
    instruction: typeof body.instruction_text === 'string' ? body.instruction_text : undefined,
  });
  errors.push(...layoutErrors);

  const imageSize = buffer ? readImageSize(buffer) : null;

  return {
    errors,
    value: errors.length > 0 ? null : {
      contentType,
      buffer,
      orientation: orientation || DEFAULT_ORIENTATION,
      width: imageSize?.width ?? null,
      height: imageSize?.height ?? null,
      layout,
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
const imageFrameFor = (imageSize, canvas) => ticketPdf.artworkFrame(imageSize, canvas);


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
 * Palet, tipografi, dan data tampilan tiket
 * ------------------------------------------------------------------------- */

/** Warna teks informasi: hitam netral agar kontras di atas artwork. */
const TICKET_TEXT_COLOR = ticketPdf.TEXT_COLOR;

/** Instruksi penukaran tiket (satu-satunya teks instruksi di tiket). */
const EXCHANGE_INSTRUCTION = layoutSpec.EXCHANGE_INSTRUCTION;

/**
 * Format tanggal + waktu event untuk data tiket.
 *
 * Memakai zona waktu penyelenggaraan (WIB) seperti email tiket. Tanggal tidak
 * valid menghasilkan string kosong, bukan "Invalid Date".
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
 * Desain referensi hanya mencetak tiga teks dinamis: judul
 * (`E-TIKET [NAMA ACARA]`), `ID TIKET: [ID]`, dan instruksi penukaran. Nilai
 * lain (nama peserta, kategori, jadwal, lokasi) tetap tersedia di objek ini
 * untuk konsumen lain, tetapi TIDAK dicetak pada tiket agar tata letak sesuai
 * referensi dan tidak ada teks tambahan yang menutupi desain.
 *
 * `placeholder` dipakai template desain: tidak memuat data peserta sungguhan.
 */
const ticketDisplayData = (ticket = {}, placeholder = false) => {
  if (placeholder) {
    return {
      eventTitle: 'Konser',
      ticketId: 'ETK-6NGS2R',
      attendeeName: 'Nama Peserta',
      ticketTypeName: 'Kategori Tiket',
      scheduleText: 'Selasa, 1 Desember 2026 19.00',
      locationText: 'Jakarta Convention Center',
      title: layoutSpec.ticketTitle('Konser'),
      instruction: EXCHANGE_INSTRUCTION,
    };
  }
  const eventTitle = String(ticket.event_title ?? '').trim();
  const location = String(ticket.location ?? '').trim();
  const onlineUrl = String(ticket.online_url ?? '').trim();
  const ticketId = String(ticket.ticket_code ?? '').trim() || '-';
  return {
    eventTitle: eventTitle || 'Nama event tidak tersedia',
    ticketId,
    attendeeName: String(ticket.attendee_name ?? '').trim() || 'Nama peserta tidak tersedia',
    ticketTypeName: String(ticket.ticket_type_name ?? '').trim(),
    scheduleText: formatTicketSchedule(ticket),
    // Event daring tanpa lokasi tetap menampilkan kanal aksesnya.
    locationText: location || (onlineUrl ? 'Online' : ''),
    title: layoutSpec.ticketTitle(eventTitle || 'Nama event tidak tersedia'),
    instruction: EXCHANGE_INSTRUCTION,
  };
};

/** Teks tiap elemen tata letak untuk data tiket tertentu. */
const layoutTexts = (data = {}) => ({
  title: data.title ?? layoutSpec.ticketTitle(data.eventTitle),
  ticketId: layoutSpec.ticketIdLine(data.ticketId),
  instruction: data.instruction ?? EXCHANGE_INSTRUCTION,
});

/**
 * Tentukan konfigurasi tata letak + kotak elemen yang dipakai satu tiket.
 *
 * @param {object|null} design desain ternormalisasi (boleh tanpa berkas gambar)
 * @param {{orientation?: string, data?: object}} options
 * @returns {{layout: object, resolved: object, texts: object}}
 */
const resolveTicketLayout = (design, { orientation, data } = {}) => {
  const normalized = orientationOrDefault(orientation);
  const layout = design && design.layout
    ? layoutSpec.normalizeLayout(design.layout, { orientation: normalized })
    : layoutSpec.defaultLayoutFor(normalized);
  const texts = layoutTexts(data);
  const resolved = layoutSpec.resolveLayout(layout, {
    orientation: normalized,
    title: texts.title,
    ticketId: texts.ticketId,
    instruction: texts.instruction,
  });
  return { layout, resolved, texts };
};

/* ------------------------------------------------------------------------- *
 * Renderer PDF
 * ------------------------------------------------------------------------- */

/**
 * PNG QR Code untuk satu tiket.
 *
 * Modul terang dibuat OPAQUE (bukan transparan) agar kontras tetap tinggi di
 * atas alas putih. `margin: 2` memberi quiet zone 2 modul di dalam PNG;
 * renderer menambah inset lagi sehingga quiet zone total ±4 modul.
 *
 * @param {number} sizePt sisi kotak QR pada kanvas (pt)
 * @param {string} token token QR unik tiket
 * @returns {Promise<Buffer>}
 */
const qrPngBuffer = (sizePt, token) => QRCode.toBuffer(token, {
  type: 'png',
  margin: 2,
  width: Math.max(640, Math.round(sizePt * 4)),
  errorCorrectionLevel: 'M',
  color: { dark: '#000000', light: '#FFFFFF' },
});

/**
 * Template desain tiket (kanvas + penanda area elemen).
 *
 * Penanda berupa kotak putus-putus TANPA teks contoh, sehingga desain yang
 * diunggah Organizer (hasil mendesain di atas template) tidak memuat teks
 * ganda saat tiket final dirender.
 *
 * @param {{title?: string, orientation?: string, layout?: object}} [options]
 * @returns {Promise<Buffer>}
 */
const buildTemplatePdf = async ({
  title = 'Template Desain Tiket', orientation, layout: layoutOverride,
} = {}) => {
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
  const data = ticketDisplayData({}, true);
  const design = layoutOverride
    ? normalizeDesign({ layout: layoutOverride, orientation: normalized })
    : null;
  const { layout, resolved } = resolveTicketLayout(design, { orientation: normalized, data });
  ticketPdf.drawTicket(doc, {
    canvas: { width, height }, layout, resolved, qrMarker: true, textMarkers: true,
  });
  doc.end();
  return done;
};

/**
 * Desain yang BENAR-BENAR dipakai untuk merender tiket.
 *
 * Aturan produk: bila Organizer sudah mengunggah desain, desain itulah yang
 * wajib dipakai. Karena itu kandidat dicoba berurutan (desain kategori ->
 * desain event) dan yang dipakai adalah kandidat PERTAMA yang file-nya benar
 * benar ada. Referensi JSON yang menunjuk file hilang (mis. storage
 * dibersihkan) dilewati, sehingga tiket memakai desain event — bukan langsung
 * jatuh ke desain default sistem. Konfigurasi tata letak tetap diambil dari
 * kandidat berprioritas tertinggi (lihat `resolveTicketLayout`).
 *
 * @param {Array<object|null>} candidates desain ternormalisasi, berurutan prioritas
 * @returns {Promise<{design: object|null, buffer: Buffer|null,
 *   imageSize: {width: number, height: number}|null}>}
 */
const resolveDesignAsset = async (candidates) => {
  for (const candidate of candidates) {
    if (!candidate || !candidate.file_path) continue;
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
 * Render tiket final (PDF) memakai desain terpilih.
 *
 * Prioritas desain: kategori tiket -> desain event -> desain default sistem.
 * Orientasi diambil dari desain yang menang, lalu dari kolom orientasi, lalu
 * dari parameter `orientation`.
 *
 * Ukuran halaman SELALU kanvas tetap orientasi (landscape 842x594 pt). Desain
 * kustom digambar `contain` (tanpa potong/regang) sebagai background utama; di
 * atasnya dicetak judul, ID tiket, instruksi, dan QR Code sesuai konfigurasi
 * tata letak yang tersimpan (sumber yang sama dengan editor & pratinjau).
 *
 * @param {object} ticket baris tiket lengkap (lihat [loadTicketForPdf])
 * @returns {Promise<Buffer>}
 */
const buildTicketPdf = async (ticket) => {
  const typeDesign = normalizeDesign(ticket.ticket_type_design);
  const eventDesign = normalizeDesign(ticket.event_ticket_design);
  // Tata letak: kategori -> event -> default sistem (walau berkas gambar hilang).
  const preferredDesign = typeDesign || eventDesign;
  // Urutan orientasi: kolom kategori tiket -> kolom event -> JSON desain ->
  // default sistem. Kolom dibaca lebih dulu karena orientasi tetap tersimpan
  // walau Organizer belum mengunggah file desain.
  const orientation = orientationOrDefault(
    ticket.ticket_type_orientation
      || ticket.event_ticket_orientation
      || designOrientationOf(ticket.ticket_type_design)
      || designOrientationOf(ticket.event_ticket_design)
      || preferredDesign?.orientation
      || ticket.orientation,
  );
  // Artwork: file yang benar-benar ada (kategori -> event).
  const { buffer: designBuffer, imageSize } = await resolveDesignAsset([typeDesign, eventDesign]);
  const { width, height } = pageSizeFor(imageSize, orientation);

  const data = ticketDisplayData(ticket, false);
  const { layout, resolved } = resolveTicketLayout(preferredDesign, { orientation, data });
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

  const qrBuffer = await qrPngBuffer(resolved.qr.size, rawTokenFor(ticket));
  ticketPdf.drawTicket(doc, {
    canvas: { width, height },
    layout,
    resolved,
    artwork: designBuffer,
    artworkSize: imageSize,
    qrBuffer,
  });

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
  ORIENTATIONS,
  DEFAULT_ORIENTATION,
  ORIENTATION_SPEC,
  DEFAULT_QR_BY_ORIENTATION,
  LANDSCAPE_CANVAS,
  PORTRAIT_CANVAS,
  TICKET_TEXT_COLOR,
  EXCHANGE_INSTRUCTION,
  QR_MIN_POINTS,
  QR_PLACEMENT_LIMITS,
  STORAGE_ROOT,
  DESIGN_URL_PREFIX,
  // Modul tata letak & font (satu sumber kebenaran desain tiket).
  layoutSpec,
  ticketFonts,
  ticketPdf,
  LAYOUT_VERSION: layoutSpec.LAYOUT_VERSION,
  TEXT_KEYS: layoutSpec.TEXT_KEYS,
  DEFAULT_LAYOUT_BY_ORIENTATION: layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION,
  normalizeOrientation,
  orientationOrDefault,
  designOrientationOf,
  normalizeDesign,
  validateUploadPayload,
  validateQrPlacement,
  validateLayoutPayload,
  applyQrPlacement,
  applyLayoutPlacement,
  saveDesignImage,
  removeDesignFile,
  designAbsolutePath,
  templatePathFor,
  buildTemplatePdf,
  buildTicketPdf,
  loadTicketForPdf,
  readImageSize,
  pageSizeFor,
  imageFrameFor,
  qrRectFromFractions,
  ticketDisplayData,
  layoutTexts,
  resolveTicketLayout,
  resolveDesignAsset,
};
