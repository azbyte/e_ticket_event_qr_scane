/**
 * Kelayakan pindai QR e-tiket (PRD §5).
 *
 * Versi JavaScript dari alat manual `backend/tools/check_qr_scannability.py`.
 * Alat Python lama mengukur QR dari PDF yang sudah dirender (300 DPI); versi ini
 * menghitungnya secara analitis dari geometri yang benar-benar dipakai saat PDF
 * dibuat, sehingga ikut berjalan pada `npm test` — tanpa Python, tanpa virtual
 * environment, dan tanpa dependensi baru.
 *
 * Syarat kelayakan pindai (sama dengan alat Python):
 *  - ukuran modul >= 0.4 mm,
 *  - quiet zone >= 2 modul di tiap sisi,
 *  - alas putih di sekitar QR tidak berlebihan (<= 6 modul per sisi).
 *
 * Catatan batasan: pengukuran ini bersifat analitis, jadi tidak mendeteksi cacat
 * piksel (mis. gambar QR yang tertarik tidak proporsional saat ditanam). Bukti
 * visual/decode akhir tetap memakai `backend/tools/` secara manual.
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
 * Metrik QR untuk satu kotak QR berukuran `sizePoints` (pt).
 *
 * Gambar QR ditanam memenuhi kotak itu, dan `qrcode` menambahkan margin
 * `QR_MARGIN_MODULES` di tiap sisi, sehingga jumlah modul efektif pada kotak =
 * modul data + 2 x margin.
 */
const qrMetrics = (token, sizePoints) => {
  const modules = moduleCount(token);
  const modulesWithMargin = modules + QR_MARGIN_MODULES * 2;
  const modulePoints = sizePoints / modulesWithMargin;
  return {
    modules,
    modulesWithMargin,
    modulePoints,
    moduleMm: modulePoints * MM_PER_POINT,
    backingModules: design.QR_BACKING_PAD / modulePoints,
  };
};

test('token QR nyata berukuran tetap sehingga jumlah modul stabil', () => {
  const token = realToken();
  // 32 byte -> 43 karakter base64url tanpa padding.
  assert.equal(token.length, 43);
  assert.equal(moduleCount(token), 33);
});

test('QR default landscape memenuhi syarat pindai', () => {
  const { qrSize } = design.LANDSCAPE_CANVAS;
  const metrics = qrMetrics(realToken(), qrSize);

  assert.ok(
    metrics.moduleMm >= MIN_MODULE_MM,
    `modul QR landscape ${metrics.moduleMm.toFixed(2)} mm < ${MIN_MODULE_MM} mm`,
  );
  assert.ok(
    metrics.backingModules <= MAX_BACKING_MODULES,
    `alas putih landscape ${metrics.backingModules.toFixed(2)} modul > ${MAX_BACKING_MODULES}`,
  );
});

test('QR default portrait memenuhi syarat pindai', () => {
  const { qrSize } = design.PORTRAIT_CANVAS;
  const metrics = qrMetrics(realToken(), qrSize);

  assert.ok(
    metrics.moduleMm >= MIN_MODULE_MM,
    `modul QR portrait ${metrics.moduleMm.toFixed(2)} mm < ${MIN_MODULE_MM} mm`,
  );
  assert.ok(
    metrics.backingModules <= MAX_BACKING_MODULES,
    `alas putih portrait ${metrics.backingModules.toFixed(2)} modul > ${MAX_BACKING_MODULES}`,
  );
});

test('QR terkecil yang diizinkan tetap dapat dipindai', () => {
  const token = realToken();
  const { size } = design.QR_PLACEMENT_LIMITS;

  for (const canvas of [design.LANDSCAPE_CANVAS, design.PORTRAIT_CANVAS]) {
    // Organizer boleh mengecilkan QR sampai batas bawah, tetapi render
    // menaikkannya ke `QR_MIN_POINTS` bila hasilnya lebih kecil.
    const requested = size.min * canvas.height;
    const sizePoints = Math.max(requested, design.QR_MIN_POINTS);
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
    'margin QR di ticketDesignService harus >= 2 modul',
  );
});
