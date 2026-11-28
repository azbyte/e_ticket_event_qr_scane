const test = require('node:test');
const assert = require('node:assert/strict');

/**
 * Default konfigurasi publik.
 *
 * `APP_PUBLIC_URL` dipakai untuk `public_url` event, tautan tiket di email, dan
 * tautan undangan staf (`/staff-access/{invitationId}`). Nilainya harus menunjuk
 * ke aplikasi Flutter, bukan port backend, karena backend tidak menyajikan
 * halaman Flutter. Default yang salah membuat tautan undangan staf tidak dapat
 * dibuka walaupun kode akses berhasil dibuat.
 */
test('default APP_PUBLIC_URL menunjuk ke aplikasi, bukan port backend', () => {
  const envPath = require.resolve('../src/config/env');
  const previous = {
    APP_PUBLIC_URL: process.env.APP_PUBLIC_URL,
    DATABASE_URL: process.env.DATABASE_URL,
    JWT_SECRET: process.env.JWT_SECRET,
  };
  // String kosong (bukan delete) agar `dotenv` tidak memuat nilai dari `.env`,
  // sehingga test tetap deterministik di mesin developer maupun CI.
  process.env.APP_PUBLIC_URL = '';
  process.env.DATABASE_URL =
    'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
  process.env.JWT_SECRET = 'test-only-jwt-secret';
  delete require.cache[envPath];

  try {
    const config = require('../src/config/env');
    assert.equal(config.appPublicUrl, 'http://localhost:3000');
    assert.ok(
      !config.appPublicUrl.endsWith(':5000'),
      'default tidak boleh memakai port backend'
    );
  } finally {
    delete require.cache[envPath];
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});
