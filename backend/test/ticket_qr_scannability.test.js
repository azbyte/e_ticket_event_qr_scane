/**
 * Kelayakan pindai QR e-tiket (PRD §5).
 *
 * Versi JavaScript dari alat manual `backend/tools/decode_ticket_qr.py`.
 * Pengukuran dihitung secara analitis dari geometri yang BENAR-BENAR dipakai
 * saat PDF dibuat (layout default + inset renderer), sehingga ikut berjalan pada
 * `npm test` — tanpa Python, tanpa virtual environment, dan tanpa dependensi
 * baru.
 *
 * Syarat kelayakan pindai:
 *  - ukuran modul >= 0.4 mm,
 *  - quiet zone >= 2 modul di tiap sisi,
 *  - alas putih di sekitar QR tidak berlebihan (<= 6 modul per sisi).
 *
 * Catatan batasan: pengukuran ini bersifat analitis, jadi tidak mendeteksi cacat
 * piksel. Bukti visual/decode akhir memakai `backend/tools/decode_ticket_qr.py`
 * dan `backend/tools/compare_ticket_render.py` secara manual.
 */
process.env.NODE_ENV = 'test';
// Unit test geometri: tidak ada koneksi database. Variabel ini hanya memenuhi
// validasi startup `config/env.js`.
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const QRCode = require('qrcode');

const design = require('../src/services/ticketDesignService');

/** 1 pt = 1/72 inci, 1 inci = 25.4 mm. */
const MM_PER_POINT = 25.4 / 72;
/** Minimum ukuran modul agar QR terbaca kamera ponsel. */
const MIN_MODULE_MM = 0.4;
/** Minimum quiet zone (spesifikasi QR meminta 4 modul; 2 modul + alas putih). */
const MIN_QUIET_MODULES = 2;
/** Batas atas alas putih agar QR tidak tenggelam di panel putih besar. */
const MAX_BACKING_MODULES = 6;
/** Margin (dalam modul) yang dipakai `QRCode.toBuffer` saat PDF dibuat. */
const QR_MARGIN_MODULES = 2;

/**
 * Token QR nyata: HMAC-SHA256 base64url (lihat `ticketTokenService`), sehingga
 * panjangnya sama dengan tiket sungguhan dan jumlah modul QR-nya representatif.
 */
const realToken = () =>
  createHmac('sha256', 'test-only-ticket-token-secret')
    .update('ticket:00000000-0000-4000-8000-000000000000:2026-01-01T00:00:00.000Z', 'utf8')
    .digest('base64url');

/** Jumlah modul (sisi) QR untuk token dan tingkat koreksi galat produksi (`M`). */
const moduleCount = (token) =>
  QRCode.create(token, { errorCorrectionLevel: 'M' }).modules.size;

/**
 * Kotak QR (pt) untuk orientasi tertentu dari konfigurasi tata letak default.
 *
 * `size` disimpan sebagai fraksi TINGGI kanvas, sehingga sisi QR = size x tinggi.
 */
const qrBoxFor = (orientation) => {
  const layout = design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION[orientation];
  const canvas = design.layoutSpec.CANVAS[orientation];
  return { side: layout.qr.size * canvas.height, canvas };
};

/**
 * Metrik QR untuk satu kotak QR berukuran `sizePoints` (pt).
 *
 * Gambar QR ditanam memenuhi kotak dikurangi inset renderer
 * (`QR_BACKING_INSET`), dan `qrcode` menambahkan margin `QR_MARGIN_MODULES` di
 * tiap sisi, sehingga jumlah modul efektif = modul data + 2 x margin.
 */
const qrMetrics = (token, sizePoints) => {
  const modules = moduleCount(token);
  const modulesWithMargin = modules + QR_MARGIN_MODULES * 2;
  const inset = sizePoints * design.ticketPdf.QR_BACKING_INSET;
  const inner = sizePoints - inset * 2;
  const modulePoints = inner / modulesWithMargin;
  return {
    modules,
    modulesWithMargin,
    modulePoints,
    moduleMm: modulePoints * MM_PER_POINT,
    quietZoneModules: (inset + modulePoints * QR_MARGIN_MODULES) / modulePoints,
  };
};

test('token QR nyata berukuran tetap sehingga jumlah modul stabil', () => {
  const token = realToken();
  // 32 byte -> 43 karakter base64url tanpa padding.
  assert.equal(token.length, 43);
  assert.equal(moduleCount(token), 33);
});

test('QR default landscape memenuhi syarat pindai', () => {
  const { side } = qrBoxFor('landscape');
  const metrics = qrMetrics(realToken(), side);

  assert.ok(
    metrics.moduleMm >= MIN_MODULE_MM,
    `modul QR landscape ${metrics.moduleMm.toFixed(2)} mm < ${MIN_MODULE_MM} mm`,
  );
  assert.ok(
    metrics.quietZoneModules >= MIN_QUIET_MODULES,
    `quiet zone landscape ${metrics.quietZoneModules.toFixed(2)} modul`,
  );
  assert.ok(
    metrics.quietZoneModules <= MAX_BACKING_MODULES,
    `alas putih landscape ${metrics.quietZoneModules.toFixed(2)} modul > ${MAX_BACKING_MODULES}`,
  );
});

test('QR default portrait memenuhi syarat pindai', () => {
  const { side } = qrBoxFor('portrait');
  const metrics = qrMetrics(realToken(), side);

  assert.ok(
    metrics.moduleMm >= MIN_MODULE_MM,
    `modul QR portrait ${metrics.moduleMm.toFixed(2)} mm < ${MIN_MODULE_MM} mm`,
  );
  assert.ok(
    metrics.quietZoneModules >= MIN_QUIET_MODULES,
    `quiet zone portrait ${metrics.quietZoneModules.toFixed(2)} modul`,
  );
  assert.ok(
    metrics.quietZoneModules <= MAX_BACKING_MODULES,
    `alas putih portrait ${metrics.quietZoneModules.toFixed(2)} modul > ${MAX_BACKING_MODULES}`,
  );
});

test('QR terkecil yang diizinkan tetap dapat dipindai', () => {
  const token = realToken();
  const { size } = design.QR_PLACEMENT_LIMITS;

  for (const orientation of ['landscape', 'portrait']) {
    const canvas = design.layoutSpec.CANVAS[orientation];
    // Organizer boleh mengecilkan QR sampai batas bawah (15% tinggi kanvas).
    const sizePoints = size.min * canvas.height;
    const metrics = qrMetrics(token, sizePoints);
    assert.ok(
      metrics.moduleMm >= MIN_MODULE_MM,
      `modul QR ${sizePoints.toFixed(1)} pt hanya ${metrics.moduleMm.toFixed(2)} mm`,
    );
  }
});

test('quiet zone dari margin QR memenuhi minimum 2 modul', () => {
  assert.ok(
    QR_MARGIN_MODULES >= MIN_QUIET_MODULES,
    'margin QR di ticketPdfRenderer harus >= 2 modul',
  );
});
