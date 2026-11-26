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

test('validasi menerima PNG nyata dengan posisi QR kustom', () => {
  const png = fs.readFileSync(TEMPLATE_LANDSCAPE_PNG);
  const { errors, value } = design.validateUploadPayload({
    content_type: 'image/png',
    image_base64: png.toString('base64'),
    orientation: 'landscape',
    qr: { x: 0.7, y: 0.2, size: 0.4 },
  });
  assert.deepEqual(errors, []);
  assert.equal(value.contentType, 'image/png');
  assert.equal(value.orientation, 'landscape');
  assert.equal(value.qr.x, 0.7);
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
  assert.deepEqual(size, { width: 1200, height: 480 });
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

test('nama event dari data tiket dipakai apa adanya (tidak diganti placeholder)', () => {
  assert.equal(design.pageSizeFor(null, 'portrait').height, 704);
  assert.deepEqual(design.pageSizeFor({ width: 1000, height: 400 }, 'landscape'),
    { width: 720, height: 288 });
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
        qr: { x: 0.74, y: 0.25, size: 0.5 },
        info: design.DEFAULT_INFO,
      },
    });
    const plain = await design.buildTicketPdf(baseTicket);
    assert.equal(withDesign.subarray(0, 5).toString(), '%PDF-');
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
        qr: { x: 0.6, y: 0.3, size: 0.3 },
        info: design.DEFAULT_INFO,
      },
    });
    assert.equal(buffer.subarray(0, 5).toString(), '%PDF-');
    assert.ok(buffer.length > 5000);
  } finally {
    await design.removeDesignFile(savedType.filePath);
  }
});

test('removeDesignFile menolak path di luar penyimpanan', async () => {
  assert.equal(await design.removeDesignFile('/etc/passwd'), false);
  assert.equal(await design.removeDesignFile(null), false);
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
