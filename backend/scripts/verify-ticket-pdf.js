/**
 * Skrip verifikasi visual + teknis e-tiket (bukan bagian `npm test`).
 *
 * Yang diverifikasi:
 *  1. tiket default landscape TEPAT 842 x 594 pt,
 *  2. tiket default portrait 440 x 704 pt (dukungan portrait tidak rusak),
 *  3. desain kustom resmi memakai kanvas tetap tanpa distorsi,
 *  4. desain lama rasio 2.5:1 tetap tercetak utuh (kompatibilitas),
 *  5. pengaturan posisi & ukuran QR Organizer benar-benar dipakai saat render,
 *  6. desain kategori yang filenya hilang TIDAK jatuh ke desain default,
 *  7. template PDF/PNG mengikuti orientasi,
 *  8. unggahan dengan rasio yang salah ditolak validasi,
 *  9. nama file lampiran `E-TIKET Nama Peserta.pdf` untuk berbagai nama,
 * 10. tata letak referensi: tujuh baris informasi bertipografi besar di kiri atas,
 *     QR ukuran medium di bawahnya, dan tidak ada informasi administratif
 *     berulang.
 *
 * Jalankan dari `backend/`: npm run verify:ticket-pdf
 * (hasil ditulis ke `backend/_verify-out/`, folder diabaikan git)
 */
const fs = require('node:fs');
const path = require('node:path');
const svc = require('../src/services/ticketDesignService');
const { ticketPdfFilename, pdfContentDisposition } = require('../src/utils/ticketFilename');

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

/** Dekompresi semua content stream PDF lalu gabungkan sebagai teks latin1. */
const inflateStreams = (buffer) => {
  const zlib = require('node:zlib');
  const raw = buffer.toString('latin1');
  const parts = [];
  const streamRe = /stream\r?\n([\s\S]*?)endstream/g;
  let match;
  while ((match = streamRe.exec(raw)) !== null) {
    const chunk = Buffer.from(match[1], 'latin1');
    try {
      parts.push(zlib.inflateSync(chunk).toString('latin1'));
    } catch (_error) {
      parts.push(chunk.toString('latin1'));
    }
  }
  return parts.join('\n');
};

/** Teks yang dapat dibaca dari PDF (string hex di dalam blok BT..ET). */
const extractPdfText = (buffer) => {
  const content = inflateStreams(buffer);
  const texts = [];
  for (const block of content.match(/BT[\s\S]*?ET/g) || []) {
    let line = '';
    for (const hex of block.match(/<([0-9A-Fa-f\s]+)>/g) || []) {
      const clean = hex.slice(1, -1).replace(/\s+/g, '');
      if (clean.length % 2 !== 0) continue;
      line += Buffer.from(clean, 'hex').toString('latin1');
    }
    if (line) texts.push(line);
  }
  return texts.join(' ');
};

/** Posisi semua matriks teks `1 0 0 1 x y Tm` (y dari bawah halaman). */
const textPositions = (buffer) => {
  const content = inflateStreams(buffer);
  const positions = [];
  for (const match of content.matchAll(/1 0 0 1 ([\d.]+) ([\d.]+) Tm/g)) {
    positions.push({ x: Number(match[1]), y: Number(match[2]) });
  }
  return positions;
};

/** Ukuran font tiap baris teks: pasangan `Tm` lalu `Tf` (pt). */
const textRows = (buffer) => {
  const content = inflateStreams(buffer);
  return [...content.matchAll(/1 0 0 1 ([\d.]+) ([\d.]+) Tm\s*\/\w+ ([\d.]+) Tf/g)]
    .map((match) => ({
      x: Number(match[1]),
      y: Number(match[2]),
      size: Number(match[3]),
    }));
};

/**
 * Verifikasi tata letak tiket pada satu PDF:
 * teks hanya di kiri atas, QR medium tepat di bawah teks, tujuh baris informasi
 * dengan tipografi besar & hierarkis, dan tidak ada informasi administratif
 * berulang.
 */
const checkReferenceLayout = (buffer, {
  label, width, height, qr, minTitle = 29,
}) => {
  const text = extractPdfText(buffer);
  const positions = textPositions(buffer);
  const rows = textRows(buffer);
  check(positions.length > 0, `${label}: PDF memuat teks informasi`);
  check(
    positions.every((pos) => pos.x < width * 0.35),
    `${label}: semua teks berada di kolom kiri (x maks `
    + `${Math.max(...positions.map((p) => p.x)).toFixed(1)} pt)`,
  );
  check(
    positions.every((pos) => pos.y > height - qr.y),
    `${label}: semua teks berada di atas area QR (y min `
    + `${Math.min(...positions.map((p) => p.y)).toFixed(1)} pt dari bawah)`,
  );
  check(
    /E-TIKET\s*Tech Fest 2026/.test(text) && /ID TIKET:\s*ETK-7K4P9Q/.test(text),
    `${label}: baris "E-TIKET [NAMA EVENT]" dan "ID TIKET: ..." tercetak`,
  );
  check(
    /Peserta:\s*Aziz Azman Faza/.test(text) && /Kategori:\s*VIP/.test(text)
    && /Jadwal:\s*\w+/.test(text) && /Lokasi:\s*Jakarta/.test(text),
    `${label}: peserta, kategori, jadwal, dan lokasi tercetak`,
  );
  check(
    (text.match(/Silakan tukarkan tiket/gi) ?? []).length === 1,
    `${label}: hanya satu instruksi penukaran tiket`,
  );
  check(
    !/No\. registrasi|ORD-20261126-0001|Diterbitkan|Berlaku untuk/i.test(text),
    `${label}: tanpa nomor registrasi / tanggal terbit / kartu informasi`,
  );
  // Tipografi: hierarki 34/23/16/16/16/16/14 pt (naik dari 31/17,5/15,5/13,5).
  check(rows.length === 7, `${label}: tujuh baris informasi (${rows.length})`);
  if (rows.length === 7) {
    const [title, attendee, id, category, schedule, location, instruction] =
      rows.map((row) => row.size);
    check(title >= minTitle, `${label}: judul ${title.toFixed(1)} pt (>= ${minTitle} pt)`);
    check(attendee >= 21, `${label}: nama peserta ${attendee.toFixed(1)} pt (>= 21 pt)`);
    check(id >= 16, `${label}: ID tiket ${id.toFixed(1)} pt (>= 16 pt)`);
    check(category >= 16, `${label}: kategori ${category.toFixed(1)} pt (>= 16 pt)`);
    check(schedule >= 16, `${label}: jadwal ${schedule.toFixed(1)} pt (>= 16 pt)`);
    check(location >= 16, `${label}: lokasi ${location.toFixed(1)} pt (>= 16 pt)`);
    check(instruction >= 13.5,
      `${label}: instruksi ${instruction.toFixed(1)} pt (>= 13,5 pt)`);
    check(title > attendee && attendee > id && id > instruction,
      `${label}: hierarki ${title.toFixed(1)} > ${attendee.toFixed(1)} > `
      + `${id.toFixed(1)} > ${instruction.toFixed(1)} pt`);
    // Blok teks berakhir sebelum QR: baris terakhir + tinggi baris < QR top.
    const lastRow = rows[rows.length - 1];
    check(height - lastRow.y < qr.y,
      `${label}: blok teks berakhir ${(height - lastRow.y).toFixed(1)} pt, `
      + `QR mulai ${qr.y.toFixed(1)} pt (tidak bertumpuk)`);
  }
  // QR ukuran medium: 200-240 pt (landscape) / 220-260 pt (portrait).
  check(qr.size >= 200 && qr.size <= 260, `${label}: QR medium (${qr.size.toFixed(0)} pt)`);
  check(
    qr.y >= 150 && qr.y < height * 0.65,
    `${label}: QR tepat di bawah blok teks (y=${qr.y.toFixed(0)} pt)`,
  );
  check(
    qr.x + qr.size + svc.QR_BACKING_PAD <= width
    && qr.y + qr.size + svc.QR_BACKING_PAD <= height,
    `${label}: QR dan alas putihnya tidak keluar halaman`,
  );
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
  ticket_code: 'ETK-7K4P9Q',
  issued_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  purchased_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  event_title: 'Tech Fest 2026',
  attendee_name: 'Aziz Azman Faza',
  ticket_type_name: 'VIP',
  event_date: new Date('2026-12-01T12:00:00Z').toISOString(),
  location: 'Jakarta Convention Center',
  organizer_name: 'Tech Fest Indonesia',
  order_number: 'ORD-20261126-0001',
  qr_code_data: 'ETK-7K4P9Q',
};

/** PNG solid berukuran bebas (menguji desain lama rasio 2.5:1). */
const solidPng = (width, height) => {
  const zlib = require('node:zlib');
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const rowStart = y * (width * 3 + 1);
    raw[rowStart] = 0;
    for (let x = 0; x < width; x += 1) {
      const offset = rowStart + 1 + x * 3;
      raw[offset] = 0xf2;
      raw[offset + 1] = 0xe2;
      raw[offset + 2] = 0xca;
    }
  }
  const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'latin1'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body) >>> 0);
    return Buffer.concat([length, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
};

(async () => {
  // 1 & 2. Tiket default untuk kedua orientasi (dimensi wajib).
  const plainLandscape = await svc.buildTicketPdf(ticket);
  fs.writeFileSync(path.join(outDir, 'ticket-landscape-default.pdf'), plainLandscape);
  const plainLandscapeSize = readPdfPageSize(plainLandscape);
  check(plainLandscapeSize?.width === 842 && plainLandscapeSize?.height === 594,
    `default landscape tepat 842x594 pt (${plainLandscapeSize?.width}x${plainLandscapeSize?.height})`);
  checkReferenceLayout(plainLandscape, {
    label: 'default landscape',
    width: 842,
    height: 594,
    qr: {
      x: svc.DEFAULT_QR_BY_ORIENTATION.landscape.x * 842,
      y: svc.DEFAULT_QR_BY_ORIENTATION.landscape.y * 594,
      size: svc.DEFAULT_QR_BY_ORIENTATION.landscape.size * 594,
    },
  });

  const plainPortrait = await svc.buildTicketPdf({
    ...ticket, event_ticket_orientation: 'portrait',
  });
  fs.writeFileSync(path.join(outDir, 'ticket-portrait-default.pdf'), plainPortrait);
  const plainPortraitSize = readPdfPageSize(plainPortrait);
  check(plainPortraitSize?.width === 440 && plainPortraitSize?.height === 704,
    `default portrait tepat 440x704 pt (${plainPortraitSize?.width}x${plainPortraitSize?.height})`);
  checkReferenceLayout(plainPortrait, {
    label: 'default portrait',
    width: 440,
    height: 704,
    // Kanvas portrait lebih sempit (344 pt), sehingga judul memakai ukuran
    // terbesar yang masih muat satu baris utuh (±28 pt).
    minTitle: 27,
    qr: {
      x: svc.DEFAULT_QR_BY_ORIENTATION.portrait.x * 440,
      y: svc.DEFAULT_QR_BY_ORIENTATION.portrait.y * 704,
      size: svc.DEFAULT_QR_BY_ORIENTATION.portrait.size * 704,
    },
  });

  // 3. Desain kustom: kanvas tetap, gambar tidak distorsi.
  for (const orientation of svc.ORIENTATIONS) {
    const { buffer, size } = templatePng(orientation);
    const design = await saveDesign('verify-orientation', buffer, orientation);
    const pdf = await svc.buildTicketPdf({ ...ticket, event_ticket_design: design });
    fs.writeFileSync(path.join(outDir, `ticket-${orientation}-custom.pdf`), pdf);
    const page = readPdfPageSize(pdf);
    const expected = svc.ORIENTATION_SPEC[orientation];
    check(page.width === expected.width && page.height === expected.height,
      `desain kustom ${orientation} memakai kanvas ${expected.width}x${expected.height} pt `
      + `(${page.width}x${page.height})`);
    check(Math.abs((size.width / size.height) - (page.width / page.height)) < 0.02,
      `desain kustom ${orientation} tidak distorsi `
      + `(gambar ${(size.width / size.height).toFixed(3)} vs kanvas ${(page.width / page.height).toFixed(3)})`);
  }

  // 3b. Kompatibilitas desain lama 2.5:1 (rasio di luar kanvas baru).
  const legacyDesign = await saveDesign('verify-legacy', solidPng(1200, 480), 'landscape');
  const legacyPdf = await svc.buildTicketPdf({ ...ticket, event_ticket_design: legacyDesign });
  fs.writeFileSync(path.join(outDir, 'ticket-landscape-legacy-ratio.pdf'), legacyPdf);
  const legacyPage = readPdfPageSize(legacyPdf);
  check(legacyPage.width === 842 && legacyPage.height === 594,
    `desain lama 2.5:1 tetap dicetak pada kanvas 842x594 pt `
    + `(${legacyPage.width}x${legacyPage.height})`);

  // 3c. Pengaturan QR dari Organizer benar-benar dipakai saat render.
  {
    const { buffer } = templatePng('landscape');
    const saved = await svc.saveDesignImage({
      eventId: 'verify-qr-settings', buffer, contentType: 'image/png',
    });
    try {
      const customQr = { x: 0.55, y: 0.15, size: 0.25 };
      const pdf = await svc.buildTicketPdf({
        ...ticket,
        event_ticket_design: {
          source: 'upload',
          template: 'custom',
          file_path: saved.filePath,
          content_type: 'image/png',
          orientation: 'landscape',
          qr: customQr,
          info: svc.DEFAULT_INFO_BY_ORIENTATION.landscape,
        },
      });
      fs.writeFileSync(path.join(outDir, 'ticket-landscape-custom-qr.pdf'), pdf);
      const rect = svc.qrRectFromFractions(customQr, { x: 0, y: 0, width: 842, height: 594 });
      check(Math.round(rect.size) === Math.round(customQr.size * 594),
        `pengaturan ukuran QR Organizer dipakai (${rect.size.toFixed(0)} pt)`);
      check(Math.round(rect.x) === Math.round(customQr.x * 842)
        && Math.round(rect.y) === Math.round(customQr.y * 594),
      `pengaturan posisi QR Organizer dipakai (${rect.x.toFixed(0)}, ${rect.y.toFixed(0)})`);
    } finally {
      await svc.removeDesignFile(saved.filePath);
    }
  }

  // 3d. Desain kategori yang filenya hilang TIDAK boleh jatuh ke desain default:
  // desain event yang valid tetap dipakai.
  {
    const { buffer } = templatePng('landscape');
    const saved = await svc.saveDesignImage({
      eventId: 'verify-fallback', buffer, contentType: 'image/png',
    });
    try {
      const pdf = await svc.buildTicketPdf({
        ...ticket,
        event_ticket_design: {
          file_path: saved.filePath,
          content_type: 'image/png',
          orientation: 'landscape',
          qr: svc.DEFAULT_QR_BY_ORIENTATION.landscape,
          info: svc.DEFAULT_INFO_BY_ORIENTATION.landscape,
        },
        ticket_type_design: { file_path: '/media/ticket-designs/hilang/x.png' },
      });
      const plainPdf = await svc.buildTicketPdf(ticket);
      check(pdf.length > plainPdf.length,
        'desain event tetap dipakai saat file desain kategori hilang');
    } finally {
      await svc.removeDesignFile(saved.filePath);
    }
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

  check(svc.validateUploadPayload({
    content_type: 'image/png',
    image_base64: landscapePng.buffer.toString('base64'),
    orientation: 'landscape',
  }).errors.length === 0, 'unggah gambar landscape ke orientasi landscape diterima');

  // 6. Nama file lampiran `E-TIKET Nama Peserta.pdf`.
  const nameCases = [
    ['Aziz', 'E-TIKET Aziz.pdf'],
    ['Budi Santoso', 'E-TIKET Budi Santoso.pdf'],
    ['Muhammad Rizky Pratama Putra', 'E-TIKET Muhammad Rizky Pratama Putra.pdf'],
    ['  Spasi   Berlebih   ', 'E-TIKET Spasi Berlebih.pdf'],
    ['Nama/Anak:Uji?', 'E-TIKET Nama Anak Uji.pdf'],
    ['Zoë Álvarez', 'E-TIKET Zoë Álvarez.pdf'],
    ['', 'E-TIKET Peserta.pdf'],
  ];
  for (const [input, expected] of nameCases) {
    const actual = ticketPdfFilename(input);
    check(actual === expected, `nama file "${input || '(kosong)'}" -> "${actual}"`);
  }
  const disposition = pdfContentDisposition('Aziz Azman Faza');
  check(/filename="E-TIKET Aziz Azman Faza\.pdf"/.test(disposition)
    && /filename\*=UTF-8''E-TIKET%20Aziz%20Azman%20Faza\.pdf/.test(disposition),
  `Content-Disposition memakai format wajib (${disposition})`);

  console.log(`\nPDF verifikasi ditulis ke ${outDir}`);
  if (failed > 0) process.exitCode = 1;
})().catch((error) => {
  console.error('FAILED', error);
  process.exitCode = 1;
});
