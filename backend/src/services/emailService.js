const nodemailer = require('nodemailer');
const config = require('../config/env');
const { query, getOne, pool } = require('../config/db');
const ticketDesignService = require('./ticketDesignService');
const ticketCodeService = require('./ticketCodeService');
const { ticketPdfFilename } = require('../utils/ticketFilename');
const logger = require('../utils/logger');

/*
 * Email e-ticket.
 *
 * Mode transport ditentukan HANYA dari environment (tidak ada kredensial di
 * dalam kode):
 *  - `brevo` : SMTP relay Brevo (`smtp-relay.brevo.com`, port 587 + STARTTLS)
 *              dengan kredensial SMTP Brevo. Penyedia email aktif aplikasi.
 *  - `smtp`  : relay SMTP generik lain (host/port dari environment).
 *  - `resend`: transport HTTPS API lama (fallback bila SMTP belum diisi).
 *  - `json`  : transport uji lokal (tanpa jaringan). Hanya diizinkan saat
 *              NODE_ENV=test; status pengiriman TIDAK pernah dilaporkan SENT
 *              karena tidak ada email yang keluar dari server.
 *  - `disabled`: host kosong/`json` di luar test, atau konfigurasi belum
 *              lengkap -> delivery dicatat PENDING secara jujur, tidak pernah
 *              diklaim terkirim.
 *
 * Token QR tidak pernah di-email; QR hanya ada di lampiran PDF.
 */
const isTestEnv = () => String(process.env.NODE_ENV || config.nodeEnv).toLowerCase() === 'test';

/**
 * Profil SMTP Brevo. Nilai di sini PUBLIK (host/port), bukan kredensial:
 * `SMTP_USER` (login SMTP Brevo) dan `SMTP_PASS` (SMTP key) selalu dibaca dari
 * environment. Port 587 Brevo memakai STARTTLS sehingga `secure=false` +
 * `requireTLS=true`.
 */
const BREVO_SMTP = {
  host: 'smtp-relay.brevo.com',
  port: 587,
  secure: false,
  requireTls: true,
};

/** Nilai yang sah untuk `EMAIL_PROVIDER` (`disabled` = alias `none`). */
const EMAIL_PROVIDERS = ['brevo', 'smtp', 'resend', 'none'];

/** True bila host adalah relay Brevo (huruf besar/kecil tidak dibedakan). */
const isBrevoHost = (host) => String(host || '').trim().toLowerCase() === BREVO_SMTP.host;

/** True bila host menunjuk mesin ini sendiri (relay/sink pengujian). */
const isLoopbackHost = (host) => /^(localhost|127\.0\.0\.1|\[?::1\]?)$/i.test(String(host || '').trim());

/** Alamat pengirim valid: `alamat@domain` atau `Nama <alamat@domain>`. */
const EMAIL_FROM_PATTERN = /^(?:[^<>]*<)?[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+>?$/;

/** Satu alamat email tanpa nama tampilan (dipakai untuk penerima & validasi). */
const EMAIL_ADDRESS_PATTERN = /^[^\s<>@,;]+@[^\s<>@,;]+\.[^\s<>@,;]+$/;

/** True bila nilai berupa SATU alamat email yang valid (bukan `Nama <alamat>`). */
const isValidEmail = (value) => EMAIL_ADDRESS_PATTERN.test(String(value || '').trim());

/**
 * Pisahkan nilai pengirim menjadi nama + alamat.
 * Mendukung `alamat@domain` dan `Nama <alamat@domain>`.
 *
 * @returns {{address: string, name: string}|null}
 */
const parseEmailAddress = (value) => {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const named = raw.match(/^(.*?)<\s*([^\s<>@,;]+@[^\s<>@,;]+\.[^\s<>@,;]+)\s*>$/);
  if (named) {
    const name = named[1].trim().replace(/^["']|["']$/g, '').trim();
    return { address: named[2].trim(), name };
  }
  if (isValidEmail(raw)) return { address: raw, name: '' };
  return null;
};

/** Gabungkan nama + alamat menjadi nilai header `From`. */
const formatAddress = ({ address, name }) => (name ? `${name} <${address}>` : address);

/** Domain (huruf kecil) dari sebuah alamat email. */
const domainOf = (address) => String(address || '').split('@').pop().toLowerCase();

/**
 * Konfigurasi identitas pengirim.
 *
 *  - `EMAIL_FROM`                     : alamat TERVERIFIKASI pada penyedia email.
 *  - `EMAIL_FROM_NAME`                : nama tampilan bila EMAIL_FROM tanpa nama.
 *  - `EMAIL_ORGANIZER_FROM_DOMAINS`    : daftar domain yang boleh dipakai sebagai
 *    `From` (domain yang sudah diverifikasi di penyedia). Kosong = alamat
 *    penyelenggara TIDAK dipakai sebagai `From`, hanya sebagai `Reply-To`.
 *  - `EMAIL_REPLY_TO_ORGANIZER`       : `false` untuk mematikan Reply-To dinamis.
 *  - `EMAIL_RESEND_COOLDOWN_SECONDS`  : jeda minimal kirim ulang eksplisit.
 *
 * Alamat penyelenggara tidak pernah dipakai untuk AUTENTIKASI SMTP: kredensial
 * tetap hanya dari `SMTP_USER`/`SMTP_PASS`. Ini mencegah spoofing sekaligus
 * menjaga agar email tetap dapat dikirim walau penyelenggara tidak memberikan
 * password emailnya.
 */
const senderConfig = () => ({
  verified: parseEmailAddress(process.env.EMAIL_FROM || ''),
  verifiedName: String(process.env.EMAIL_FROM_NAME || '').trim(),
  organizerDomains: String(process.env.EMAIL_ORGANIZER_FROM_DOMAINS || '')
    .split(',')
    .map((domain) => domain.trim().toLowerCase().replace(/^@/, ''))
    .filter(Boolean),
  replyToOrganizer: !/^(0|false|no)$/i.test(
    String(process.env.EMAIL_REPLY_TO_ORGANIZER ?? 'true'),
  ),
  resendCooldownSeconds: Math.max(0, Number(process.env.EMAIL_RESEND_COOLDOWN_SECONDS || 60) || 0),
});

/**
 * Tentukan identitas pengirim untuk satu tiket.
 *
 * Aturan:
 *  1. `From` = email penyelenggara HANYA bila penyedia email mengizinkannya,
 *     yaitu saat alamat itu sama dengan akun SMTP terautentikasi, sama dengan
 *     `EMAIL_FROM` terverifikasi, atau domainnya terdaftar pada
 *     `EMAIL_ORGANIZER_FROM_DOMAINS` (domain terverifikasi di penyedia).
 *  2. Selain itu `From` = `EMAIL_FROM` terverifikasi dan email penyelenggara
 *     dipasang sebagai `Reply-To`, sehingga balasan peserta tetap menuju
 *     penyelenggara tanpa memalsukan identitas pengirim.
 *  3. Penerima tidak pernah dipakai sebagai pengirim.
 *
 * @returns {{
 *   from: string, fromAddress: string, fromName: string, fromOrganizer: boolean,
 *   replyTo: string|null, organizerEmail: string|null, organizerName: string|null
 * }}
 */
const resolveSender = (ticket) => {
  const cfg = senderConfig();
  const verifiedAddress = cfg.verified?.address || '';
  const verifiedName = cfg.verified?.name || cfg.verifiedName;
  const smtpUser = String(process.env.SMTP_USER || '').trim().toLowerCase();
  const organizerRaw = String(ticket?.organizer_email || '').trim();
  const organizerEmail = isValidEmail(organizerRaw) ? organizerRaw : '';
  const organizerName = String(ticket?.organizer_name || '').trim();

  const organizerAuthorized = Boolean(organizerEmail) && (
    organizerEmail.toLowerCase() === smtpUser
    || organizerEmail.toLowerCase() === verifiedAddress.toLowerCase()
    || (domainOf(organizerEmail) && cfg.organizerDomains.includes(domainOf(organizerEmail)))
  );

  const from = organizerAuthorized
    ? { address: organizerEmail, name: organizerName || cfg.verifiedName || '' }
    : { address: verifiedAddress, name: verifiedName || '' };

  const organizerAsReplyTo = cfg.replyToOrganizer && organizerEmail
    && organizerEmail.toLowerCase() !== from.address.toLowerCase();
  const replyTo = organizerAsReplyTo ? organizerEmail : (from.address || null);

  return {
    from: from.address ? formatAddress(from) : '',
    fromAddress: from.address || '',
    fromName: from.name || '',
    fromOrganizer: organizerAuthorized,
    replyTo: replyTo || null,
    organizerEmail: organizerEmail || null,
    organizerName: organizerName || null,
  };
};

/** Ringkasan identitas pengirim untuk respons API/log (tanpa kredensial). */
const senderInfo = (sender) => ({
  from: sender?.fromAddress || null,
  name: sender?.fromName || null,
  organizer: Boolean(sender?.fromOrganizer),
  reply_to: sender?.replyTo || null,
});

/*
 * Konfigurasi SMTP dibaca ulang dari environment setiap kali dipakai agar
 * perubahan .env (atau kegagalan konfigurasi) tidak "nyangkut" pada nilai yang
 * sudah di-cache saat proses pertama kali start.
 *
 * `EMAIL_PROVIDER=brevo` membuat host/port/TLS memakai profil Brevo secara
 * default, sehingga cukup mengisi kredensial. `SMTP_HOST`/`SMTP_PORT`/
 * `SMTP_SECURE`/`SMTP_REQUIRE_TLS` tetap boleh menimpa nilai default tersebut
 * (mis. untuk pengujian dengan relay lokal).
 */
const emailProvider = () => {
  const raw = String(process.env.EMAIL_PROVIDER || '').trim().toLowerCase();
  if (!raw) return '';
  return raw === 'disabled' ? 'none' : raw;
};

const smtpConfig = () => {
  const provider = emailProvider();
  const useBrevoDefaults = provider === 'brevo';
  const rawPort = String(process.env.SMTP_PORT ?? '').trim();
  const rawSecure = String(process.env.SMTP_SECURE ?? '').trim().toLowerCase();
  const rawRequireTls = String(process.env.SMTP_REQUIRE_TLS ?? '').trim().toLowerCase();

  const host = String(process.env.SMTP_HOST || '').trim()
    || (useBrevoDefaults ? BREVO_SMTP.host : '');
  const port = rawPort === ''
    ? (useBrevoDefaults ? BREVO_SMTP.port : 587)
    : Number(rawPort);
  const secure = rawSecure === ''
    ? (useBrevoDefaults ? BREVO_SMTP.secure : false)
    : rawSecure === 'true';
  const brevo = useBrevoDefaults || isBrevoHost(host);
  // Port 587 Brevo memakai STARTTLS: wajib, bukan sekadar "bila server
  // menawarkan", supaya pesan (termasuk kredensial AUTH) tidak turun ke
  // koneksi polos. Bila `secure=true` (port 465) TLS sudah implisit.
  const requireTls = secure
    ? false
    : (rawRequireTls === '' ? brevo : rawRequireTls === 'true');

  return {
    provider,
    brevo,
    host,
    port,
    secure,
    requireTls,
    loopback: isLoopbackHost(host),
    user: String(process.env.SMTP_USER || '').trim(),
    pass: String(process.env.SMTP_PASS || ''),
    from: String(process.env.EMAIL_FROM || '').trim(),
    fromName: String(process.env.EMAIL_FROM_NAME || '').trim(),
  };
};

/**
 * Opsi transport Nodemailer (tanpa membuat koneksi).
 *
 * Dipisahkan agar dapat diperiksa oleh unit test dan log startup tanpa
 * menyentuh jaringan, serta agar nilai rahasia tidak pernah ikut tercetak.
 */
const smtpTransportOptions = () => {
  const smtp = smtpConfig();
  return {
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    ...(smtp.requireTls ? { requireTLS: true } : {}),
    // Batas waktu eksplisit: tanpa ini kegagalan jaringan dapat menggantung
    // lebih lama dari masa klaim pengiriman sehingga tiket dinilai ganda.
    connectionTimeout: Number(process.env.SMTP_CONNECTION_TIMEOUT_MS || 20000),
    greetingTimeout: Number(process.env.SMTP_GREETING_TIMEOUT_MS || 20000),
    socketTimeout: Number(process.env.SMTP_SOCKET_TIMEOUT_MS || 45000),
    ...(smtp.user ? { auth: { user: smtp.user, pass: smtp.pass } } : {}),
  };
};

/**
 * Konfigurasi penyedia email berbasis HTTPS API (Resend).
 *
 * Dipakai ketika jaringan/hosting memblokir port SMTP (25/465/587). Tidak ada
 * dependensi baru: API-nya hanya HTTP POST/GET biasa. Kredensial tetap hanya
 * dibaca dari environment, tidak pernah ditulis di kode.
 */
const resendConfig = () => ({
  apiKey: String(process.env.RESEND_API_KEY || '').trim(),
  endpoint: String(process.env.RESEND_API_URL || 'https://api.resend.com').replace(/\/$/, ''),
  from: String(process.env.EMAIL_FROM || '').trim(),
  fromName: String(process.env.EMAIL_FROM_NAME || '').trim(),
});

/**
 * Status konfigurasi transport email tanpa membocorkan nilai rahasia.
 *
 * Urutan pemilihan penyedia:
 *  1. `EMAIL_PROVIDER` bila diisi (`brevo` | `smtp` | `resend` | `none`).
 *  2. Tanpa `EMAIL_PROVIDER`: SMTP/Brevo bila host tersedia, lalu HTTPS API
 *     Resend (jalur lama) bila `RESEND_API_KEY` diisi, lalu `disabled`.
 *
 * SMTP didahulukan karena penyedia aktif aplikasi adalah Brevo SMTP. Kunci API
 * lama tetap dihormati sebagai fallback agar deployment lain tidak rusak.
 *
 * @returns {{
 *   provider: string,
 *   mode: 'brevo'|'smtp'|'resend'|'json'|'disabled',
 *   configured: boolean,
 *   auth: boolean,
 *   host: string|null,
 *   port: number,
 *   secure: boolean,
 *   requireTls: boolean,
 *   brevo: boolean,
 *   loopback: boolean,
 *   from: string|null,
 *   missing: string[],
 *   reason: string|null
 * }}
 */
const smtpStatus = () => {
  // Lingkungan yang boleh memakai relay lokal/webhook (host loopback, port
  // kustom, atau transport uji). Relay seperti itu tidak wajib punya kredensial.
  const isLocalRelayEnv = () => /^(1|true|yes)$/i.test(String(process.env.SMTP_ALLOW_LOCAL_RELAY || ''));

  const provider = emailProvider();
  const smtp = smtpConfig();
  const resend = resendConfig();
  const missing = [];
  const base = {
    provider: provider || 'auto',
    mode: 'disabled',
    configured: false,
    auth: false,
    host: smtp.host || null,
    port: smtp.port,
    secure: smtp.secure,
    requireTls: smtp.requireTls,
    brevo: smtp.brevo,
    loopback: smtp.loopback,
    from: smtp.from || resend.from || null,
    missing,
    reason: null,
  };

  /** Validasi jalur HTTPS API lama (fallback, bukan penyedia utama). */
  const resendStatus = () => {
    if (!resend.apiKey) {
      missing.push('RESEND_API_KEY');
      return {
        ...base,
        reason: 'EMAIL_PROVIDER=resend tetapi RESEND_API_KEY kosong; email BELUM dikirim.',
      };
    }
    if (!resend.from || !EMAIL_FROM_PATTERN.test(resend.from)) {
      missing.push('EMAIL_FROM');
      return {
        ...base,
        reason: 'RESEND_API_KEY diisi tetapi EMAIL_FROM kosong/tidak valid; email BELUM dikirim.',
      };
    }
    return {
      ...base,
      mode: 'resend',
      configured: true,
      auth: true,
      from: resend.from,
    };
  };

  if (provider && !EMAIL_PROVIDERS.includes(provider)) {
    return {
      ...base,
      reason: `EMAIL_PROVIDER="${provider}" tidak dikenal (pilihan: ${EMAIL_PROVIDERS.join(', ')}); email BELUM dikirim.`,
    };
  }

  if (provider === 'resend') return resendStatus();
  if (provider === 'none') {
    return {
      ...base,
      reason: 'EMAIL_PROVIDER=none: pengiriman email dinonaktifkan lewat konfigurasi.',
    };
  }

  if (smtp.host === 'json') {
    if (isTestEnv()) {
      return { ...base, mode: 'json', configured: true };
    }
    return {
      ...base,
      reason: 'SMTP_HOST=json hanya untuk pengujian otomatis; email BELUM dikirim ke jaringan.',
    };
  }

  if (!smtp.host) {
    // Mode otomatis: jalur HTTPS API lama tetap dipakai bila API key tersedia.
    if (!provider && resend.apiKey) return resendStatus();
    // Laporkan SEMUA yang belum tersedia, bukan hanya SMTP_HOST: tanpa jalur
    // HTTPS, konfigurasi SMTP lengkap (port/user/pass) juga wajib diisi.
    missing.push(provider === 'smtp' ? 'SMTP_HOST' : 'RESEND_API_KEY|SMTP_HOST');
    if (!smtp.from) missing.push('EMAIL_FROM');
    return {
      ...base,
      reason:
        'Layanan email belum dikonfigurasi. Isi pada backend/.env: '
        + 'EMAIL_PROVIDER=brevo + SMTP_HOST=smtp-relay.brevo.com + SMTP_PORT=587 '
        + '+ SMTP_USER (login SMTP Brevo) + SMTP_PASS (SMTP key) + EMAIL_FROM. '
        + 'Jalur HTTPS API lama (RESEND_API_KEY + EMAIL_FROM) tetap didukung sebagai fallback. '
        + 'Email BELUM dikirim.',
    };
  }

  if (!Number.isInteger(smtp.port) || smtp.port < 1 || smtp.port > 65535) {
    missing.push('SMTP_PORT');
    return {
      ...base,
      reason: 'SMTP_PORT tidak valid (harus 1-65535); email BELUM dikirim.',
    };
  }

  // Autentikasi opsional (relay lokal), tetapi bila salah satu diisi maka
  // pasangannya wajib ada. Nilai password tidak pernah dilaporkan.
  if (smtp.user && !smtp.pass) {
    missing.push('SMTP_PASS');
    return {
      ...base,
      reason: smtp.brevo
        ? 'SMTP_USER Brevo diisi tetapi SMTP_PASS kosong (isi SMTP key Brevo, bukan password akun); email BELUM dikirim.'
        : 'SMTP_USER diisi tetapi SMTP_PASS kosong; email BELUM dikirim.',
    };
  }
  if (!smtp.user && smtp.pass) {
    missing.push('SMTP_USER');
    return {
      ...base,
      reason: smtp.brevo
        ? 'SMTP_PASS Brevo diisi tetapi SMTP_USER kosong (login SMTP Brevo, mis. 1234567@smtp-brevo.com); email BELUM dikirim.'
        : 'SMTP_PASS diisi tetapi SMTP_USER kosong; email BELUM dikirim.',
    };
  }

  if (!smtp.from || !EMAIL_FROM_PATTERN.test(smtp.from)) {
    missing.push('EMAIL_FROM');
    return {
      ...base,
      reason: 'EMAIL_FROM belum diisi atau bukan alamat email yang valid; email BELUM dikirim.',
    };
  }

  // SMTP relay nyata (selain relay lokal, dan tanpa SMTP_ALLOW_LOCAL_RELAY)
  // wajib memakai autentikasi. Tanpa ini pesan hanya akan ditolak relay
  // (550/535) setelah pendaftaran peserta selesai.
  if (!smtp.user && !smtp.loopback && !isLocalRelayEnv()) {
    missing.push('SMTP_USER', 'SMTP_PASS');
    return {
      ...base,
      reason: smtp.brevo
        ? 'Brevo SMTP mewajibkan SMTP_USER (login SMTP Brevo) dan SMTP_PASS (SMTP key); email BELUM dikirim.'
        : 'SMTP_HOST diisi tetapi SMTP_USER/SMTP_PASS kosong; email BELUM dikirim.',
    };
  }

  return {
    ...base,
    mode: smtp.brevo ? 'brevo' : 'smtp',
    configured: true,
    auth: Boolean(smtp.user),
    from: smtp.from,
  };
};

const transportMode = () => smtpStatus().mode;

/**
 * Validasi konfigurasi email untuk dipanggil saat backend dijalankan.
 *
 * Mengembalikan daftar variabel yang belum tersedia dan alasan yang dapat
 * ditindaklanjuti. Tidak pernah memuat nilai rahasia.
 */
const validateEmailConfig = () => {
  const status = smtpStatus();
  const cfg = senderConfig();
  return {
    ok: status.configured,
    provider: status.provider,
    mode: status.mode,
    host: status.host,
    port: status.port,
    secure: status.secure,
    requireTls: status.requireTls,
    loopback: status.loopback,
    missing: status.missing,
    reason: status.reason,
    from: status.from,
    organizerFromDomains: cfg.organizerDomains,
    replyToOrganizer: cfg.replyToOrganizer,
    resendCooldownSeconds: cfg.resendCooldownSeconds,
  };
};

/** Pesan alasan saat transport tidak tersedia (disimpan sebagai last_error). */
const unavailableReason = () =>
  smtpStatus().reason || 'Layanan email belum dikonfigurasi; email BELUM dikirim.';

let transport;
let transportKey = '';
const getTransport = () => {
  const status = smtpStatus();
  if (status.mode === 'disabled') return null;
  const smtp = smtpConfig();
  const key = status.mode === 'json'
    ? 'json'
    : `${status.mode}:${smtp.host}:${smtp.port}:${smtp.secure}:${smtp.requireTls}:${smtp.user}:${smtp.from}`;
  if (transport && key === transportKey) return transport;
  transportKey = key;
  transport = status.mode === 'json'
    ? nodemailer.createTransport({ jsonTransport: true })
    : nodemailer.createTransport(smtpTransportOptions());
  return transport;
};

/**
 * Kirim satu pesan melalui HTTPS API (Resend).
 *
 * Mengembalikan bentuk yang sama dengan `nodemailer.sendMail` (messageId,
 * accepted, rejected, response) agar jalur pencatatan status tidak berubah.
 * Lampiran PDF dikirim sebagai base64.
 */
const sendViaResend = async (message) => {
  const resend = resendConfig();
  // Hormati identitas pengirim yang sudah ditentukan `resolveSender()` (mis.
  // email penyelenggara yang domainnya terverifikasi). Fallback ke EMAIL_FROM.
  const fromAddress = message.from
    || (resend.fromName ? `${resend.fromName} <${resend.from}>` : resend.from);
  const payload = {
    from: fromAddress,
    to: Array.isArray(message.to) ? message.to : [message.to],
    subject: message.subject,
    text: message.text,
    html: message.html,
    ...(message.replyTo ? { reply_to: message.replyTo } : {}),
    ...(Array.isArray(message.attachments) && message.attachments.length > 0
      ? {
        attachments: message.attachments.map((file) => ({
          filename: file.filename,
          content: Buffer.isBuffer(file.content)
            ? file.content.toString('base64')
            : String(file.content || ''),
          content_type: file.contentType || 'application/octet-stream',
        })),
      }
      : {}),
  };

  const response = await fetch(`${resend.endpoint}/emails`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resend.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(Number(process.env.EMAIL_API_TIMEOUT_MS || 30000)),
  });

  const raw = await response.text();
  let parsed = null;
  try { parsed = JSON.parse(raw); } catch (_e) { parsed = null; }

  if (!response.ok) {
    // Pesan error penyedia diteruskan apa adanya (tanpa API key) agar penyebab
    // kegagalan dapat diketahui dari log/last_error.
    const detail = parsed?.message || parsed?.error?.message || raw.slice(0, 300);
    const error = new Error(`resend_${response.status}: ${detail}`);
    error.code = `RESEND_${response.status}`;
    throw error;
  }

  return {
    messageId: parsed?.id || null,
    response: `resend accepted (${response.status})`,
    accepted: payload.to,
    rejected: [],
    pending: [],
  };
};

/**
 * Kirim satu pesan memakai transport aktif (`resend` atau `smtp`).
 * Titik tunggal ini menjaga perilaku pencatatan status tetap sama.
 */
const deliver = async (message) => {
  const mode = transportMode();
  if (mode === 'resend') return sendViaResend(message);
  const mailTransport = getTransport();
  if (!mailTransport) throw new Error(unavailableReason());
  return mailTransport.sendMail(message);
};

/**
 * Klasifikasi kegagalan SMTP agar diagnosis tidak menebak-nebak.
 *
 * Tahapan: `dns` (nama host tidak resolve), `connect` (port tertutup/timeout),
 * `tls` (STARTTLS gagal), `auth` (kredensial ditolak), `sender` (alamat From
 * belum diverifikasi penyedia), `send` (lain-lain).
 *
 * @returns {{stage: string, hint: string}}
 */
const classifySmtpError = (error) => {
  const code = String(error?.code || '').toUpperCase();
  const response = String(error?.response || error?.message || '');
  // Nodemailer membungkus banyak kegagalan koneksi sebagai `ESOCKET`, jadi
  // pesan/kode asli (ECONNREFUSED, ETIMEDOUT, sertifikat) harus ikut dibaca.
  const raw = `${code} ${response}`;
  const smtp = smtpConfig();
  if (/sender|from address|not valid|unverified|not verified/i.test(response)) {
    return {
      stage: 'sender',
      hint: 'Alamat EMAIL_FROM belum diverifikasi sebagai sender di Brevo (menu Senders & IP).',
    };
  }
  if (code === 'EAUTH' || /\b(535|534|530)\b/.test(response)) {
    return {
      stage: 'auth',
      hint: 'Kredensial SMTP ditolak: periksa SMTP_USER (login SMTP Brevo) dan SMTP_PASS (SMTP key, bukan password akun).',
    };
  }
  if (code === 'EDNS' || code === 'ENOTFOUND' || code === 'EAI_AGAIN') {
    return {
      stage: 'dns',
      hint: `Nama host ${smtp.host || 'SMTP'} tidak dapat di-resolve; periksa koneksi/DNS.`,
    };
  }
  if (/ECONNREFUSED|ETIMEDOUT|ECONNECTION|EHOSTUNREACH|ENETUNREACH|ECONNRESET/i.test(raw)) {
    return {
      stage: 'connect',
      hint: `Koneksi ke ${smtp.host || 'host SMTP'}:${smtp.port} gagal/diblokir; periksa jaringan atau firewall port keluar.`,
    };
  }
  if (code === 'ETLS' || /STARTTLS|certificate|ssl|tls/i.test(response)) {
    return {
      stage: 'tls',
      hint: smtp.brevo
        ? 'Negosiasi TLS/STARTTLS gagal; port 587 Brevo membutuhkan STARTTLS (SMTP_SECURE=false, SMTP_REQUIRE_TLS=true).'
        : 'Negosiasi TLS/STARTTLS gagal; periksa SMTP_SECURE/SMTP_REQUIRE_TLS dan sertifikat server.',
    };
  }
  return { stage: 'send', hint: '' };
};

/**
 * Preflight transport: pastikan penyedia benar-benar dapat dihubungi dan
 * kredensial diterima. Tidak pernah melempar error dan tidak membocorkan
 * password/API key.
 *
 * @returns {Promise<{ok: boolean, skipped?: boolean, mode?: string, stage?: string,
 *   host?: string|null, port?: number, reason: string|null}>}
 */
const verifyTransport = async () => {
  const status = smtpStatus();
  if (status.mode === 'disabled') {
    return { ok: false, skipped: true, mode: status.mode, stage: 'config', reason: status.reason };
  }
  if (status.mode === 'json') {
    return {
      ok: false,
      skipped: true,
      mode: status.mode,
      stage: 'config',
      reason: 'Transport uji json tidak memakai jaringan.',
    };
  }
  if (status.mode === 'resend') {
    const resend = resendConfig();
    try {
      // Endpoint baca-ringan: membuktikan API key diterima tanpa mengirim email.
      const response = await fetch(`${resend.endpoint}/domains`, {
        headers: { Authorization: `Bearer ${resend.apiKey}` },
        signal: AbortSignal.timeout(Number(process.env.EMAIL_API_TIMEOUT_MS || 30000)),
      });
      if (response.ok) return { ok: true, mode: status.mode, stage: 'ready', reason: null };
      const body = await response.text();
      logger.error('ticket_email_transport_preflight_failed', {
        mode: 'resend', status: response.status, body: body.slice(0, 300),
      });
      return {
        ok: false, mode: status.mode, stage: 'api', reason: `resend_${response.status}: ${body.slice(0, 200)}`,
      };
    } catch (error) {
      logger.error('ticket_email_transport_preflight_failed', {
        mode: 'resend', error: error.message,
      });
      return { ok: false, mode: status.mode, stage: 'api', reason: error.message };
    }
  }
  const mailTransport = getTransport();
  if (!mailTransport) {
    return {
      ok: false, skipped: true, mode: status.mode, stage: 'config', reason: unavailableReason(),
    };
  }
  try {
    await mailTransport.verify();
    return {
      ok: true,
      mode: status.mode,
      stage: 'ready',
      host: status.host,
      port: status.port,
      reason: null,
    };
  } catch (error) {
    const { stage, hint } = classifySmtpError(error);
    logger.error('ticket_email_transport_preflight_failed', {
      mode: status.mode,
      host: status.host,
      port: status.port,
      stage,
      error: error.message,
      code: error.code || null,
    });
    resetTransport();
    const reason = `${error.code ? error.code + ': ' : ''}${error.message}${hint ? ` | ${hint}` : ''}`;
    return {
      ok: false, mode: status.mode, stage, host: status.host, port: status.port, reason,
    };
  }
};

/** Buang transport dari cache agar konfigurasi/kegagalan tidak "nyangkut". */
const resetTransport = () => { transport = null; transportKey = ''; };

const escapeHtml = (value) => String(value ?? '')
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/**
 * Data minimal yang dibutuhkan email + lampiran tiket.
 *
 * Nama event SELALU diambil dari tabel `events` melalui relasi
 * `tickets.event_id` (bukan dari payload/order), sehingga tidak mungkin
 * tertukar dengan event lain atau bernilai null/undefined.
 */
const loadTicketContext = (ticketId) => getOne(
  `SELECT t.id, t.ticket_code, t.status, t.event_id, t.ticket_type_id,
          t.attendee_id, a.name AS attendee_name, a.email AS attendee_email,
          tt.name AS ticket_type_name,
          e.title AS event_title, e.event_date, e.end_date_time, e.location,
          e.online_url, e.organizer_name, e.contact_info,
          p.email AS organizer_email
   FROM tickets t
   JOIN events e ON e.id = t.event_id
   LEFT JOIN attendees a ON a.id = t.attendee_id
   LEFT JOIN ticket_types tt ON tt.id = t.ticket_type_id
   LEFT JOIN profiles p ON p.id = e.created_by
   WHERE t.id = $1`,
  [ticketId]
);

const formatEventDate = (value) => {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'long',
    timeStyle: 'short',
    timeZone: 'Asia/Jakarta',
  }).format(date);
};

/** Label nama event: selalu nilai dari DB; '-' hanya bila data benar-benar kosong. */
const eventTitleOf = (ticket) => {
  const title = String(ticket?.event_title ?? '').trim();
  return title.length > 0 ? title : '(nama event tidak tersedia)';
};

const buildMessage = (ticket, recipient, { attachment = null } = {}) => {
  const date = formatEventDate(ticket.event_date);
  const eventTitle = eventTitleOf(ticket);
  const location = String(ticket?.location || ticket?.online_url || '').trim() || '-';
  // Tautan menuju halaman tiket publik; token akses guest tidak pernah
  // ditempatkan pada URL (PRD §8.2 / C-02).
  const url = ticket.event_id
    ? `${config.appPublicUrl}/e/${ticket.event_id}/ticket/${ticket.id}`
    : `${config.appPublicUrl}/tickets/${ticket.id}`;
  const attendeeName = String(ticket?.attendee_name || '').trim() || 'Peserta';
  const ticketType = String(ticket?.ticket_type_name || '').trim() || '-';
  const organizerName = String(ticket?.organizer_name || '').trim();
  const organizerEmail = String(ticket?.organizer_email || '').trim();
  // Baris penyelenggara hanya ditampilkan bila datanya benar-benar ada.
  const organizerLine = organizerName && organizerEmail
    ? `Penyelenggara: ${organizerName} (${organizerEmail})`
    : organizerName
      ? `Penyelenggara: ${organizerName}`
      : organizerEmail
        ? `Penyelenggara: ${organizerEmail}`
        : null;
  const text = [
    `Halo ${attendeeName},`,
    `Tiket ${ticket.ticket_code} untuk ${eventTitle} telah terbit.`,
    `Jenis: ${ticketType} | Jadwal: ${date}`,
    `Lokasi: ${location}`,
    ...(organizerLine ? [organizerLine] : []),
    `Buka e-ticket dan QR dari perangkat yang dipakai saat memesan: ${url}`,
    attachment
      ? 'E-ticket PDF dengan QR unik terlampir pada email ini. Jangan bagikan QR Anda.'
      : 'Buka e-ticket di aplikasi untuk melihat QR unik. Jangan bagikan QR Anda.',
  ].join('\n');
  const html = `<p>Halo ${escapeHtml(attendeeName)},</p>
<p>Tiket untuk <strong>${escapeHtml(eventTitle)}</strong> telah terbit.</p>
<ul><li>Kode: ${escapeHtml(ticket.ticket_code || '-')}</li>
<li>Jenis: ${escapeHtml(ticketType)}</li>
<li>Jadwal: ${escapeHtml(date)}</li>
<li>Lokasi: ${escapeHtml(location)}</li>${organizerLine ? `
<li>${escapeHtml(organizerLine)}</li>` : ''}</ul>
<p><a href="${escapeHtml(url)}">Buka e-ticket di aplikasi</a>.</p>
${attachment ? '<p>E-ticket PDF dengan QR unik terlampir pada email ini.</p>' : '<p>Buka e-ticket di aplikasi untuk melihat QR unik.</p>'}`;
  const sender = resolveSender(ticket);
  return {
    ...(sender.from ? { from: sender.from } : {}),
    // Envelope eksplisit: beberapa relay menolak alamat envelope yang berbeda
    // dari akun terautentikasi. Nilainya mengikuti alamat From yang dipakai.
    ...(sender.fromAddress
      ? { envelope: { from: sender.fromAddress, to: recipient } }
      : {}),
    ...(sender.replyTo ? { replyTo: sender.replyTo } : {}),
    to: recipient,
    subject: `E-Ticket ${eventTitle} - ${ticket.ticket_code || ''}`.trim(),
    text,
    html,
    ...(attachment ? { attachments: [attachment] } : {}),
  };
};

/**
 * Simpan/perbarui catatan pengiriman satu tiket.
 *
 * Pencarian baris memakai `lower(recipient)` agar konsisten dengan
 * `claimDelivery` dan `emailDeliveryStatusForTicket` (alamat email tidak case
 * sensitive). Baris `SENT` tidak pernah diturunkan kembali ke status lain.
 */
const upsertDelivery = async ({
  ticketId, recipient, status, error, incrementAttempt = true, retryDelayMs,
  allowSentUpdate = false, preserveSent = false,
}) => {
  const retryAt = new Date(
    Date.now() + (Number(retryDelayMs) > 0 ? Number(retryDelayMs) : 15 * 60 * 1000),
  ).toISOString();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT pg_catalog.pg_advisory_xact_lock(
         pg_catalog.hashtextextended($1::uuid::text || ':' || $2::varchar(320), 0)
       )`,
      [ticketId, recipient],
    );
    const existing = await client.query(
      `SELECT id FROM ticket_email_deliveries
        WHERE ticket_id=$1 AND lower(recipient)=lower($2::varchar(320))
        ORDER BY created_at DESC LIMIT 1
        FOR UPDATE`,
      [ticketId, recipient],
    );
    let result;
    if (existing.rows[0]) {
      if (preserveSent) {
        // Kirim ulang eksplisit gagal padahal pengiriman sebelumnya SENT:
        // status SENT dipertahankan (peserta sudah menerima tiket), kegagalan
        // percobaan ini tetap tercatat pada last_error.
        result = await client.query(
          `UPDATE ticket_email_deliveries
           SET attempt_count=attempt_count+$2,
               last_error=$3,
               next_attempt_at=NULL
           WHERE id=$1
           RETURNING *`,
          [existing.rows[0].id, incrementAttempt ? 1 : 0, error],
        );
      } else {
        // Catatan: parameter penerima ($2) tidak dipakai pada UPDATE. Parameter
        // yang dikirim tetapi tidak dirujuk membuat PostgreSQL menolak query
        // ("could not determine data type of parameter"), sehingga catatan
        // kegagalan/percobaan ulang tidak pernah tersimpan.
        result = await client.query(
          `UPDATE ticket_email_deliveries
           SET status=$2::"EmailDeliveryStatus",
               attempt_count=attempt_count+$3,
               last_error=$4,
               sent_at=CASE WHEN $2::"EmailDeliveryStatus"='SENT' THEN NOW() ELSE sent_at END,
               next_attempt_at=CASE WHEN $2::"EmailDeliveryStatus"='FAILED' THEN $5::timestamptz ELSE NULL END
           WHERE id=$1
             ${allowSentUpdate ? '' : `AND status <> 'SENT'::"EmailDeliveryStatus"`}
           RETURNING *`,
          [existing.rows[0].id, status, incrementAttempt ? 1 : 0, error, retryAt],
        );
        if (!result.rows[0]) {
          // Baris sudah SENT: kembalikan apa adanya, jangan diturunkan.
          result = await client.query(
            'SELECT * FROM ticket_email_deliveries WHERE id=$1',
            [existing.rows[0].id],
          );
        }
      }
    } else {
      result = await client.query(
        `INSERT INTO ticket_email_deliveries
           (id,ticket_id,recipient,status,attempt_count,last_error,sent_at,next_attempt_at,created_at)
         VALUES (gen_random_uuid(),$1::uuid,$2::varchar(320),$3::"EmailDeliveryStatus",$4,$5,
                 CASE WHEN $3::"EmailDeliveryStatus"='SENT' THEN NOW() ELSE NULL END,
                 CASE WHEN $3::"EmailDeliveryStatus"='FAILED' THEN $6::timestamptz ELSE NULL END,NOW())
         ON CONFLICT DO NOTHING
         RETURNING *`,
        [ticketId, recipient, status, incrementAttempt ? 1 : 0, error, retryAt],
      );
      if (!result.rows[0]) {
        // Balapan dengan proses lain yang baru membuat baris: pakai baris itu.
        result = await client.query(
          `SELECT * FROM ticket_email_deliveries
            WHERE ticket_id=$1 AND lower(recipient)=lower($2::varchar(320))
            ORDER BY created_at DESC LIMIT 1`,
          [ticketId, recipient],
        );
      }
    }
    await client.query('COMMIT');
    return result?.rows?.[0] || null;
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* transaction already ended */ }
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Tandai tiket sedang menunggu pengiriman (status belum terkirim) tanpa
 * menunggu SMTP. Dipakai oleh antrean pengiriman agar peserta/klien dapat
 * melihat status jujur segera setelah tiket terbit.
 *
 * Catatan: catatan yang sudah `SENT` tidak pernah diturunkan kembali.
 */
const markQueued = async (ticketId, recipient, reason) => {
  const to = String(recipient || '').trim();
  if (!to) return null;
  const existing = await getOne(
    `SELECT status FROM ticket_email_deliveries
      WHERE ticket_id=$1 AND lower(recipient)=lower($2)
      ORDER BY created_at DESC LIMIT 1`,
    [ticketId, to],
  );
  if (existing?.status === 'SENT') return null;
  return upsertDelivery({
    ticketId,
    recipient: to,
    status: 'PENDING',
    error: reason || 'Menunggu pengiriman email.',
    incrementAttempt: false,
  });
};

/** Lama klaim pengiriman berlaku (detik). Melebihi ini klaim dianggap gugur. */
const SEND_CLAIM_SECONDS = Number(process.env.EMAIL_SEND_CLAIM_SECONDS || 120);

/**
 * Jeda sebelum percobaan berikutnya setelah kegagalan (backoff linear).
 *
 * Tujuannya mencegah dua hal sekaligus: (1) hammering relay yang sedang down,
 * dan (2) pengiriman ganda ketika upstream (mis. relay penerima) sebenarnya
 * sudah menerima pesan walau respons gagal diterima server ini.
 */
const RETRY_BASE_DELAY_MS = Number(process.env.EMAIL_RETRY_BASE_DELAY_MS || 60000);
const retryDelayFor = (attemptCount) => {
  const attempt = Math.max(1, Number(attemptCount) || 1);
  return Math.min(attempt, 10) * RETRY_BASE_DELAY_MS;
};

/**
 * Ambil hak kirim (klaim) untuk satu tiket penerima secara ATOMIK.
 *
 * Penjaga anti email ganda yang menentukan: hanya SATU proses yang boleh
 * mengirim satu tiket ke satu penerima. Klaim dilakukan dalam satu UPDATE
 * bersyarat sehingga aman terhadap retry paralel, permintaan klik ganda, dan
 * lebih dari satu instance backend:
 *
 *  - baris `SENT`                 -> tidak diklaim (`already_sent`), KECUALI
 *    `allowResend` (permintaan kirim ulang eksplisit pengguna) dan jeda
 *    cooldown sudah lewat. Baris tetap `SENT` agar riwayat tidak turun.
 *  - baris `PENDING` yang masih dalam masa klaim -> tidak diklaim (`in_progress`).
 *  - selain itu (belum ada, `FAILED`, `PENDING` kedaluwarsa) -> klaim diberikan
 *    dengan menandai `PENDING` + `next_attempt_at = now + masa klaim`.
 *
 * @returns {Promise<{claimed: boolean, reason?: string, delivery?: object,
 *   resend?: boolean}>}
 */
const claimDelivery = async (ticketId, recipient, { allowResend = false } = {}) => {
  const leaseUntil = new Date(Date.now() + SEND_CLAIM_SECONDS * 1000).toISOString();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT pg_catalog.pg_advisory_xact_lock(
         pg_catalog.hashtextextended($1::uuid::text || ':' || $2::varchar(320), 0)
       )`,
      [ticketId, recipient],
    );

    const previous = await client.query(
      `SELECT id, status, next_attempt_at, sent_at, attempt_count
         FROM ticket_email_deliveries
        WHERE ticket_id = $1 AND lower(recipient) = lower($2::varchar(320))
        ORDER BY created_at DESC LIMIT 1
        FOR UPDATE`,
      [ticketId, recipient],
    );
    const row = previous.rows[0];

    if (row?.status === 'SENT') {
      if (!allowResend) {
        await client.query('COMMIT');
        return { claimed: false, reason: 'already_sent', delivery: row };
      }
      // Kirim ulang eksplisit: klaim hanya bila cooldown lewat, dan status
      // tetap SENT supaya catatan pengiriman yang sudah berhasil tidak turun.
      const cooldown = senderConfig().resendCooldownSeconds;
      const claimedResend = await client.query(
        `UPDATE ticket_email_deliveries
            SET attempt_count = attempt_count + 1,
                last_error = 'Pengiriman ulang diminta pengguna; sedang dikirim.',
                next_attempt_at = $2::timestamptz
          WHERE id = $1
            AND status = 'SENT'::"EmailDeliveryStatus"
            AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
            AND (sent_at IS NULL OR sent_at <= NOW() - ($3::int * INTERVAL '1 second'))
          RETURNING *`,
        [row.id, leaseUntil, cooldown],
      );
      await client.query('COMMIT');
      if (!claimedResend.rows[0]) {
        return { claimed: false, reason: 'recently_sent', delivery: row };
      }
      return { claimed: true, resend: true, delivery: claimedResend.rows[0] };
    }
    const claimedNow = row && row.status === 'PENDING'
      && row.next_attempt_at && new Date(row.next_attempt_at).getTime() > Date.now();
    if (claimedNow) {
      await client.query('COMMIT');
      return { claimed: false, reason: 'in_progress', delivery: row };
    }

    // Belum ada catatan: buat klaim pertama (attempt_count=1) sekaligus.
    const claimed = row
      ? await client.query(
        `UPDATE ticket_email_deliveries
            SET status = 'PENDING'::"EmailDeliveryStatus",
                attempt_count = attempt_count + 1,
                last_error = 'Sedang dikirim oleh server.',
                next_attempt_at = $2::timestamptz
          WHERE id = $1
          RETURNING *`,
        [row.id, leaseUntil],
      )
      : await client.query(
        `INSERT INTO ticket_email_deliveries
           (id, ticket_id, recipient, status, attempt_count, last_error,
            sent_at, next_attempt_at, created_at)
         VALUES (gen_random_uuid(), $1::uuid, $2::varchar(320),
                 'PENDING'::"EmailDeliveryStatus", 1,
                 'Sedang dikirim oleh server.', NULL, $3::timestamptz, NOW())
         RETURNING *`,
        [ticketId, recipient, leaseUntil],
      );
    await client.query('COMMIT');
    return { claimed: true, delivery: claimed.rows[0] };
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* already ended */ }
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Lampiran e-ticket PDF (desain Organizer + QR unik).
 *
 * Mengembalikan `{ attachment, error }`. Tiket adalah lampiran WAJIB: bila
 * rendering gagal, email tidak dikirim dan kegagalan dicatat apa adanya
 * (lebih baik gagal jujur daripada mengirim email tanpa tiket).
 *
 * Nama file mengikuti format wajib `E-TIKET Nama Peserta.pdf` dan diambil dari
 * `attendees.name` pada tiket yang sama (bukan kode tiket/UUID).
 */
const buildPdfAttachment = async (ticketId) => {
  try {
    // Tiket lama: rapikan ID publik lebih dulu agar PDF & nama file konsisten
    // dengan format `ETK-XXXXXX` (kegagalan di sini tidak menggagalkan lampiran).
    try {
      await ticketCodeService.ensurePublicTicketCode(ticketId);
    } catch (error) {
      logger.warn('ticket_public_code_failed', { ticketId, error: error.message });
    }
    const ticket = await ticketDesignService.loadTicketForPdf(ticketId);
    if (!ticket) return { attachment: null, error: 'data_tiket_tidak_ditemukan' };
    const buffer = await ticketDesignService.buildTicketPdf(ticket);
    if (!buffer || buffer.length === 0) {
      return { attachment: null, error: 'pdf_tiket_kosong' };
    }
    return {
      attachment: {
        filename: ticketPdfFilename(ticket.attendee_name),
        content: buffer,
        contentType: 'application/pdf',
      },
      error: null,
    };
  } catch (error) {
    logger.error('ticket_pdf_render_failed', { ticketId, error: error.message });
    return { attachment: null, error: `pdf_tiket_gagal: ${error.message}` };
  }
};

/**
 * Kirim e-ticket (PDF lampiran wajib) ke email peserta.
 *
 * Aturan penting:
 *  - Penerima SELALU email pada data peserta tiket (`attendees.email`);
 *    `recipient` hanya boleh menunjuk email yang sama (mis. saat retry).
 *  - Pengiriman otomatis idempoten: satu tiket hanya dikirim sekali per
 *    penerima (`SKIPPED/already_sent`).
 *  - `force` dipakai HANYA oleh tombol "Kirim ulang email": email dikirim lagi
 *    dengan nomor tiket & PDF yang sama (tidak membuat tiket baru), dibatasi
 *    cooldown `EMAIL_RESEND_COOLDOWN_SECONDS` agar klik ganda tidak men-spam.
 *  - Status `SENT` hanya dicatat setelah transport menerima pesan. Transport
 *    uji (json) dicatat `PENDING` karena tidak ada email yang keluar.
 *  - `DELIVERED` tidak pernah dicatat: tidak ada bukti/konfirmasi inbox.
 */
const sendTicketEmail = async (ticketId, { recipient, force = false } = {}) => {
  // Nomor percobaan dipakai untuk backoff; dideklarasikan di luar try agar
  // tetap tersedia pada penanganan kegagalan.
  let attemptCount = 1;
  // True bila ini kirim ulang eksplisit atas catatan yang sudah SENT.
  let resendOfSent = false;
  let ticket = null;
  try {
    // ID publik tiket (`ETK-XXXXXX`) ditetapkan SEBELUM konteks dimuat agar
    // subjek, isi email, PDF, dan nama lampiran memakai kode yang sama.
    // Kegagalan di sini tidak menggagalkan pengiriman (kode lama tetap valid).
    try {
      await ticketCodeService.ensurePublicTicketCode(ticketId);
    } catch (error) {
      logger.warn('ticket_public_code_failed', { ticketId, error: error.message });
    }
    ticket = await loadTicketContext(ticketId);
    if (!ticket) return { status: 'SKIPPED', reason: 'ticket_not_found' };
    const sender = resolveSender(ticket);

    const attendeeEmail = String(ticket.attendee_email || '').trim();
    const requested = String(recipient || '').trim();
    // Email peserta adalah sumber kebenaran; alamat lain tidak pernah dipakai.
    const to = attendeeEmail || requested;
    if (!to) {
      const delivery = await upsertDelivery({
        ticketId, recipient: 'unknown', status: 'FAILED',
        error: 'Email peserta kosong pada data pendaftaran.',
      });
      return { status: 'FAILED', reason: 'no_recipient', delivery };
    }
    if (attendeeEmail && requested && requested.toLowerCase() !== attendeeEmail.toLowerCase()) {
      return { status: 'SKIPPED', reason: 'recipient_mismatch' };
    }
    // Alamat penerima wajib valid; tanpa ini kegagalan hanya muncul sebagai
    // error SMTP yang sulit dipahami peserta.
    if (!isValidEmail(to)) {
      const delivery = await upsertDelivery({
        ticketId, recipient: to.slice(0, 320), status: 'FAILED',
        error: 'Alamat email peserta tidak valid pada data pendaftaran.',
        incrementAttempt: false,
      });
      logger.error('ticket_email_invalid_recipient', {
        eventId: ticket.event_id,
        ticketId,
        recipient: to,
        status: 'FAILED',
      });
      return { status: 'FAILED', reason: 'invalid_recipient', delivery };
    }

    // Tiket yang dibatalkan/dicabut tidak boleh dikirim ulang.
    const ticketStatus = String(ticket.status || '').toLowerCase();
    if (ticketStatus === 'cancelled' || ticketStatus === 'revoked') {
      logger.warn('ticket_email_skipped_inactive_ticket', {
        eventId: ticket.event_id,
        ticketId,
        recipient: to,
        ticketStatus,
      });
      return { status: 'SKIPPED', reason: `ticket_${ticketStatus}` };
    }

    // Transport belum siap: catat status belum terkirim TANPA mengambil klaim
    // pengiriman, sehingga tidak ada percobaan yang terpakai sia-sia.
    const mode = transportMode();
    if (!smtpStatus().configured) {
      const status = smtpStatus();
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'PENDING', error: unavailableReason(),
        incrementAttempt: false,
      });
      logger.warn('ticket_email_not_configured', {
        eventId: ticket.event_id,
        ticketId,
        recipient: to,
        mode,
        missing: status.missing,
        reason: status.reason,
        status: 'NOT_CONFIGURED',
      });
      return { status: 'NOT_CONFIGURED', reason: unavailableReason(), delivery, sender: senderInfo(sender) };
    }

    // Penjaga anti email ganda: klaim atomik per (tiket, penerima).
    const claim = await claimDelivery(ticketId, to, { allowResend: force });
    if (!claim.claimed) {
      logger.info('ticket_email_skipped', {
        eventId: ticket.event_id,
        ticketId,
        recipient: to,
        reason: claim.reason,
      });
      return {
        status: 'SKIPPED',
        reason: claim.reason,
        delivery: claim.delivery,
        sender: senderInfo(sender),
      };
    }
    resendOfSent = Boolean(claim.resend);
    attemptCount = Number(claim.delivery?.attempt_count) || 1;

    const { attachment, error: pdfError } = await buildPdfAttachment(ticketId);
    if (!attachment) {
      const errorMessage = `Lampiran tiket gagal dibuat (${pdfError || 'unknown'}).`;
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: resendOfSent ? 'SENT' : 'FAILED',
        error: errorMessage,
        incrementAttempt: false,
        retryDelayMs: retryDelayFor(attemptCount),
        preserveSent: resendOfSent,
      });
      logger.error('ticket_email_attachment_failed', {
        eventId: ticket.event_id,
        ticketId,
        recipient: to,
        pdfError,
        attemptCount,
      });
      return {
        status: 'FAILED',
        reason: 'attachment_failed',
        error: pdfError,
        delivery,
        previously_sent: resendOfSent,
      };
    }

    const info = await deliver(buildMessage(ticket, to, { attachment }));
    if (mode === 'json') {
      // Tidak ada email yang keluar dari server pada transport uji.
      const delivery = await upsertDelivery({
        ticketId, recipient: to, status: 'PENDING',
        error: 'Transport uji (SMTP_HOST=json): email TIDAK dikirim.',
        incrementAttempt: false,
      });
      logger.warn('ticket_email_test_transport', { ticketId, messageId: info.messageId });
      return { status: 'NOT_SENT_TEST_TRANSPORT', mode, delivery };
    }

    const knownRecipient = Array.isArray(info.rejected) && info.rejected.length > 0;
    const delivery = await upsertDelivery({
      ticketId,
      recipient: to,
      status: 'SENT',
      error: null,
      incrementAttempt: false,
      allowSentUpdate: resendOfSent,
    });
    logger.info('ticket_email_accepted', {
      eventId: ticket.event_id,
      ticketId,
      ticketCode: ticket.ticket_code,
      recipient: to,
      from: sender.fromAddress,
      fromOrganizer: sender.fromOrganizer,
      replyTo: sender.replyTo,
      mode,
      status: 'SENT',
      attemptCount,
      resend: resendOfSent,
      messageId: info.messageId,
      response: info.response,
      envelopeTo: info.envelope?.to || null,
      accepted: info.accepted,
      rejected: info.rejected,
      pending: info.pending,
      recipientRejected: knownRecipient,
      sentAt: delivery?.sent_at || null,
    });
    return {
      status: 'SENT',
      mode,
      messageId: info.messageId,
      response: info.response || null,
      accepted: info.accepted || [],
      rejected: info.rejected || [],
      sender: senderInfo(sender),
      delivery,
    };
  } catch (error) {
    // Transport yang gagal (mis. kredensial/timeout) di-cache jangan dipakai lagi.
    resetTransport();
    try {
      const context = ticket || await loadTicketContext(ticketId);
      const sender = resolveSender(context);
      const to = String(recipient || context?.attendee_email || '').trim() || 'unknown';
      // Tahap kegagalan + saran tindakan disimpan pada last_error agar penyebab
      // (kredensial Brevo, sender belum terverifikasi, port diblokir) terlihat
      // langsung di aplikasi/log — tanpa pernah memuat password.
      const failure = transportMode() === 'resend'
        ? { stage: 'api', hint: '' }
        : classifySmtpError(error);
      const errorMessage = `${String(error.message)}${failure.hint ? ` | ${failure.hint}` : ''}`
        .slice(0, 500);
      logger.error('ticket_email_failed', {
        eventId: context?.event_id || null,
        ticketId,
        ticketCode: context?.ticket_code || null,
        recipient: to,
        from: sender.fromAddress || null,
        replyTo: sender.replyTo || null,
        mode: transportMode(),
        stage: failure.stage,
        status: 'FAILED',
        attemptCount,
        resend: resendOfSent,
        error: errorMessage,
      });
      // Catat FAILED apa adanya + jadwalkan percobaan berikutnya (bukan
      // langsung, supaya relay yang sedang bermasalah tidak dibanjiri).
      // Bila ini kirim ulang atas catatan SENT, status SENT dipertahankan.
      const delivery = await upsertDelivery({
        ticketId,
        recipient: to,
        status: resendOfSent ? 'SENT' : 'FAILED',
        error: resendOfSent ? `Pengiriman ulang gagal: ${errorMessage}` : errorMessage,
        incrementAttempt: false,
        retryDelayMs: retryDelayFor(attemptCount),
        preserveSent: resendOfSent,
      });
      return {
        status: 'FAILED',
        reason: errorMessage,
        delivery,
        previously_sent: resendOfSent,
      };
    } catch (recordError) {
      // Pencatatan gagal juga tidak boleh disembunyikan.
      logger.error('ticket_email_failure_record_failed', {
        ticketId, error: recordError.message,
      });
      return { status: 'FAILED', reason: error.message, recordError: recordError.message };
    }
  }
};

/**
 * Kirim tiket untuk satu order (setelah pembayaran lunas / event gratis).
 *
 * Mengembalikan array hasil per tiket. Kegagalan email TIDAK membatalkan
 * penerbitan tiket: tiket tetap ada di database dan dapat dikirim ulang.
 * Idempoten: pemanggilan berulang tidak membuat email ganda.
 */
const sendOrderTicketEmails = async (orderId) => {
  const rows = await query(
    `SELECT t.id, a.email AS attendee_email
       FROM tickets t
       JOIN attendees a ON a.id = t.attendee_id
       JOIN order_items oi ON oi.id = a.order_item_id
      WHERE oi.order_id = $1
      ORDER BY a.name ASC`,
    [orderId]
  );
  const results = [];
  for (const row of rows) {
    const outcome = await sendTicketEmail(row.id);
    results.push({ ticketId: row.id, recipient: row.attendee_email || null, ...outcome });
  }
  return results;
};

/**
 * Kirim ulang tiket yang belum terkirim (PENDING/FAILED).
 *
 * Retry tidak pernah membuat tiket baru dan tidak pernah mengirim ganda:
 * pengiriman yang sudah `SENT` tidak ikut terpilih.
 */
const retryPendingDeliveries = async (limit = 20) => {
  const rows = await query(
    `SELECT ticket_id, recipient FROM ticket_email_deliveries
     WHERE status IN ('PENDING','FAILED')
       AND attempt_count < 5
       AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
     ORDER BY created_at ASC LIMIT $1`,
    [limit]
  );
  const results = [];
  for (const row of rows) {
    const outcome = await sendTicketEmail(row.ticket_id, { recipient: row.recipient });
    results.push({ ticketId: row.ticket_id, recipient: row.recipient, ...outcome });
  }
  return results;
};

/** Status email tiket untuk ditampilkan (tanpa kredensial). */
const emailDeliveryStatusForTicket = (ticketId) => getOne(
  `SELECT id, recipient, status, attempt_count, last_error, sent_at, next_attempt_at
     FROM ticket_email_deliveries WHERE ticket_id = $1
     ORDER BY created_at DESC LIMIT 1`,
  [ticketId]
);

module.exports = {
  BREVO_SMTP,
  smtpStatus,
  smtpConfig,
  smtpTransportOptions,
  emailProvider,
  isBrevoHost,
  classifySmtpError,
  validateEmailConfig,
  transportMode,
  verifyTransport,
  deliver,
  resetTransport,
  buildMessage,
  resolveSender,
  parseEmailAddress,
  isValidEmail,
  loadTicketContext,
  markQueued,
  claimDelivery,
  // Diekspor agar dapat diuji tanpa SMTP: membuktikan lampiran email memakai
  // renderer & tata letak yang sama dengan PDF unduhan peserta.
  buildPdfAttachment,
  sendTicketEmail,
  sendOrderTicketEmails,
  retryPendingDeliveries,
  emailDeliveryStatusForTicket,
};

