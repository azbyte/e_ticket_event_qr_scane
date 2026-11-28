/**
 * Regresi desain tiket (PRD §5).
 *
 * Menguji normalisasi & validasi payload desain, template PDF/PNG, rendering
 * tiket memakai desain kategori/event/default, serta normalisasi
 * `attendee_fields` pada respons event.
 */
process.env.NODE_ENV = 'test';
// Unit test normalisasi/validasi desain & rendering: tidak ada koneksi database.
// Variabel ini hanya memenuhi validasi startup `config/env.js`.
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const design = require('../src/services/ticketDesignService');
const { extractPdfLines, extractPdfText } = require('./helpers/pdfText');
const {
  parseAttendeeFields,
  serializeEvent,
} = require('../src/utils/eventResponse');

const TEMPLATE_PNG = path.join(
  __dirname, '..', 'assets', 'ticket-templates', 'ticket-template.png',
);
const TEMPLATE_LANDSCAPE_PNG = path.join(
  __dirname, '..', 'assets', 'ticket-templates', 'ticket-template-landscape.png',
);
const TEMPLATE_PORTRAIT_PNG = path.join(
  __dirname, '..', 'assets', 'ticket-templates', 'ticket-template-portrait.png',
);

const baseTicket = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'TKT-TEST-001',
  issued_at: new Date('2026-11-26T10:00:00.000Z').toISOString(),
  purchased_at: new Date('2026-11-26T10:00:00.000Z').toISOString(),
  event_title: 'Konser Uji',
  attendee_name: 'Peserta Uji',
  ticket_type_name: 'VIP',
  event_date: new Date('2026-12-01T12:00:00.000Z').toISOString(),
  location: 'Jakarta',
  order_number: 'ORD-UJI-1',
};

/**
 * Catatan: ekstraksi teks PDF memakai `./helpers/pdfText` karena font Times New
 * Roman kini TERTANAM sebagai subset TTF (teks ditulis sebagai glyph id dan
 * harus di-decode melalui `ToUnicode` CMap).
 */

test('validasi menolak format selain PNG/JPEG', () => {
  const { errors, value } = design.validateUploadPayload({
    content_type: 'image/gif',
    image_base64: '',
  });
  assert.equal(value, null);
  assert.ok(errors.some((item) => /PNG atau JPEG/.test(item)));
});

test('validasi menolak file di luar batas ukuran', () => {
  const { errors } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: Buffer.alloc(50).toString('base64'),
  });
  assert.ok(errors.some((item) => /terlalu kecil/.test(item)));
});

test('validasi menerima PNG nyata dengan tata letak kustom', () => {
  const png = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const { errors, value } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: png.toString('base64'),
    orientation: 'landscape',
    layout: {
      qr: { x: 0.7, y: 0.2, size: 0.3 },
      title: { x: 0.05, y: 0.05, font_size: 44, bold: true },
    },
  });
  assert.deepEqual(errors, []);
  assert.equal(value.contentType, 'image/png');
  assert.equal(value.orientation, 'landscape');
  assert.equal(value.layout.qr.x, 0.7);
  assert.equal(value.layout.qr.size, 0.3);
  // Elemen yang tidak dikirim memakai default orientasi.
  assert.equal(value.layout.ticket_id.font_size, 30);
  assert.equal(value.buffer.length, png.length);
});

test('validasi menolak tanda tangan file yang tidak cocok', () => {
  const { errors } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: Buffer.alloc(2048, 0x42).toString('base64'),
  });
  assert.ok(errors.some((item) => /tidak sesuai/.test(item)));
});

test('posisi QR di luar rentang ditolak', () => {
  const png = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const { errors } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: png.toString('base64'),
    orientation: 'landscape',
    qr: { x: 1.5, y: 0.2, size: 0.4 },
  });
  assert.ok(errors.some((item) => /Posisi X QR/.test(item)));
});

test('normalizeDesign mengabaikan path di luar folder media', () => {
  assert.equal(design.normalizeDesign({ file_path: '/etc/passwd' }), null);
  const normalized = design.normalizeDesign({
    file_path: '/media/ticket-designs/x/y.png',
    content_type: 'image/png',
  });
  assert.equal(normalized.file_path, '/media/ticket-designs/x/y.png');
  assert.equal(normalized.qr.x, design.DEFAULT_QR.x);
});

test('template PDF terbentuk dengan ukuran kanvas tetap', async () => {
  const buffer = await design.buildTemplatePdf({ title: 'Uji' });
  assert.ok(buffer.length > 500);
  assert.equal(buffer.subarray(0, 5).toString(), '%PDF-');
});

test('template PNG tersedia dan dimensinya terbaca', () => {
  const pngPath = design.templatePathFor('png');
  assert.ok(pngPath && fs.existsSync(pngPath));
  const size = design.readImageSize(fs.readFileSync(pngPath));
  // Template landscape = 2x kanvas 842x594 pt (1684x1188 px).
  assert.deepEqual(size, { width: 1684, height: 1188 });
});

test('template PNG mengikuti orientasi yang dipilih', () => {
  const landscape = design.readImageSize(fs.readFileSync(design.templatePathFor('png', 'landscape')));
  const portrait = design.readImageSize(fs.readFileSync(design.templatePathFor('png', 'portrait')));
  assert.ok(landscape.width > landscape.height, 'template landscape harus horizontal');
  assert.ok(portrait.height > portrait.width, 'template portrait harus vertikal');
});

test('template PDF mengikuti orientasi yang dipilih', async () => {
  const readPageSize = (buffer) => {
    const match = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
    return { width: Number(match[1]), height: Number(match[2]) };
  };
  const landscape = readPageSize(await design.buildTemplatePdf({ orientation: 'landscape' }));
  const portrait = readPageSize(await design.buildTemplatePdf({ orientation: 'portrait' }));
  assert.ok(landscape.width > landscape.height);
  assert.ok(portrait.height > portrait.width);
});

test('validasi menolak orientasi yang tidak dikenal', () => {
  const png = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const { errors } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: png.toString('base64'),
    orientation: 'diagonal',
  });
  assert.ok(errors.some((item) => /landscape.*portrait/.test(item)));
});

test('desain dengan rasio berlawanan orientasi ditolak agar tidak terpotong', () => {
  const portraitPng = fs.readFileSync(TEMPLATE_PORTRAIT_PNG);
  const asLandscape = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: portraitPng.toString('base64'),
    orientation: 'landscape',
  });
  assert.ok(asLandscape.errors.some((item) => /landscape/i.test(item)));

  const landscapePng = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const asPortrait = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: landscapePng.toString('base64'),
    orientation: 'portrait',
  });
  assert.ok(asPortrait.errors.some((item) => /portrait/i.test(item)));
});

test('tiket default portrait ter-render sebagai halaman vertikal', async () => {
  const buffer = await design.buildTicketPdf({
    ...baseTicket, event_ticket_orientation: 'portrait',
  });
  const match = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
  assert.ok(Number(match[2]) > Number(match[1]), 'halaman portrait harus lebih tinggi dari lebar');
});

test('ukuran halaman tetap per orientasi dan tidak bergantung file desain', () => {
  // Kanvas landscape wajib 842 x 594 pt; portrait tetap 440 x 704 pt.
  assert.deepEqual(design.pageSizeFor(null, 'landscape'), { width: 842, height: 594 });
  assert.deepEqual(design.pageSizeFor(null, 'portrait'), { width: 440, height: 704 });
  // Dimensi gambar desain TIDAK lagi mengubah ukuran halaman (dulu tinggi
  // halaman mengikuti rasio file sehingga tiket menjadi sangat pipih).
  assert.deepEqual(
    design.pageSizeFor({ width: 1200, height: 480 }, 'landscape'),
    { width: 842, height: 594 },
  );
  assert.deepEqual(
    design.pageSizeFor({ width: 880, height: 1408 }, 'portrait'),
    { width: 440, height: 704 },
  );
});

test('QR default landscape sesuai referensi dan tidak menutupi tulisan', () => {
  const layout = design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape;
  const qr = layout.qr;
  const side = qr.size * 594;
  // Sisi QR ± 251 pt (42,3% tinggi kanvas) seperti gambar referensi Canva.
  assert.ok(Math.abs(side - 251.3) < 1.5, `sisi QR ${side.toFixed(1)} pt`);
  assert.ok(qr.x < 0.1, 'QR berada di kiri bawah');
  assert.ok(qr.y > 0.3 && qr.y < 0.4, 'QR berada di bawah blok teks');
  // Kotak teks berakhir sebelum QR dimulai (tanpa tabrakan).
  const resolved = design.layoutSpec.resolveLayout(layout, {
    orientation: 'landscape',
    title: 'E-TIKET KONSER',
    ticketId: 'ID TIKET: ETK-6NGS2R',
  });
  assert.deepEqual(design.layoutSpec.findOverlaps(resolved), []);
  assert.ok(resolved.boxes.instruction.y + resolved.boxes.instruction.height
    <= resolved.qr.y, 'teks berakhir sebelum QR');
  // QR tetap di dalam halaman.
  assert.ok((qr.x * 842) + side <= 842, 'QR tidak keluar halaman (kanan)');
  assert.ok((qr.y * 594) + side <= 594, 'QR tidak keluar halaman (bawah)');
});

test('QR default portrait berada di bawah blok teks dan di dalam halaman', () => {
  const layout = design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.portrait;
  const qr = layout.qr;
  const side = qr.size * 704;
  assert.ok(side >= 220 && side <= 260, `sisi QR ${side.toFixed(1)} pt`);
  assert.ok(qr.x < 0.2, 'QR berada di kolom kiri');
  assert.ok(qr.y > 0.4, 'QR berada di bawah blok teks');
  const resolved = design.layoutSpec.resolveLayout(layout, {
    orientation: 'portrait',
    title: 'E-TIKET KONSER',
    ticketId: 'ID TIKET: ETK-6NGS2R',
  });
  assert.deepEqual(design.layoutSpec.findOverlaps(resolved), []);
  assert.ok((qr.y * 704) + side <= 704, 'QR tidak keluar halaman');
});

test('ukuran & posisi QR dari Organizer dipakai apa adanya saat render', () => {
  const frame = { x: 0, y: 0, width: 842, height: 594 };
  // Pengaturan Organizer: QR kecil di kanan bawah.
  const rect = design.qrRectFromFractions({ x: 0.7, y: 0.6, size: 0.3 }, frame);
  assert.equal(Math.round(rect.size), Math.round(0.3 * 594), 'ukuran mengikuti pengaturan');
  assert.equal(Math.round(rect.x), Math.round(0.7 * 842), 'posisi X mengikuti pengaturan');
  assert.equal(Math.round(rect.y), Math.round(0.6 * 594), 'posisi Y mengikuti pengaturan');

  // Posisi dekat tepi: QR digeser agar tetap utuh, TIDAK diperkecil diam-diam.
  const edge = design.qrRectFromFractions({ x: 0.9, y: 0.9, size: 0.3 }, frame);
  assert.equal(Math.round(edge.size), Math.round(0.3 * 594), 'ukuran tetap');
  assert.ok(edge.x + edge.size <= 842, 'QR tetap di dalam halaman (kanan)');
  assert.ok(edge.y + edge.size <= 594, 'QR tetap di dalam halaman (bawah)');

  // Ukuran di bawah batas pindai dinaikkan ke minimum yang aman.
  const tiny = design.qrRectFromFractions({ x: 0.1, y: 0.1, size: 0.16 }, frame);
  assert.equal(tiny.size, design.QR_MIN_POINTS);
});

test('validasi pengaturan QR menolak nilai di luar rentang', () => {
  assert.deepEqual(design.validateQrPlacement({ x: 0.2, y: 0.3, size: 0.4 }).errors, []);
  assert.ok(design.validateQrPlacement({ x: 1.2, y: 0.3, size: 0.4 })
    .errors.some((item) => /Posisi X QR/.test(item)));
  assert.ok(design.validateQrPlacement({ x: 0.2, y: -0.1, size: 0.4 })
    .errors.some((item) => /Posisi Y QR/.test(item)));
  assert.ok(design.validateQrPlacement({ x: 0.2, y: 0.3, size: 0.05 })
    .errors.some((item) => /Ukuran QR/.test(item)));
  // Batas atas 60%: QR yang lebih besar menutupi hampir seluruh desain tiket.
  assert.ok(design.validateQrPlacement({ x: 0.2, y: 0.3, size: 0.75 })
    .errors.some((item) => /Ukuran QR/.test(item)));
  assert.ok(design.validateQrPlacement(null)
    .errors.some((item) => /tidak valid/.test(item)));
});

test('applyLayoutPlacement memperbarui tata letak tanpa mengubah file desain', () => {
  const previous = design.normalizeDesign({
    file_path: '/media/ticket-designs/evt-1/desain.png',
    content_type: 'image/png',
    orientation: 'portrait',
    layout: design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.portrait,
  });
  const updated = design.applyLayoutPlacement(previous, {
    layout: {
      ...previous.layout,
      qr: { x: 0.3, y: 0.55, size: 0.3 },
      title: { x: 0.08, y: 0.05, font_size: 24, bold: true },
    },
  });
  assert.equal(updated.file_path, previous.file_path, 'file desain tidak berubah');
  assert.equal(updated.orientation, 'portrait', 'orientasi tidak berubah');
  assert.deepEqual(updated.layout.qr, { x: 0.3, y: 0.55, size: 0.3 });
  assert.equal(updated.layout.title.font_size, 24);
  // `qr` cermin tetap sinkron dengan `layout.qr`.
  assert.deepEqual(updated.qr, updated.layout.qr);
  // Konfigurasi tetap dapat dibuat walau belum ada desain tersimpan.
  const fresh = design.applyLayoutPlacement(null, {
    layout: design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape,
    orientation: 'landscape',
  });
  assert.equal(fresh.file_path, null);
  assert.equal(fresh.layout.title.font_size, 50);
});

test('tiket landscape default tepat 842 x 594 pt', async () => {
  const buffer = await design.buildTicketPdf(baseTicket);
  const match = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
  assert.equal(Number(match[1]), 842);
  assert.equal(Number(match[2]), 594);
});

test('tiket memakai nama acara & ID tiket dinamis dari data tiket', async () => {
  const buffer = await design.buildTicketPdf({
    ...baseTicket, ticket_code: 'ETK-7K4P9Q', event_title: 'Konser Uji',
  });
  const text = extractPdfText(buffer);
  assert.ok(text.includes('ETK-7K4P9Q'), 'ID tiket tampil di PDF');
  assert.ok(text.includes('KONSER UJI'), 'nama acara tampil di PDF (kapital)');
  // Judul diawali "E-TIKET" (referensi desain: E-TIKET [NAMA EVENT]).
  assert.match(text, /E-TIKET\s*KONSER UJI/, 'baris pertama E-TIKET [NAMA EVENT]');
  assert.match(text, /ID TIKET:\s*ETK-7K4P9Q/, 'baris kedua ID TIKET');
  assert.ok(
    text.includes('Silahkan tukarkan tiket di meja registrasi'),
    'instruksi penukaran sesuai referensi',
  );
});

test('tiket hanya mencetak tiga teks dinamis seperti referensi', async () => {
  const buffer = await design.buildTicketPdf(baseTicket);
  const text = extractPdfText(buffer);
  // Informasi administratif tidak dicetak pada tiket.
  assert.ok(!/No\. registrasi/i.test(text), 'nomor registrasi tidak dicetak');
  assert.ok(!/ORD-UJI-1/.test(text), 'nomor order tidak dicetak');
  assert.ok(!/Diterbitkan/i.test(text), 'tanggal terbit tidak dicetak');
  assert.ok(!/Berlaku untuk/i.test(text), 'kartu masa berlaku tidak dicetak');
  // Desain referensi tidak memuat nama peserta/kategori/jadwal/lokasi: teks
  // tambahan akan menutupi artwork dan membuat tata letak tidak sesuai.
  assert.ok(!/Peserta:/i.test(text), 'nama peserta tidak dicetak');
  assert.ok(!/Kategori:/i.test(text), 'kategori tidak dicetak');
  assert.ok(!/Jadwal:/i.test(text), 'jadwal tidak dicetak');
  assert.ok(!/Lokasi:/i.test(text), 'lokasi tidak dicetak');
  // Satu instruksi saja.
  const instructions = text.match(/Silahkan tukarkan tiket/gi) ?? [];
  assert.equal(instructions.length, 1, 'hanya satu instruksi penukaran');
});

test('tipografi tiket memakai ukuran referensi (judul 50, ID & instruksi 30)', async () => {
  const buffer = await design.buildTicketPdf({ ...baseTicket, event_title: 'Konser' });
  const lines = extractPdfLines(buffer);
  assert.equal(lines.length, 3, 'tiga baris teks (judul, ID tiket, instruksi)');

  const [title, id, instruction] = lines;
  assert.equal(title.text, 'E-TIKET KONSER');
  assert.equal(title.size, 50, 'judul 50 pt');
  assert.match(id.text, /^ID TIKET: /);
  assert.equal(id.size, 30, 'ID tiket 30 pt');
  assert.equal(instruction.text, 'Silahkan tukarkan tiket di meja registrasi');
  assert.equal(instruction.size, 30, 'instruksi 30 pt');
  // Semua baris rata kiri pada posisi yang sama (4,45% lebar kanvas).
  for (const line of lines) {
    assert.ok(Math.abs(line.x - 37.5) < 1, `x baris = ${line.x.toFixed(2)} pt`);
  }
  // Jarak antarbaris tidak bertumpuk dan blok teks berakhir sebelum QR.
  assert.ok(title.y > id.y && id.y > instruction.y, 'urutan baris benar');
  assert.ok(
    instruction.y - instruction.size > 594 - design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape.qr.y * 594,
    'blok teks berakhir di atas QR',
  );
});

test('nama event panjang dibungkus dan tetap di atas ID tiket', async () => {
  const buffer = await design.buildTicketPdf({
    ...baseTicket,
    event_title: 'Konferensi Nasional Teknologi Informasi dan Sistem Informasi Kesehatan 2026',
  });
  const lines = extractPdfLines(buffer);
  assert.ok(
    lines.some((line) => /^E-TIKET KONFERENSI NASIONAL/.test(line.text)),
    'judul tercetak',
  );
  // Judul menjadi beberapa baris, tetapi ID & instruksi tetap 30 pt.
  assert.ok(lines.length >= 5, `judul dibungkus (${lines.length} baris)`);
  const idLine = lines[lines.length - 2];
  const instructionLine = lines[lines.length - 1];
  assert.match(idLine.text, /^ID TIKET: /);
  assert.equal(idLine.size, 30, 'ID tiket tetap 30 pt');
  assert.equal(instructionLine.size, 30, 'instruksi tetap 30 pt');
  // Seluruh baris judul berada di atas ID tiket dan tidak terpotong elipsis.
  for (const line of lines.slice(0, lines.length - 2)) {
    assert.ok(line.y > idLine.y, 'baris judul di atas ID tiket');
    assert.ok(!line.text.includes('…'), 'judul tidak dipotong elipsis');
  }
});


test('teks informasi tambahan berada di kiri atas halaman', async () => {
  const buffer = await design.buildTicketPdf(baseTicket);
  const raw = buffer.toString('latin1');
  const zlib = require('node:zlib');
  const streams = [...raw.matchAll(/stream\r?\n([\s\S]*?)endstream/g)];
  const positions = [];
  for (const stream of streams) {
    const chunk = Buffer.from(stream[1], 'latin1');
    let content;
    try {
      content = zlib.inflateSync(chunk).toString('latin1');
    } catch (_error) {
      content = chunk.toString('latin1');
    }
    // PDFKit menulis matriks teks `1 0 0 1 <x> <y> Tm` (y dari bawah halaman).
    for (const match of content.matchAll(/1 0 0 1 ([\d.]+) ([\d.]+) Tm/g)) {
      positions.push({ x: Number(match[1]), y: Number(match[2]) });
    }
  }
  assert.ok(positions.length > 0, 'ada operasi teks di PDF');
  const qrTop = design.DEFAULT_QR_BY_ORIENTATION.landscape.y * 594;
  for (const position of positions) {
    assert.ok(position.x < 842 / 2, `teks di kolom kiri (x=${position.x})`);
    // y diukur dari bawah: seluruh blok teks berada di atas area QR.
    assert.ok(position.y > 594 - qrTop, `teks di bagian atas (y=${position.y})`);
  }
});


test('orientasi tersimpan dipakai walau belum ada file desain', async () => {
  const readPageSize = (buffer) => {
    const m = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
    return { width: Number(m[1]), height: Number(m[2]) };
  };
  const portrait = readPageSize(await design.buildTicketPdf({
    ...baseTicket, ticket_type_orientation: 'portrait',
  }));
  assert.ok(portrait.height > portrait.width, 'orientasi kategori portrait dipakai');
});

test('kategori tanpa orientasi mewarisi orientasi event', async () => {
  const readPageSize = (buffer) => {
    const m = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
    return { width: Number(m[1]), height: Number(m[2]) };
  };
  const inherited = readPageSize(await design.buildTicketPdf({
    ...baseTicket,
    ticket_type_orientation: null,
    event_ticket_orientation: 'portrait',
  }));
  assert.ok(inherited.height > inherited.width, 'kategori mewarisi portrait dari event');

  const explicitType = readPageSize(await design.buildTicketPdf({
    ...baseTicket,
    ticket_type_orientation: 'landscape',
    event_ticket_orientation: 'portrait',
  }));
  assert.ok(explicitType.width > explicitType.height,
    'orientasi eksplisit kategori menang atas event');
});

test('designOrientationOf membaca orientasi tanpa file desain', () => {
  assert.equal(design.designOrientationOf({ orientation: 'portrait' }), 'portrait');
  assert.equal(design.designOrientationOf({ orientation: 'landscape' }), 'landscape');
  assert.equal(design.designOrientationOf({}), null);
  assert.equal(design.designOrientationOf(null), null);
  assert.equal(design.designOrientationOf('bukan-objek'), null);
});

test('tiket default ter-render tanpa desain unggahan', async () => {
  const buffer = await design.buildTicketPdf(baseTicket);
  assert.equal(buffer.subarray(0, 5).toString(), '%PDF-');
  assert.ok(buffer.length > 5000);
});

test('tiket memakai desain event yang diunggah', async () => {
  const png = fs.readFileSync(TEMPLATE_PNG);
  const saved = await design.saveDesignImage({
    eventId: 'uji-desain',
    buffer: png,
    contentType: 'image/png',
  });
  try {
    const withDesign = await design.buildTicketPdf({
      ...baseTicket,
      event_ticket_design: {
        file_path: saved.filePath,
        content_type: 'image/png',
        layout: {
          ...design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape,
          qr: { x: 0.0713, y: 0.5791, size: 0.3199 },
        },
      },
    });
    const plain = await design.buildTicketPdf(baseTicket);
    assert.equal(withDesign.subarray(0, 5).toString(), '%PDF-');
    // Desain kustom TIDAK mengubah ukuran halaman: tetap 842 x 594 pt.
    const page = withDesign.toString('latin1')
      .match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
    assert.equal(Number(page[1]), 842);
    assert.equal(Number(page[2]), 594);
    // Gambar desain ikut tertanam sehingga PDF lebih besar dari default.
    assert.ok(withDesign.length > plain.length);
  } finally {
    await design.removeDesignFile(saved.filePath);
  }
});

test('desain kategori diprioritaskan di atas desain event', async () => {
  const png = fs.readFileSync(TEMPLATE_PNG);
  const savedType = await design.saveDesignImage({
    eventId: 'uji-prioritas',
    buffer: png,
    contentType: 'image/png',
  });
  try {
    const buffer = await design.buildTicketPdf({
      ...baseTicket,
      // Desain event menunjuk file yang tidak ada; yang dipakai harus kategori.
      event_ticket_design: {
        file_path: '/media/ticket-designs/hilang/x.png',
      },
      ticket_type_design: {
        file_path: savedType.filePath,
        content_type: 'image/png',
        layout: {
          ...design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape,
          qr: { x: 0.6, y: 0.3, size: 0.3 },
        },
      },
    });
    assert.equal(buffer.subarray(0, 5).toString(), '%PDF-');
    assert.ok(buffer.length > 5000);
  } finally {
    await design.removeDesignFile(savedType.filePath);
  }
});

test('desain kategori yang filenya hilang tidak menjatuhkan tiket ke desain default', async () => {
  const png = fs.readFileSync(TEMPLATE_PNG);
  const saved = await design.saveDesignImage({
    eventId: 'uji-fallback',
    buffer: png,
    contentType: 'image/png',
  });
  try {
    const withEventDesign = await design.buildTicketPdf({
      ...baseTicket,
      event_ticket_design: {
        file_path: saved.filePath,
        content_type: 'image/png',
        orientation: 'landscape',
        qr: { x: 0.3, y: 0.5, size: 0.3 },
      },
      // Desain kategori menunjuk file yang tidak ada: harus dilewati, BUKAN
      // membuat tiket memakai desain default sistem.
      ticket_type_design: {
        file_path: '/media/ticket-designs/hilang/tidak-ada.png',
        orientation: 'landscape',
      },
    });
    const plain = await design.buildTicketPdf(baseTicket);
    assert.equal(withEventDesign.subarray(0, 5).toString(), '%PDF-');
    // Gambar desain event tertanam → PDF lebih besar dari tiket default.
    assert.ok(withEventDesign.length > plain.length,
      'desain event dipakai saat desain kategori tidak terbaca');
  } finally {
    await design.removeDesignFile(saved.filePath);
  }
});

test('resolveDesignAsset memilih kandidat pertama yang filenya ada', async () => {
  const png = fs.readFileSync(TEMPLATE_PNG);
  const saved = await design.saveDesignImage({
    eventId: 'uji-resolve',
    buffer: png,
    contentType: 'image/png',
  });
  try {
    const missing = design.normalizeDesign({
      file_path: '/media/ticket-designs/hilang/x.png',
    });
    const existing = design.normalizeDesign({
      file_path: saved.filePath,
      orientation: 'landscape',
    });
    const resolved = await design.resolveDesignAsset([missing, existing]);
    assert.equal(resolved.design.file_path, saved.filePath);
    assert.ok(resolved.buffer.length > 0);
    assert.ok(resolved.imageSize.width > 0);

    const none = await design.resolveDesignAsset([missing, null]);
    assert.equal(none.design, null);
    assert.equal(none.buffer, null);
  } finally {
    await design.removeDesignFile(saved.filePath);
  }
});

test('validateLayout menolak tata letak yang bertumpuk atau keluar kanvas', () => {
  const spec = design.layoutSpec;
  const defaults = spec.DEFAULT_LAYOUT_BY_ORIENTATION.landscape;
  const texts = {
    orientation: 'landscape',
    title: 'E-TIKET KONSER',
    ticketId: 'ID TIKET: ETK-6NGS2R',
  };

  // Tata letak default valid.
  const ok = spec.validateLayout(spec.normalizeLayout(defaults), texts);
  assert.deepEqual(ok.errors, [], 'default tidak bertumpuk');

  // QR diperbesar ke tengah: menutupi instruksi.
  const overlapping = spec.normalizeLayout({
    ...defaults,
    qr: { x: 0.05, y: 0.16, size: 0.5 },
  });
  const bad = spec.validateLayout(overlapping, texts);
  assert.ok(
    bad.errors.some((error) => /QR Code menutupi/.test(error)),
    'tumpang tindih QR dengan tulisan dilaporkan',
  );

  // Elemen teks dipindah keluar kanvas.
  const outside = spec.normalizeLayout({
    ...defaults,
    instruction: { x: 0.9, y: 0.9, font_size: 30, bold: false },
  });
  const outOfCanvas = spec.validateLayout(outside, texts);
  assert.ok(
    outOfCanvas.errors.some((error) => /keluar dari batas kanvas/.test(error)),
    'elemen di luar kanvas dilaporkan',
  );
});

test('fitTextElement mempertahankan ukuran referensi bila teks muat', () => {
  const spec = design.layoutSpec;
  const element = { font_size: 50, bold: true };
  const fitted = spec.fitTextElement('E-TIKET KONSER', element, {
    maxWidth: 505.2,
    maxHeight: 200,
    maxLines: 2,
    lineLimit: 3,
  });
  assert.equal(fitted.fontSize, 50, 'judul tetap 50 pt untuk teks pendek');
  assert.equal(fitted.lines.length, 1);
  assert.equal(fitted.truncated, false);
});

test('removeDesignFile menolak path di luar penyimpanan', async () => {
  assert.equal(await design.removeDesignFile('/etc/passwd'), false);
  assert.equal(await design.removeDesignFile(null), false);
});

test('saveDesignImage menolak id event yang dapat keluar dari folder desain', async () => {
  const png = fs.readFileSync(TEMPLATE_PNG);
  await assert.rejects(
    () => design.saveDesignImage({ eventId: '../keluar', buffer: png, contentType: 'image/png' }),
    /Id event tidak valid/,
  );
  await assert.rejects(
    () => design.saveDesignImage({ eventId: 'C:\\temp', buffer: png, contentType: 'image/png' }),
    /Id event tidak valid/,
  );
  await assert.rejects(
    () => design.saveDesignImage({ eventId: 'uji-desain', buffer: png, contentType: 'image/gif' }),
    /PNG atau JPEG/,
  );
});

test('designAbsolutePath menolak folder saudara dan folder desain itu sendiri', () => {
  // `startsWith` saja akan meloloskan folder `ticket-designs-lama`; path harus
  // benar-benar berada DI DALAM folder desain.
  assert.equal(
    design.designAbsolutePath({ file_path: '/media/ticket-designs/../ticket-designs-lama/x.png' }),
    null,
  );
  assert.equal(design.designAbsolutePath({ file_path: '/media/ticket-designs/' }), null);
  const inside = design.designAbsolutePath({ file_path: '/media/ticket-designs/event-1/x.png' });
  assert.ok(inside && inside.startsWith(design.STORAGE_ROOT));
});

test('readImageSize membaca JPEG yang memakai fill byte sebelum SOF', () => {
  const jpeg = Buffer.concat([
    Buffer.from([0xff, 0xd8]), // SOI
    Buffer.from([0xff, 0xe0, 0x00, 0x10]), // APP0, panjang 16
    Buffer.alloc(14, 0x00),
    Buffer.from([0xff, 0xff]), // fill byte sebelum marker berikutnya
    // SOF0: panjang 17, presisi 8, tinggi 0x0580 (1408), lebar 0x0370 (880)
    Buffer.from([0xff, 0xc0, 0x00, 0x11, 0x08, 0x05, 0x80, 0x03, 0x70]),
    Buffer.alloc(12, 0x00),
  ]);
  assert.deepEqual(design.readImageSize(jpeg), { width: 880, height: 1408 });
});

test('readImageSize menolak PNG tanpa chunk IHDR', () => {
  const fake = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    Buffer.from([0x00, 0x00, 0x00, 0x0d]),
    Buffer.from('IDAT', 'latin1'),
    Buffer.alloc(16, 0x00),
  ]);
  assert.equal(design.readImageSize(fake), null);
});

test('validasi menolak payload base64 raksasa sebelum di-decode', () => {
  // ±3 MB teks base64: bila di-decode lebih dulu, error akan menumpuk
  // (ukuran, tanda tangan file, dan dimensi). Cukup satu error ukuran.
  const { errors, value } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: 'A'.repeat(3 * 1024 * 1024),
    orientation: 'landscape',
  });
  assert.equal(value, null);
  assert.deepEqual(errors, ['Ukuran desain tiket melebihi 2 MB.']);
});

test('content type bernama properti bawaan objek tidak dianggap sah', () => {
  const png = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const { errors } = design.validateUploadPayload({
    content_type: 'constructor',
    image_base64: png.toString('base64'),
    orientation: 'landscape',
  });
  assert.ok(errors.some((item) => /PNG atau JPEG/.test(item)));
  const normalized = design.normalizeDesign({
    file_path: '/media/ticket-designs/x/y.png',
    content_type: 'constructor',
  });
  assert.equal(normalized.content_type, 'image/png');
});

test('template PNG portrait tidak memakai fallback template landscape', () => {
  const portrait = design.templatePathFor('png', 'portrait');
  assert.ok(portrait && /ticket-template-portrait\.png$/.test(portrait.replace(/\\/g, '/')));
});

test('attendee_fields berbentuk teks JSON tetap dikirim sebagai array', () => {
  assert.deepEqual(parseAttendeeFields('[{"key":"name"}]'), [{ key: 'name' }]);
  assert.deepEqual(parseAttendeeFields(null), []);
  assert.deepEqual(parseAttendeeFields('bukan json'), []);
});

test('serializeEvent menormalkan attendee_fields dan public_url', () => {
  const event = serializeEvent({
    id: 'abc',
    status: 'PUBLISHED',
    event_format: 'OFFLINE',
    is_public: true,
    created_by: 'user-1',
    event_date: '2026-12-01T00:00:00.000Z',
    attendee_fields: '[{"key":"name","required":true}]',
    event_categories: [{ name: 'Seminar' }],
    review_note: null,
  });
  // Email adalah media pengiriman e-ticket: selalu ditambahkan dan wajib,
  // walau konfigurasi lama hanya menyimpan `name`.
  assert.deepEqual(event.attendee_fields.map((field) => field.key), ['name', 'email']);
  assert.equal(event.attendee_fields[0].required, true);
  assert.equal(event.attendee_fields[1].required, true);
  assert.equal(event.attendee_fields[1].type, 'text');
  assert.ok(event.public_url.endsWith('/e/abc'));
  assert.equal(event.organizer_id, 'user-1');
});
