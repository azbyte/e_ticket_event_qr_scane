const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

process.env.NODE_ENV = 'test';
// Unit test token/log/email/plan: tidak ada koneksi database. Variabel ini hanya
// memenuhi validasi startup `config/env.js` pada modul yang di-require.
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';
process.env.SMTP_HOST = 'json';

const tokens = require('../src/services/ticketTokenService');
const logger = require('../src/utils/logger');
const email = require('../src/services/emailService');
const { validatePlanPayload } = require('../src/controllers/planController');

test('QR token deterministic per ticket and never equals stored SHA-256 hash', () => {
  const ticket = { id: 'ticket-a', issued_at: new Date('2026-11-18T00:00:00.000Z') };
  const raw = tokens.rawTokenFor(ticket);
  assert.equal(raw, tokens.rawTokenFor(ticket));
  assert.notEqual(tokens.hashToken(raw), raw);
  assert.match(tokens.hashToken(raw), /^[a-f0-9]{64}$/);
});

test('QR token changes for different ticket id or issued timestamp', () => {
  const base = { id: 'ticket-a', issued_at: '2026-11-18T00:00:00.000Z' };
  assert.notEqual(tokens.rawTokenFor(base), tokens.rawTokenFor({ ...base, id: 'ticket-b' }));
  assert.notEqual(tokens.rawTokenFor(base), tokens.rawTokenFor({ ...base, issued_at: '2026-11-19T00:00:00.000Z' }));
});

test('QR token constant-time comparison rejects mismatch and length mismatch', () => {
  assert.equal(tokens.safeEqual('hash-value', 'hash-value'), true);
  assert.equal(tokens.safeEqual('hash-value', 'hash-valuf'), false);
  assert.equal(tokens.safeEqual('short', 'longer'), false);
});

test('logger redacts token, authorization, password, and nested secrets', () => {
  const output = logger.redact({
    token: 'raw-token',
    Authorization: 'Bearer secret',
    nested: { password: 'pw', public: 'ok' },
  });
  assert.equal(output.token, '[redacted]');
  assert.equal(output.Authorization, '[redacted]');
  assert.equal(output.nested.password, '[redacted]');
  assert.equal(output.nested.public, 'ok');
});

test('email template includes event/ticket access but never embeds QR bearer token', () => {
  const message = email.buildMessage({
    id: 'ticket-1', ticket_code: 'TKT-REF-1', attendee_name: 'Peserta <Uji>',
    event_title: 'Event Aman', ticket_type_name: 'Reguler',
    event_date: new Date('2026-11-18T10:00:00.000Z'), location: 'Jakarta',
    organizer_name: 'Organizer', contact_info: 'support@example.test',
  }, 'recipient@example.test');
  assert.match(message.subject, /Event Aman/);
  assert.match(message.text, /TKT-REF-1/);
  assert.match(message.html, /Peserta &lt;Uji&gt;/);
  assert.doesNotMatch(message.text + message.html, /qr_token|rawToken|SECRET/);
  assert.match(message.text, /Buka e-ticket/);
  assert.equal(message.attachments, undefined);
});

test('email template melampirkan PDF e-ticket saat desain tiket dirender', () => {
  const attachment = {
    filename: 'E-TIKET Peserta.pdf',
    content: Buffer.from('%PDF-1.4 contoh'),
    contentType: 'application/pdf',
  };
  const message = email.buildMessage({
    id: 'ticket-1', ticket_code: 'ETK-7K4P9Q', attendee_name: 'Peserta',
    event_title: 'Event Aman', ticket_type_name: 'Reguler',
    event_date: new Date('2026-11-18T10:00:00.000Z'), location: 'Jakarta',
  }, 'recipient@example.test', { attachment });
  assert.equal(message.attachments.length, 1);
  assert.equal(message.attachments[0].contentType, 'application/pdf');
  assert.match(message.text, /terlampir/);
});

test('plan validator rejects invalid prices, limits, and status', () => {
  const errors = validatePlanPayload({
    name: 'X', status: 'INVALID', priceMonthly: -1, maxActiveEvents: 0,
  });
  assert.ok(errors.length >= 3);
});

test('plan validator accepts a valid free plan and optional JSON features', () => {
  assert.deepEqual(validatePlanPayload({
    name: 'Paket Gratis', status: 'ACTIVE', isFree: true,
    priceMonthly: 0, priceYearly: 0, maxActiveEvents: 3,
    maxTicketsPerEvent: 100, maxStaffPerEvent: 2,
    features: { analytics: true },
  }), []);
});
