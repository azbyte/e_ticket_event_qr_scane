#!/usr/bin/env node
/*
 * Kirim SATU email uji sungguhan memakai konfigurasi pada backend/.env.
 *
 * Tujuan: membuktikan kredensial & identitas pengirim benar-benar diterima
 * penyedia email TANPA perlu menjalankan seluruh aplikasi. Script ini TIDAK
 * memakai data dummy: pesan benar-benar dikirim ke alamat yang Anda berikan.
 *
 * Pemakaian (dari folder backend/):
 *   npm run email:test -- --to=inbox-anda@gmail.com
 *   npm run email:test -- --to inbox-anda@gmail.com   # bentuk lain, sama
 *   # atau isi VERIFY_EMAIL_TO pada backend/.env lalu:
 *   npm run email:test
 *
 * Exit code 0 hanya bila penyedia MENERIMA pesan (SENT). Ini bukan bukti
 * DELIVERED: periksa inbox dan folder spam secara manual.
 */
const path = require('node:path');

const { createCliOptions } = require('../src/utils/cliArgs');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const emailService = require('../src/services/emailService');

/**
 * Nilai opsi CLI. Menerima `--nama=nilai`, `--nama nilai`, dan cadangan
 * `npm_config_<nama>` (argumen yang tertelan `npm.ps1` di PowerShell), sama
 * seperti `verify-brevo-smtp.js`.
 */
const cli = createCliOptions();
const argValue = (name) => cli.read(name);

(async () => {
  const config = emailService.validateEmailConfig();
  console.log(`Mode transport : ${config.mode}`);
  console.log(`Pengirim (From): ${config.from || '-'}`);
  console.log(`Reply-To       : ${process.env.EMAIL_REPLY_TO_TEST || config.from || '-'}`);

  if (!config.ok) {
    console.error('\nBELUM SIAP: konfigurasi email belum lengkap.');
    if (config.missing.length > 0) {
      console.error(`Variabel belum diisi: ${config.missing.join(', ')}`);
    }
    if (config.reason) console.error(`Alasan: ${config.reason}`);
    console.error(
      '\nIsi konfigurasi pada backend/.env (penyedia aktif: Brevo SMTP):\n'
      + '  EMAIL_PROVIDER=brevo + SMTP_HOST=smtp-relay.brevo.com + SMTP_PORT=587\n'
      + '  + SMTP_USER (login SMTP Brevo) + SMTP_PASS (SMTP key) + EMAIL_FROM terverifikasi\n'
      + 'Jalur lama (RESEND_API_KEY + EMAIL_FROM) tetap didukung sebagai fallback.\n'
      + 'Lalu jalankan ulang perintah ini. Tidak ada email yang dikirim.',
    );
    process.exit(1);
  }

  const to = argValue('to') || String(process.env.VERIFY_EMAIL_TO || '').trim();
  if (!emailService.isValidEmail(to)) {
    console.error(
      '\nAlamat tujuan tidak valid. Gunakan --to=alamat@domain.com, --to alamat@domain.com, '
      + 'atau isi VERIFY_EMAIL_TO pada backend/.env.',
    );
    process.exit(1);
  }

  // Preflight hanya untuk SMTP (verify koneksi + autentikasi). Pada transport
  // HTTPS API, pengiriman itu sendiri yang menjadi bukti; sebagian API key
  // dibatasi hanya untuk mengirim sehingga tidak boleh membaca endpoint lain.
  if (config.mode === 'smtp' || config.mode === 'brevo') {
    const preflight = await emailService.verifyTransport();
    if (!preflight.ok) {
      console.error(`\nPreflight GAGAL: ${preflight.reason || 'tidak diketahui'}`);
      console.error('Periksa host/port/kredensial dan koneksi jaringan. Tidak ada email yang dikirim.');
      process.exit(1);
    }
    console.log('Preflight      : SMTP dapat dihubungi dan kredensial diterima.');
  }

  const info = await emailService.deliver({
    from: config.from,
    to,
    replyTo: String(process.env.EMAIL_REPLY_TO_TEST || config.from),
    subject: 'Uji pengiriman email E-Ticket Event',
    text: 'Ini email uji dari sistem E-Ticket Event. Jika Anda menerimanya, '
      + 'konfigurasi pengiriman email sudah benar.',
    html: '<p>Ini email uji dari sistem <strong>E-Ticket Event</strong>.</p>'
      + '<p>Jika Anda menerimanya, konfigurasi pengiriman email sudah benar.</p>',
  });

  console.log(`\nSENT (diterima penyedia) :: messageId=${info.messageId || '-'}`);
  console.log(`Respons penyedia        : ${info.response || '-'}`);
  console.log('Periksa inbox DAN folder spam. Status SENT bukan bukti DELIVERED.');
})().catch((error) => {
  console.error(`\nFAILED: ${error.message}`);
  console.error('Email TIDAK terkirim. Periksa last_error/log dan konfigurasi backend/.env.');
  process.exit(1);
});
