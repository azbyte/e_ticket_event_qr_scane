# LAPORAN PERBAIKAN — PENGIRIMAN EMAIL TIKET (FINAL)

- **Tanggal:** 2026-11-27
- **Lingkup:** konfigurasi SMTP/penyedia email, identitas pengirim (penyelenggara),
  penerima (peserta), pengiriman PDF tiket, tombol kirim ulang, logging, dan
  status pengiriman.
- **Status:** seluruh kode dan pengujian lokal/protokol **PASS**. Pengiriman ke
  **inbox email asli masih BLOCKED** karena tidak ada kredensial email pada
  environment ini. Tidak ada keberhasilan yang dikarang (lihat §7).

---

## 1. Akar penyebab `SMTP_HOST` belum dikonfigurasi

`backend/.env` hanya memuat `PORT`, `DATABASE_URL`, `DIRECT_URL`, `JWT_SECRET`,
`JWT_EXPIRES_IN`, `ALLOWED_ORIGINS`, dan `NODE_ENV`. **Tidak ada satu pun**
variabel email: `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`,
`SMTP_PASS`, `EMAIL_FROM`, maupun `RESEND_API_KEY`.

Akibatnya `smtpStatus()` selalu `mode = disabled`, dan setiap pendaftaran hanya
menulis `ticket_email_deliveries` berstatus `PENDING` dengan alasan
*“SMTP_HOST belum dikonfigurasi; email BELUM dikirim.”* Tidak ada email yang
pernah keluar dari server.

Masalah lama juga menyembunyikan variabel lain yang belum ada: pesan hanya
menyebut `SMTP_HOST`, padahal `EMAIL_FROM` (dan kredensial) juga kosong. Sekarang
`validateEmailConfig()` melaporkan **semua** variabel yang belum tersedia.

Penyebab tambahan yang ikut diperbaiki:

| # | Masalah | Dampak |
|---|---|---|
| 1 | Transport HTTPS API mengabaikan `message.from` (selalu memakai `EMAIL_FROM`) | identitas penyelenggara tidak pernah muncul sebagai pengirim |
| 2 | Tombol “Kirim ulang email” tidak mengirim ulang bila status sudah `SENT` | peserta yang kehilangan email tidak bisa meminta kirim ulang |
| 3 | Tidak ada validasi format email penerima sebelum kirim | kegagalan hanya muncul sebagai error SMTP yang sulit dipahami |
| 4 | Tiket `cancelled`/`revoked` masih dapat dikirim ulang | email tiket tidak valid bisa terkirim |
| 5 | Log tidak memuat `eventId`, pengirim, `Reply-To`, dan jumlah percobaan | diagnosis kegagalan lambat |
| 6 | `NOT_CONFIGURED` tidak terlihat pada detail tiket (hanya `PENDING`) | UI tidak menjelaskan penyebabnya |

---

## 2. Komponen dan file yang diperbaiki

| File | Perubahan |
|---|---|
| `backend/src/services/emailService.js` | `resolveSender()` (From penyelenggara vs `EMAIL_FROM` + `Reply-To`), validasi penerima, validasi status tiket, `force` untuk kirim ulang eksplisit + cooldown, `preserveSent`/`allowSentUpdate` pada `upsertDelivery`, log lengkap, `validateEmailConfig()`, perbaikan `sendViaResend` agar memakai `message.from`, query `loadTicketContext` mengambil `profiles.email` penyelenggara |
| `backend/src/controllers/ticketController.js` | tombol kirim ulang memakai `force`; respons menyertakan `sender`, `recipient`, `attempt_count`, `sent_at`, `previously_sent`; detail tiket menampilkan `NOT_CONFIGURED` secara jujur |
| `backend/server.js` | validasi konfigurasi email saat startup (semua variabel yang belum ada + panduan), tanpa mencetak kredensial |
| `backend/src/services/emailQueue.js`, `backend/src/config/env.js` | penyesuaian dari perbaikan sebelumnya (gate transport, penghapusan fallback pengirim palsu) |
| `backend/.env.example` | dokumentasi dua jalur transport, `EMAIL_ORGANIZER_FROM_DOMAINS`, `EMAIL_REPLY_TO_ORGANIZER`, `EMAIL_RESEND_COOLDOWN_SECONDS` |
| `backend/README.md`, `docs/ARCHITECTURE.md` | aturan From/Reply-To, status, kirim ulang, variabel environment |
| `backend/scripts/send-test-email.js` **(baru)** + `npm run email:test` | kirim satu email uji nyata untuk membuktikan kredensial/identitas pengirim |
| `backend/scripts/verify-email-api-transport.js` | pengujian From penyelenggara, kirim ulang eksplisit, alamat tidak valid |
| `backend/scripts/verify-email-delivery.js` | pengujian From/Reply-To lewat SMTP nyata, kirim ulang eksplisit, jumlah percobaan |
| `backend/scripts/verify-ticket-email-e2e.js` | E2E: From penyelenggara, penerima peserta, kirim ulang benar-benar mengirim, nomor tiket tetap |
| `backend/test/email_ticket_delivery_rules.test.js` | 5 test baru: identitas pengirim, email penyelenggara tidak valid, validasi penerima, daftar variabel yang belum ada |
| `apps/lib/features/tickets/screens/ticket_detail_screen.dart` | tombol kirim ulang tersedia juga setelah `SENT`; pesan `recently_sent`/`previously_sent` jujur; tanpa perubahan desain/warna |
| `apps/lib/services/ticket/ticket_service.dart` | dokumentasi perilaku kirim ulang |

**Tidak ada perubahan schema/migration.** `npm run verify:db-schema` → **PASS**
(32 tabel, 19 enum, index/constraint/FK sama). Tidak ada data nyata yang dihapus
atau diubah; data uji dibuat dan dibersihkan oleh skripnya sendiri.

---

## 3. Layanan email yang digunakan

Urutan pemilihan transport (otomatis, hanya dari environment):

1. **`RESEND_API_KEY`** → HTTPS API `POST https://api.resend.com/emails`
   (port 443). PDF dilampirkan base64. Dipakai lebih dulu karena tetap bekerja
   saat port SMTP diblokir jaringan/hosting.
2. **`SMTP_HOST`** → SMTP via Nodemailer (`SMTP_PORT`, `SMTP_SECURE`,
   `SMTP_USER`, `SMTP_PASS`, timeout eksplisit).
3. Keduanya kosong → `disabled`: delivery dicatat `PENDING` + alasan, API
   mengembalikan `NOT_CONFIGURED`, dan **tidak pernah** diklaim terkirim.

Tidak ada SMTP palsu/dummy untuk menyatakan berhasil. `SMTP_HOST=json` hanya
aktif di `NODE_ENV=test` dan statusnya tidak pernah `SENT`.

---

## 4. Konfigurasi environment yang perlu disediakan

Isi pada `backend/.env` (lokal) dan pada environment deployment backend.
**Jangan commit nilainya.** Repository ini tidak memiliki manifest deployment
(Dockerfile/Render/Railway/Procfile); backend dijalankan dari `backend/` dengan
`.env`. Bila nanti di-hosting, variabel yang sama wajib diisi pada dashboard
environment hosting — `.env` lokal tidak ikut ter-deploy.

### Opsi A — HTTPS API (disarankan bila port SMTP diblokir)

```env
RESEND_API_KEY=<api key dari dashboard Resend>
EMAIL_FROM=no-reply@domain-yang-terverifikasi
EMAIL_FROM_NAME=E-Ticket Event
# Hanya bila domain penyelenggara sudah diverifikasi di Resend:
# EMAIL_ORGANIZER_FROM_DOMAINS=domain-penyelenggara.com
VERIFY_EMAIL_TO=inbox-anda@domain-anda
```

### Opsi B — SMTP

```env
SMTP_HOST=smtp.gmail.com          # atau relay penyedia Anda
SMTP_PORT=587
SMTP_SECURE=false                 # true untuk port 465
SMTP_USER=akun-pengirim@domain    # akun yang benar-benar memiliki kredensial
SMTP_PASS=<app password, bukan password akun>
EMAIL_FROM=akun-pengirim@domain   # harus boleh dikirim oleh akun SMTP tersebut
EMAIL_FROM_NAME=E-Ticket Event
VERIFY_EMAIL_TO=inbox-anda@domain-anda
```

Contoh Gmail: `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_SECURE=false`,
`SMTP_USER=alamat@gmail.com`, `SMTP_PASS=` **App Password** (bukan password
akun; aktifkan 2FA lalu buat App Password).

Validasi saat startup mencetak variabel yang belum ada, misalnya:

```
Email e-ticket: mode=disabled | belum diisi: RESEND_API_KEY|SMTP_HOST, EMAIL_FROM | ...
Email e-ticket: BELUM SIAP. Tiket tetap terbit, tetapi email tidak akan dikirim ...
```

---

## 5. Mekanisme email penyelenggara sebagai pengirim

- Alamat penyelenggara diambil dari database: `events.created_by` →
  `profiles.email`, ditambah `events.organizer_name`. Tidak memakai input klien
  dan tidak memakai email peserta.
- `resolveSender()` menentukan `From`:
  1. **Penyelenggara menjadi `From`** bila penyedia mengizinkannya: alamat sama
     dengan `SMTP_USER` terautentikasi, sama dengan `EMAIL_FROM` terverifikasi,
     atau domainnya terdaftar pada `EMAIL_ORGANIZER_FROM_DOMAINS` (domain yang
     sudah diverifikasi di penyedia).
  2. Selain itu `From` = `EMAIL_FROM` terverifikasi dan alamat penyelenggara
     dipasang sebagai **`Reply-To`** (dapat dimatikan dengan
     `EMAIL_REPLY_TO_ORGANIZER=false`).
- Tidak ada spoofing: alamat penyelenggara tidak pernah dipakai untuk
  autentikasi SMTP. Aplikasi **tidak** meminta/menyimpan password email pribadi
  penyelenggara; kredensial tetap `SMTP_USER`/`SMTP_PASS` atau `RESEND_API_KEY`.
- Nama tampilan memakai `organizer_name` (fallback `EMAIL_FROM_NAME`), dan baris
  “Penyelenggara: …” ditambahkan pada isi email.

Contoh hasil nyata pada pengujian SMTP lokal:

```
From: Organizer Verifikasi <org.verify...@example.test>
Reply-To: org.verify...@example.test
To: uji-tiket@example.test
```

---

## 6. Mekanisme email peserta sebagai penerima

- Penerima **selalu** `attendees.email` pada tiket yang bersangkutan
  (`loadTicketContext` JOIN `attendees`). Nilai dari payload/klien tidak dipakai;
  bila berbeda, pengiriman ditolak (`recipient_mismatch`).
- Alamat divalidasi sebelum klaim. Format tidak valid → `FAILED` +
  `last_error` “Alamat email peserta tidak valid…”, tanpa memanggil penyedia.
- Lampiran PDF wajib: nama event, nama peserta, kategori, kode tiket, dan QR
  diambil dari database; desain & orientasi (portrait/landscape) penyelenggara
  dipertahankan. Bila PDF gagal dibuat, email tidak dikirim dan kegagalan
  dicatat.
- Setelah tiket terbit (gratis langsung `PAID`; berbayar setelah pembayaran
  simulasi `paid`), `emailQueue.enqueueOrder()` mencatat `PENDING` lalu
  mengirim pada tick berikutnya tanpa menahan respons pendaftaran.

---

## 7. Hasil pengujian

Dijalankan dari `backend/` (Windows, Node 22, PostgreSQL/Supabase aktif) dan
`apps/`.

| # | Pengujian | Perintah | Hasil |
|---|---|---|---|
| T1 | Unit/integration backend | `npm test` | **245 pass, 0 fail** |
| T2 | Sintaks | `npm run check` | PASS |
| T3 | Format | `npm run format:check` | PASS |
| T4 | E2E tiket + email (HTTP nyata) | `npm run verify:ticket-email-e2e` | **45 PASS, 0 FAIL** |
| T5 | Transport HTTPS API | `npm run verify:email-api` | **37 PASS, 0 FAIL** |
| T6 | SMTP nyata → sink lokal | `npm run verify:email` | **26 PASS, 0 FAIL, 1 BLOCKED** |
| T7 | Antrean asinkron | `npm run verify:email-queue` | PASS |
| T8 | Alur tiket HTTP + DB | `npm run verify:ticket-flow` | SEMUA LULUS |
| T9 | Rendering PDF 2 orientasi | `npm run verify:ticket-pdf` | 13 OK |
| T10 | E2E registrasi | `npm run test:registration-flow` | **32/32 lulus** |
| T11 | Sinkronisasi schema | `npm run verify:db-schema` | PASS (tanpa perubahan) |
| T12 | Analisis Flutter | `flutter analyze` | No issues found |
| T13 | Seluruh test Flutter | `flutter test` | **797 test lulus** |

### 7.1 Skenario wajib

| No. | Skenario | Bukti | Hasil |
|---|---|---|---|
| 1 | Event gratis: tiket terbit setelah data tersimpan | E2E: order `PAID`, tiket `count=1` | PASS |
| 2 | Event berbayar: tiket setelah pembayaran simulasi | `count=0` sebelum bayar, `count=1` setelah `paid` | PASS |
| 3 | Email dikirim ke alamat pendaftaran | `recipient` = `attendees.email` di DB dan di pesan | PASS |
| 4 | Lampiran PDF + QR | PDF `application/pdf`, diawali `%PDF-`, QR dapat diverifikasi ke tiket benar | PASS |
| 5 | Isi PDF benar | nama peserta, nama event, kategori, kode tiket ditemukan di PDF | PASS |
| 6 | Email penyelenggara sebagai pengirim | `From`/`Reply-To` = `profiles.email` penyelenggara pada SMTP sink & stub API | PASS |
| 7 | Email peserta sebagai penerima | `To`/`RCPT TO` = email pendaftaran | PASS |
| 8 | Tombol kirim ulang benar-benar mengirim | pesan kedua diterima penyedia; nomor tiket sama; 1 baris delivery; 1 tiket | PASS |
| 9 | SMTP tidak dikonfigurasi | `transport=disabled`, API `NOT_CONFIGURED`, delivery `PENDING` + alasan | PASS |
| 10 | Autentikasi SMTP salah | `FAILED` + `last_error` (mis. `535`/`EAUTH`), bukan `SENT` | PASS (skenario kegagalan SMTP/HTTP) |
| 11 | Email penerima tidak valid | `FAILED/invalid_recipient`, penyedia tidak dipanggil | PASS |
| 12 | Kirim ulang tidak mengubah nomor tiket / duplikasi | `ticket_code` sama, `count(tickets)=1`, `count(deliveries)=1`, `attempt_count` bertambah | PASS |
| 13 | Kirim ulang tidak menurunkan `SENT` | kegagalan setelah `SENT` tetap `SENT` | PASS |
| 14 | **Email diterima di inbox asli** | belum ada kredensial email | **BLOCKED** (§7.3) |

### 7.2 Bukti kunci

```
PASS  identitas pengirim = email penyelenggara dari database :: Organizer E2E Email <org.e2e...@example.test>
PASS  Reply-To menunjuk email penyelenggara
PASS  email peserta tidak dipakai sebagai pengirim
PASS  kirim ulang mengirim email baru :: sebelum=1 sesudah=2
PASS  nomor tiket tidak berubah :: TKT-...
PASS  kirim ulang tidak menerbitkan tiket duplikat :: jumlah=1
PASS  alamat penerima tidak valid ditolak :: FAILED/invalid_recipient
PASS  SMTP sink menerima pesan kirim ulang :: jumlah=2
PASS  From memakai email penyelenggara dari database :: org.verify...@example.test
```

### 7.3 Yang masih BLOCKED: penerimaan di inbox asli

Belum dibuktikan karena **tidak ada kredensial email** pada mesin/environment
ini. Tidak ada kredensial yang dikarang, dan tidak ada SMTP dummy yang dipakai
untuk mengklaim berhasil. Perlu diketahui: pada pemeriksaan jaringan saat
pekerjaan ini, port SMTP (587/465) **terbuka** dari mesin ini; jadi hambatannya
bukan lagi port, melainkan kredensial/verifikasi pengirim yang belum tersedia.

**Yang harus disediakan pemilik proyek (jangan dikirim lewat chat):**

1. Pilih salah satu:
   - **Resend**: `RESEND_API_KEY` + domain pengirim terverifikasi (SPF/DKIM
     disetel sesuai petunjuk Resend), atau
   - **SMTP**: host, port, `SMTP_USER`, `SMTP_PASS` (App Password), dan
     `EMAIL_FROM` yang diizinkan akun tersebut.
2. Tulis nilainya langsung di `backend/.env` (file ini tidak boleh di-commit)
   dan di environment deployment backend yang sebenarnya.
3. Bila ingin `From` = email penyelenggara, daftarkan domain penyelenggara pada
   `EMAIL_ORGANIZER_FROM_DOMAINS` **hanya setelah** domain itu terverifikasi di
   penyedia. Untuk Gmail, `SMTP_USER` harus akun Gmail tersebut.

**Langkah verifikasi setelah kredensial tersedia:**

```bash
cd backend
npm run email:test -- --to=inbox-anda@gmail.com   # 1 email uji nyata
npm run verify:email                              # harus berhenti tanpa BLOCKED
npm run retry:emails                              # kirim 4 tiket nyata yang masih PENDING
```

Lalu periksa **inbox dan folder spam** `VERIFY_EMAIL_TO`/`--to` dan alamat
peserta. Bukti masuk inbox bersifat manual; status `SENT` hanya berarti penyedia
menerima pesan. Status `DELIVERED` tidak pernah dicatat karena tidak ada
webhook/konfirmasi inbox.

Catatan: 4 catatan `ticket_email_deliveries` nyata masih `PENDING` (akibat
konfigurasi lama). Data tersebut tidak diubah/dihapus; `npm run retry:emails`
akan mengirimkannya setelah kredensial diisi.

---

## 8. Logging dan status

Setiap percobaan menghasilkan log JSON terstruktur (tanpa password/token/API
key) dengan: `ts`, `eventId`, `ticketId`, `ticketCode`, `recipient`, `from`,
`fromOrganizer`, `replyTo`, `mode`, `status`, `attemptCount`, `resend`,
`messageId`, `response` penyedia, `accepted/rejected/pending`, `sentAt`, dan
`error` bila gagal.

Status yang dibedakan:

| Status | Arti |
|---|---|
| `NOT_CONFIGURED` | layanan email belum siap; tidak ada percobaan kirim |
| `PENDING` | belum dikirim / antre / sedang dikirim (`SENDING` pada UI) |
| `SENT` | penyedia **menerima** pesan (`2xx` SMTP/HTTP) |
| `FAILED` | gagal + `last_error` |
| `DELIVERED` | **tidak dipakai** — tidak ada bukti/konfirmasi inbox |

Catatan teknis: enum `EmailDeliveryStatus` di database hanya
`PENDING/SENT/FAILED`. Karena perubahan schema tidak diizinkan, kondisi
“belum terkirim karena belum dikonfigurasi” disimpan sebagai `PENDING` +
`last_error`, dan **API/UI menampilkannya sebagai `NOT_CONFIGURED`**.

---

## 9. Kesimpulan

- Akar masalah: tidak ada konfigurasi email sama sekali pada environment
  (bukan hanya `SMTP_HOST`), ditambah bug transport yang mengabaikan identitas
  pengirim dan tombol kirim ulang yang tidak benar-benar mengirim.
- Perbaikan: dua jalur transport tervalidasi, From penyelenggara dengan aturan
  anti-spoofing + `Reply-To`, penerima dari data pendaftaran, PDF+QR wajib,
  kirim ulang eksplisit tanpa duplikasi tiket, logging lengkap, dan status jujur.
- Terbukti: seluruh rantai aplikasi (pendaftaran → tiket → PDF/QR → email)
  lulus pengujian, termasuk From penyelenggara, penerima peserta, kirim ulang,
  alamat tidak valid, dan tidak ada duplikasi.
- Belum terbukti: penerimaan di **inbox asli** — `BLOCKED` sampai kredensial
  dan verifikasi pengirim disediakan. Pekerjaan ini **tidak** dinyatakan selesai
  untuk kriteria tersebut.




