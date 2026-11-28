/**
 * Tata letak desain e-tiket — SATU sumber kebenaran untuk editor, pratinjau,
 * generator PDF, dan template.
 *
 * ## Sistem koordinat
 *
 * Kanvas tiket = ukuran halaman PDF (pt):
 *  - `landscape` 842 x 594 pt (A4 landscape; acuan desain referensi Canva),
 *  - `portrait`  440 x 704 pt.
 *
 * Setiap elemen disimpan sebagai FRAKSI kanvas 0..1 (`x` = fraksi lebar,
 * `y` = fraksi tinggi) sehingga tidak bergantung pada resolusi berkas desain
 * maupun ukuran layar editor. Ukuran huruf disimpan dalam **pt kanvas**:
 * pada kanvas landscape 842 pt, judul 50 pt dan ID/instruksi 30 pt menghasilkan
 * proporsi yang persis sama dengan gambar referensi
 * (`docs/references/desain_tiket_referensi.png`, 2000x1414 px = 842x595 pt
 * diekspor 2,375x).
 *
 * ## Arti `y`
 *
 * `y` adalah tepi ATAS baris teks (posisi `y` yang dipakai `doc.text()`),
 * bukan garis dasar. Renderer menurunkan garis dasar dari metrik font aktif,
 * sehingga posisi visual tidak bergeser ketika font yang tersedia berbeda.
 *
 * ## Pencegahan tumpang tindih
 *
 * `resolveLayout()` menghitung kotak (bounding box) setiap elemen dalam pt,
 * lalu `findOverlaps()` melaporkan pasangan yang bertabrakan. Editor memakai
 * hasil yang sama untuk menandai tabrakan, dan endpoint simpan menolak
 * konfigurasi yang bertabrakan sehingga PDF tidak pernah memuat teks yang
 * tertutup QR Code.
 */

const { measureTextWidth } = require('./ticketFontService');

/** Versi skema konfigurasi tata letak (naik bila arti field berubah). */
const LAYOUT_VERSION = 2;


/** Ukuran kanvas = ukuran halaman PDF per orientasi (pt). */
const CANVAS = Object.freeze({
  landscape: Object.freeze({ width: 842, height: 594 }),
  portrait: Object.freeze({ width: 440, height: 704 }),
});

/** Kunci elemen teks pada konfigurasi tata letak. */
const TEXT_KEYS = Object.freeze(['title', 'ticket_id', 'instruction']);

/** Label elemen untuk pesan validasi/UI. */
const TEXT_LABELS = Object.freeze({
  title: 'Judul tiket',
  ticket_id: 'ID tiket',
  instruction: 'Instruksi penukaran',
  qr: 'QR Code',
});

/**
 * Jarak aman antar-elemen (pt). Dipakai saat menilai tumpang tindih: dua kotak
 * yang berselisih kurang dari jarak ini dianggap bertabrakan, sehingga QR tidak
 * hanya "tidak menimpa" tetapi juga tidak menempel pada tulisan.
 */
const ELEMENT_GAP = 3;

/** Tinggi baris relatif terhadap ukuran huruf (Times: 1.18 x ukuran). */
const LINE_HEIGHT = 1.18;

/**
 * Batas nilai yang diterima dari editor. `font_size` dalam pt kanvas; batas
 * bawah 8 pt menjaga keterbacaan cetak, batas atas 120 pt mencegah judul
 * memenuhi seluruh kanvas.
 */
const LIMITS = Object.freeze({
  position: Object.freeze({ min: 0, max: 0.98 }),
  fontSize: Object.freeze({ min: 8, max: 120 }),
  qrSize: Object.freeze({ min: 0.15, max: 0.6 }),
  panelSplit: Object.freeze({ min: 0.2, max: 0.85 }),
  maxWidth: Object.freeze({ min: 0.2, max: 1 }),
});

/**
 * Nilai default desain — HASIL PENGUKURAN gambar referensi
 * (`docs/references/desain_tiket_referensi.png`), dikonversi ke pt kanvas
 * 842 x 594 dengan skala 2,375 px/pt.
 *
 * Angka pada spesifikasi produk (judul atas 3,2%, ID 10,8%, instruksi 17,7%)
 * adalah perkiraan; nilai di bawah diukur langsung dari gambar agar hasil PDF
 * semirip mungkin dengan referensi:
 *  - judul: tepi atas glyph 63 px  -> 26,5 pt -> y 0,0446
 *  - ID   : tepi atas glyph 221 px -> 93,0 pt -> y 0,1566
 *  - instr: tepi atas glyph 319 px -> 134,3 pt -> y 0,2261
 * dikurangi ascender font (0,891 x ukuran) menjadi tepi atas baris teks.
 */
const DEFAULT_LAYOUT_BY_ORIENTATION = Object.freeze({
  landscape: Object.freeze({
    version: LAYOUT_VERSION,
    panel_split: 0.558,
    text_width: 0.6,
    title: Object.freeze({ x: 0.0445, y: 0.0286, font_size: 50, bold: true }),
    ticket_id: Object.freeze({ x: 0.0445, y: 0.1470, font_size: 30, bold: false }),
    instruction: Object.freeze({ x: 0.0445, y: 0.2165, font_size: 30, bold: false }),
    qr: Object.freeze({ x: 0.0595, y: 0.3260, size: 0.4231 }),
  }),
  portrait: Object.freeze({
    version: LAYOUT_VERSION,
    panel_split: 0.38,
    text_width: 0.86,
    title: Object.freeze({ x: 0.07, y: 0.042, font_size: 26, bold: true }),
    ticket_id: Object.freeze({ x: 0.07, y: 0.108, font_size: 16, bold: false }),
    instruction: Object.freeze({ x: 0.07, y: 0.152, font_size: 16, bold: false }),
    qr: Object.freeze({ x: 0.07, y: 0.46, size: 0.36 }),
  }),
});

/** Warna desain default (diukur dari gambar referensi). */
const DEFAULT_COLORS = Object.freeze({
  leftTop: '#F8E0DC',
  leftMid: '#EDC3BE',
  leftBottom: '#DEA5A0',
  right: '#FBF2E4',
  rightDeep: '#F3E4CD',
  accent: '#C9837F',
  accentSoft: '#E4C3B9',
  text: '#1A1A1A',
});

/** Instruksi penukaran tiket (teks tetap, sesuai referensi). */
const EXCHANGE_INSTRUCTION = 'Silahkan tukarkan tiket di meja registrasi';

/** Format judul tiket: `E-TIKET [NAMA ACARA]` dalam huruf kapital. */
const ticketTitle = (eventTitle) => `E-TIKET ${String(eventTitle ?? '').trim()}`.toUpperCase();

/** Format baris ID tiket: `ID TIKET: [ID TIKET]` (tanpa diubah kapitalisasinya). */
const ticketIdLine = (ticketId) => `ID TIKET: ${String(ticketId ?? '').trim()}`;

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
const isFiniteNumber = (value) => typeof value === 'number' && Number.isFinite(value);
const round = (value, digits = 4) => {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
};
const parseNumber = (value, fallback) => {
  const parsed = typeof value === 'string' ? Number(value) : value;
  return isFiniteNumber(parsed) ? parsed : fallback;
};

/** Kanvas untuk orientasi (fallback landscape). */
const canvasFor = (orientation) =>
  (orientation === 'portrait' ? CANVAS.portrait : CANVAS.landscape);

const defaultLayoutFor = (orientation) =>
  (orientation === 'portrait'
    ? DEFAULT_LAYOUT_BY_ORIENTATION.portrait
    : DEFAULT_LAYOUT_BY_ORIENTATION.landscape);


/**
 * Normalisasi konfigurasi tata letak dari database/permintaan API.
 *
 * Nilai yang hilang/tidak valid diisi default orientasi; nilai di luar batas
 * dipotong ke batas (clamp) agar renderer tidak pernah menerima angka ekstrem.
 * Desain lama yang hanya menyimpan `info` (area teks) tetap dihormati posisi
 * horizontal & lebarnya, sedangkan posisi vertikal memakai default baru.
 *
 * @param {object|null} raw konfigurasi tersimpan
 * @param {{orientation?: string, legacyInfo?: object}} [options]
 * @returns {object} konfigurasi lengkap (selalu ada)
 */
const normalizeLayout = (raw, { orientation, legacyInfo } = {}) => {
  const defaults = defaultLayoutFor(orientation);
  const source = raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  const legacy = legacyInfo && typeof legacyInfo === 'object' ? legacyInfo : null;
  const legacyX = legacy ? parseNumber(legacy.x, null) : null;
  const legacyWidth = legacy ? parseNumber(legacy.width, null) : null;

  const textWidth = clamp(
    parseNumber(source.text_width, legacyWidth ?? defaults.text_width),
    LIMITS.maxWidth.min,
    LIMITS.maxWidth.max,
  );

  const readElement = (key) => {
    const fallback = defaults[key];
    const value = source[key] && typeof source[key] === 'object' ? source[key] : {};
    return {
      x: clamp(
        parseNumber(value.x, legacyX ?? fallback.x),
        LIMITS.position.min,
        LIMITS.position.max,
      ),
      y: clamp(
        parseNumber(value.y, fallback.y),
        LIMITS.position.min,
        LIMITS.position.max,
      ),
      font_size: clamp(
        parseNumber(value.font_size, fallback.font_size),
        LIMITS.fontSize.min,
        LIMITS.fontSize.max,
      ),
      bold: typeof value.bold === 'boolean' ? value.bold : fallback.bold,
    };
  };

  const qrSource = source.qr && typeof source.qr === 'object' ? source.qr : {};
  return {
    version: LAYOUT_VERSION,
    panel_split: clamp(
      parseNumber(source.panel_split, defaults.panel_split),
      LIMITS.panelSplit.min,
      LIMITS.panelSplit.max,
    ),
    text_width: textWidth,
    title: readElement('title'),
    ticket_id: readElement('ticket_id'),
    instruction: readElement('instruction'),
    qr: {
      x: clamp(parseNumber(qrSource.x, defaults.qr.x), LIMITS.position.min, LIMITS.position.max),
      y: clamp(parseNumber(qrSource.y, defaults.qr.y), LIMITS.position.min, LIMITS.position.max),
      size: clamp(parseNumber(qrSource.size, defaults.qr.size), LIMITS.qrSize.min, LIMITS.qrSize.max),
    },
  };
};

/** Potong satu baris dengan elipsis bila melebihi lebar area. */
const truncateLine = (text, { fontSize, bold = false, maxWidth }) => {
  const value = String(text ?? '');
  if (measureTextWidth(value, { fontSize, bold }) <= maxWidth) return value;
  let cut = value;
  while (cut.length > 1 && measureTextWidth(`${cut}…`, { fontSize, bold }) > maxWidth) {
    cut = cut.slice(0, -1);
  }
  return `${cut.trimEnd()}…`;
};

/**
 * Pecah teks menjadi baris yang muat pada `maxWidth` (pt).
 * Satu kata yang lebih lebar dari area dipotong dengan elipsis agar tidak
 * melewati batas kanvas.
 *
 * @returns {string[]} minimal satu baris (bisa berisi string kosong)
 */
const wrapLines = (text, { fontSize, bold = false, maxWidth }) => {
  const words = String(text ?? '').split(/\s+/).filter(Boolean);
  if (words.length === 0) return [''];
  const lines = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (measureTextWidth(candidate, { fontSize, bold }) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current) {
      lines.push(current);
      current = word;
      continue;
    }
    lines.push(truncateLine(word, { fontSize, bold, maxWidth }));
    current = '';
  }
  if (current) lines.push(current);
  return lines.length > 0 ? lines : [''];
};

/**
 * Sesuaikan ukuran huruf & pembungkusan satu elemen teks.
 *
 * Aturan (dipakai renderer DAN pratinjau editor):
 *  1. ukuran huruf dipertahankan bila teks muat (`maxLines`, `maxHeight`),
 *  2. bila tidak muat, ukuran diturunkan bertahap 0,5 pt sampai batas
 *     `min_ratio` x ukuran asli (judul 50 -> minimal 20 pt) dan teks boleh
 *     memakai hingga `lineLimit` baris (judul 3 baris) agar nama acara panjang
 *     TIDAK terpotong,
 *  3. hanya bila tetap tidak muat pada ukuran minimum, baris terakhir dipotong
 *     dengan elipsis (keadaan darurat, mis. satu kata sangat panjang).
 *
 * @returns {{fontSize: number, lines: string[], width: number, height: number,
 *   truncated: boolean}}
 */
const fitTextElement = (text, element, {
  maxWidth, maxHeight, maxLines = 1, lineLimit = maxLines, minRatio = 0.5,
}) => {
  const bold = element.bold === true;
  const configured = element.font_size;
  const minSize = Math.max(LIMITS.fontSize.min, configured * minRatio);
  const measure = (size) => {
    const lines = wrapLines(text, { fontSize: size, bold, maxWidth });
    return {
      lines,
      width: lines.reduce(
        (widest, line) => Math.max(widest, measureTextWidth(line, { fontSize: size, bold })),
        0,
      ),
      height: lines.length * size * LINE_HEIGHT,
    };
  };

  let size = configured;
  let fitted = measure(size);
  while ((fitted.lines.length > lineLimit || fitted.height > maxHeight)
    && size > minSize + 1e-9) {
    size = Math.max(minSize, round(size - 0.5, 2));
    fitted = measure(size);
  }

  let truncated = false;
  if (fitted.lines.length > lineLimit || fitted.height > maxHeight) {
    // Darurat: batasi jumlah baris agar kotak elemen tidak melewati elemen
    // berikutnya, lalu potong baris terakhir dengan elipsis.
    const allowed = Math.max(1, Math.min(
      lineLimit,
      Math.floor(maxHeight / (size * LINE_HEIGHT)) || 1,
    ));
    if (fitted.lines.length > allowed) {
      const lines = fitted.lines.slice(0, allowed);
      lines[allowed - 1] = truncateLine(
        fitted.lines.slice(allowed - 1).join(' '),
        { fontSize: size, bold, maxWidth },
      );
      fitted = { ...measure(size), lines };
      truncated = true;
    }
    fitted.width = fitted.lines.reduce(
      (widest, line) => Math.max(widest, measureTextWidth(line, { fontSize: size, bold })),
      0,
    );
    fitted.height = fitted.lines.length * size * LINE_HEIGHT;
  }
  return {
    fontSize: size,
    lines: fitted.lines,
    width: fitted.width,
    height: fitted.height,
    truncated,
  };
};

/**
 * Hitung kotak (bounding box) seluruh elemen tiket dalam pt.
 *
 * @param {object} layout konfigurasi ternormalisasi
 * @param {{orientation?: string, title?: string, ticketId?: string,
 *   instruction?: string}} data teks dinamis yang akan dicetak
 * @returns {{canvas: {width: number, height: number}, boxes: object,
 *   qr: {x: number, y: number, size: number}}}
 */
const resolveLayout = (layout, {
  orientation, title = '', ticketId = '', instruction = EXCHANGE_INSTRUCTION,
} = {}) => {
  const canvas = canvasFor(orientation);
  const maxWidth = layout.text_width * canvas.width;
  const texts = { title, ticket_id: ticketId, instruction };
  const boxes = {};
  for (let index = 0; index < TEXT_KEYS.length; index += 1) {
    const key = TEXT_KEYS[index];
    const element = layout[key];
    const x = element.x * canvas.width;
    const y = element.y * canvas.height;
    const nextKey = TEXT_KEYS[index + 1];
    const limitY = nextKey ? layout[nextKey].y * canvas.height : canvas.height;
    // Ruang vertikal sebelum elemen berikutnya; minimal satu baris agar ukuran
    // huruf tidak pernah menjadi nol.
    const maxHeight = Math.max(element.font_size * LINE_HEIGHT, limitY - y - ELEMENT_GAP);
    const fitted = fitTextElement(texts[key], element, {
      maxWidth,
      maxHeight,
      maxLines: key === 'title' ? 2 : 1,
      // Judul boleh 3 baris (nama acara panjang) dan mengecil hingga 35%
      // ukuran aslinya (50 -> 17,5 pt), sehingga tidak terpotong elipsis.
      lineLimit: key === 'title' ? 3 : 1,
      minRatio: key === 'title' ? 0.35 : 0.6,
    });
    boxes[key] = {
      key,
      label: TEXT_LABELS[key],
      x,
      y,
      width: fitted.width,
      height: fitted.height,
      lines: fitted.lines,
      font_size: fitted.fontSize,
      bold: element.bold === true,
      truncated: fitted.truncated === true,
      max_width: maxWidth,
    };
  }
  return {
    canvas,
    boxes,
    qr: {
      x: layout.qr.x * canvas.width,
      y: layout.qr.y * canvas.height,
      size: layout.qr.size * canvas.height,
    },
  };
};

/** True bila dua kotak berselisih (termasuk jarak aman `gap`). */
const boxesOverlap = (a, b, gap = 0) =>
  a.x < b.x + b.width + gap
  && a.x + a.width + gap > b.x
  && a.y < b.y + b.height + gap
  && a.y + a.height + gap > b.y;

/**
 * Pasangan elemen yang bertabrakan.
 *
 * @param {{boxes: object, qr: {x: number, y: number, size: number}}} resolved
 * @returns {Array<{a: string, b: string, label: string}>}
 */
const findOverlaps = (resolved) => {
  const { boxes, qr } = resolved;
  const conflicts = [];
  const qrBox = { x: qr.x, y: qr.y, width: qr.size, height: qr.size };
  for (const key of TEXT_KEYS) {
    const box = boxes[key];
    if (!box) continue;
    // QR Code tidak boleh menutupi tulisan (dengan jarak aman ELEMENT_GAP).
    if (boxesOverlap(box, qrBox, ELEMENT_GAP)) {
      conflicts.push({ a: 'qr', b: key, label: `${TEXT_LABELS.qr} menutupi ${TEXT_LABELS[key]}` });
    }
    for (const otherKey of TEXT_KEYS) {
      if (otherKey <= key) continue;
      const other = boxes[otherKey];
      if (other && boxesOverlap(box, other, ELEMENT_GAP)) {
        conflicts.push({
          a: key,
          b: otherKey,
          label: `${TEXT_LABELS[key]} bertabrakan dengan ${TEXT_LABELS[otherKey]}`,
        });
      }
    }
  }
  return conflicts;
};

/** Elemen yang keluar dari batas kanvas (dengan toleransi 0,5 pt). */
const findOutOfCanvas = (resolved) => {
  const { canvas, boxes, qr } = resolved;
  const tolerance = 0.5;
  const problems = [];
  const check = (label, box) => {
    if (box.x < -tolerance
      || box.y < -tolerance
      || box.x + box.width > canvas.width + tolerance
      || box.y + box.height > canvas.height + tolerance) {
      problems.push(`${label} keluar dari batas kanvas tiket`);
    }
  };
  for (const key of TEXT_KEYS) {
    if (boxes[key]) check(TEXT_LABELS[key], boxes[key]);
  }
  check(TEXT_LABELS.qr, { x: qr.x, y: qr.y, width: qr.size, height: qr.size });
  return problems;
};

/**
 * Validasi konfigurasi tata letak yang akan disimpan.
 *
 * @param {object} layout konfigurasi ternormalisasi
 * @param {{orientation?: string, title?: string, ticketId?: string,
 *   instruction?: string}} data teks untuk menghitung kotak sebenarnya
 * @returns {{errors: string[], resolved: object}}
 */
const validateLayout = (layout, data = {}) => {
  const resolved = resolveLayout(layout, data);
  const errors = findOutOfCanvas(resolved);
  for (const conflict of findOverlaps(resolved)) {
    errors.push(`${conflict.label}. Geser elemen agar tidak bertumpuk.`);
  }
  return { errors, resolved };
};

module.exports = {
  LAYOUT_VERSION,
  CANVAS,
  TEXT_KEYS,
  TEXT_LABELS,
  ELEMENT_GAP,
  LINE_HEIGHT,
  LIMITS,
  DEFAULT_LAYOUT_BY_ORIENTATION,
  DEFAULT_COLORS,
  EXCHANGE_INSTRUCTION,
  ticketTitle,
  ticketIdLine,
  canvasFor,
  defaultLayoutFor,
  normalizeLayout,
  resolveLayout,
  findOverlaps,
  findOutOfCanvas,
  validateLayout,
  wrapLines,
  truncateLine,
  fitTextElement,
  boxesOverlap,
};

