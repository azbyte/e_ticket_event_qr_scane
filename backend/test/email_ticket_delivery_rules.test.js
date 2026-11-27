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

test('transport HTTPS API dipilih otomatis dan menyembunyikan API key', () => {
  withEnv({
    RESEND_API_KEY: 'kunci-uji-rahasia',
    EMAIL_FROM: 'no-reply@example.test',
    SMTP_HOST: '',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'resend');
    assert.equal(status.configured, true);
    // Status tidak boleh membocorkan kredensial.
    assert.doesNotMatch(JSON.stringify(status), /kunci-uji-rahasia/);
  });
});

test('transport HTTPS API tanpa EMAIL_FROM valid ditolak', () => {
  withEnv({
    RESEND_API_KEY: 'kunci-uji-rahasia',
    EMAIL_FROM: '',
    SMTP_HOST: '',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['EMAIL_FROM']);
  });
});

test('identitas pengirim: email penyelenggara hanya dipakai bila diizinkan', () => {
  const ticket = {
    id: 't1', ticket_code: 'TKT-1', event_id: 'e1',
    attendee_name: 'Peserta', attendee_email: 'peserta@example.test',
    event_title: 'Event Uji', ticket_type_name: 'Reguler',
    organizer_name: 'Penyelenggara Uji', organizer_email: 'penyelenggara@event.test',
  };

  // Domain penyelenggara belum terverifikasi -> From terverifikasi, Reply-To penyelenggara.
  withEnv({
    EMAIL_FROM: 'no-reply@eticket.test',
    EMAIL_FROM_NAME: 'E-Ticket Event',
    SMTP_USER: '',
    EMAIL_ORGANIZER_FROM_DOMAINS: '',
    EMAIL_REPLY_TO_ORGANIZER: undefined,
  }, () => {
    const sender = email.resolveSender(ticket);
    assert.equal(sender.fromAddress, 'no-reply@eticket.test');
    assert.equal(sender.fromOrganizer, false);
    assert.equal(sender.replyTo, 'penyelenggara@event.test');
    const message = email.buildMessage(ticket, 'peserta@example.test');
    assert.equal(message.replyTo, 'penyelenggara@event.test');
    assert.match(String(message.from), /no-reply@eticket\.test/);
    assert.notEqual(message.from, 'peserta@example.test');
    assert.match(message.text, /Penyelenggara: Penyelenggara Uji/);
  });

  // Domain terverifikasi di penyedia -> penyelenggara menjadi From.
  withEnv({
    EMAIL_FROM: 'no-reply@eticket.test',
    EMAIL_FROM_NAME: 'E-Ticket Event',
    SMTP_USER: '',
    EMAIL_ORGANIZER_FROM_DOMAINS: '@event.test',
  }, () => {
    const sender = email.resolveSender(ticket);
    assert.equal(sender.fromAddress, 'penyelenggara@event.test');
    assert.equal(sender.fromOrganizer, true);
    assert.match(sender.from, /Penyelenggara Uji <penyelenggara@event\.test>/);
    assert.equal(sender.replyTo, 'penyelenggara@event.test');
  });

  // Alamat = akun SMTP terautentikasi -> boleh menjadi From tanpa allow-list.
  withEnv({
    EMAIL_FROM: 'no-reply@eticket.test',
    SMTP_USER: 'penyelenggara@event.test',
    EMAIL_ORGANIZER_FROM_DOMAINS: '',
  }, () => {
    assert.equal(email.resolveSender(ticket).fromOrganizer, true);
  });
});

test('email penyelenggara tidak valid tidak dipakai sebagai From/Reply-To', () => {
  withEnv({
    EMAIL_FROM: 'no-reply@eticket.test',
    SMTP_USER: '',
    EMAIL_ORGANIZER_FROM_DOMAINS: 'event.test',
    EMAIL_REPLY_TO_ORGANIZER: 'false',
  }, () => {
    const sender = email.resolveSender({
      organizer_email: 'bukan-email', organizer_name: 'X',
    });
    assert.equal(sender.fromAddress, 'no-reply@eticket.test');
    assert.equal(sender.replyTo, 'no-reply@eticket.test');
    assert.equal(sender.organizerEmail, null);
  });
});

test('validasi alamat email penerima menolak format tidak valid', () => {
  assert.equal(email.isValidEmail('peserta@gmail.com'), true);
  assert.equal(email.isValidEmail('peserta@gmail'), false);
  assert.equal(email.isValidEmail('Nama <peserta@gmail.com>'), false);
  assert.equal(email.isValidEmail(''), false);
  assert.deepEqual(email.parseEmailAddress('Nama <a@b.co>'), { address: 'a@b.co', name: 'Nama' });
});

test('validasi konfigurasi startup melaporkan semua variabel yang belum ada', () => {
  withEnv({
    RESEND_API_KEY: undefined,
    SMTP_HOST: '',
    SMTP_PORT: undefined,
    SMTP_USER: '',
    SMTP_PASS: '',
    EMAIL_FROM: '',
  }, () => {
    const config = email.validateEmailConfig();
    assert.equal(config.ok, false);
    assert.ok(config.missing.includes('RESEND_API_KEY|SMTP_HOST'));
    assert.ok(config.missing.includes('EMAIL_FROM'));
    assert.match(config.reason, /RESEND_API_KEY/);
    assert.match(config.reason, /SMTP_HOST/);
  });
});

test('SMTP relay tanpa kredensial ditolak, relay lokal tetap diizinkan', () => {
  // Relay publik tanpa user/pass hampir pasti menolak pesan; gagalkan lebih awal.
  withEnv({
    RESEND_API_KEY: undefined,
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '587',
    SMTP_USER: '',
    SMTP_PASS: '',
    EMAIL_FROM: 'no-reply@example.test',
    SMTP_ALLOW_LOCAL_RELAY: undefined,
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['SMTP_USER', 'SMTP_PASS']);
  });

  // Relay lokal tanpa autentikasi (mis. SMTP sink untuk pengujian) tetap sah.
  withEnv({
    RESEND_API_KEY: undefined,
    SMTP_HOST: '127.0.0.1',
    SMTP_PORT: '2526',
    SMTP_USER: '',
    SMTP_PASS: '',
    EMAIL_FROM: 'no-reply@example.test',
  }, () => {
    assert.equal(email.smtpStatus().mode, 'smtp');
  });
});
