# LAPORAN PERBAIKAN — PENERBITAN & PENGIRIMAN TIKET MELALUI EMAIL

> **Catatan:** laporan ini mendokumentasikan pekerjaan tahap sebelumnya.
> Perbaikan identitas pengirim (From penyelenggara/Reply-To), kirim ulang
> eksplisit, validasi penerima, dan status terbaru ada di
> [`LAPORAN_PERBAIKAN_PENGIRIMAN_EMAIL_TIKET_FINAL.md`](LAPORAN_PERBAIKAN_PENGIRIMAN_EMAIL_TIKET_FINAL.md).

- **Tanggal:** 2026-11-27
- **Lingkup:** alur pendaftaran peserta → penyimpanan data → penerbitan tiket →
  PDF + QR → pengiriman email ke peserta, serta integrasi layanan email.
- **Status ringkas:** penyebab utama ditemukan dan diperbaiki. Seluruh rantai
  aplikasi **lulus pengujian**. Pengiriman ke **inbox email asli tetap
  `BLOCKED`** karena tidak ada kredensial email dan port SMTP diblokir jaringan
  di mesin ini (lihat §6). Tidak ada keberhasilan yang dikarang.

---

## 1. Akar permasalahan

Masalah **bukan** pada pembuatan tiket, PDF, atau QR. Ketiga bagian itu sudah
benar sebelum perbaikan. Penyebab sebenarnya ada pada **lapisan transport email**
dan **penjagaan anti-duplikat**, ditambah beberapa cacat lain yang membuat
pengiriman tidak pernah berhasil atau tidak dapat dipercaya.

### 1.1 Penyebab utama (P1) — tidak ada layanan email yang dikonfigurasi

`backend/.env` sama sekali **tidak memuat** `SMTP_HOST`, `SMTP_USER`,
`SMTP_PASS`, maupun `EMAIL_FROM`. Akibatnya `smtpStatus()` selalu menghasilkan
`mode = disabled`, dan setiap pendaftaran hanya menulis baris
`ticket_email_deliveries` berstatus `PENDING` dengan alasan
*“SMTP_HOST belum dikonfigurasi; email BELUM dikirim.”* Tidak ada satu pun email
yang keluar dari server.

Bukti langsung pada database (3 tiket peserta nyata, semuanya `PENDING`):

```
ticket 7cf65da5… recipient alfifidia3@gmail.com status PENDING attempt_count 0
        last_error "SMTP_HOST belum dikonfigurasi; email BELUM dikirim." sent_at NULL
ticket 73ca84eb… recipient yes@gmail.com        status PENDING attempt_count 0
ticket da5a5bcd… recipient alfifidia3@gmail.com status PENDING attempt_count 0
```

**Inilah sebab peserta tidak pernah menerima tiket.** Tiket terbit dan dapat
dibuka di aplikasi, tetapi email tidak pernah dicoba dikirim.

### 1.2 Penyebab kedua (P2) — port SMTP diblokir jaringan

Diuji langsung dari mesin ini (bukan asumsi):

| Tujuan | Port | Hasil |
|---|---|---|
| `smtp.gmail.com` | 587 | **timeout** |
| `smtp.gmail.com` | 465 | **timeout** |
| `smtp-relay.brevo.com` | 587 | **timeout** |
| `smtp.mailgun.org` | 587 | **timeout** |
| `api.resend.com` | 443 | **OPEN** |
| `api.sendgrid.com` | 443 | **OPEN** |

Artinya: **walaupun** kredensial SMTP diisi, pengiriman dari mesin ini tetap
gagal karena port SMTP diblokir. Hanya HTTPS (443) yang terbuka. Karena itu
perbaikan tidak cukup dengan “mengisi SMTP”, tetapi harus menyediakan jalur
pengiriman yang berfungsi pada kondisi jaringan ini.

### 1.3 Cacat lain yang ditemukan saat penelusuran

| # | Masalah | Akar penyebab | Dampak |
|---|---|---|---|
| P3 | Email bisa terkirim **ganda** | Penjagaan anti-duplikat hanya `Map` in-memory per proses + `SELECT` sebelum kirim (race condition). Tidak ada klaim atomik di database. | Retry bersamaan, klik ganda, atau lebih dari satu instance backend dapat mengirim tiket yang sama dua kali |
| P4 | Catatan pengiriman bisa **ganda** per tiket | `upsertDelivery` mencocokkan `recipient` **case-sensitive** (`recipient=$2`), sedangkan `markQueued` memakai `lower(recipient)` | Baris duplikat bila kapitalisasi email berbeda |
| P5 | Status `SENT` bisa **turun** jadi `FAILED` | `UPDATE` di `upsertDelivery` tidak melindungi baris `SENT` | Riwayat pengiriman yang sudah benar menjadi rusak |
| P6 | Retry tanpa backoff | Jeda tetap 15 menit untuk semua kegagalan | Relay yang bermasalah dibanjiri percobaan berulang |
| P7 | **Kirim ulang email 404 untuk peserta guest** | `resendTicketEmail` memakai `SELECT * FROM tickets`, padahal tabel `tickets` **tidak punya kolom `order_id`**; fallback otorisasi selalu `null` | Tombol “Kirim ulang email” gagal bila `order_id` tidak dikirim klien |
| P8 | Relay tanpa kredensial tidak ditolak lebih awal | `smtpStatus()` tidak mewajibkan `SMTP_USER`/`SMTP_PASS` untuk host non-lokal | Pesan baru ditolak relay (535/550) setelah pendaftaran selesai |
| P9 | Pengirim default palsu | `src/config/env.js` punya fallback `no-reply@eticket.local` (tidak dipakai di mana pun) | Berpotensi mengirim dengan alamat palsu/tidak valid |
| P10 | Kegagalan tidak terlihat sejak awal | Tidak ada preflight koneksi ke penyedia email saat server start | Kegagalan baru ketahuan setelah peserta pertama mendaftar |
| P11 | Kegagalan sulit didiagnosis | `sendMail` tanpa batas waktu eksplisit; log tidak memuat respons penyedia | Proses dapat menggantung; penyebab tidak jelas |

### 1.4 Bagian yang sudah benar (tidak diubah)

Ditrace dan **tidak** diubah karena sudah sesuai ketentuan:

- Event **gratis** → order langsung `PAID`, tiket terbit otomatis.
- Event **berbayar** → tiket hanya terbit setelah pembayaran simulasi `paid`.
- Penerima email = `attendees.email` (email yang diisi saat mendaftar).
- PDF dibuat dari data database, mengikuti **desain & orientasi** penyelenggara.
- QR unik per tiket (`token_hash`, HMAC + secret), dapat dipindai dan terhubung
  ke tiket yang benar.
- Lampiran PDF **wajib**; bila rendering gagal, email tidak dikirim.
- Pengiriman asinkron (tidak memblokir respons pendaftaran).
- Tidak ada perubahan skema database, tampilan, navigasi, atau alur pembayaran.

---

## 2. Perbaikan yang dilakukan

### 2.1 `backend/src/services/emailService.js` (inti perbaikan)

| Perubahan | Menyelesaikan |
|---|---|
| Transport **HTTPS API (Resend)** via `RESEND_API_KEY` — dipilih **lebih dulu** karena memakai port 443 yang terbuka; lampiran PDF dikirim base64; memakai `fetch` bawaan Node (**tanpa dependensi baru**) | P1, P2 |
| `claimDelivery()` — klaim kirim **atomik** per `(ticket_id, recipient)` dalam satu `UPDATE` bersyarat + `pg_advisory_xact_lock`. `SENT` tidak pernah diklaim ulang; `PENDING` dalam masa klaim dianggap sedang dikirim; klaim kedaluwarsa (`EMAIL_SEND_CLAIM_SECONDS`, default 120 dtk) sehingga proses yang berhenti tetap dilanjutkan worker retry | P3 |
| `upsertDelivery()` — pencocokan penerima memakai `lower(recipient)`; baris `SENT` tidak pernah diturunkan; `INSERT … ON CONFLICT DO NOTHING` mencegah balapan | P4, P5 |
| Backoff retry `EMAIL_RETRY_BASE_DELAY_MS × nomor percobaan` (maks. 10×) | P6 |
| `verifyTransport()` — preflight nyata ke penyedia (SMTP `verify()` / HTTPS `GET /domains`); tidak membocorkan kredensial | P10 |
| Batas waktu transport eksplisit (`SMTP_CONNECTION_TIMEOUT_MS`, `SMTP_GREETING_TIMEOUT_MS`, `SMTP_SOCKET_TIMEOUT_MS`, `EMAIL_API_TIMEOUT_MS`) | P11 |
| Log penerimaan memuat `response`, `envelope.to`, `accepted`, `rejected`, `pending` | P11 |
| Relay non-loopback tanpa kredensial ditolak lebih awal (`SMTP_ALLOW_LOCAL_RELAY=true` untuk relay lokal) | P8 |
| Envelope eksplisit + `Reply-To` pada pesan | keandalan relay |
| Pemeriksaan konfigurasi dipindah **sebelum** klaim, agar percobaan tidak terpakai saat transport belum siap | P3 |

### 2.2 File lain yang diperbaiki

| File | Perubahan | Alasan |
|---|---|---|
| `backend/src/controllers/ticketController.js` | `resendTicketEmail` mengambil `order_id` lewat join `attendees → order_items` (bukan `SELECT * FROM tickets`) | P7 |
| `backend/src/services/emailQueue.js` | Gate worker & `enqueueTicket` memakai `status.configured` (mendukung `resend`); `summarize().configured` tidak menghitung transport uji | konsistensi transport baru |
| `backend/server.js` | Preflight transport saat startup (log status, tanpa kredensial) | P10 |
| `backend/src/config/env.js` | Menghapus blok `smtp` mati berisi fallback pengirim palsu `no-reply@eticket.local` | P9 |
| `backend/.env.example` | Dokumentasi dua opsi transport + variabel baru (tanpa nilai rahasia) | konfigurasi |
| `backend/package.json` | Script `verify:email-api`, `verify:ticket-email-e2e` | pengujian |
| `backend/scripts/verify-email-delivery.js` | Skenario kegagalan memakai tiket **baru** (agar `SENT` tidak diturunkan) + asersi “catatan SENT tidak diturunkan”; pesan BLOCKED menyebut opsi HTTPS | kebenaran pengujian |
| `backend/scripts/retry-ticket-emails.js` | Menerima mode `resend` | transport baru |
| `backend/test/email_ticket_delivery_rules.test.js` | 3 test baru (transport HTTPS, `EMAIL_FROM` wajib, relay tanpa kredensial) | regresi |
| `backend/scripts/verify-email-api-transport.js` **(baru)** | Verifikasi transport HTTPS + anti-duplikat + kirim paralel | bukti |
| `backend/scripts/verify-ticket-email-e2e.js` **(baru)** | E2E HTTP nyata: daftar → tiket → PDF+QR → email | bukti |
| `backend/README.md`, `docs/ARCHITECTURE.md` | Dokumentasi transport, anti-duplikat, variabel environment | dokumentasi |

### 2.3 Perubahan database

**Tidak ada.** Tidak ada migrasi, perubahan skema, kolom, tabel, atau seed.
`npm run verify:db-schema` → **PASS** (tidak ada perbedaan schema Prisma vs DB).
Yang berubah hanya **perilaku penulisan data** pada tabel
`ticket_email_deliveries` yang sudah ada.

---

## 3. Mekanisme pengiriman email yang dipakai

Urutan pemilihan transport (otomatis, hanya dari environment):

1. **`RESEND_API_KEY` terisi** → HTTPS API `POST https://api.resend.com/emails`
   (port 443). PDF dilampirkan sebagai base64. **Ini yang dipakai bila port SMTP
   diblokir.**
2. **`SMTP_HOST` terisi** → SMTP via Nodemailer.
3. Keduanya kosong → `disabled`; delivery dicatat `PENDING` + alasan, **tidak
   pernah** diklaim terkirim.

Alur setelah peserta mendaftar / pembayaran lunas:

```
order PAID (gratis) / payment paid (berbayar)
  → tiket terbit (transaksi DB)
  → emailQueue.enqueueOrder()  → delivery dicatat PENDING (respons tidak menunggu)
  → setImmediate: sendTicketEmail()
      → claimDelivery()            (atomik; cegah email ganda)
      → loadTicketContext()        (nama, email, event, kategori dari DB)
      → buildPdfAttachment()       (PDF desain+orientasi penyelenggara, QR unik)
      → deliver()                  (HTTPS API atau SMTP)
      → upsertDelivery(SENT/FAILED + last_error + backoff)
```

Kegagalan email **tidak** membatalkan penerbitan tiket dan **tidak** merusak
data pendaftaran; statusnya tercatat jujur dan dapat dikirim ulang.

---

## 4. Hasil pengujian

Semua dijalankan dari `backend/` (Windows, Node 22, PostgreSQL/Supabase aktif).

| # | Pengujian | Perintah | Hasil |
|---|---|---|---|
| T1 | Unit/integration backend | `npm test` | **241 pass, 0 fail** (sebelumnya 238; +3 test baru) |
| T2 | Sintaks | `npm run check` | Syntax OK: 59 file |
| T3 | Format | `npm run format:check` | passed |
| T4 | Skills | `npm run validate:skills` | 7 skills, 8 file |
| T5 | Sinkronisasi konfigurasi | `npm run test:sync-config` | 14 pass, 0 fail |
| T6 | **E2E tiket+email (HTTP nyata)** | `npm run verify:ticket-email-e2e` | **36 PASS, 0 FAIL** |
| T7 | **Transport HTTPS API** | `npm run verify:email-api` | **24 PASS, 0 FAIL** |
| T8 | SMTP nyata → sink lokal | `npm run verify:email` | **18 PASS, 0 FAIL, 1 BLOCKED** |
| T9 | Antrean asinkron | `npm run verify:email-queue` | PASS (enqueue 129 ms vs kirim 2.185 ms) |
| T10 | Alur tiket HTTP + DB | `npm run verify:ticket-flow` | SEMUA PEMERIKSAAN LULUS |
| T11 | Rendering PDF 2 orientasi | `npm run verify:ticket-pdf` | 13 OK |
| T12 | E2E registrasi | `npm run test:registration-flow` | 32/32 lulus |
| T13 | Sinkronisasi schema | `npm run verify:db-schema` | PASS |
| T14 | Analisis statis Flutter | `flutter analyze` | No issues found |
| T15 | Seluruh test Flutter | `flutter test` | **797 test lulus** |

### 4.1 Skenario wajib

| No. | Skenario | Bukti | Hasil |
|---|---|---|---|
| 1 | Event **gratis**: tiket otomatis terbit setelah data tersimpan | `verify:ticket-email-e2e` → order `PAID`, `count=1` | PASS |
| 2 | Event **berbayar**: tiket hanya setelah pembayaran dikonfirmasi | `count=0` sebelum bayar, `count=1` setelah `paid`; email **belum** dikirim sebelum bayar | PASS |
| 3 | Email dikirim ke alamat yang didaftarkan | `recipient` = email peserta di DB **dan** di pesan | PASS |
| 4 | Email berisi lampiran PDF | lampiran `application/pdf`, diawali `%PDF-`, ±16 KB | PASS |
| 5 | PDF memuat nama peserta | teks PDF memuat `Peserta Gratis E2E` / `Peserta Bayar E2E` | PASS |
| 6 | PDF memuat nama event | teks PDF memuat nama event dari DB | PASS |
| 7 | PDF memuat kategori tiket | `Reguler` (gratis) & `VIP` (berbayar) | PASS |
| 8 | PDF memuat kode tiket unik | `TKT-…` ditemukan di dalam PDF | PASS |
| 9 | QR dapat dipindai & terhubung ke tiket benar | `POST /api/tickets/verify` → `200`, `id` cocok, email cocok | PASS |
| 10 | Tidak ada pengiriman ganda saat kirim ulang | `SKIPPED/already_sent`; 1 baris delivery; pesan tetap 1 | PASS |
| 11 | Tidak ada pengiriman ganda saat **paralel** | 3 kirim bersamaan → `SENT,SKIPPED,SKIPPED`; API dipanggil 1×; 1 baris delivery | PASS |
| 12 | Kegagalan email tidak merusak data | delivery `FAILED` + `last_error`; tiket & peserta tetap ada; `SENT` lama tidak turun | PASS |
| 13 | Desain & orientasi tiket dipertahankan | `verify:ticket-pdf` 13 OK (landscape 720×288, portrait 440×704, tidak distorsi) | PASS |
| 14 | Layanan email tidak dikonfigurasi | `transport=disabled`, `delivered=false`, delivery `PENDING` + alasan | PASS |
| 15 | **Email diterima di inbox asli** | belum ada kredensial & port SMTP diblokir | **BLOCKED** |

### 4.2 Bukti kunci

`verify:ticket-email-e2e` (rantai penuh lewat HTTP nyata):

```
PASS  pendaftaran event gratis diterima :: status=201
PASS  event gratis langsung PAID :: paid
PASS  tiket event gratis terbit :: count=1
PASS  email tiket gratis terkirim otomatis :: SENT
PASS  penerima email = email yang didaftarkan :: peserta.gratis…@example.test
PASS  email berisi lampiran PDF yang sah :: 16531 byte
PASS  PDF memuat nama peserta
PASS  PDF memuat kode tiket unik :: TKT-099f53640b0d4296b7f600e4c51466ec
PASS  PDF memuat kategori tiket :: Reguler
PASS  QR dapat dipindai dan terhubung ke tiket yang benar :: status=200
PASS  kirim ulang tidak mengirim email ganda :: SKIPPED/already_sent
PASS  event berbayar menunggu pembayaran :: pending_payment
PASS  tiket BELUM terbit sebelum pembayaran :: count=0
PASS  email tiket belum dikirim sebelum pembayaran
PASS  tiket terbit setelah pembayaran dikonfirmasi backend :: count=1
PASS  email tiket berbayar terkirim setelah lunas :: SENT
PASS  PDF berbayar memuat kategori tiket :: VIP
E2E TIKET+EMAIL LULUS (endpoint penyedia email = stub lokal)
```

`verify:email-api` (anti-duplikat & kegagalan jujur):

```
PASS  pengiriman pertama tercatat SENT :: SENT
PASS  permintaan memakai Bearer token dari environment
PASS  isi lampiran adalah PDF yang sah :: 16666 byte
PASS  kirim ulang tidak mengirim email ganda :: SKIPPED/already_sent
PASS  hanya satu pengiriman paralel yang benar-benar mengirim :: sent=1 status=SENT,SKIPPED,SKIPPED
PASS  pengiriman paralel hanya memanggil API sekali :: tambahan=1
PASS  kegagalan transport API dicatat FAILED :: FAILED/fetch failed
PASS  catatan SENT tidak diturunkan oleh kegagalan berikutnya :: SENT
TRANSPORT HTTPS API TERVERIFIKASI (lokal; inbox nyata perlu kredensial)
```

`verify:email` (transmisi SMTP sungguhan ke sink lokal):

```
PASS  RCPT TO memakai email peserta :: uji-tiket@example.test
PASS  subjek email adalah E-Ticket
PASS  lampiran PDF tiket ikut terkirim
PASS  kirim ulang tidak mengirim email ganda :: SKIPPED/already_sent
PASS  kegagalan SMTP dicatat FAILED (tidak diklaim terkirim)
BLOCKED  pengiriman ke inbox nyata :: layanan email belum siap.
PEMERIKSAAN LOKAL LULUS; 1 verifikasi eksternal BLOCKED
```

---

## 5. Kebersihan data

- Data uji E2E **dihapus otomatis** oleh skripnya: 0 event `Event … E2E Email …`
  dan 0 event `Konser Verifikasi …` tersisa.
- Data nyata tidak diubah: 3 tiket, 3 peserta, 3 order, 3 baris delivery tetap
  seperti sebelum pekerjaan ini.
- 3 baris delivery nyata masih `PENDING` — inilah tiket peserta yang belum
  pernah terkirim (akibat P1). Setelah kredensial diisi, jalankan
  `npm run retry:emails` untuk mengirimkannya.

---

## 6. Yang masih BLOCKED dan mengapa

### 6.1 Pengiriman ke inbox email asli — **BLOCKED**

**Belum dibuktikan.** Dua hambatan nyata di lingkungan ini:

1. **Tidak ada kredensial email.** `backend/.env` tidak memuat `SMTP_*` maupun
   `RESEND_API_KEY`. Kredensial tidak boleh dikarang dan tidak boleh ditulis ke
   source code.
2. **Port SMTP diblokir jaringan** (lihat §1.2). Jadi bahkan dengan kredensial
   SMTP, pengiriman dari mesin ini akan gagal. Karena itu ditambahkan transport
   HTTPS API (port 443) sebagai jalur yang berfungsi pada kondisi ini.

**Yang sudah disiapkan** agar begitu kredensial diisi tidak perlu ubah kode:

```
# Opsi A (disarankan di jaringan ini) — backend/.env
RESEND_API_KEY=<api key Anda>
EMAIL_FROM=alamat@domain-terverifikasi
VERIFY_EMAIL_TO=inbox-anda@domain-anda

# Opsi B — backend/.env
SMTP_HOST=smtp.domain-anda
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=alamat@domain-anda
SMTP_PASS=<app password>
EMAIL_FROM=alamat@domain-anda
VERIFY_EMAIL_TO=inbox-anda@domain-anda
```

Langkah verifikasi setelah kredensial tersedia:

1. `cd backend; npm run verify:email` → harus berhenti `BLOCKED`.
2. Periksa **inbox dan folder spam** alamat `VERIFY_EMAIL_TO` — bukti masuk inbox
   bersifat manual dan tidak dapat diklaim oleh skrip.
3. `npm run retry:emails` untuk mengirim 3 tiket peserta yang masih `PENDING`.
4. Daftarkan peserta sungguhan lewat tautan publik event, lalu pastikan tiket PDF
   diterima di email tersebut.

### 6.2 Uji perangkat fisik — **BLOCKED (manual)**

Tidak ada perangkat/emulator Android/iOS di lingkungan ini. Tidak ada perubahan
UI, `flutter analyze` bersih, dan 797 widget/test lulus, tetapi pengujian pada
perangkat nyata tidak diklaim sudah dilakukan.

### 6.3 Catatan asumsi

- Pemilihan **Resend** sebagai penyedia HTTPS karena API-nya sederhana (satu
  `POST`, lampiran base64) dan tidak memerlukan dependensi baru. Bila
  penyelenggara memakai penyedia lain (SendGrid/Mailgun HTTP API), penyesuaian
  hanya pada `sendViaResend()` — kontrak pemanggilan tidak berubah.
- `EMAIL_FROM` wajib memakai domain yang **terverifikasi** di penyedia. Bila
  belum, penyedia akan menolak pesan; kegagalan tercatat pada `last_error`.
- Masa klaim 120 detik dipilih karena lebih lama dari batas waktu transport
  (maks. 45 detik) sehingga tidak ada dua pengiriman aktif bersamaan, tetapi
  tetap cukup singkat agar tiket yang tertinggal cepat dipulihkan.
- Transport HTTP API menandai `SENT` berdasarkan respons `2xx` penyedia
  (pesan **diterima** penyedia), bukan bukti masuk inbox. Status ini sama
  tingkatnya dengan `SENT` pada SMTP (`250 OK`).

---

## 7. Kesimpulan

- **Akar masalah:** tidak ada layanan email yang dikonfigurasi (P1), diperberat
  port SMTP yang diblokir jaringan (P2), serta tidak adanya penjagaan
  anti-duplikat lintas proses dan beberapa cacat pendukung (P3–P11).
- **Perbaikan:** transport HTTPS API + SMTP dengan validasi konfigurasi, klaim
  atomik anti email ganda, backoff retry, preflight startup, logging diagnostik,
  serta perbaikan otorisasi kirim ulang.
- **Terbukti:** tiket terbit sesuai aturan gratis/berbayar; PDF memuat nama
  peserta, nama event, kategori, kode tiket, dan QR yang dapat dipindai serta
  terhubung ke tiket benar; email berisi lampiran PDF terkirim ke alamat peserta
  tanpa duplikasi; kegagalan tidak merusak data.
- **Belum terbukti:** penerimaan di **inbox email asli** — `BLOCKED` sampai
  kredensial diisi oleh pemilik proyek (§6.1). Pekerjaan ini **tidak** dinyatakan
  selesai untuk kriteria tersebut.
