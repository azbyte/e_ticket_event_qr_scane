/**
 * Font e-tiket (Times New Roman) untuk renderer PDF.
 *
 * Desain referensi memakai **Times New Roman** (judul bold, isi regular). PDF
 * hanya menampilkan font yang benar-benar tertanam (atau font standar PDF yang
 * metriknya identik), sehingga:
 *  1. berkas TTF Times New Roman dicari pada beberapa lokasi (env -> aset
 *     aplikasi -> font sistem) dan DIDAFTARKAN ke PDFKit agar tersubset+tertanam,
 *  2. bila tidak ditemukan, dipakai font standar PDF `Times-Roman`/`Times-Bold`
 *     yang metrik lebarnya identik dengan Times New Roman sehingga tata letak
 *     tidak bergeser (hanya tidak tertanam).
 *
 * Tidak ada berkas font yang di-commit ke repositori: Times New Roman adalah
 * font berlisensi Microsoft, jadi berkas TTF tidak boleh didistribusikan ulang
 * lewat repositori. Untuk deployment Linux tanpa font Microsoft, set
 * `TICKET_FONT_REGULAR`/`TICKET_FONT_BOLD` ke font serif metric-compatible
 * (mis. Liberation Serif atau Tinos) — atau biarkan fallback standar PDF.
 */
const fs = require('node:fs');
const path = require('node:path');
const PDFDocument = require('pdfkit');

const ASSET_FONT_DIR = path.join(__dirname, '..', '..', 'assets', 'fonts');

/** Nama font internal yang dipakai seluruh renderer tiket. */
const FONT_NAMES = Object.freeze({
  regular: 'TicketSerif',
  bold: 'TicketSerif-Bold',
});

/** Nama font standar PDF (base-14) sebagai fallback; metrik = Times New Roman. */
const BASE14_NAMES = Object.freeze({
  regular: 'Times-Roman',
  bold: 'Times-Bold',
});

/**
 * Kandidat lokasi berkas font, berurutan prioritas. `null`/kosong dilewati.
 * Disusun agar Windows (dev), Linux (CI/produksi) dan macOS sama-sama tercakup.
 */
const FONT_CANDIDATES = Object.freeze({
  regular: Object.freeze([
    process.env.TICKET_FONT_REGULAR,
    path.join(ASSET_FONT_DIR, 'times.ttf'),
    path.join(ASSET_FONT_DIR, 'Times New Roman.ttf'),
    'C:\\Windows\\Fonts\\times.ttf',
    '/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman.ttf',
    '/usr/share/fonts/truetype/msttcorefonts/times.ttf',
    '/usr/share/fonts/TTF/times.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
    '/usr/share/fonts/liberation/LiberationSerif-Regular.ttf',
    '/Library/Fonts/Times New Roman.ttf',
    '/System/Library/Fonts/Supplemental/Times New Roman.ttf',
  ]),
  bold: Object.freeze([
    process.env.TICKET_FONT_BOLD,
    path.join(ASSET_FONT_DIR, 'timesbd.ttf'),
    path.join(ASSET_FONT_DIR, 'Times New Roman Bold.ttf'),
    'C:\\Windows\\Fonts\\timesbd.ttf',
    '/usr/share/fonts/truetype/msttcorefonts/Times_New_Roman_Bold.ttf',
    '/usr/share/fonts/truetype/msttcorefonts/timesbd.ttf',
    '/usr/share/fonts/TTF/timesbd.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf',
    '/usr/share/fonts/liberation/LiberationSerif-Bold.ttf',
    '/Library/Fonts/Times New Roman Bold.ttf',
    '/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf',
  ]),
});

const isReadableFile = (candidate) => {
  if (typeof candidate !== 'string' || candidate.trim() === '') return false;
  try {
    return fs.statSync(candidate).isFile();
  } catch (_error) {
    return false;
  }
};


/** Berkas font yang benar-benar tersedia (null bila tidak ada). */
let resolvedCache = null;
const resolveFontFiles = () => {
  if (resolvedCache) return resolvedCache;
  resolvedCache = {
    regular: FONT_CANDIDATES.regular.find(isReadableFile) || null,
    bold: FONT_CANDIDATES.bold.find(isReadableFile) || null,
  };
  return resolvedCache;
};

/** Reset cache (dipakai test yang mengubah env). */
const resetFontCache = () => {
  resolvedCache = null;
  measurerCache = null;
};

/**
 * Daftarkan font Times ke dokumen PDFKit lalu aktifkan font regular.
 *
 * @param {object} doc dokumen PDFKit
 * @returns {{regular: string, bold: string, embedded: boolean}}
 *   nama font yang harus dipakai untuk `doc.font(...)`
 */
const registerFonts = (doc) => {
  const files = resolveFontFiles();
  if (files.regular) doc.registerFont(FONT_NAMES.regular, files.regular);
  if (files.bold) doc.registerFont(FONT_NAMES.bold, files.bold);
  const names = {
    regular: files.regular ? FONT_NAMES.regular : BASE14_NAMES.regular,
    // Bold tanpa TTF tetap memakai Times-Bold standar (tidak memalsukan
    // ketebalan dengan font regular) agar hierarki judul tetap terlihat.
    bold: files.bold ? FONT_NAMES.bold : BASE14_NAMES.bold,
    embedded: Boolean(files.regular && files.bold),
  };
  doc.font(names.regular);
  return names;
};

/**
 * Metrik vertikal font yang sedang aktif pada dokumen (per 1000 unit em).
 *
 * Dipakai untuk menempatkan teks berdasarkan GARIS DASAR (baseline) agar posisi
 * tidak bergeser ketika font yang tersedia berbeda (TTF tertanam vs base-14).
 * `doc._font` adalah properti internal PDFKit, tetapi satu-satunya cara membaca
 * ascender font aktif; nilainya diberi fallback metrik Times.
 */
const fontMetrics = (doc) => {
  const font = doc && doc._font ? doc._font : {};
  return {
    ascender: Number.isFinite(font.ascender) ? font.ascender : 891,
    descender: Number.isFinite(font.descender) ? font.descender : -216,
    capHeight: Number.isFinite(font.capHeight) ? font.capHeight : 662,
  };
};

/**
 * Dokumen PDF "tak terlihat" untuk mengukur lebar teks tanpa menggambar apa pun.
 *
 * Di-cache karena pembuatan PDFDocument relatif mahal dan pengukuran dipanggil
 * berkali-kali (validasi + render). Font yang dipakai SAMA dengan renderer
 * sehingga lebar teks pada validasi tumpang tindih identik dengan hasil PDF.
 */
let measurerCache = null;
const measurer = () => {
  if (measurerCache) return measurerCache;
  const doc = new PDFDocument({ size: [842, 594], margin: 0 });
  // Dokumen hanya untuk mengukur: jangan biarkan error/stream menggantung.
  doc.on('error', () => {});
  measurerCache = { doc, names: registerFonts(doc) };
  return measurerCache;
};

/**
 * Lebar teks (pt) pada ukuran font tertentu.
 *
 * @param {string} text
 * @param {{fontSize: number, bold?: boolean}} options
 * @returns {number}
 */
const measureTextWidth = (text, { fontSize, bold = false }) => {
  const { doc, names } = measurer();
  doc.font(bold ? names.bold : names.regular).fontSize(fontSize);
  return doc.widthOfString(String(text ?? ''));
};

/** Metrik font yang dipakai renderer (untuk perhitungan posisi baseline). */
const textMetrics = (bold = false) => {
  const { doc, names } = measurer();
  doc.font(bold ? names.bold : names.regular);
  return fontMetrics(doc);
};

module.exports = {
  FONT_NAMES,
  BASE14_NAMES,
  ASSET_FONT_DIR,
  FONT_CANDIDATES,
  resolveFontFiles,
  resetFontCache,
  registerFonts,
  fontMetrics,
  measureTextWidth,
  textMetrics,
};
