/**
 * Konfigurasi transport Brevo SMTP (tanpa jaringan, tanpa database).
 *
 * Fokus:
 *  - `EMAIL_PROVIDER=brevo` memakai smtp-relay.brevo.com:587 + STARTTLS,
 *  - kredensial hanya dari environment (SMTP_USER/SMTP_PASS), tidak pernah
 *    dilaporkan pada status/log,
 *  - Brevo didahulukan atas kunci API lama,
 *  - konfigurasi tidak lengkap ditolak SEBELUM ada percobaan kirim,
 *  - kegagalan diklasifikasikan (auth/sender/connect) agar mudah ditindak.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const email = require('../src/services/emailService');

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

/** Environment dasar Brevo yang lengkap. */
const BREVO_ENV = {
  EMAIL_PROVIDER: 'brevo',
  SMTP_HOST: undefined,
  SMTP_PORT: undefined,
  SMTP_SECURE: undefined,
  SMTP_REQUIRE_TLS: undefined,
  SMTP_USER: '1234567@smtp-brevo.com',
  SMTP_PASS: 'kunci-smtp-brevo-rahasia',
  EMAIL_FROM: 'E-Ticket <no-reply@eventku.test>',
  RESEND_API_KEY: undefined,
  SMTP_ALLOW_LOCAL_RELAY: undefined,
};

test('EMAIL_PROVIDER=brevo memakai host/port Brevo dan STARTTLS wajib', () => {
  withEnv(BREVO_ENV, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'brevo');
    assert.equal(status.configured, true);
    assert.equal(status.auth, true);
    assert.equal(status.host, 'smtp-relay.brevo.com');
    assert.equal(status.port, 587);
    assert.equal(status.secure, false);
    assert.equal(status.requireTls, true);
    assert.equal(status.brevo, true);
    assert.equal(status.from, 'E-Ticket <no-reply@eventku.test>');

    const options = email.smtpTransportOptions();
    assert.equal(options.host, 'smtp-relay.brevo.com');
    assert.equal(options.port, 587);
    assert.equal(options.secure, false);
    assert.equal(options.requireTLS, true);
    assert.deepEqual(options.auth, {
      user: '1234567@smtp-brevo.com',
      pass: 'kunci-smtp-brevo-rahasia',
    });
    assert.ok(options.connectionTimeout > 0);
  });
});

test('status/log tidak pernah membocorkan kredensial Brevo', () => {
  withEnv(BREVO_ENV, () => {
    const serialized = JSON.stringify(email.smtpStatus());
    assert.doesNotMatch(serialized, /kunci-smtp-brevo-rahasia/);
    assert.doesNotMatch(serialized, /1234567@smtp-brevo\.com/);

    const config = email.validateEmailConfig();
    assert.doesNotMatch(JSON.stringify(config), /kunci-smtp-brevo-rahasia/);
    assert.doesNotMatch(JSON.stringify(config), /1234567@smtp-brevo\.com/);
  });
});

test('Brevo didahulukan atas sisa RESEND_API_KEY', () => {
  withEnv({ ...BREVO_ENV, RESEND_API_KEY: 'kunci-resend-lama' }, () => {
    assert.equal(email.smtpStatus().mode, 'brevo');
  });
});

test('host Brevo tanpa EMAIL_PROVIDER tetap dikenali sebagai Brevo', () => {
  withEnv({
    ...BREVO_ENV,
    EMAIL_PROVIDER: undefined,
    SMTP_HOST: 'smtp-relay.brevo.com',
    SMTP_PORT: '587',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'brevo');
    assert.equal(status.requireTls, true);
  });
});


test('Brevo tanpa SMTP_PASS ditolak sebelum pengiriman', () => {
  withEnv({ ...BREVO_ENV, SMTP_PASS: '' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['SMTP_PASS']);
    assert.match(status.reason, /SMTP key/i);
  });
});

test('Brevo tanpa SMTP_USER ditolak sebelum pengiriman', () => {
  withEnv({ ...BREVO_ENV, SMTP_USER: '' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['SMTP_USER']);
    assert.match(status.reason, /SMTP_USER/);
  });
});

test('Brevo tanpa kredensial sama sekali tidak diklaim siap kirim', () => {
  withEnv({ ...BREVO_ENV, SMTP_USER: '', SMTP_PASS: '' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.equal(status.configured, false);
    assert.deepEqual(status.missing, ['SMTP_USER', 'SMTP_PASS']);
  });
});

test('Brevo tanpa EMAIL_FROM valid ditolak', () => {
  withEnv({ ...BREVO_ENV, EMAIL_FROM: '' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.deepEqual(status.missing, ['EMAIL_FROM']);
  });
});

test('port 465 Brevo memakai TLS implisit tanpa STARTTLS tambahan', () => {
  withEnv({
    ...BREVO_ENV,
    SMTP_PORT: '465',
    SMTP_SECURE: 'true',
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'brevo');
    assert.equal(status.secure, true);
    assert.equal(status.requireTls, false);
    const options = email.smtpTransportOptions();
    assert.equal(options.secure, true);
    assert.equal(options.requireTLS, undefined);
  });
});

test('relay SMTP generik tidak dipaksa STARTTLS kecuali diminta', () => {
  withEnv({
    EMAIL_PROVIDER: 'smtp',
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '2525',
    SMTP_SECURE: 'false',
    SMTP_REQUIRE_TLS: undefined,
    SMTP_USER: 'pengirim@example.test',
    SMTP_PASS: 'rahasia-uji',
    EMAIL_FROM: 'no-reply@example.test',
    RESEND_API_KEY: undefined,
  }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'smtp');
    assert.equal(status.brevo, false);
    assert.equal(status.requireTls, false);
    assert.equal(email.smtpTransportOptions().requireTLS, undefined);
  });

  withEnv({
    EMAIL_PROVIDER: 'smtp',
    SMTP_HOST: 'smtp.example.test',
    SMTP_PORT: '587',
    SMTP_SECURE: 'false',
    SMTP_REQUIRE_TLS: 'true',
    SMTP_USER: 'pengirim@example.test',
    SMTP_PASS: 'rahasia-uji',
    EMAIL_FROM: 'no-reply@example.test',
    RESEND_API_KEY: undefined,
  }, () => {
    assert.equal(email.smtpStatus().requireTls, true);
    assert.equal(email.smtpTransportOptions().requireTLS, true);
  });
});

test('EMAIL_PROVIDER=resend dan none tetap dihormati', () => {
  withEnv({
    EMAIL_PROVIDER: 'resend',
    RESEND_API_KEY: 'kunci-resend-uji',
    EMAIL_FROM: 'no-reply@example.test',
    SMTP_HOST: '',
  }, () => {
    assert.equal(email.smtpStatus().mode, 'resend');
  });

  withEnv({ ...BREVO_ENV, EMAIL_PROVIDER: 'none' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.match(status.reason, /dinonaktifkan/i);
  });
});

test('EMAIL_PROVIDER tidak dikenal ditolak dengan alasan jelas', () => {
  withEnv({ ...BREVO_ENV, EMAIL_PROVIDER: 'mailgun-salah' }, () => {
    const status = email.smtpStatus();
    assert.equal(status.mode, 'disabled');
    assert.match(status.reason, /tidak dikenal/i);
  });
});

test('kegagalan Brevo diklasifikasikan sesuai tahap', () => {
  withEnv(BREVO_ENV, () => {
    const auth = email.classifySmtpError(
      Object.assign(new Error('Invalid login: 535 5.7.8'), { code: 'EAUTH' }),
    );
    assert.equal(auth.stage, 'auth');
    assert.match(auth.hint, /SMTP key/i);

    const sender = email.classifySmtpError(
      Object.assign(new Error('550 Sender not valid'), { code: 'EENVELOPE' }),
    );
    assert.equal(sender.stage, 'sender');
    assert.match(sender.hint, /diverifikasi/i);

    const connect = email.classifySmtpError(
      Object.assign(new Error('connect ETIMEDOUT'), { code: 'ETIMEDOUT' }),
    );
    assert.equal(connect.stage, 'connect');
    assert.match(connect.hint, /smtp-relay\.brevo\.com:587/);

    // Nodemailer membungkus ECONNREFUSED sebagai ESOCKET: tetap harus
    // diklasifikasikan sebagai masalah koneksi, bukan TLS.
    const refused = email.classifySmtpError(
      Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:2526'), { code: 'ESOCKET' }),
    );
    assert.equal(refused.stage, 'connect');
  });
});

