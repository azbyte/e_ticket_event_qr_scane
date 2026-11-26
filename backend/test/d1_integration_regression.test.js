/**
 * Regresi bug integrasi lintas modul yang ditemukan Developer 1 pada Tahap 3
 * (T3-D1-06). Setiap test mereproduksi bug yang benar-benar terjadi saat
 * pengujian API + PostgreSQL nyata, lalu mengunci perbaikannya.
 *
 * Tidak ada koneksi database: modul yang diuji murni/berbasis mock pool.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://d1:d1@127.0.0.1:5432/e_ticket_d1_regression';
process.env.JWT_SECRET = 'd1-regression-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'd1-regression-ticket-secret';
process.env.SMTP_HOST = 'json';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

/**
 * BUG-01 — `assertScanPermission` memilih kolom `event_members.status` yang
 * tidak ada pada schema. Akibat nyata: SETIAP scan QR dan check-in gagal 500
 * `column "status" does not exist`, sehingga alur inti demo mustahil.
 */
test('BUG-01: tidak ada query yang memilih event_members.status', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'checkInController.js'),
    'utf8',
  );
  assert.equal(
    /SELECT[^`']*status[^`']*FROM\s+event_members/i.test(source),
    false,
    'event_members tidak memiliki kolom status',
  );
  assert.equal(
    /member\.status/.test(source),
    false,
    'status membership tidak boleh dibaca dari event_members',
  );
});

/**
 * BUG-02 — `verifyTicketValidator` hanya mewajibkan `ticket_code`, sedangkan
 * scanner Flutter mengirim `token`. Akibat nyata: seluruh scan kamera ditolak
 * 400 sebelum logika validasi sempat berjalan.
 */
test('BUG-02: validator scan menerima token maupun ticket_code', async () => {
  const { verifyTicketValidator } = require('../src/validators');

  // Jalankan seluruh rantai validator terhadap body tiruan dan kembalikan
  // daftar pesan error (kosong berarti lolos).
  const errorsFor = async (body) => {
    const messages = [];
    const req = { body };
    for (const chain of verifyTicketValidator) {
      await chain.run(req);
    }
    const { validationResult } = require('express-validator');
    for (const error of validationResult(req).array()) messages.push(error.msg);
    return messages;
  };

  assert.deepEqual(await errorsFor({ token: 'opaque-token-abc', event_id: 'evt' }), []);
  assert.deepEqual(await errorsFor({ ticket_code: 'TK-001', event_id: 'evt' }), []);
  assert.equal((await errorsFor({ event_id: 'evt' })).length, 1);
});

/**
 * BUG-03 — `moderateEvent` menerima `PUBLISHED` sebagai keputusan, tetapi
 * fungsi DB `moderate_event` hanya mengenal `APPROVED`. Akibat nyata: Admin
 * tidak dapat memulihkan event yang ditangguhkan (selalu 400).
 */
test('BUG-03: keputusan moderasi PUBLISHED dipetakan ke APPROVED', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'eventMetricsController.js'),
    'utf8',
  );
  assert.match(source, /requested === 'PUBLISHED' \? 'APPROVED' : requested/);
  assert.match(source, /public\.moderate_event\(\$1, \$2, \$3, \$4, \$5\)/);
});

/**
 * BUG-04 — `updateAccountStatus` membaca `req.body.disabled`, sedangkan layar
 * Admin mengirim `is_active`. Akibat nyata: "suspend akun" melaporkan sukses
 * padahal akun tetap aktif dan audit log tidak bertambah.
 */
test('BUG-04: status akun menerima is_active, disabled, dan status', async () => {
  process.env.NODE_ENV = 'test';
  const adminController = require('../src/controllers/adminController');
  assert.equal(typeof adminController.updateAccountStatus, 'function');

  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'adminController.js'),
    'utf8',
  );
  assert.match(source, /typeof body\.is_active === 'boolean'/);
  assert.match(source, /typeof body\.disabled === 'boolean'/);
  assert.match(source, /typeof body\.status === 'string'/);
  assert.match(source, /is_active: !row\.disabled_at/);
});

/**
 * BUG-05 — daftar peserta memakai `profiles.phone` dan `UNION` antara
 * enum `OrderStatus` dan `text`. Akibat nyata: endpoint peserta dan export CSV
 * mengembalikan 500 sehingga fitur inti Organizer tidak dapat dipakai.
 */
test('BUG-05: query peserta tidak memakai profiles.phone dan meng-cast enum', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'controllers', 'checkInController.js'),
    'utf8',
  );
  assert.equal(/p\.phone/.test(source), false, 'profiles tidak memiliki kolom phone');
  assert.equal(
    /eo\.status AS order_status/.test(source),
    false,
    'UNION enum vs text harus memakai cast ::text',
  );
  assert.match(source, /eo\.status::text AS order_status/);
});
