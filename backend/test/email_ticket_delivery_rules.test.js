/**
 * Aturan pengiriman e-ticket (tanpa database):
 *  - field email tidak dapat dihapus/dijadikan opsional dari konfigurasi form,
 *  - format email divalidasi di server,
 *  - konfigurasi SMTP divalidasi dari environment (tanpa kredensial di kode),
 *  - SMTP_HOST=json di luar NODE_ENV=test dianggap nonaktif,
 *  - ringkasan status tidak pernah mengklaim terkirim saat masih antre.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeAttendeeFields,
  validateAttendeeAnswers,
} = require('../src/utils/eventValidation');
const email = require('../src/services/emailService');
const emailQueue = require('../src/services/emailQueue');

const withEnv = (values, fn) => {
  const previous = {};
  for (const [key, value] of Object.entries(values)) {
    previous[key] = process.env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  email.resetTransport();
  try {
    return fn();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    email.resetTransport();
  }
};

test('event tanpa field email otomatis mendapat email wajib', () => {
  const { fields, errors } = normalizeAttendeeFields([
    { key: 'name', label: 'Nama', type: 'text', required: true },
    { key: 'shirt_size', label: 'Ukuran kaos', type: 'select', options: ['M', 'L'] },
  ]);
  assert.deepEqual(errors, []);
  assert.deepEqual(fields.map((field) => field.key), ['name', 'email', 'shirt_size']);
  const emailField = fields.find((field) => field.key === 'email');
  assert.equal(emailField.required, true);
  assert.equal(emailField.type, 'text');
  // Field dinamis Organizer tidak berubah.
  assert.deepEqual(
    fields.find((field) => field.key === 'shirt_size').options,
    ['M', 'L'],
  );
});

test('email tidak dapat dijadikan opsional atau bertipe lain', () => {
  const { fields } = normalizeAttendeeFields([
    { key: 'name', label: 'Nama', type: 'text', required: true },
    { key: 'email', label: 'Email', type: 'number', required: false },
  ]);
  const emailField = fields.find((field) => field.key === 'email');
  assert.equal(emailField.required, true);
  assert.equal(emailField.type, 'text');
});

test('format email tidak valid ditolak validasi server', () => {
  const { fields } = normalizeAttendeeFields([
    { key: 'name', label: 'Nama', type: 'text', required: true },
    { key: 'email', label: 'Email', type: 'text', required: true },
  ]);
  const errors = validateAttendeeAnswers(fields, {
    name: 'Peserta',
    email: 'bukan-email',
  });
  assert.ok(errors.some((message) => /email.*valid/i.test(message)));
  assert.deepEqual(
    validateAttendeeAnswers(fields, { name: 'Peserta', email: 'ok@example.test' }),
    [],
  );
});

test('SMTP_HOST=json hanya aktif di NODE_ENV=test', () => {
  withEnv({ SMTP_HOST: 'json', EMAIL_FROM: '' }, () => {
    assert.equal(email.smtpStatus().mode, 'json');
  });
  withEnv({ SMTP_HOST: 'json', NODE_ENV: 'production' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.match(status.reason, /json/i);
  });
});

test('konfigurasi SMTP tidak lengkap ditolak sebelum pengiriman', () => {
  withEnv({
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '587',
    SMTP_USER: 'pengirim@example.test',
    SMTP_PASS: '',
    EMAIL_FROM: 'no-reply@example.test',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['SMTP_PASS']);
    assert.doesNotMatch(JSON.stringify(status), /pengirim@example\.test/);
  });

  withEnv({
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '587',
    SMTP_USER: '',
    SMTP_PASS: '',
    EMAIL_FROM: '',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['EMAIL_FROM']);
  });
});

test('konfigurasi SMTP lengkap menghasilkan mode smtp', () => {
  withEnv({
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '465',
    SMTP_SECURE: 'true',
    SMTP_USER: 'pengirim@example.test',
    SMTP_PASS: 'rahasia-uji',
    EMAIL_FROM: 'E-Ticket <no-reply@example.test>',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'smtp');
    assert.equal(status.configured, true);
    assert.equal(status.auth, true);
    assert.deepEqual(status.missing, []);
  });
});

test('ringkasan status tidak mengklaim terkirim saat masih antre', () => {
  const queued = emailQueue.summarize([
    { ticketId: 't1', recipient: 'peserta@example.test', status: 'QUEUED' },
  ]);
  assert.equal(queued.delivered, false);
  assert.equal(queued.queued, true);
  assert.equal(queued.results[0].status, 'QUEUED');

  const sent = emailQueue.summarize([
    { ticketId: 't1', recipient: 'peserta@example.test', status: 'SENT' },
  ]);
  assert.equal(sent.delivered, true);

  const already = emailQueue.summarize([
    { ticketId: 't1', status: 'SKIPPED', reason: 'already_sent' },
  ]);
  assert.equal(already.delivered, true);
});
