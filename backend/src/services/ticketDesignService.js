/**
 * Desain e-ticket (PRD §5).
 *
 * Tanggung jawab:
 *  - memvalidasi & menyimpan gambar desain yang diunggah Organizer,
 *  - menyediakan template PDF/PNG berukuran tetap dengan penanda posisi QR,
 *  - merender tiket final (PDF) memakai desain kategori/event atau desain
 *    default sistem, dengan QR unik pada posisi yang ditentukan.
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

const DEFAULT_QR = Object.freeze({ x: 0.74, y: 0.25, size: 0.5 });
const DEFAULT_INFO = Object.freeze({
  x: 0.34,
  y: 0.2,
  width: 0.36,
  height: 0.66,
  color: '#111111',
});

/**
 * Orientasi desain tiket.
 *
 * - `landscape`: kanvas horizontal (rasio 2.5:1).
 * - `portrait` : kanvas vertikal (rasio 1:1.6).
 *
 * Orientasi menentukan ukuran halaman PDF, rasio template, dan area penempatan
 * QR bawaan. Desain kustom yang diunggah WAJIB mengikuti rasio orientasi yang
 * dipilih agar tidak dipotong/diregangkan saat dirender.
 */
const ORIENTATIONS = Object.freeze(['landscape', 'portrait']);
const DEFAULT_ORIENTATION = 'landscape';

/** Rasio kanvas (lebar:tinggi) per orientasi + batas toleransi validasi. */
const ORIENTATION_SPEC = Object.freeze({
  landscape: Object.freeze({ width: 720, height: 288, ratio: 720 / 288, minRatio: 1.8 }),
  portrait: Object.freeze({ width: 440, height: 704, ratio: 440 / 704, maxRatio: 0.95 }),
});

/** QR default per orientasi: di kanan bawah area informasi. */
const DEFAULT_QR_BY_ORIENTATION = Object.freeze({
  landscape: DEFAULT_QR,
  portrait: Object.freeze({ x: 0.32, y: 0.66, size: 0.28 }),
});

const DEFAULT_INFO_BY_ORIENTATION = Object.freeze({
  landscape: DEFAULT_INFO,
  portrait: Object.freeze({
    x: 0.08, y: 0.16, width: 0.84, height: 0.42, color: '#111111',
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
    content_type: ALLOWED_CONTENT_TYPES[raw.content_type]
      ? raw.content_type
      : 'image/png',
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
  const defaultQr = DEFAULT_QR_BY_ORIENTATION[orientation || DEFAULT_ORIENTATION];
  const defaultInfo = DEFAULT_INFO_BY_ORIENTATION[orientation || DEFAULT_ORIENTATION];

  const contentType = String(body.content_type || '').toLowerCase().trim();
  if (!ALLOWED_CONTENT_TYPES[contentType]) {
    errors.push('Format desain harus PNG atau JPEG.');
  }

  const base64 = typeof body.image_base64 === 'string'
    ? body.image_base64.replace(/^data:[^;]+;base64,/, '')
    : '';
  let buffer = null;
  if (!base64) {
    errors.push('File desain tiket wajib diunggah.');
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
    // Validasi orientasi: rasio gambar harus sesuai kanvas orientasi yang
    // dipilih supaya hasil PDF tidak dipotong/diregangkan.
    const size = readImageSize(buffer);
    if (!size || !(size.width > 0) || !(size.height > 0)) {
      errors.push('Dimensi file desain tiket tidak dapat dibaca.');
    } else {
      const ratio = size.width / size.height;
      const fits = orientation === 'portrait'
        ? ratio <= spec.maxRatio
        : ratio >= spec.minRatio;
      if (!fits) {
        errors.push(
          orientation === 'portrait'
            ? 'Desain tidak sesuai orientasi portrait. Unggah gambar vertikal '
              + '(rasio tinggi:lebar 1.6:1, mis. 440x704 px).'
            : 'Desain tidak sesuai orientasi landscape. Unggah gambar horizontal '
              + '(rasio lebar:tinggi 2.5:1, mis. 1080x432 px).'
        );
      }
    }
  }

  const qrRaw = body.qr && typeof body.qr === 'object' ? body.qr : {};
  const qr = {
    x: parseFraction(qrRaw.x, defaultQr.x),
    y: parseFraction(qrRaw.y, defaultQr.y),
    size: parseFraction(qrRaw.size, defaultQr.size),
  };
  if (qr.x < 0 || qr.x > 0.95) errors.push('Posisi X QR harus 0-95%.');
  if (qr.y < 0 || qr.y > 0.95) errors.push('Posisi Y QR harus 0-95%.');
  if (qr.size < 0.15 || qr.size > 0.9) {
    errors.push('Ukuran QR harus 15-90% dari tinggi tiket.');
  }

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
  if (contentType === 'image/png') {
    return buffer[0] === 0x89 && buffer[1] === 0x50 &&
      buffer[2] === 0x4e && buffer[3] === 0x47;
  }
  if (contentType === 'image/jpeg') {
    return buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  }
  return false;
};

/**
 * Simpan gambar desain ke penyimpanan server.
 * @returns {Promise<{ filePath: string, absolutePath: string }>}
 */
const saveDesignImage = async ({ eventId, buffer, contentType }) => {
  const extension = ALLOWED_CONTENT_TYPES[contentType];
  const directory = path.join(DESIGN_DIR, String(eventId));
  await fsp.mkdir(directory, { recursive: true });
  const filename = `${Date.now()}-${randomUUID()}${extension}`;
  const absolutePath = path.join(directory, filename);
  await fsp.writeFile(absolutePath, buffer);
  return {
    filePath: `${DESIGN_URL_PREFIX}/${eventId}/${filename}`,
    absolutePath,
  };
};

/** Path absolut file desain dari `file_path` tersimpan. */
const designAbsolutePath = (design) => {
  if (!design || typeof design.file_path !== 'string') return null;
  if (!design.file_path.startsWith(`${DESIGN_URL_PREFIX}/`)) return null;
  const relative = design.file_path.slice(DESIGN_URL_PREFIX.length + 1);
  const absolutePath = path.join(DESIGN_DIR, relative);
  return absolutePath.startsWith(DESIGN_DIR) ? absolutePath : null;
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
    const candidate = path.join(
      TEMPLATE_DIR,
      `ticket-template-${orientationOrDefault(orientation)}.png`,
    );
    if (fs.existsSync(candidate)) return candidate;
    // Fallback template lama (landscape) agar tautan lama tetap berfungsi.
    return fs.existsSync(TEMPLATE_PNG) ? TEMPLATE_PNG : null;
  }
  return null; // PDF dirender dinamis agar konsisten dengan layout QR default.
};

/**
 * Ukuran kanvas PDF tiket.
 *
 * Bila ada gambar desain, halaman mengikuti rasio gambar apa adanya (tanpa
 * crop / regangan). Bila tidak ada desain, dipakai ukuran kanvas orientasi.
 */
const pageSizeFor = (imageSize, orientation) => {
  const spec = ORIENTATION_SPEC[orientationOrDefault(orientation)];
  const hasImage = imageSize && imageSize.width > 0 && imageSize.height > 0;
  if (!hasImage) return { width: spec.width, height: spec.height };
  // Skala seragam: lebar tetap, tinggi mengikuti rasio asli gambar.
  const width = spec.width;
  const height = Math.round(width * (imageSize.height / imageSize.width));
  return { width, height };
};

/** Baca dimensi PNG/JPEG tanpa dependency gambar tambahan. */
const readImageSize = (buffer) => {
  if (!buffer || buffer.length < 26) return null;
  // PNG: lebar/tinggi pada IHDR (byte 16..23).
  if (buffer[0] === 0x89 && buffer[1] === 0x50) {
    return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  }
  // JPEG: cari marker SOF0/SOF2.
  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    let offset = 2;
    while (offset + 9 < buffer.length) {
      if (buffer[offset] !== 0xff) {
        offset += 1;
        continue;
      }
      const marker = buffer[offset + 1];
      const length = buffer.readUInt16BE(offset + 2);
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 &&
          marker !== 0xc8 && marker !== 0xcc) {
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

const formatDate = (value) => {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'long',
    timeStyle: 'short',
    timeZone: 'Asia/Jakarta',
  }).format(date);
};

/**
 * Gambar layout tiket default (dipakai saat Organizer tidak mengunggah desain
 * dan sebagai dasar template PDF). Mengikuti orientasi yang dipilih.
 */
const drawDefaultLayout = (doc, { width, height }, { placeholder = false, orientation } = {}) => {
  const normalized = orientationOrDefault(orientation);
  const defaultInfo = DEFAULT_INFO_BY_ORIENTATION[normalized];
  const defaultQr = DEFAULT_QR_BY_ORIENTATION[normalized];

  doc.rect(0, 0, width, height).fill('#ffffff');
  if (normalized === 'portrait') {
    // Header penuh di atas, area informasi di tengah, QR di bawah.
    doc.rect(0, 0, width, height * 0.11).fill('#1e3a8a');
    doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(18)
      .text('E-TICKET', width * 0.08, height * 0.035, { width: width * 0.6 });
    doc.fillColor('#c7d2fe').font('Helvetica').fontSize(8)
      .text('E-Ticket Event Platform', width * 0.08, height * 0.075, {
        width: width * 0.6,
      });
  } else {
    doc.rect(0, 0, width * 0.3, height).fill('#1e3a8a');
    doc.rect(width * 0.3, 0, width * 0.7, height * 0.12).fill('#eef2ff');
    doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(16)
      .text('E-TICKET', width * 0.04, height * 0.12, { width: width * 0.22 });
    doc.fillColor('#c7d2fe').font('Helvetica').fontSize(9)
      .text('E-Ticket Event Platform', width * 0.04, height * 0.22, {
        width: width * 0.22,
      });
  }

  const infoX = width * defaultInfo.x;
  const infoY = height * defaultInfo.y;
  const infoWidth = width * defaultInfo.width;
  doc.fillColor('#111111').font('Helvetica-Bold').fontSize(15)
    .text('Nama Event', infoX, infoY, { width: infoWidth, ellipsis: true });
  doc.fillColor('#374151').font('Helvetica').fontSize(10)
    .text('Nama Peserta', infoX, infoY + 24, { width: infoWidth })
    .text('Kategori Tiket', infoX, infoY + 42, { width: infoWidth })
    .text('Tanggal & lokasi event', infoX, infoY + 58, { width: infoWidth })
    .text('Kode tiket', infoX, infoY + 76, { width: infoWidth });

  const qrSize = Math.min(
    defaultQr.size * height,
    (1 - defaultQr.x) * width,
    (1 - defaultQr.y) * height,
  );
  const qrX = defaultQr.x * width;
  const qrY = defaultQr.y * height;
  doc.rect(qrX, qrY, qrSize, qrSize).lineWidth(1).strokeColor('#9ca3af').stroke();
  if (placeholder) {
    doc.fillColor('#6b7280').font('Helvetica').fontSize(8)
      .text('AREA QR', qrX, qrY + qrSize / 2 - 4, {
        width: qrSize,
        align: 'center',
      });
  }
};

/** Render template PDF (ukuran & penanda posisi QR) sesuai orientasi. */
const buildTemplatePdf = async ({ title = 'Template Desain Tiket', orientation } = {}) => {
  const normalized = orientationOrDefault(orientation);
  const { width, height } = ORIENTATION_SPEC[normalized];
  const doc = new PDFDocument({ size: [width, height], margin: 0 });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  drawDefaultLayout(doc, { width, height }, { placeholder: true, orientation: normalized });
  const label = `${title} (${normalized === 'portrait' ? 'Portrait' : 'Landscape'})`;
  doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8)
    .text(label, width * 0.05, height * 0.9, {
      width: width * 0.9,
      align: 'left',
    });
  doc.end();
  return done;
};

/**
 * Render tiket final (PDF) memakai desain terpilih.
 *
 * Prioritas desain: kategori tiket -> desain default event -> layout default
 * sistem. Orientasi diambil dari desain yang menang, lalu dari default event,
 * lalu dari parameter `orientation`. QR selalu ditanam pada posisi yang
 * ditentukan desain tersebut, dan gambar desain digambar dengan skala seragam
 * sehingga proporsinya tidak berubah.
 *
 * @param {object} ticket baris tiket lengkap (lihat [loadTicketForPdf])
 * @returns {Promise<Buffer>}
 */
const buildTicketPdf = async (ticket) => {
  const typeDesign = normalizeDesign(ticket.ticket_type_design);
  const eventDesign = normalizeDesign(ticket.event_ticket_design);
  const design = typeDesign || eventDesign;
  // Urutan orientasi: kolom kategori tiket -> kolom event -> JSON desain ->
  // default sistem. Kolom dibaca lebih dulu karena orientasi tetap tersimpan
  // walau Organizer belum mengunggah file desain; nilai NULL berarti
  // "belum diatur" sehingga mewarisi level di atasnya.
  const orientation = orientationOrDefault(
    ticket.ticket_type_orientation
      || ticket.event_ticket_orientation
      || designOrientationOf(ticket.ticket_type_design)
      || designOrientationOf(ticket.event_ticket_design)
      || design?.orientation
      || ticket.orientation,
  );
  const absoluteDesignPath = design ? designAbsolutePath(design) : null;
  const hasDesignFile = Boolean(
    absoluteDesignPath && fs.existsSync(absoluteDesignPath),
  );
  const designBuffer = hasDesignFile ? await fsp.readFile(absoluteDesignPath) : null;
  const imageSize = designBuffer ? readImageSize(designBuffer) : null;
  const { width, height } = pageSizeFor(imageSize, orientation);

  const doc = new PDFDocument({ size: [width, height], margin: 0 });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  if (designBuffer) {
    // Skala seragam: gambar mengisi kanvas tanpa distorsi (rasio halaman =
    // rasio gambar).
    doc.image(designBuffer, 0, 0, { width, height });
  } else {
    drawDefaultLayout(doc, { width, height }, { orientation });
  }

  const qr = design ? design.qr : DEFAULT_QR_BY_ORIENTATION[orientation];
  const info = design ? design.info : DEFAULT_INFO_BY_ORIENTATION[orientation];
  const qrSize = Math.min(
    qr.size * height,
    (1 - qr.x) * width,
    (1 - qr.y) * height,
  );
  const qrX = qr.x * width;
  const qrY = qr.y * height;

  const token = rawTokenFor(ticket);
  const qrBuffer = await QRCode.toBuffer(token, {
    type: 'png',
    margin: 1,
    width: Math.max(256, Math.round(qrSize * 4)),
    errorCorrectionLevel: 'M',
  });
  if (!designBuffer) {
    doc.rect(qrX - 4, qrY - 4, qrSize + 8, qrSize + 8).fill('#ffffff');
  }
  doc.image(qrBuffer, qrX, qrY, { width: qrSize, height: qrSize });

  const infoX = info.x * width;
  const infoY = info.y * height;
  const infoWidth = Math.max(80, info.width * width);
  // Nama event WAJIB teks asli dari database; tidak pernah diganti "Event"
  // atau placeholder lain kecuali datanya benar-benar kosong.
  const eventTitle = String(ticket.event_title ?? '').trim();
  const attendeeName = String(ticket.attendee_name ?? '').trim();
  const ticketTypeName = String(ticket.ticket_type_name ?? '').trim();
  doc.fillColor(info.color).font('Helvetica-Bold').fontSize(14)
    .text(eventTitle || 'Nama event tidak tersedia', infoX, infoY, {
      width: infoWidth,
      height: 34,
      ellipsis: true,
    });
  doc.font('Helvetica').fontSize(10)
    .text(attendeeName || 'Nama peserta tidak tersedia', infoX, infoY + 36, {
      width: infoWidth,
      ellipsis: true,
    })
    .text(ticketTypeName || 'Kategori tidak tersedia', infoX, infoY + 52, {
      width: infoWidth,
      ellipsis: true,
    })
    .text(
      `${formatDate(ticket.event_date)} - ${ticket.location || ticket.online_url || 'Online'}`,
      infoX,
      infoY + 68,
      { width: infoWidth, ellipsis: true },
    )
    .text(`Kode tiket: ${ticket.ticket_code || '-'}`, infoX, infoY + 84, {
      width: infoWidth,
      ellipsis: true,
    });
  if (ticket.order_number) {
    doc.text(`No. registrasi: ${ticket.order_number}`, infoX, infoY + 100, {
      width: infoWidth,
      ellipsis: true,
    });
  }

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
  STORAGE_ROOT,
  DESIGN_URL_PREFIX,
  normalizeOrientation,
  orientationOrDefault,
  designOrientationOf,
  normalizeDesign,
  validateUploadPayload,
  saveDesignImage,
  removeDesignFile,
  designAbsolutePath,
  templatePathFor,
  buildTemplatePdf,
  buildTicketPdf,
  loadTicketForPdf,
  readImageSize,
  pageSizeFor,
};
