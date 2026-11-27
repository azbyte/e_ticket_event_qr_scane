/**
 * Pembacaan argumen `scripts/verify-brevo-smtp.js` (tanpa jaringan).
 *
 * Regresi yang dijaga: `npm run verify:brevo -- --to=alamat` pernah melaporkan
 * "tidak ada --to / --ticket / VERIFY_EMAIL_TO" padahal alamat sudah diberikan.
 * Penyebabnya: di PowerShell `npm` berjalan lewat `npm.ps1` yang membuang token
 * `--`, sehingga npm membaca `--to=alamat` sebagai konfigurasi npm dan
 * meneruskannya sebagai environment `npm_config_to` (argv skrip kosong).
 *
 * Semua pemanggilan skrip memakai `--dry-run` sehingga hanya pembacaan argumen
 * dan validasi lokal yang dieksekusi: tidak ada koneksi SMTP, tidak ada email
 * dikirim, dan tidak ada data yang diubah.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const { parseCliArgs, readNpmConfigValue, createCliOptions } = require('../src/utils/cliArgs');

const BACKEND_DIR = path.join(__dirname, '..');
const SCRIPT = path.join(BACKEND_DIR, 'scripts', 'verify-brevo-smtp.js');
const TO = 'aa8700702@gmail.com';
const TICKET = '11111111-1111-1111-1111-111111111111';
const SMTP_USER = 'uji@smtp-brevo.com';
const SMTP_SECRET = 'kunci-smtp-uji-jangan-dicetak';

/** Environment sintetis lengkap: pengujian tidak bergantung pada backend/.env. */
const baseEnv = () => {
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (key.startsWith('npm_config_')) delete env[key];
  }
  Object.assign(env, {
    NODE_ENV: 'test',
    DATABASE_URL: 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test',
    JWT_SECRET: 'test-only-jwt-secret',
    EMAIL_PROVIDER: 'brevo',
    SMTP_HOST: 'smtp-relay.brevo.com',
    SMTP_PORT: '587',
    SMTP_SECURE: 'false',
    SMTP_REQUIRE_TLS: 'true',
    SMTP_USER,
    SMTP_PASS: SMTP_SECRET,
    EMAIL_FROM: 'no-reply@eventku.test',
    VERIFY_EMAIL_TO: '',
    BREVO_API_KEY: '',
  });
  return env;
};

const runScript = (args, envOverrides = {}) => spawnSync(
  process.execPath,
  [SCRIPT, ...args],
  { cwd: BACKEND_DIR, env: { ...baseEnv(), ...envOverrides }, encoding: 'utf8' },
);

const outputOf = (result) => `${result.stdout || ''}${result.stderr || ''}`;

test('parseCliArgs membaca --to=nilai', () => {
  const { options, flags } = parseCliArgs([`--to=${TO}`]);
  assert.equal(options.get('to'), TO);
  assert.equal(flags.size, 0);
});

test('parseCliArgs membaca --to nilai (dipisah spasi)', () => {
  const { options } = parseCliArgs(['--to', TO]);
  assert.equal(options.get('to'), TO);
});

test('parseCliArgs membaca --ticket dan --wait pada kedua bentuk', () => {
  const equals = parseCliArgs([`--ticket=${TICKET}`, '--wait=45']).options;
  assert.equal(equals.get('ticket'), TICKET);
  assert.equal(equals.get('wait'), '45');

  const spaced = parseCliArgs(['--ticket', TICKET, '--wait', '45']).options;
  assert.equal(spaced.get('ticket'), TICKET);
  assert.equal(spaced.get('wait'), '45');
});

test('parseCliArgs membedakan flag tanpa nilai dari opsi bernilai', () => {
  const { options, flags } = parseCliArgs(['--as-configured', '--dry-run', `--to=${TO}`]);
  assert.deepEqual([...flags].sort(), ['as-configured', 'dry-run']);
  assert.equal(options.get('to'), TO);
  assert.equal(options.has('as-configured'), false);
});

test('createCliOptions memakai argv lebih dulu daripada npm config', () => {
  const cli = createCliOptions([`--to=${TO}`], { npm_config_to: 'lain@domain.test' });
  assert.equal(cli.read('to'), TO);
  assert.equal(cli.source('to'), 'argv');
});

test('createCliOptions memakai npm_config_* saat argv kosong (token -- dibuang)', () => {
  const cli = createCliOptions([], {
    npm_config_to: TO,
    npm_config_ticket: TICKET,
    npm_config_wait: '30',
    npm_config_as_configured: 'true',
  });
  assert.equal(cli.read('to'), TO);
  assert.equal(cli.read('ticket'), TICKET);
  assert.equal(cli.read('wait'), '30');
  assert.equal(cli.flag('as-configured'), true);
  assert.equal(cli.source('to'), 'npm-config');
});

test('createCliOptions mengembalikan string kosong bila opsi tidak diberikan', () => {
  const cli = createCliOptions([], {});
  assert.equal(cli.read('to'), '');
  assert.equal(cli.flag('dry-run'), false);
  assert.equal(cli.source('to'), 'none');
});

test('readNpmConfigValue memetakan nama opsi berstrip ke underscore', () => {
  assert.equal(readNpmConfigValue('as-configured', { npm_config_as_configured: 'true' }), 'true');
  assert.equal(readNpmConfigValue('to', { npm_config_to: '   ' }), undefined);
  assert.equal(readNpmConfigValue('to', {}), undefined);
});

test('skrip mengenali --to=alamat (format sama dengan dokumentasi)', () => {
  const result = runScript([`--to=${TO}`, '--dry-run']);
  const output = outputOf(result);
  assert.equal(result.status, 0, output);
  assert.match(output, new RegExp(`Penerima : ${TO}`));
  assert.match(output, new RegExp(`penerima :: ${TO}`));
  assert.match(output, /rencana :: kirim 1 email uji ke alamat penerima/);
  assert.doesNotMatch(output, /tidak ada --to/);
});

test('skrip mengenali --to alamat (format dipisah spasi)', () => {
  const result = runScript(['--to', TO, '--dry-run']);
  const output = outputOf(result);
  assert.equal(result.status, 0, output);
  assert.match(output, new RegExp(`Penerima : ${TO}`));
  assert.match(output, /rencana :: kirim 1 email uji ke alamat penerima/);
  assert.doesNotMatch(output, /tidak ada --to/);
});

test('skrip mengenali --to lewat npm_config_to saat argv kosong (PowerShell)', () => {
  const result = runScript(['--dry-run'], { npm_config_to: TO, npm_config_dry_run: 'true' });
  const output = outputOf(result);
  assert.equal(result.status, 0, output);
  assert.match(output, new RegExp(`Penerima : ${TO}`));
  assert.match(output, /sumber argumen :: --to/);
  assert.doesNotMatch(output, /tidak ada --to/);
});

test('skrip tetap mengenali --ticket dan --wait pada kedua bentuk', () => {
  const equals = runScript([`--ticket=${TICKET}`, '--wait=45', '--dry-run']);
  const equalsOutput = outputOf(equals);
  assert.equal(equals.status, 0, equalsOutput);
  assert.match(equalsOutput, new RegExp(`tiket=${TICKET}`));
  assert.match(equalsOutput, /wait :: 45 detik/);
  assert.match(equalsOutput, /rencana :: kirim e-ticket/);

  const spaced = runScript(['--ticket', TICKET, '--wait', '45', '--dry-run']);
  const spacedOutput = outputOf(spaced);
  assert.equal(spaced.status, 0, spacedOutput);
  assert.match(spacedOutput, new RegExp(`tiket=${TICKET}`));
  assert.match(spacedOutput, /wait :: 45 detik/);
});

test('alamat penerima divalidasi sebelum pengiriman', () => {
  const result = runScript(['--to=bukan-email', '--dry-run']);
  const output = outputOf(result);
  assert.equal(result.status, 1, output);
  assert.match(output, /alamat tujuan tidak valid :: bukan-email/);
  assert.doesNotMatch(output, /DRY RUN/);
  assert.match(output, /Tidak ada email yang dikirim/);
});

test('tanpa --to/--ticket skrip melaporkan rencana lewati, bukan mengirim', () => {
  const result = runScript(['--dry-run']);
  const output = outputOf(result);
  assert.equal(result.status, 0, output);
  assert.match(output, /Penerima : \(tidak ada\)/);
  assert.match(output, /rencana :: lewati pengiriman/);
});

test('skrip tidak pernah mencetak SMTP_PASS maupun SMTP_USER utuh', () => {
  const result = runScript([`--to=${TO}`, '--dry-run']);
  const output = outputOf(result);
  assert.equal(result.status, 0, output);
  assert.doesNotMatch(output, new RegExp(SMTP_SECRET));
  assert.doesNotMatch(output, new RegExp(SMTP_USER.replace('.', '\\.')));
  assert.match(output, /SMTP_PASS :: tersedia \(tidak dicetak\)/);
});
