# Laporan Migrasi Email E-Ticket ke Brevo SMTP

Tanggal: 27 November 2026
Lingkup: backend `e_ticket_event_qr_scane` (Nodemailer + Brevo SMTP)
Status: **implementasi selesai & teruji lokal; pengiriman ke inbox nyata BELUM terverifikasi**

---

## 1. Ringkasan

Penyedia email aplikasi dipindahkan ke **Brevo SMTP** (`smtp-relay.brevo.com`,
port `587` + STARTTLS) memakai **Nodemailer**. Seluruh kredensial dibaca dari
environment (`SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM`), tidak ada yang di-hardcode.
Mekanisme tiket (PDF, QR, desain tiket, lampiran), alur event gratis/berbayar,
pencatatan status, retry, dan penjagaan anti email ganda **tidak diubah**.

Kesimpulan bukti yang jujur:

| Tingkat bukti | Status |
|---|---|
| Konfigurasi transport Brevo (host/port/STARTTLS/auth dari env) | **PASS** |
| DNS + TCP `smtp-relay.brevo.com:587` dari mesin ini | **PASS** (101 ms) |
| STARTTLS + autentikasi diterima Brevo (`transporter.verify()`) | **PASS** |
| Rantai aplikasi: daftar → tiket → PDF+QR → email (gratis & berbayar) | **PASS** (SMTP sink lokal) |
| Anti email ganda, status `FAILED`+`last_error`, retry/backoff | **PASS** |
| Brevo **menerima** pesan untuk penerima eksternal (250 queued) | **BLOCKED** — belum ada penerima eksternal & `EMAIL_FROM` belum terverifikasi |
| Email **benar-benar masuk inbox** penerima | **BELUM DIVERIFIKASI** (tidak diklaim) |

`SENT` pada aplikasi berarti **penyedia menerima pesan**, bukan jaminan masuk inbox.

---

## 2. Analisis kondisi awal

Temuan pada implementasi sebelum perubahan:

1. `backend/src/services/emailService.js` sudah memakai Nodemailer, tetapi
   transport dipilih otomatis dengan **Resend (HTTPS API) sebagai prioritas
   pertama**. Jika `RESEND_API_KEY` masih terisi, konfigurasi SMTP Brevo tidak
   akan pernah dipakai.
2. `.env.example` hanya memberi contoh **Gmail/Workspace**
   (`smtp.gmail.com` + App Password); tidak ada profil Brevo, tidak ada
   `EMAIL_PROVIDER`, dan tidak ada kewajiban STARTTLS.
3. Belum ada cara memverifikasi secara bertahap: pengguna tidak bisa membedakan
   "host tidak resolve", "port diblokir", "kredensial ditolak", "sender belum
   terverifikasi", dan "pesan diterima penyedia".
4. Temuan pada `backend/.env` (hanya dibaca sebagai status, nilainya tidak
   dicetak/diubah): `SMTP_HOST=127.0.0.1` (sisa relay uji lokal), port `2529`,
   `SMTP_USER` berformat login Brevo, dan `EMAIL_FROM=no-reply@eticket.test`.
   Artinya runtime saat ini **tidak akan mengirim ke inbox nyata** walau
   kredensial Brevo valid, dan `EMAIL_FROM` berdomain `.test` tidak mungkin
   diverifikasi sebagai sender Brevo.

---

## 3. Perubahan yang dilakukan

### 3.1 `backend/src/services/emailService.js`

- Menambah profil publik Brevo: `BREVO_SMTP = { host: 'smtp-relay.brevo.com',
  port: 587, secure: false, requireTls: true }` (host/port bukan rahasia).
- `EMAIL_PROVIDER` (`brevo` | `smtp` | `resend` | `none`; kosong = otomatis).
  `EMAIL_PROVIDER=brevo` memakai host/port/TLS Brevo secara default sehingga
  cukup mengisi kredensial.
- Urutan prioritas baru: **SMTP/Brevo → Resend (fallback lama) → nonaktif**.
  Brevo didahulukan agar sisa `RESEND_API_KEY` tidak lagi menimpa konfigurasi
  Brevo, tanpa menghapus jalur lama.
- `SMTP_REQUIRE_TLS` + `requireTLS` Nodemailer: port 587 Brevo **wajib**
  STARTTLS sehingga kredensial tidak pernah terkirim pada koneksi polos.
  Port 465 (`SMTP_SECURE=true`) tetap memakai TLS implisit.
- `smtpTransportOptions()` dipisah agar dapat diuji tanpa jaringan dan dipakai
  konsisten oleh `getTransport()`.
- `validateEmailConfig()`/`smtpStatus()` kini melaporkan `provider`, `host`,
  `port`, `secure`, `requireTls`, `loopback`, dan `brevo` — **tanpa**
  `SMTP_USER`/`SMTP_PASS`.
- `classifySmtpError()`: kegagalan diklasifikasikan per tahap (`dns`, `connect`,
  `tls`, `auth`, `sender`, `send`) beserta saran tindakan; dipakai pada
  preflight dan disimpan pada `last_error` (mis. "SMTP key salah" atau
  "EMAIL_FROM belum diverifikasi di Brevo"). `ESOCKET` + `ECONNREFUSED`
  dikenali sebagai masalah koneksi, bukan TLS.
- Tidak ada perubahan pada: pembuatan PDF/QR, `buildMessage`, `claimDelivery`,
  `upsertDelivery`, `retryDelayFor`, `sendOrderTicketEmails`, skema database.

### 3.2 `backend/server.js`

- Log startup menampilkan mode/penyedia/host:port/TLS dan peringatan eksplisit
  bila `SMTP_HOST` menunjuk loopback (relay uji tidak mengirim ke inbox nyata).
- Preflight menampilkan tahap kegagalan (DNS/koneksi/TLS/auth).

### 3.3 `backend/scripts/verify-brevo-smtp.js` (baru, `npm run verify:brevo`)

Verifikasi bertahap dengan pemisahan bukti yang tegas:

1. konfigurasi (login di-mask, password hanya "tersedia/tidak"),
2. DNS resolve,
3. TCP ke `smtp-relay.brevo.com:587`,
4. STARTTLS + autentikasi (`transporter.verify()`),
5. kirim nyata: `--to=<inbox>` (email uji) atau `--ticket=<uuid>` (e-ticket asli
   dengan PDF+QR ke email peserta pada database),
6. bukti inbox: **selalu** dilaporkan `BELUM TERVERIFIKASI`; bila
   `BREVO_API_KEY` diisi, event `delivered`/bounce Brevo ditampilkan sebagai
   bukti tambahan (bukan jaminan inbox).

Skrip tidak pernah mencetak kredensial dan tidak mengubah `.env`; opsi
`--as-configured` memakai `.env` apa adanya, sedangkan default memakai profil
Brevo agar pengujian tidak diam-diam memakai sisa relay loopback.

### 3.4 `.env.example`

- Contoh Gmail diganti placeholder Brevo: `EMAIL_PROVIDER=brevo`,
  `SMTP_HOST=smtp-relay.brevo.com`, `SMTP_PORT=587`, `SMTP_SECURE=false`,
  `SMTP_REQUIRE_TLS=true`, `SMTP_USER=your-brevo-smtp-login@smtp-brevo.com`,
  `SMTP_PASS=your-brevo-smtp-key`, `EMAIL_FROM=no-reply@your-verified-domain.com`.
- Ditambah penjelasan verifikasi sender Brevo, `BREVO_API_KEY` opsional, dan
  catatan bahwa jalur Resend hanya fallback. Semua nilai placeholder.

### 3.5 Dokumentasi & skrip lain

- `backend/README.md`: penyedia aktif Brevo, langkah setup, urutan prioritas,
  klasifikasi kegagalan, tabel env, dan deskripsi `npm run verify:brevo`.
- `docs/ARCHITECTURE.md`: mode `brevo` + STARTTLS + klasifikasi kegagalan.
- Skrip verifikasi lama diselaraskan agar deterministik: `EMAIL_PROVIDER`
  eksplisit (`smtp` untuk sink lokal, `resend` untuk stub API) dan
  `SMTP_REQUIRE_TLS=false` untuk sink lokal; `retry-ticket-emails.js`,
  `send-test-email.js`, dan `verify-email-delivery.js` mengenali mode `brevo`.
- Unit test baru `backend/test/brevo_smtp_config.test.js` (13 test).

### 3.6 Yang TIDAK diubah

- Skema/migration/seed database: tidak ada perubahan (`backend/prisma` bersih).
- Tidak ada penghapusan data.
- `backend/.env` tidak dibaca nilainya, tidak dicetak, dan tidak diubah.
- Alur event gratis/berbayar, penerbitan tiket, PDF, QR, dan desain tiket.


Yang sudah benar dan dipertahankan: klaim atomik anti email ganda
(`claimDelivery`), status `PENDING/SENT/FAILED`, `last_error`, backoff retry,
worker periodik, endpoint kirim ulang, lampiran PDF wajib, serta pemilihan
`From`/`Reply-To` tanpa spoofing.

---

## 4. Bukti pengujian

Dijalankan dari `backend/` pada 27 November 2026.

| Perintah | Hasil | Cakupan |
|---|---|---|
| `npm test` (`node --test`) | **PASS** — 258 test, 0 gagal (13 test baru Brevo) | Konfigurasi, aturan tiket, kontrak API |
| `npm run check` | **PASS** — 59 file JS | Sintaks |
| `npm run format:check` | **PASS** | Whitespace/JSON |
| `npm run validate:skills` | **PASS** — 7 skill | Dokumentasi skill |
| `npm run verify:brevo` | **PASS** preflight, kirim **BLOCKED** | DNS, TCP 587, STARTTLS, AUTH Brevo |
| `npm run verify:email` | **PASS** lokal; 1 eksternal **BLOCKED** | Transmisi SMTP nyata ke sink, PDF, anti ganda, kegagalan |
| `npm run verify:email-queue` | **PASS** | Respons tidak menunggu SMTP, kirim tepat sekali |
| `npm run verify:ticket-email-e2e` | **PASS** | Event gratis & berbayar, PDF+QR, penerima dari DB, kirim ulang |
| `npm run verify:email-api` | **PASS** | Regresi jalur HTTPS API lama (fallback) |

Kutipan hasil preflight Brevo nyata (kredensial dari `backend/.env`, tidak dicetak):

```
INFO    mode transport :: brevo
INFO    host:port :: smtp-relay.brevo.com:587 (STARTTLS wajib)
INFO    SMTP_USER :: c57***@smtp-brevo.com
INFO    SMTP_PASS :: tersedia (tidak dicetak)
PASS    konfigurasi transport lengkap
PASS    DNS resolve :: 1.179.116.1
PASS    TCP smtp-relay.brevo.com:587 terbuka :: 101 ms
PASS    STARTTLS + autentikasi diterima Brevo :: brevo | smtp-relay.brevo.com:587
BLOCKED kirim email nyata :: tidak ada --to / --ticket / VERIFY_EMAIL_TO
```

Hasil E2E (ringkas): event gratis → `PAID` → tiket terbit → email `SENT` ke
email peserta; event berbayar → `pending_payment` → tiket/email **belum** ada →
pembayaran simulasi → tiket terbit → email `SENT`; PDF berisi nama peserta,
nama event, kategori, dan kode tiket; QR memverifikasi tiket yang benar; kirim
ulang tidak membuat tiket/catatan ganda.

---

## 5. Pemisahan bukti: SMTP menerima vs masuk inbox

- **Terbukti**: kredensial Brevo diterima (AUTH sukses) dan pesan yang dikirim
  aplikasi diterima transport SMTP (`250 OK queued`, `messageId` tercatat).
- **Tidak terbukti**: email masuk ke inbox penerima. Aplikasi tidak mencatat
  `DELIVERED`; status maksimum adalah `SENT`.
- Untuk membuktikan inbox, diperlukan **akun penerima eksternal** dan
  `EMAIL_FROM` yang sudah diverifikasi Brevo. Perintahnya:
  `npm run verify:brevo -- --to=<inbox-anda> --wait=60`
  (opsional isi `BREVO_API_KEY` agar event `delivered`/bounce Brevo ikut dibaca).
- Bahkan event `delivered` dari Brevo berarti **server penerima menerima** pesan,
  bukan jaminan tampil di folder Inbox (bisa Spam/Promotions).

---

## 6. Tindakan yang masih diperlukan pemilik proyek

1. Pada `backend/.env` (tidak diubah oleh pekerjaan ini):
   - set `EMAIL_PROVIDER=brevo`,
   - set `SMTP_HOST=smtp-relay.brevo.com` (saat ini `127.0.0.1` — relay uji
     lokal, sehingga email tidak akan pernah sampai ke peserta),
   - set `SMTP_PORT=587`, `SMTP_SECURE=false`, `SMTP_REQUIRE_TLS=true`,
   - pastikan `SMTP_USER`/`SMTP_PASS` adalah login & **SMTP key** Brevo,
   - ganti `EMAIL_FROM` dari `no-reply@eticket.test` ke alamat pada domain yang
     **sudah diverifikasi** di Brevo (menu Senders & IP).
2. Verifikasi: `npm run verify:brevo` → harus PASS sampai tahap AUTH.
3. Uji kirim nyata: `npm run verify:brevo -- --to=<inbox-eksternal>` atau
   `npm run verify:brevo -- --ticket=<uuid-tiket>`.
4. Baru setelah email terlihat di inbox penerima, status "pengiriman email
   berhasil" boleh diklaim.

---

## 7. Catatan & limitasi

- Tidak ada perubahan skema/migration database, tidak ada data dihapus, dan
  tidak ada dependency runtime baru (Nodemailer sudah dipakai).
- Tidak ada nilai rahasia yang ditulis ke kode, log, dokumentasi, atau laporan;
  `.env` tidak dibaca isinya, tidak dicetak, dan tidak diubah.
- Jalur HTTPS API lama (Resend) dipertahankan hanya sebagai fallback agar
  deployment lain tidak rusak; bukan penyedia aktif.
- Retry otomatis tetap dibatasi 5 percobaan dengan backoff; kirim ulang eksplisit
  tetap dibatasi `EMAIL_RESEND_COOLDOWN_SECONDS`.
- Preflight/verifikasi bergantung pada jaringan mesin ini. Port 587/465 Brevo
  terbuka pada pengujian ini, tetapi jaringan/hosting lain dapat memblokirnya.

