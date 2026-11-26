/**
 * Skrip verifikasi manual (bukan bagian test suite): memastikan template dan
 * tiket PDF benar-benar terbentuk untuk kedua orientasi, termasuk dengan desain
 * unggahan.
 *
 * Yang diverifikasi:
 *  1. tiket default landscape benar-benar horizontal,
 *  2. tiket default portrait benar-benar vertikal,
 *  3. desain kustom tidak diubah proporsinya (rasio halaman = rasio gambar),
 *  4. template PDF/PNG mengikuti orientasi,
 *  5. unggahan dengan rasio yang salah ditolak validasi.
 *
 * Jalankan dari `backend/`: npm run verify:ticket-pdf
 * (hasil ditulis ke `backend/_verify-out/`, folder diabaikan git)
 */
const fs = require('node:fs');
const path = require('node:path');
const svc = require('../src/services/ticketDesignService');

const outDir = path.join(__dirname, '..', '_verify-out');
fs.mkdirSync(outDir, { recursive: true });

/** Baca Mediabox halaman pertama PDF (satuan pt). */
const readPdfPageSize = (buffer) => {
  const text = buffer.toString('latin1');
  const match = text.match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
  if (!match) return null;
  return { width: Number(match[1]), height: Number(match[2]) };
};

let failed = 0;
const check = (condition, message) => {
  if (condition) {
    console.log(`OK    : ${message}`);
  } else {
    failed += 1;
    console.error(`GAGAL : ${message}`);
  }
};

const templatePng = (orientation) => {
  const file = path.join(
    __dirname, '..', 'assets', 'ticket-templates', `ticket-template-${orientation}.png`,
  );
  const buffer = fs.readFileSync(file);
  return { buffer, size: svc.readImageSize(buffer) };
};

/** Simpan gambar ke storage lalu bentuk objek desain seperti dari DB. */
const saveDesign = async (eventId, buffer, orientation) => {
  const saved = await svc.saveDesignImage({
    eventId, buffer, contentType: 'image/png',
  });
  const size = svc.readImageSize(buffer);
  return {
    source: 'upload',
    template: 'custom',
    file_path: saved.filePath,
    content_type: 'image/png',
    orientation,
    width: size.width,
    height: size.height,
    qr: svc.DEFAULT_QR_BY_ORIENTATION[orientation],
    info: svc.DEFAULT_INFO_BY_ORIENTATION[orientation],
  };
};

const ticket = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'TKT-VERIFY-001',
  issued_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  purchased_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  event_title: 'Konser Verifikasi',
  attendee_name: 'Peserta Verifikasi',
  ticket_type_name: 'VIP',
  event_date: new Date('2026-12-01T12:00:00Z').toISOString(),
  location: 'Jakarta Convention Center',
  order_number: 'ORD-VERIFY-1',
  qr_code_data: 'TKT-VERIFY-001',
};

(async () => {
  // 1 & 2. Tiket default untuk kedua orientasi.
  const plainLandscape = await svc.buildTicketPdf(ticket);
  fs.writeFileSync(path.join(outDir, 'ticket-landscape-default.pdf'), plainLandscape);
  const plainLandscapeSize = readPdfPageSize(plainLandscape);
  check(plainLandscapeSize && plainLandscapeSize.width > plainLandscapeSize.height,
    `default landscape horizontal (${plainLandscapeSize?.width}x${plainLandscapeSize?.height} pt)`);

  const plainPortrait = await svc.buildTicketPdf({
    ...ticket, event_ticket_orientation: 'portrait',
  });
  fs.writeFileSync(path.join(outDir, 'ticket-portrait-default.pdf'), plainPortrait);
  const plainPortraitSize = readPdfPageSize(plainPortrait);
  check(plainPortraitSize && plainPortraitSize.height > plainPortraitSize.width,
    `default portrait vertikal (${plainPortraitSize?.width}x${plainPortraitSize?.height} pt)`);

  // 3. Desain kustom: proporsi harus dipertahankan.
  for (const orientation of svc.ORIENTATIONS) {
    const { buffer, size } = templatePng(orientation);
    const design = await saveDesign('verify-orientation', buffer, orientation);
    const pdf = await svc.buildTicketPdf({ ...ticket, event_ticket_design: design });
    fs.writeFileSync(path.join(outDir, `ticket-${orientation}-custom.pdf`), pdf);
    const page = readPdfPageSize(pdf);
    const pageRatio = page.width / page.height;
    const imageRatio = size.width / size.height;
    check(orientation === 'portrait' ? page.height > page.width : page.width > page.height,
      `desain kustom ${orientation} mengikuti orientasi (${page.width}x${page.height} pt)`);
    check(Math.abs(pageRatio - imageRatio) < 0.02,
      `desain kustom ${orientation} tidak distorsi `
      + `(halaman ${pageRatio.toFixed(3)} vs gambar ${imageRatio.toFixed(3)})`);
  }

  // 4. Template PDF/PNG per orientasi.
  const templateLandscape = await svc.buildTemplatePdf({ orientation: 'landscape' });
  fs.writeFileSync(path.join(outDir, 'template-landscape.pdf'), templateLandscape);
  const templatePortrait = await svc.buildTemplatePdf({ orientation: 'portrait' });
  fs.writeFileSync(path.join(outDir, 'template-portrait.pdf'), templatePortrait);
  check(readPdfPageSize(templateLandscape).width > readPdfPageSize(templateLandscape).height,
    'template PDF landscape horizontal');
  check(readPdfPageSize(templatePortrait).height > readPdfPageSize(templatePortrait).width,
    'template PDF portrait vertikal');
  check(Boolean(svc.templatePathFor('png', 'portrait')), 'template PNG portrait tersedia');
  check(Boolean(svc.templatePathFor('png', 'landscape')), 'template PNG landscape tersedia');

  // 5. Validasi rasio unggahan terhadap orientasi.
  const landscapePng = templatePng('landscape');
  const portraitPng = templatePng('portrait');
  check(svc.validateUploadPayload({
    content_type: 'image/png',
    image_base64: portraitPng.buffer.toString('base64'),
    orientation: 'landscape',
  }).errors.some((item) => /landscape/i.test(item)),
  'unggah gambar portrait ke orientasi landscape ditolak');

  check(svc.validateUploadPayload({
    content_type: 'image/png',
    image_base64: landscapePng.buffer.toString('base64'),
    orientation: 'portrait',
  }).errors.some((item) => /portrait/i.test(item)),
  'unggah gambar landscape ke orientasi portrait ditolak');

  check(svc.validateUploadPayload({
    content_type: 'image/png',
    image_base64: portraitPng.buffer.toString('base64'),
    orientation: 'portrait',
  }).errors.length === 0, 'unggah gambar portrait ke orientasi portrait diterima');

  console.log(`\nPDF verifikasi ditulis ke ${outDir}`);
  if (failed > 0) process.exitCode = 1;
})().catch((error) => {
  console.error('FAILED', error);
  process.exitCode = 1;
});
