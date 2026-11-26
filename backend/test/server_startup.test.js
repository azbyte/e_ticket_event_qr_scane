/**
 * Regresi startup backend (Tahap 3, Developer 1).
 *
 * Bug yang direproduksi: `server.js` memanggil `app.listen(PORT, HOST, cb)` tanpa
 * handler `error`, sehingga `EADDRINUSE` menjadi unhandled `error` event dan
 * proses mati dengan stack trace mentah. Pengguna tidak tahu penyebabnya dan
 * hanya melihat "backend crash".
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://d1:d1@127.0.0.1:5432/e_ticket_d1_startup';
process.env.JWT_SECRET = 'd1-startup-jwt-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const { explainListenError } = require('../server');

test('EADDRINUSE dijelaskan dengan langkah perbaikan, bukan stack trace', () => {
  const message = explainListenError(
    Object.assign(new Error('listen EADDRINUSE: address already in use'), { code: 'EADDRINUSE' }),
    5000,
    '0.0.0.0',
  );
  assert.match(message, /Port 5000/);
  assert.match(message, /sudah dipakai proses lain/);
  // Harus memberi cara mengatasi, bukan hanya menyebut kode error.
  assert.match(message, /PORT=5001/);
  assert.match(message, /Get-NetTCPConnection|ss -ltnp/);
  assert.equal(/at Server\.setupListenHandle/.test(message), false);
});

test('EACCES menyarankan port di atas 1024', () => {
  const message = explainListenError(
    Object.assign(new Error('permission denied'), { code: 'EACCES' }),
    80,
    '0.0.0.0',
  );
  assert.match(message, /izin/i);
  assert.match(message, /1024/);
});

test('EADDRNOTAVAIL dan ENOTFOUND menunjuk konfigurasi HOST', () => {
  for (const code of ['EADDRNOTAVAIL', 'ENOTFOUND']) {
    const message = explainListenError(Object.assign(new Error('bad host'), { code }), 5000, 'host-salah');
    assert.match(message, /HOST/);
    assert.match(message, /host-salah/);
  }
});

test('kode error tak dikenal tetap menghasilkan pesan informatif', () => {
  const message = explainListenError(
    Object.assign(new Error('sesuatu rusak'), { code: 'EWHATEVER' }),
    5000,
    '0.0.0.0',
  );
  assert.match(message, /EWHATEVER/);
  assert.match(message, /sesuatu rusak/);
});

test('server.js memasang handler error pada instance HTTP server', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
  assert.match(source, /listenWithRetry\(PORT, HOST\)/);
  assert.match(source, /server\.on\('error'/);
  // Handler error wajib menetapkan exit code non-nol agar supervisor tahu gagal.
  assert.match(source, /process\.exitCode = 1/);
});

/**
 * Nodemon me-restart dengan menghentikan proses lama lalu segera menjalankan
 * yang baru. Di Windows socket lama belum tentu dilepas tepat waktu sehingga
 * bind gagal sesaat dan nodemon melaporkan
 * "app crashed - waiting for file changes".
 */
test('listenWithRetry mencoba ulang saat port masih dilepas (EADDRINUSE)', async () => {
  const net = require('node:net');
  const { listenWithRetry } = require('../server');

  // Port tetap supaya hasil deterministik.
  const blocker = net.createServer();
  const port = await new Promise((resolve) => {
    blocker.listen(0, '127.0.0.1', () => resolve(blocker.address().port));
  });

  const attempt = listenWithRetry(port, '127.0.0.1');
  // Lepas port setelah percobaan pertama gagal, meniru socket lama yang baru
  // dilepas oleh OS.
  setTimeout(() => blocker.close(), 700);

  const server = await attempt;
  assert.equal(server.listening, true);
  await new Promise((resolve) => server.close(resolve));
});

test('nodemon tidak mengawasi file log dan memakai delay restart', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const config = JSON.parse(
    fs.readFileSync(path.join(__dirname, '..', 'nodemon.json'), 'utf8'),
  );
  // Menonton `*.*` membuat penulisan log memicu restart berulang.
  assert.ok(Array.isArray(config.watch));
  assert.equal(config.watch.includes('*.*'), false);
  assert.ok(config.ignore.some((pattern) => pattern.includes('.log')));
  assert.ok(Number(config.delay) >= 300, 'delay restart harus cukup untuk melepas socket');
});

test('npm run dev memakai launcher dengan preflight dan opsi pemulihan', () => {
  const scripts = require('../package.json').scripts;
  assert.equal(scripts.predev, 'node scripts/preflight-port.js');
  // Launcher (bukan nodemon langsung) agar proses anak tidak menjadi yatim.
  assert.equal(scripts.dev, 'node scripts/dev.js');
  assert.match(scripts['dev:reset'], /dev\.js --kill-port/);
});

test('launcher dev menghentikan pohon proses dan mendeteksi induk hilang', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'dev.js'), 'utf8');
  // taskkill /T di Windows = hentikan seluruh pohon proses.
  assert.match(source, /taskkill/);
  assert.match(source, /\/T/);
  // Induk dipantau; `process.on('exit')` saja tidak cukup pada SIGKILL.
  assert.match(source, /process\.kill\(parentPid, 0\)/);
  assert.match(source, /SIGINT/);
});
