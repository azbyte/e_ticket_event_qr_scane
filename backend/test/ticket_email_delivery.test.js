/**
 * Regresi pengiriman e-ticket (PRD §7 / kriteria tiket by email).
 *
 * Menguji aturan yang sebelumnya rusak:
 *  - nama event pada subjek & isi email diambil dari data tiket (bukan kosong),
 *  - transport uji (SMTP_HOST=json) TIDAK boleh mengklaim status SENT,
 *  - SMTP_HOST=json di luar NODE_ENV=test dianggap tidak aktif,
 *  - lampiran PDF wajib ada pada email,
 *  - email berisi data peserta & kode tiket yang benar.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const email = require('../src/services/emailService');

const ticketRow = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'TKT-EMAIL-001',
  event_id: '22222222-2222-4222-8222-222222222222',
  attendee_name: 'Peserta Email',
  attendee_email: 'peserta.asli@example.com',
  ticket_type_name: 'Reguler',
  event_title: 'Konser Nama Event Asli',
  event_date: new Date('2026-12-24T15:00:00.000Z'),
  location: 'Jakarta',
};

test('subjek email memuat nama event asli dan kode tiket', () => {
  const message = email.buildMessage(ticketRow, ticketRow.attendee_email);
  assert.match(message.subject, /Konser Nama Event Asli/);
  assert.match(message.subject, /TKT-EMAIL-001/);
  assert.match(message.text, /Konser Nama Event Asli/);
  assert.match(message.html, /Konser Nama Event Asli/);
  assert.equal(message.to, 'peserta.asli@example.com');
});

test('nama event kosong tidak menghasilkan "undefined" di email', () => {
  const message = email.buildMessage(
    { ...ticketRow, event_title: null }, ticketRow.attendee_email,
  );
  assert.doesNotMatch(message.text + message.html + message.subject, /undefined|null/);
  assert.match(message.subject, /E-Ticket/);
});

test('lampiran PDF wajib muncul pada pesan email', () => {
  // Nama lampiran mengikuti format wajib `E-TIKET Nama Peserta.pdf`.
  const attachment = {
    filename: 'E-TIKET Peserta Email.pdf',
    content: Buffer.from('%PDF-1.4 uji'),
    contentType: 'application/pdf',
  };
  const withAttachment = email.buildMessage(ticketRow, ticketRow.attendee_email, { attachment });
  assert.equal(withAttachment.attachments.length, 1);
  assert.equal(withAttachment.attachments[0].contentType, 'application/pdf');
  assert.equal(withAttachment.attachments[0].filename, 'E-TIKET Peserta Email.pdf');
  assert.match(withAttachment.text, /terlampir/);
});

test('mode transport jujur: SMTP_HOST=json hanya aktif di NODE_ENV=test', () => {
  const original = process.env.SMTP_HOST;
  // `.env` proyek dapat mengunci EMAIL_PROVIDER (mis. `brevo`). Pengujian ini
  // menguji perilaku yang ditentukan SMTP_HOST, jadi provider eksplisit harus
  // dilepas dulu lalu dikembalikan seperti semula.
  const originalProvider = process.env.EMAIL_PROVIDER;
  delete process.env.EMAIL_PROVIDER;
  process.env.SMTP_HOST = 'json';
  process.env.NODE_ENV = 'test';
  assert.equal(email.transportMode(), 'json');

  process.env.NODE_ENV = 'production';
  assert.equal(
    email.transportMode(),
    'disabled',
    'transport json tidak boleh dipakai di produksi',
  );

  process.env.SMTP_HOST = '';
  process.env.NODE_ENV = 'test';
  assert.equal(email.transportMode(), 'disabled', 'tanpa SMTP_HOST pengiriman dinonaktifkan');

  process.env.SMTP_HOST = original;
  if (originalProvider === undefined) delete process.env.EMAIL_PROVIDER;
  else process.env.EMAIL_PROVIDER = originalProvider;
  process.env.NODE_ENV = 'test';
});
