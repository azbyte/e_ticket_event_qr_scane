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
  const qrRaw = raw.qr && typeof raw.qr === 'object' ? raw.qr : {};
  const infoRaw = raw.info && typeof raw.info === 'object' ? raw.info : {};
  return {
    source: raw.source === 'upload' ? 'upload' : 'template',
    template: typeof raw.template === 'string' ? raw.template : 'classic',
    file_path: filePath,
    content_type: ALLOWED_CONTENT_TYPES[raw.content_type]
      ? raw.content_type
      : 'image/png',
    qr: {
      x: clamp(parseFraction(qrRaw.x, DEFAULT_QR.x), 0, 0.95),
      y: clamp(parseFraction(qrRaw.y, DEFAULT_QR.y), 0, 0.95),
      size: clamp(parseFraction(qrRaw.size, DEFAULT_QR.size), 0.15, 0.9),
    },
    info: {
      x: clamp(parseFraction(infoRaw.x, DEFAULT_INFO.x), 0, 0.95),
      y: clamp(parseFraction(infoRaw.y, DEFAULT_INFO.y), 0, 0.95),
      width: clamp(parseFraction(infoRaw.width, DEFAULT_INFO.width), 0.1, 0.95),
      height: clamp(parseFraction(infoRaw.height, DEFAULT_INFO.height), 0.1, 0.95),
      color:
        typeof infoRaw.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(infoRaw.color)
          ? infoRaw.color
          : DEFAULT_INFO.color,
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
  }

  const qrRaw = body.qr && typeof body.qr === 'object' ? body.qr : {};
  const qr = {
    x: parseFraction(qrRaw.x, DEFAULT_QR.x),
    y: parseFraction(qrRaw.y, DEFAULT_QR.y),
    size: parseFraction(qrRaw.size, DEFAULT_QR.size),
  };
  if (qr.x < 0 || qr.x > 0.95) errors.push('Posisi X QR harus 0-95%.');
  if (qr.y < 0 || qr.y > 0.95) errors.push('Posisi Y QR harus 0-95%.');
  if (qr.size < 0.15 || qr.size > 0.9) {
    errors.push('Ukuran QR harus 15-90% dari tinggi tiket.');
  }

  const infoRaw = body.info && typeof body.info === 'object' ? body.info : {};
  const info = {
    x: clamp(parseFraction(infoRaw.x, DEFAULT_INFO.x), 0, 0.95),
    y: clamp(parseFraction(infoRaw.y, DEFAULT_INFO.y), 0, 0.95),
    width: clamp(parseFraction(infoRaw.width, DEFAULT_INFO.width), 0.1, 0.95),
    height: clamp(parseFraction(infoRaw.height, DEFAULT_INFO.height), 0.1, 0.95),
    color:
      typeof infoRaw.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(infoRaw.color)
        ? infoRaw.color
        : DEFAULT_INFO.color,
  };

  return {
    errors,
    value: errors.length > 0 ? null : { contentType, buffer, qr, info },
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

/** Path template PNG bawaan sistem (null bila belum digenerate). */
const templatePathFor = (format) => {
  const normalized = String(format || '').toLowerCase();
  if (normalized === 'png') {
    return fs.existsSync(TEMPLATE_PNG) ? TEMPLATE_PNG : null;
  }
  return null; // PDF dirender dinamis agar konsisten dengan layout QR default.
};

/** Ukuran kanvas PDF berdasarkan rasio gambar desain. */
const pageSizeFor = (imageSize) => {
  const width = 720;
  const ratio = imageSize && imageSize.width > 0 && imageSize.height > 0
    ? imageSize.height / imageSize.width
    : 0.4;
  const height = clamp(width * ratio, 200, 520);
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
 * dan sebagai dasar template PDF).
 */
const drawDefaultLayout = (doc, { width, height }, { placeholder = false } = {}) => {
  doc.rect(0, 0, width, height).fill('#ffffff');
  doc.rect(0, 0, width * 0.3, height).fill('#1e3a8a');
  doc.rect(width * 0.3, 0, width * 0.7, height * 0.12).fill('#eef2ff');

  doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(16)
    .text('E-TICKET', width * 0.04, height * 0.12, { width: width * 0.22 });
  doc.fillColor('#c7d2fe').font('Helvetica').fontSize(9)
    .text('E-Ticket Event Platform', width * 0.04, height * 0.22, {
      width: width * 0.22,
    });

  const infoX = width * DEFAULT_INFO.x;
  const infoY = height * DEFAULT_INFO.y;
  const infoWidth = width * DEFAULT_INFO.width;
  doc.fillColor('#111111').font('Helvetica-Bold').fontSize(15)
    .text('Nama Event', infoX, infoY, { width: infoWidth, ellipsis: true });
  doc.fillColor('#374151').font('Helvetica').fontSize(10)
    .text('Nama Peserta', infoX, infoY + 24, { width: infoWidth })
    .text('Kategori Tiket', infoX, infoY + 42, { width: infoWidth })
    .text('Tanggal & lokasi event', infoX, infoY + 58, { width: infoWidth })
    .text('Kode tiket', infoX, infoY + 76, { width: infoWidth });

  const qrSize = Math.min(
    DEFAULT_QR.size * height,
    (1 - DEFAULT_QR.x) * width,
    (1 - DEFAULT_QR.y) * height,
  );
  const qrX = DEFAULT_QR.x * width;
  const qrY = DEFAULT_QR.y * height;
  doc.rect(qrX, qrY, qrSize, qrSize).lineWidth(1).strokeColor('#9ca3af').stroke();
  if (placeholder) {
    doc.fillColor('#6b7280').font('Helvetica').fontSize(8)
      .text('AREA QR', qrX, qrY + qrSize / 2 - 4, {
        width: qrSize,
        align: 'center',
      });
  }
};

/** Render template PDF (ukuran & penanda posisi QR). */
const buildTemplatePdf = async ({ title = 'Template Desain Tiket' } = {}) => {
  const width = 720;
  const height = 288;
  const doc = new PDFDocument({ size: [width, height], margin: 0 });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  drawDefaultLayout(doc, { width, height }, { placeholder: true });
  doc.fillColor('#1e3a8a').font('Helvetica-Bold').fontSize(8)
    .text(String(title || ''), width * 0.05, height * 0.86, {
      width: width * 0.9,
    });
  doc.end();
  return done;
};

/**
 * Render tiket final (PDF) memakai desain terpilih.
 *
 * Prioritas desain: kategori tiket -> desain default event -> layout default
 * sistem. QR selalu ditanam pada posisi yang ditentukan desain tersebut.
 *
 * @param {object} ticket baris tiket lengkap (lihat [loadTicketForPdf])
 * @returns {Promise<Buffer>}
 */
const buildTicketPdf = async (ticket) => {
  const design = normalizeDesign(ticket.ticket_type_design) ||
    normalizeDesign(ticket.event_ticket_design);
  const absoluteDesignPath = design ? designAbsolutePath(design) : null;
  const hasDesignFile = Boolean(
    absoluteDesignPath && fs.existsSync(absoluteDesignPath),
  );
  const designBuffer = hasDesignFile ? await fsp.readFile(absoluteDesignPath) : null;
  const imageSize = designBuffer ? readImageSize(designBuffer) : null;
  const { width, height } = pageSizeFor(imageSize);

  const doc = new PDFDocument({ size: [width, height], margin: 0 });
  const chunks = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  if (designBuffer) {
    doc.image(designBuffer, 0, 0, { width, height });
  } else {
    drawDefaultLayout(doc, { width, height });
  }

  const qr = design ? design.qr : DEFAULT_QR;
  const info = design ? design.info : DEFAULT_INFO;
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
  doc.fillColor(info.color).font('Helvetica-Bold').fontSize(14)
    .text(String(ticket.event_title || 'Event'), infoX, infoY, {
      width: infoWidth,
      height: 34,
      ellipsis: true,
    });
  doc.font('Helvetica').fontSize(10)
    .text(String(ticket.attendee_name || 'Peserta'), infoX, infoY + 36, {
      width: infoWidth,
      ellipsis: true,
    })
    .text(String(ticket.ticket_type_name || 'Kategori tiket'), infoX, infoY + 52, {
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
          e.title AS event_title, e.event_date, e.end_date_time,
          e.location, e.online_url, e.organizer_name,
          e.ticket_design AS event_ticket_design,
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
  STORAGE_ROOT,
  DESIGN_URL_PREFIX,
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
