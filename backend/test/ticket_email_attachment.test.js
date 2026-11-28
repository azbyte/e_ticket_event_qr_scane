/**
 * Lampiran email tiket memakai renderer & tata letak yang SAMA dengan unduhan
 * PDF peserta.
 *
 * Regresi penting: PDF yang dikirim lewat email tidak boleh berbeda dari PDF
 * yang diunduh peserta (posisi tulisan, ukuran huruf, QR). Test ini memanggil
 * jalur nyata `emailService.buildPdfAttachment` (tanpa SMTP) dengan database
 * distub, lalu membandingkan hasilnya dengan `buildTicketPdf` langsung.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const dbPath = require.resolve('../src/config/db');
const ticketCodePath = require.resolve('../src/services/ticketCodeService');

const ticketRow = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'ETK-7K4P9Q',
  status: 'active',
  event_id: 'evt-1',
  ticket_type_id: 'tt-1',
  purchased_at: '2026-11-26T10:00:00.000Z',
  issued_at: '2026-11-26T10:00:00.000Z',
  qr_code_data: null,
  attendee_name: 'Aziz Azman Faza',
  attendee_email: 'peserta@example.test',
  ticket_type_name: 'VIP',
  ticket_type_design: null,
  ticket_type_orientation: null,
  // Judul pendek agar ukuran huruf tersimpan (44 pt) dipakai apa adanya.
  event_title: 'Konser',
  event_date: '2026-12-01T12:00:00.000Z',
  end_date_time: null,
  location: 'Jakarta Convention Center',
  online_url: null,
  organizer_name: 'Tech Fest Indonesia',
  // Tata letak kustom tersimpan: membuktikan lampiran email memakai konfigurasi
  // yang sama dengan editor (bukan default yang di-hardcode).
  event_ticket_design: {
    orientation: 'landscape',
    layout: {
      panel_split: 0.558,
      text_width: 0.6,
      title: { x: 0.05, y: 0.04, font_size: 44, bold: true },
      ticket_id: { x: 0.05, y: 0.16, font_size: 26, bold: false },
      instruction: { x: 0.05, y: 0.23, font_size: 26, bold: false },
      qr: { x: 0.42, y: 0.34, size: 0.3 },
    },
  },
  event_ticket_orientation: 'landscape',
  order_number: 'ORD-20261126-0001',
};

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    query: async () => [],
    getOne: async () => ticketRow,
    pool: { end: async () => {} },
  },
};

require.cache[ticketCodePath] = {
  id: ticketCodePath,
  filename: ticketCodePath,
  loaded: true,
  exports: {
    ensurePublicTicketCode: async () => 'ETK-7K4P9Q',
    generatePublicTicketCode: () => 'ETK-7K4P9Q',
    isPublicTicketCode: () => true,
    PUBLIC_TICKET_CODE_PREFIX: 'ETK-',
  },
};

const emailService = require('../src/services/emailService');
const design = require('../src/services/ticketDesignService');
const { extractPdfLines } = require('../tools/pdf-text');

test('lampiran email memakai tata letak desain yang sama dengan PDF unduhan', async () => {
  const { attachment, error } = await emailService.buildPdfAttachment(ticketRow.id);
  assert.equal(error, null);
  assert.ok(attachment, 'lampiran PDF terbentuk');
  assert.equal(attachment.contentType, 'application/pdf');
  assert.equal(attachment.filename, 'E-TIKET Aziz Azman Faza.pdf');

  // PDF unduhan langsung dari renderer yang sama.
  const direct = await design.buildTicketPdf(ticketRow);
  const emailLines = extractPdfLines(attachment.content);
  const directLines = extractPdfLines(direct);

  assert.deepEqual(emailLines, directLines,
    'isi & posisi teks lampiran identik dengan PDF unduhan');
  assert.equal(emailLines.length, 3, 'tiga baris teks');
  // Ukuran huruf mengikuti konfigurasi tata letak tersimpan (44/26/26).
  assert.deepEqual(emailLines.map((line) => line.size), [44, 26, 26]);
  assert.equal(emailLines[0].text, 'E-TIKET KONSER');
  assert.match(emailLines[1].text, /^ID TIKET: ETK-7K4P9Q$/);
  assert.equal(emailLines[2].text, 'Silahkan tukarkan tiket di meja registrasi');

  const size = (buffer) => {
    const match = buffer.toString('latin1').match(/\/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/);
    return { width: Number(match[1]), height: Number(match[2]) };
  };
  assert.deepEqual(size(attachment.content), size(direct));
  assert.deepEqual(size(attachment.content), { width: 842, height: 594 });
});
