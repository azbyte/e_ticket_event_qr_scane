#!/usr/bin/env node
/*
 * Verifikasi bertahap pengiriman email lewat SMTP Brevo
 * (`smtp-relay.brevo.com`, port 587 + STARTTLS) memakai Nodemailer.
 *
 * Skrip ini memisahkan bukti yang BERBEDA, supaya tidak ada klaim berlebihan:
 *
 *   1. konfigurasi  : host/port/TLS/from terbaca, kredensial tersedia (masked)
 *   2. dns          : smtp-relay.brevo.com dapat di-resolve
 *   3. tcp          : port 587 dapat dibuka dari mesin ini
 *   4. starttls+auth: Brevo menerima kredensial SMTP (transporter.verify())
 *   5. kirim        : Brevo menerima pesan (250 queued + messageId)
 *   6. inbox        : TIDAK dapat dibuktikan dari sini. Bila BREVO_API_KEY
 *                     diisi, event "delivered"/"bounce" dari Brevo API
 *                     dilaporkan sebagai bukti tambahan (bukan jaminan inbox).
 *
 * Pemakaian (dari folder backend/):
 *   npm run verify:brevo                                   # preflight saja
 *   npm run verify:brevo -- --to=inbox-anda@domain.com     # + 1 email nyata
 *   npm run verify:brevo -- --to inbox-anda@domain.com     # bentuk lain, sama
 *   npm run verify:brevo -- --ticket=<uuid-tiket>          # + e-ticket PDF asli
 *   npm run verify:brevo -- --as-configured                # pakai .env apa adanya
 *   npm run verify:brevo -- --to=... --dry-run             # cek argumen saja
 *
 * Catatan argumen: di PowerShell `npm` berjalan lewat `npm.ps1`, yang membuang
 * token `--` sebelum sampai ke npm sehingga `--to=...` dibaca npm sebagai
 * konfigurasinya sendiri dan argv skrip menjadi kosong. Karena itu opsi dibaca
 * lewat `src/utils/cliArgs.js` yang juga menerima cadangan `npm_config_<opsi>`.
 * Bila ragu, `npm.cmd run verify:brevo -- --to=...` meneruskan argumen apa adanya.
 *
 * Kredensial TIDAK pernah dicetak dan `.env` TIDAK pernah diubah. Nilai host/
 * port Brevo di bawah adalah profil publik, bukan rahasia.
 */
const dns = require('node:dns').promises;
const net = require('node:net');
const path = require('node:path');

const { createCliOptions } = require('../src/utils/cliArgs');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const BREVO_HOST = 'smtp-relay.brevo.com';
const BREVO_PORT = 587;

const cli = createCliOptions();

/**
 * Nilai opsi CLI. Menerima `--nama=nilai`, `--nama nilai`, dan cadangan
 * `npm_config_<nama>` untuk argumen yang tertelan `npm.ps1` di PowerShell.
 */
const argValue = (name) => cli.read(name);
/** True bila flag ditulis tanpa nilai (`--as-configured`, `--dry-run`). */
const hasFlag = (name) => cli.flag(name);
/** Opsi yang nilainya sampai lewat `npm_config_*` (token `--` dibuang shell). */
const optionsFromNpmConfig = (names) => names.filter((name) => cli.source(name) === 'npm-config');

let failures = 0;
let blocked = 0;
const pass = (name, detail = '') => console.log(`PASS    ${name}${detail ? ` :: ${detail}` : ''}`);
const fail = (name, detail = '') => {
  failures += 1;
  console.error(`FAIL    ${name}${detail ? ` :: ${detail}` : ''}`);
};
const skip = (name, detail = '') => {
  blocked += 1;
  console.log(`BLOCKED ${name}${detail ? ` :: ${detail}` : ''}`);
};
const info = (name, detail = '') => console.log(`INFO    ${name}${detail ? ` :: ${detail}` : ''}`);

/** Tampilkan login SMTP tanpa membocorkan nilai utuh. */
const maskLogin = (value) => {
  const raw = String(value || '').trim();
  if (!raw) return '(kosong)';
  const at = raw.indexOf('@');
  if (at < 1) return raw.length <= 4 ? '***' : `${raw.slice(0, 2)}***`;
  return `${raw.slice(0, 3)}***${raw.slice(at)}`;
};

/** Resolusi DNS host SMTP. */
const resolveHost = async (host) => {
  try {
    const addresses = await dns.lookup(host, { all: true });
    return { ok: true, addresses: addresses.map((item) => item.address) };
  } catch (error) {
    return { ok: false, reason: error.code || error.message };
  }
};

/** Buka koneksi TCP polos (belum TLS) ke host:port. */
const probeTcp = (host, port, timeoutMs = 10000) => new Promise((resolve) => {
  const started = Date.now();
  const socket = net.connect({ host, port });
  const finish = (result) => {
    socket.destroy();
    resolve(result);
  };
  socket.setTimeout(timeoutMs);
  socket.once('connect', () => finish({ ok: true, ms: Date.now() - started }));
  socket.once('timeout', () => finish({ ok: false, reason: `timeout ${timeoutMs}ms` }));
  socket.once('error', (error) => finish({ ok: false, reason: error.code || error.message }));
});

/**
 * Bukti tambahan dari Brevo API (opsional, butuh BREVO_API_KEY).
 * Kegagalan di sini TIDAK dihitung sebagai kegagalan pengiriman: endpoint ini
 * hanya pelengkap, bukan sumber kebenaran status email.
 */
const fetchBrevoEvents = async (recipient, { waitSeconds = 0 } = {}) => {
  const apiKey = String(process.env.BREVO_API_KEY || '').trim();
  if (!apiKey) return { ok: false, reason: 'BREVO_API_KEY tidak diisi' };

  const deadline = Date.now() + Math.max(0, waitSeconds) * 1000;
  let lastError = null;
  while (true) {
    try {
      const url = 'https://api.brevo.com/v3/smtp/statistics/events'
        + `?email=${encodeURIComponent(recipient)}&limit=50&sort=desc`;
      const response = await fetch(url, {
        headers: { 'api-key': apiKey, accept: 'application/json' },
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) {
        lastError = `HTTP ${response.status}`;
      } else {
        const body = await response.json();
        const events = Array.isArray(body?.events) ? body.events : [];
        if (events.length > 0) return { ok: true, events };
        lastError = 'belum ada event untuk alamat ini';
      }
    } catch (error) {
      lastError = error.message;
    }
    if (Date.now() >= deadline) return { ok: false, reason: lastError };
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }
};


(async () => {
  if (hasFlag('help') || hasFlag('h')) {
    console.log('Pemakaian: node scripts/verify-brevo-smtp.js [--to=alamat] [--ticket=uuid]');
    console.log('           [--as-configured] [--host=host] [--port=587] [--secure=false]');
    console.log('           [--wait=30] [--dry-run]');
    console.log('');
    console.log('  --to=alamat / --to alamat  penerima email uji (kedua bentuk sama)');
    console.log('  --ticket=uuid              kirim e-ticket asli dari database');
    console.log('  --wait=30                  tunggu event Brevo API (butuh BREVO_API_KEY)');
    console.log('  --dry-run                  tampilkan argumen terbaca tanpa mengirim email');
    console.log('');
    console.log('  PowerShell membuang token "--", jadi `npm run verify:brevo -- --to=...`');
    console.log('  tetap dikenali lewat npm_config_to. Bila ragu pakai:');
    console.log('  npm.cmd run verify:brevo -- --to=inbox-anda@domain.com');
    return;
  }

  // Profil Brevo dipakai secara default agar pengujian TIDAK diam-diam memakai
  // sisa SMTP_HOST loopback dari pengujian lokal. `.env` tidak diubah.
  const useEnvAsIs = hasFlag('as-configured');
  const targetHost = argValue('host') || (useEnvAsIs
    ? String(process.env.SMTP_HOST || '').trim()
    : BREVO_HOST);
  const targetPort = argValue('port') || (useEnvAsIs
    ? String(process.env.SMTP_PORT || '').trim()
    : String(BREVO_PORT));
  const targetSecure = argValue('secure') || (useEnvAsIs
    ? String(process.env.SMTP_SECURE || '').trim()
    : 'false');

  if (!useEnvAsIs) {
    process.env.EMAIL_PROVIDER = 'brevo';
    process.env.SMTP_HOST = targetHost;
    process.env.SMTP_PORT = targetPort;
    process.env.SMTP_SECURE = targetSecure;
    process.env.SMTP_REQUIRE_TLS = targetSecure === 'true' ? 'false' : 'true';
  }

  const emailService = require('../src/services/emailService');

  /*
   * Argumen dibaca SEBELUM preflight jaringan supaya alamat penerima yang salah
   * gagal cepat tanpa membuka koneksi SMTP. `--to` menerima `--to=nilai` maupun
   * `--to nilai`, dan cadangan `npm_config_to` menutup kasus token `--` yang
   * dibuang `npm.ps1` di PowerShell (argv skrip kosong, nilai pindah ke
   * environment npm) sehingga perintah yang benar tidak lagi terlihat "tanpa --to".
   */
  const ticketId = argValue('ticket');
  const recipient = (argValue('to') || String(process.env.VERIFY_EMAIL_TO || '').trim()).trim();
  const waitSeconds = Math.max(0, Number(argValue('wait') || 0) || 0);
  const dryRun = hasFlag('dry-run');
  const viaNpmConfig = optionsFromNpmConfig([
    'to', 'ticket', 'wait', 'host', 'port', 'secure', 'as-configured', 'dry-run',
  ]);

  console.log('=== Verifikasi email Brevo SMTP (Nodemailer) ===');
  console.log(`Target   : ${targetHost || '(kosong)'}:${targetPort || '(kosong)'}`
    + ` | secure=${targetSecure || '(kosong)'}`
    + (useEnvAsIs ? ' | mode=as-configured' : ' | mode=profil Brevo'));
  console.log(`Penerima : ${recipient || (ticketId ? '(dari data tiket)' : '(tidak ada)')}`
    + (ticketId ? ` | tiket=${ticketId}` : ''));
  if (viaNpmConfig.length > 0) {
    info('sumber argumen', `${viaNpmConfig.map((name) => `--${name}`).join(', ')}`
      + ' dibaca dari npm_config_* (token "--" tidak diteruskan shell)');
  }

  // Alamat penerima divalidasi SEBELUM preflight/kirim: alamat salah tidak
  // boleh menghabiskan koneksi SMTP dan tidak boleh terlihat seperti terkirim.
  if (recipient && !emailService.isValidEmail(recipient)) {
    fail('alamat tujuan tidak valid', recipient);
    console.error('\nGunakan satu alamat email, mis. --to=inbox@domain.com atau --to inbox@domain.com.');
    console.error('Tidak ada email yang dikirim.');
    process.exitCode = 1;
    return;
  }

  // --- Tahap 1: konfigurasi ---
  const config = emailService.validateEmailConfig();
  info('mode transport', config.mode);
  info('host:port', `${config.host || '-'}:${config.port}`
    + (config.requireTls ? ' (STARTTLS wajib)' : config.secure ? ' (TLS implisit)' : ''));
  info('SMTP_USER', maskLogin(process.env.SMTP_USER));
  info('SMTP_PASS', process.env.SMTP_PASS ? 'tersedia (tidak dicetak)' : '(kosong)');
  info('EMAIL_FROM', config.from || '(kosong)');
  if (config.ok) {
    pass('konfigurasi transport lengkap');
  } else {
    fail('konfigurasi transport belum lengkap', config.reason || '');
    if (config.missing.length > 0) info('variabel belum diisi', config.missing.join(', '));
    console.error('\nTidak ada email yang dikirim. Lengkapi backend/.env lalu jalankan ulang.');
    process.exitCode = 1;
    return;
  }

  const plannedAction = ticketId
    ? 'kirim e-ticket (PDF + QR) memakai email peserta pada database'
    : recipient
      ? 'kirim 1 email uji ke alamat penerima'
      : 'lewati pengiriman (tidak ada --to / --ticket / VERIFY_EMAIL_TO)';

  /*
   * Mode aman untuk membuktikan argumen terbaca tanpa koneksi SMTP dan tanpa
   * mengirim email. Ditempatkan setelah validasi konfigurasi lokal (tanpa
   * jaringan) tetapi sebelum tahap DNS/TCP/STARTTLS.
   */
  if (dryRun) {
    console.log('\nDRY RUN: argumen dan konfigurasi terbaca; TIDAK ada koneksi SMTP, TIDAK ada email dikirim.');
    info('penerima', recipient || '(tidak ada)');
    info('tiket', ticketId || '(tidak ada)');
    info('wait', `${waitSeconds} detik`);
    info('rencana', plannedAction);
    return;
  }

  // --- Tahap 2: DNS ---
  const dnsResult = await resolveHost(config.host);
  if (dnsResult.ok) pass('DNS resolve', dnsResult.addresses.join(', '));
  else fail('DNS resolve gagal', dnsResult.reason);

  // --- Tahap 3: TCP ---
  const tcpResult = await probeTcp(config.host, config.port);
  if (tcpResult.ok) pass(`TCP ${config.host}:${config.port} terbuka`, `${tcpResult.ms} ms`);
  else fail(`TCP ${config.host}:${config.port} gagal`, tcpResult.reason);

  // --- Tahap 4: STARTTLS + autentikasi (Nodemailer verify) ---
  const preflight = await emailService.verifyTransport();
  if (preflight.ok) {
    pass('STARTTLS + autentikasi diterima Brevo',
      `${preflight.mode} | ${preflight.host}:${preflight.port}`);
  } else {
    fail(`preflight gagal pada tahap ${preflight.stage || 'unknown'}`, preflight.reason || '');
  }

  if (failures > 0) {
    console.error('\nPreflight gagal: email TIDAK dikirim. Perbaiki penyebab di atas lebih dulu.');
    process.exitCode = 1;
    return;
  }

  // --- Tahap 5: kirim nyata (opsional) ---
  let messageId = null;
  let sentTo = null;

  if (!ticketId && !recipient) {
    skip('kirim email nyata', 'tidak ada --to / --ticket / VERIFY_EMAIL_TO');
    console.log('        Jalankan: npm run verify:brevo -- --to=inbox-anda@domain.com');
    console.log('        atau    : npm run verify:brevo -- --ticket=<uuid-tiket>');
    console.log('        Bila --to sudah ditulis tetapi pesan ini muncul, jalankan');
    console.log('        "npm.cmd run verify:brevo -- --to=..." agar argumen diteruskan.');
  } else if (ticketId) {
    if (recipient) info('--to diabaikan', 'mode --ticket memakai email peserta dari database');
    const { pool } = require('../src/config/db');
    try {
      const result = await emailService.sendTicketEmail(ticketId, { force: true });
      const delivery = result.delivery || await emailService.emailDeliveryStatusForTicket(ticketId);
      sentTo = delivery?.recipient || null;
      messageId = result.messageId || null;
      if (result.status === 'SENT') {
        pass('e-ticket (PDF + QR) diterima Brevo',
          `messageId=${messageId || '-'} | response=${String(result.response || '-').slice(0, 80)}`);
        info('penerima', `${sentTo} (email peserta pada database)`);
        info('status delivery', `SENT | attempt=${delivery?.attempt_count ?? '-'}`
          + ` | sent_at=${delivery?.sent_at || '-'}`);
      } else {
        fail('pengiriman e-ticket tidak diterima Brevo',
          `${result.status}/${String(result.reason || '').slice(0, 160)}`);
      }
    } catch (error) {
      fail('pengiriman e-ticket gagal', error.message);
    } finally {
      await pool.end().catch(() => {});
    }
  } else {
    try {
      const message = {
        from: config.from,
        to: recipient,
        subject: 'Uji pengiriman Brevo SMTP - E-Ticket Event',
        text: 'Ini email uji dari sistem E-Ticket Event melalui Brevo SMTP. '
          + 'Jika Anda menerimanya di inbox, jalur pengiriman sudah benar.',
        html: '<p>Ini email uji dari sistem <strong>E-Ticket Event</strong> melalui Brevo SMTP.</p>'
          + '<p>Jika Anda menerimanya di inbox, jalur pengiriman sudah benar.</p>',
      };
      const result = await emailService.deliver(message);
      sentTo = recipient;
      messageId = result.messageId || null;
      const rejected = Array.isArray(result.rejected) ? result.rejected : [];
      if (rejected.length > 0) {
        fail('sebagian penerima ditolak penyedia', rejected.join(', '));
      } else {
        pass('Brevo menerima pesan (250 queued)', `messageId=${messageId || '-'}`);
        info('respons SMTP', String(result.response || '-').slice(0, 120));
      }
    } catch (error) {
      fail('Brevo menolak/gagal menerima pesan', error.message);
    }
  }

  // --- Tahap 6: bukti inbox (tidak dapat dipastikan dari mesin ini) ---
  if (sentTo && failures === 0) {
    const events = await fetchBrevoEvents(sentTo, { waitSeconds });
    if (events.ok) {
      const summary = events.events.reduce((acc, item) => {
        const key = String(item?.event || 'unknown');
        acc[key] = (acc[key] || 0) + 1;
        return acc;
      }, {});
      info('event Brevo API', JSON.stringify(summary));
      if (summary.delivered) {
        console.log('        Brevo melaporkan "delivered": server penerima menerima pesan.');
        console.log('        Ini BUKAN jaminan masuk folder inbox (bisa spam/promotions).');
      }
      if (summary.bounce || summary.hardBounce || summary.softBounce) {
        console.warn('        Brevo melaporkan bounce: periksa alamat/penerima.');
      }
    } else {
      info('event Brevo API', `tidak tersedia (${events.reason})`);
    }
    console.log('\nINBOX   : BELUM TERVERIFIKASI dari mesin ini.');
    console.log(`          Periksa ${sentTo} (inbox, spam, promotions) secara manual.`);
    console.log('          "SENT"/"250 queued" hanya berarti Brevo MENERIMA pesan.');
  }

  console.log('\n=== Ringkasan ===');
  console.log(`  Konfigurasi & preflight : ${failures === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`  Kirim ke Brevo          : ${sentTo ? (failures === 0 ? 'ACCEPTED' : 'FAILED') : 'TIDAK DIJALANKAN'}`);
  console.log(`  Diterima di inbox       : ${sentTo ? 'BELUM DIVERIFIKASI (manual)' : '-'}`);
  console.log(`  Tahap dilewati          : ${blocked}`);
  if (failures > 0) process.exitCode = 1;
})().catch((error) => {
  console.error('Verifikasi Brevo gagal:', error.message);
  process.exitCode = 1;
});

