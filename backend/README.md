# Backend - E Ticket Event QR Scan

Backend API untuk aplikasi mobile e-ticket event dengan verifikasi QR code.
Dibangun dengan **Node.js + Express + JavaScript** dan database **PostgreSQL via Supabase**.

## Fondasi Prisma

- Schema target berada di [`prisma/schema.prisma`](prisma/schema.prisma).
- Analisis entitas, relasi, konflik kontrak, dan prasyarat migration ada di
  [`docs/DATABASE.md`](../docs/DATABASE.md).
- Backend menjalankan query melalui PostgreSQL langsung (`pg`) di
  `src/config/db.js`. `src/config/supabase.js` hanya alias kompatibilitas dan
  tidak lagi membuat Supabase JS client.
- Migration Prisma **sudah diterapkan** pada database yang dikonfigurasi
  `DATABASE_URL` dan tercatat di `_prisma_migrations` (9 migration, terakhir
  `20261118000400_restore_payment_status_enum_cast`). Bukti pemeriksaan ada di
  `../task/DATABASE_AUDIT_FINAL.md` (arsip).
- `npx prisma migrate diff --from-schema-datasource prisma/schema.prisma
  --to-schema-datamodel prisma/schema.prisma --script` menghasilkan
  `-- This is an empty migration.` yang berarti struktur database aktual sesuai
  schema.
- Function PostgreSQL `moderate_event`, `create_event_order`,
  `simulate_event_payment`, dan `expire_event_order_reservations` tersedia.
- RLS aktif pada **32/32** tabel aplikasi dengan **0 policy** dan **0 grant**
  untuk `anon`/`authenticated` (diterapkan oleh migration
  `20261118000200_rls_and_supabase_grants`); hanya `service_role` yang memiliki
  privilege. Pemilik tabel adalah `postgres` (juga role koneksi backend),
  sehingga RLS tidak memutus backend. Otorisasi aplikasi tetap ditegakkan di
  middleware/controller backend, bukan oleh RLS.
- Verifikasi schema berlapis: `npm run verify:db-schema` (introspeksi `prisma db
  pull` + `migrate diff` dua arah + perbandingan jumlah index). Hasil terakhir:
  tidak ada perbedaan.
- Audit read-only: `node scripts/audit-db.js`. Rekonsiliasi function PL/pgSQL
  pada database lama dilakukan lewat migration Prisma (`npx prisma migrate
  deploy`), bukan skrip terpisah.

## Struktur Folder

```
backend/
├── .env                    # Environment variables lokal (buat dari .env.example)
├── .env.example            # Contoh variabel environment
├── .env.test.example       # Contoh variabel untuk environment uji
├── .gitignore
├── nodemon.json            # Konfigurasi watch untuk `npm run dev`
├── package.json
├── package-lock.json
├── server.js               # Entry point server (bootstrap akun + listen)
├── README.md
├── backups/                # Backup JSON lokal (di-ignore Git)
├── prisma/
│   ├── schema.prisma       # Sumber kebenaran schema
│   ├── migrations/         # 9 migration aktif + migration_lock.toml
│   └── legacy-migrations/  # SQL legacy; jangan dijalankan tanpa rekonsiliasi
├── scripts/                # Tooling dev, audit, verifikasi, backup, dan E2E
│   └── integration/        # Harness integrasi destruktif (opt-in)
├── test/                   # 29 file `*.test.js` untuk `npm test`
└── src/
    ├── app.js              # Setup Express + mount 5 router domain pada `/api`
    ├── config/
    │   ├── db.js           # Pool PostgreSQL (`pg`) satu-satunya koneksi
    │   ├── env.js          # Validasi & ekspor environment variables
    │   └── supabase.js     # Alias kompatibilitas (tanpa Supabase JS client)
    ├── controllers/
    │   ├── adminController.js             # Daftar akun & aktif/nonaktif
    │   ├── adminOverviewController.js     # Ringkasan konsol Admin
    │   ├── auditLogController.js          # Riwayat audit platform
    │   ├── authController.js              # Register, login, profil, logout
    │   ├── checkInController.js           # Check-in, peserta, export, order event
    │   ├── eventController.js             # CRUD, publikasi, anggota event
    │   ├── eventInvitationController.js   # Undangan staf & membership
    │   ├── eventMetricsController.js      # Ringkasan, grafik, moderasi
    │   ├── notificationController.js      # Notifikasi in-app
    │   ├── orderController.js             # Checkout dan akses order
    │   ├── organizerProfileController.js  # Profil organizer
    │   ├── paymentController.js           # Pembayaran Virtual Account simulasi
    │   ├── planController.js              # Katalog paket langganan
    │   ├── platformSettingsController.js  # Pengaturan platform
    │   ├── reportController.js            # Laporan dukungan
    │   ├── revenueController.js           # Pendapatan organizer & platform
    │   ├── subscriptionController.js      # Langganan organizer
    │   ├── ticketController.js            # Tiket, QR, kirim ulang email
    │   └── ticketTypeController.js        # CRUD kategori tiket
    ├── middleware/
    │   ├── authMiddleware.js       # Verifikasi JWT + role dari database
    │   ├── errorMiddleware.js      # Global error handler
    │   ├── notFoundMiddleware.js   # 404 handler
    │   ├── rateLimitMiddleware.js  # Limit global/auth/scan/tulis
    │   ├── requestLogger.js        # Log request terstruktur
    │   ├── roleMiddleware.js       # Gate role
    │   └── validationMiddleware.js # Hasil express-validator
    ├── models/            # Legacy (tidak dipakai runtime; lihat catatan di bawah)
    │   ├── User.js      # Model profil pengguna (legacy Supabase client)
    │   ├── Event.js     # Model event (legacy)
    │   └── Ticket.js    # Model tiket & QR code (legacy)
    ├── routes/                     # 5 router domain; semuanya di-mount pada `/api`
    │   ├── admin.js       # /admin, /plans, /subscriptions, /revenue,
    │   │                  # /support-reports, /notifications
    │   ├── auth.js        # /auth, /me
    │   ├── events.js      # /events, /ticket-types, /invitations
    │   ├── orders.js      # /orders, /payments, /tickets, /check-ins
    │   └── organizer.js   # /organizer (overview, summaries, profile)
    ├── services/
    │   ├── adminBootstrapService.js# Bootstrap akun admin (+ bootstrapConfiguredAccounts)
    │   ├── authService.js          # Logic auth (token, hash password)
    │   ├── emailService.js         # Pengiriman email tiket
    │   ├── notificationService.js  # Notifikasi in-app
    │   └── ticketTokenService.js   # Token QR tiket bertanda tangan (HMAC)
    ├── utils/
    │   ├── auditLog.js       # Penulisan audit log
    │   ├── constants.js      # Konstanta aplikasi
    │   ├── eventResponse.js  # Serializer event
    │   ├── eventSummary.js   # Agregasi ringkasan event
    │   ├── eventValidation.js# Validasi kelayakan publikasi
    │   ├── logger.js         # Logger terstruktur
    │   ├── orderResponse.js  # Serializer order/payment
    │   ├── response.js       # Helper response standar (dipakai test)
    │   └── validators.js     # Validator sederhana
    └── validators/
        └── index.js             # Validasi register/login & verifikasi tiket
```

> **Catatan legacy:** `src/models/*.js` dan `src/config/supabase.js` adalah sisa
> lapisan Supabase JS client lama. Runtime sekarang memakai `pg` melalui
> `src/config/db.js`, dan tidak ada modul runtime yang mengimpor `models/*`.
> Keduanya dipertahankan sementara karena berada di area konfigurasi database yang
> wewenangnya ada pada FINISHING; lihat proposal di laporan audit struktur.
> `src/utils/response.js` juga tidak dipakai controller, tetapi tetap dipertahankan
> karena diuji oleh `test/utils.test.js`.

Daftar di atas adalah kondisi aktual `backend/`. Setiap modul, route, atau script
baru wajib ditambahkan ke daftar ini pada perubahan yang sama agar dokumentasi
tidak menyimpang dari kode.

**Konsolidasi router (Tier C).** Enam belas berkas route lama
(`authRoutes`, `eventRoutes`, `ticketRoutes`, `ticketTypeRoutes`,
`checkInRoutes`, `invitationsRoutes`, `meRoutes`, `notificationRoutes`,
`reportRoutes`, `adminRoutes`, `organizerRoutes`, `orderRoutes`,
`paymentRoutes`, `planRoutes`, `subscriptionRoutes`, `revenueRoutes`) digabung
menjadi **5 router domain** di atas. Setiap router di-mount pada `/api` dan
mendaftarkan sub-path-nya sendiri, sehingga **path API tidak berubah**
(88 endpoint, terverifikasi `npm run routes:list` dan `npm run test:routes`).
Empat route yang sebelumnya didaftarkan langsung di `app.js`
(`/api/events/:id/attendees/export`, `/api/events/:id/orders`,
`/api/organizer/profile` GET/PUT, `/api/admin/email/retry`) kini berada di
domainnya masing-masing.

**Konsolidasi berkas pendukung (Tier B).** `services/seedService.js` dilebur ke
`services/adminBootstrapService.js` (ekspor `bootstrapConfiguredAccounts`), dan
`validators/authValidator.js` + `validators/ticketValidator.js` dilebur menjadi
`validators/index.js`. Nama ekspor tidak berubah.

Menambah endpoint baru: letakkan pada router domain yang sesuai di
`src/routes/*.js`. Penggabungan berkas **tidak** memengaruhi performa request
(`require` di-cache Node); dampaknya hanya pada waktu boot.

### Script dan tooling

| Script | Dijalankan lewat | Fungsi |
|--------|------------------|--------|
| `scripts/check-syntax.js` | `npm run check` / `npm run lint` | Parse seluruh `src/` dan `server.js` |
| `scripts/check-format.js` | `npm run format:check` | Deteksi CRLF dan trailing whitespace |
| `scripts/preflight-port.js` + `scripts/dev.js` | `npm run dev` / `npm run dev:reset` | Cek port dan jalankan nodemon tanpa proses yatim |
| `scripts/provision-admin.js` | `npm run admin:provision` | Bootstrap akun Admin idempotent |
| `scripts/audit-db.js` | `npm run audit:db` | Audit database read-only |
| `scripts/verify-schema-sync.js` | `npm run verify:db-schema` | Bandingkan schema Prisma dengan database (read-only) |
| `scripts/integration/` | `npm run test:integration` | Harness integrasi destruktif (opt-in) |
| `scripts/e2e-live.js` + `scripts/e2e-live-helpers.js` | `npm run test:e2e` | E2E alur PRD terhadap API + database nyata |
| `scripts/e2e-auth-live.js` | `npm run test:auth-live` | E2E login & registrasi Organizer terhadap API + database nyata |
| `scripts/verify-db-state.js` | `npm run verify:auth-db` | Ringkasan akun & profil Organizer di database (read-only) |
| `scripts/repair-organizer-profiles.js` | `npm run repair:organizer-profiles` | Buat `organizer_profiles` yang hilang (idempotent, tidak menghapus akun) |
| `scripts/dump-routes.js` | `npm run routes:list` | Cetak tabel 88 route yang terdaftar di Express (read-only) |
| `scripts/smoke-routes.js` | `npm run test:routes` | Pastikan semua endpoint terdaftar (regresi konsolidasi router) |
| `scripts/backup-db-json.js` | manual | Backup seluruh tabel sebagai JSON sebelum operasi destruktif |
| `scripts/verify-email-delivery.js` | `npm run verify:email` | Bukti transmisi SMTP nyata ke sink lokal + cek kesiapan inbox nyata |
| `scripts/verify-brevo-smtp.js` | `npm run verify:brevo` | Preflight bertahap Brevo (DNS/TCP/STARTTLS/AUTH) + uji kirim nyata & pemisahan bukti inbox |
| `scripts/verify-email-api-transport.js` | `npm run verify:email-api` | Bukti transport HTTPS API (attachment PDF base64, anti email ganda, kegagalan jujur) |
| `scripts/verify-ticket-email-e2e.js` | `npm run verify:ticket-email-e2e` | E2E HTTP nyata: daftar → tiket → PDF+QR → email (gratis & berbayar) |
| `scripts/verify-async-email-queue.js` | `npm run verify:email-queue` | Bukti respons tidak menunggu SMTP lambat + antrean mengirim tepat sekali |
| `scripts/retry-ticket-emails.js` | `npm run retry:emails` | Coba ulang delivery PENDING/FAILED (tanpa tiket/email ganda) |
| `scripts/backfill-ticket-codes.js` | `npm run tickets:backfill-codes` | Rapikan ID tiket lama menjadi `ETK-XXXXXX` (idempotent, tanpa menghapus data) |
| `scripts/repair-email-delivery-status.js` | `npm run repair:email-delivery` | Turunkan catatan `SENT` palsu dari transport json (dry-run default) |

### Test

- `npm test` menjalankan seluruh `test/*.test.js` dengan `node --test`.
- `npm run test:sync-config` memvalidasi validator sinkronisasi konfigurasi.
- `test/ticket_qr_scannability.test.js` memverifikasi ukuran modul, quiet zone, dan
  alas putih QR secara analitis dari geometri `ticketDesignService`, sehingga
  kelayakan pindai QR ikut dijaga `npm test` tanpa Python.
- Alat validasi Python di `tools/` (`render_ticket_pdf.py`,
  `decode_ticket_qr.py`)
  dijalankan manual dengan virtual environment proyek: `py -3.14 -m venv .venv`
  lalu `.\.venv\Scripts\python.exe -m pip install -r tools/requirements.txt`
  (PyMuPDF, opencv-python-headless, numpy). Alat ini bukan dependensi
  runtime backend, sehingga `.venv` tidak perlu aktif di terminal; panggil
  interpreter secara eksplisit, mis.
  `.\.venv\Scripts\python.exe tools/decode_ticket_qr.py <file.pdf>`.
- `npm run test:integration` dan `npm run test:e2e` memerlukan database/API uji
  serta `ALLOW_DESTRUCTIVE_TESTS=true`; jangan arahkan ke database produksi.
- `npm run test:registration-flow` menguji alur nyata (registrasi Organizer →
  event → kategori → publikasi → link/QR publik → desain tiket → pendaftaran
  guest → pembayaran simulasi → tiket PDF) terhadap backend yang sedang
  berjalan. `npm run verify:ticket-pdf` memverifikasi rendering template/tiket
  untuk kedua orientasi (landscape/portrait).
- `npm run verify:ticket-flow` menguji alur tiket lewat HTTP API + database nyata
  (nama event pada tiket, penerbitan tiket gratis/berbayar, status email jujur,
  kirim ulang tanpa duplikasi, orientasi tersimpan & dipakai PDF). Data uji
  memakai domain `.test` dan dihapus kembali.
- `npm run verify:email-queue` membuktikan pengiriman tidak lagi memblokir
  request: SMTP sink sengaja dilambatkan, penjadwalan email selesai jauh lebih
  cepat daripada percakapan SMTP, status awal `QUEUED/PENDING`, lalu berubah
  `SENT` setelah antrean selesai tanpa email ganda.
- `npm run verify:email` membuktikan pengiriman email sungguhan melalui SMTP:
  skrip menyalakan SMTP sink lokal, mengirim e-ticket, lalu memeriksa penerima,
  subjek, lampiran PDF, status `SENT`, tidak ada email ganda saat kirim ulang,
  serta pencatatan `FAILED` + `last_error` saat SMTP mati. Setelah itu skrip
  memeriksa konfigurasi SMTP nyata di `backend/.env`; bila lengkap dan
  `VERIFY_EMAIL_TO` diisi, skrip benar-benar mengirim ke alamat tersebut dan
  mencatat bahwa bukti masuk inbox tetap harus dicek manual. Tanpa kredensial,
  hasilnya `BLOCKED` (bukan `PASS` palsu).
- `npm run email:test -- --to=alamat@domain.com` mengirim SATU email uji nyata
  memakai konfigurasi aktif (tanpa data tiket). Exit code 0 hanya bila penyedia
  menerima pesan; masuk inbox/spam tetap diperiksa manual.
- `npm run verify:brevo` memverifikasi jalur Brevo secara bertahap: konfigurasi →
  DNS → TCP `smtp-relay.brevo.com:587` → STARTTLS + autentikasi
  (`transporter.verify()`) → (opsional) kirim nyata → (opsional) event Brevo API.
  Skrip mencetak pemisahan tegas antara **"Brevo menerima pesan" (250 queued)**
  dan **"email diterima di inbox"** yang tetap harus diperiksa manual. Dengan
  `--ticket=<uuid>` skrip mengirim e-ticket asli (PDF + QR) ke email peserta pada
  database. Kredensial tidak pernah dicetak dan `.env` tidak diubah.
  Opsi penerima diterima dalam dua bentuk, `--to=alamat@domain.com` maupun
  `--to alamat@domain.com`; `--dry-run` hanya menampilkan argumen yang terbaca
  tanpa menghubungi SMTP. Di PowerShell, `npm` dijalankan lewat `npm.ps1` yang
  membuang token `--` sehingga `--to=...` dibaca npm sebagai konfigurasinya
  sendiri (argv skrip kosong); skrip menutup kasus itu dengan membaca cadangan
  `npm_config_to` dan melaporkannya sebagai `INFO sumber argumen`. Bila masih
  ragu, `npm.cmd run verify:brevo -- --to=alamat@domain.com` meneruskan argumen
  apa adanya.

### Email e-ticket

Konfigurasi email dibaca dari environment; lihat `.env.example`. Tidak ada
kredensial di source code, dan log hanya memuat mode/status/host.

**Penyedia aktif: Brevo SMTP** (`smtp-relay.brevo.com`) melalui Nodemailer.
Port `587` memakai STARTTLS (`SMTP_SECURE=false`, `SMTP_REQUIRE_TLS=true`);
port `465` memakai TLS implisit (`SMTP_SECURE=true`).

Setup singkat (detail ada di `.env.example`):

1. Dashboard Brevo → **SMTP & API → SMTP**: salin host, login SMTP
   (`xxxxx@smtp-brevo.com`), buat **SMTP key**.
2. Dashboard Brevo → **Senders & IP → Senders**: verifikasi `EMAIL_FROM`.
   Brevo menolak (`550`) alamat `From` yang belum terverifikasi.
3. Isi `SMTP_USER`, `SMTP_PASS` (SMTP key, bukan password akun), `EMAIL_FROM`
   pada `backend/.env` lokal atau environment deployment. Jangan commit `.env`.
4. Verifikasi: `npm run verify:brevo` (preflight) lalu
   `npm run verify:brevo -- --to=inbox-anda@domain.com` (kirim nyata).
   Bentuk `--to inbox-anda@domain.com` juga diterima. Tambahkan `--dry-run` untuk
   memastikan alamat terbaca tanpa mengirim email.

Aplikasi memilih transport dengan urutan prioritas:

1. **`EMAIL_PROVIDER`** bila diisi: `brevo` (default profil Brevo), `smtp`
   (relay generik), `resend` (jalur HTTPS API lama), atau `none`.
2. Tanpa `EMAIL_PROVIDER`: **SMTP/Brevo** bila host tersedia → **`RESEND_API_KEY`**
   (jalur HTTPS API lama, fallback) → nonaktif.
3. Tidak ada transport aktif → email dinonaktifkan secara jujur: catatan
   `ticket_email_deliveries` berstatus `PENDING` + alasan, dan respons API
   (`email_delivery.delivered=false`) tidak pernah mengklaim email terkirim.

`EMAIL_FROM` wajib berupa alamat valid dan **terverifikasi sebagai sender di
Brevo**, jika tidak pesan ditolak.


**Identitas pengirim & penerima**

- Penerima selalu email peserta pada data pendaftaran (`attendees.email`), bukan
  alamat dari payload/klien.
- Alamat penyelenggara diambil dari database: akun pembuat event
  (`events.created_by` → `profiles.email`) beserta `events.organizer_name`.
- `From` memakai alamat penyelenggara **hanya bila penyedia mengizinkannya**:
  sama dengan `SMTP_USER` terautentikasi, sama dengan `EMAIL_FROM` terverifikasi,
  atau domainnya terdaftar pada `EMAIL_ORGANIZER_FROM_DOMAINS` (domain yang sudah
  diverifikasi di penyedia). Selain itu `From` memakai `EMAIL_FROM` dan alamat
  penyelenggara dipasang sebagai `Reply-To` (`EMAIL_REPLY_TO_ORGANIZER=false`
  untuk mematikan). Tidak ada spoofing dan tidak ada password email pribadi
  penyelenggara yang diminta/disimpan.
- Log pengiriman mencatat `eventId`, `ticketId`, `ticketCode`, penerima, alamat
  pengirim, `Reply-To`, mode transport, status, jumlah percobaan, dan
  `last_error` tanpa pernah menulis password/API key.
- `DELIVERED` tidak pernah dicatat: tidak ada bukti/konfirmasi inbox. `SENT`
  berarti penyedia **menerima** pesan (`2xx`), bukan jaminan masuk inbox.

- Validasi sebelum kirim: `EMAIL_PROVIDER` harus dikenal, `SMTP_PORT` 1–65535,
  `SMTP_USER`/`SMTP_PASS` harus berpasangan, relay non-loopback wajib memakai
  kredensial (relay lokal dapat diizinkan dengan `SMTP_ALLOW_LOCAL_RELAY=true`),
  dan `EMAIL_FROM` wajib valid. Brevo (port 587) memaksa STARTTLS sehingga
  kredensial tidak pernah terkirim pada koneksi polos. Bila salah satu tidak
  valid, transport `disabled` dengan alasan jelas (tidak ada percobaan kirim).
- Kegagalan transport diklasifikasikan (`dns`, `connect`, `tls`, `auth`,
  `sender`, `send`) dan saran tindakannya disimpan pada `last_error` — mis.
  SMTP key Brevo salah (`auth`) atau `EMAIL_FROM` belum diverifikasi (`sender`).
  Password/SMTP key tidak pernah ditulis ke log maupun `last_error`.
- `SMTP_HOST=json` hanya berlaku saat `NODE_ENV=test`; di luar test dianggap
  nonaktif dan **tidak pernah** dicatat `SENT`.
- Status `SENT` hanya dicatat setelah penyedia email menerima pesan (respons
  SMTP `2xx` atau HTTP `2xx` dari API).
- **Pengiriman asinkron di dalam proses** (`src/services/emailQueue.js`):
  pendaftaran/pembayaran hanya menerbitkan tiket + mencatat delivery `PENDING`
  lalu menjadwalkan email pada tick berikutnya. Respons tidak menunggu SMTP.
  Status `SENDING` ditampilkan selama pekerjaan berjalan; `QUEUED` berarti masih
  antre. Tidak ada job queue/dependensi runtime baru.
- Lampiran PDF wajib: bila rendering PDF gagal, email tidak dikirim dan
  kegagalan dicatat pada `last_error`.
- **Nama lampiran** mengikuti format wajib `E-TIKET Nama Peserta.pdf`
  (`src/utils/ticketFilename.js`), diambil dari `attendees.name` tiket yang
  sama — bukan kode tiket/UUID. Spasi biasa dipakai sebagai pemisah; karakter
  yang terlarang pada filesystem diganti spasi, dan nama non-Latin tetap utuh
  lewat `filename*=UTF-8''…`. Nama file unduhan manual
  (`GET /api/tickets/:id/pdf`) memakai format yang sama.
- **Anti email ganda** (`claimDelivery`): klaim atomik per `(ticket_id,
  recipient)` dalam satu `UPDATE` bersyarat + advisory lock. Aman terhadap klik
  ganda, retry bersamaan, dan lebih dari satu instance backend. Baris `SENT`
  tidak pernah diklaim ulang maupun diturunkan menjadi `FAILED`. Klaim
  kedaluwarsa setelah `EMAIL_SEND_CLAIM_SECONDS` (default 120) sehingga tiket
  yang tertinggal saat proses berhenti tetap terkirim oleh worker retry.
- Retry memakai backoff (`EMAIL_RETRY_BASE_DELAY_MS` × nomor percobaan),
  dibatasi 5 percobaan otomatis, menghormati `next_attempt_at`, dan tersedia
  lewat `POST /api/tickets/:id/email`, `POST /api/admin/email/retry`, worker
  periodik (interval 5 menit), serta `npm run retry:emails`.
- **Kirim ulang eksplisit** (tombol "Kirim ulang email") memakai `force`:
  email benar-benar dikirim lagi dengan nomor tiket dan PDF yang sama (tidak ada
  tiket baru, tidak ada perubahan nomor tiket), dibatasi
  `EMAIL_RESEND_COOLDOWN_SECONDS` (default 60 detik; `recently_sent` bila masih
  dalam jeda). Pengiriman otomatis tetap idempoten (`already_sent`).
  Respons memuat `sender`, `recipient`, `attempt_count`, `sent_at`, dan
  `previously_sent` (true bila kirim ulang gagal padahal pengiriman sebelumnya
  sudah SENT — status SENT tidak diturunkan).
- Alamat penerima divalidasi sebelum klaim; alamat tidak valid dicatat `FAILED`
  dengan alasan jelas tanpa memanggil penyedia. Tiket berstatus
  `cancelled`/`revoked` tidak dikirim ulang.
- Catatan lama yang salah berstatus `SENT` karena transport json dapat
  dinormalisasi dengan `npm run repair:email-delivery -- --apply` (membuat backup
  JSON lebih dulu; tidak menghapus data).
- Status yang dibedakan: `PENDING` (belum dikirim/antre), `SENDING` (sedang
  dikirim), `SENT` (diterima transport), `FAILED` (gagal + `last_error`), dan
  `NOT_CONFIGURED` (layanan email belum siap). Status pembayaran tidak pernah
  disamakan dengan status pengiriman email.
- Preflight saat startup (`verifyTransport`): server mencetak apakah penyedia
  email benar-benar dapat dihubungi beserta tahap kegagalannya (DNS, koneksi,
  TLS, autentikasi), sehingga masalah jaringan/port/kredensial terlihat tanpa
  harus menunggu pendaftaran pertama. `SMTP_HOST` yang menunjuk loopback
  (sisa relay uji) diperingatkan secara eksplisit karena tidak akan sampai ke
  inbox peserta.

## Endpoint API

Health check: `GET /health` (tanpa prefix `/api`) mengembalikan status server dan
koneksi database.

### Auth
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/auth/register` | Register pengguna baru (role organizer) | Public |
| POST | `/api/auth/login` | Login & dapatkan JWT | Public |
| GET | `/api/auth/me` | Profil pengguna login | Private |
| PUT | `/api/auth/me` | Perbarui nama/avatar | Private |
| POST | `/api/auth/logout` | Cabut token (revoked_tokens) | Private |

### E-Tiket PDF (dimensi, QR, ID, nama file)

Sumber tunggal rendering ada di `src/services/ticketDesignService.js` dan dipakai
bersama oleh unduhan manual (`GET /api/tickets/:id/pdf`) serta lampiran email —
tidak ada jalur rendering kedua untuk event gratis/berbayar.

- **Kanvas tetap per orientasi**: `landscape` 842 × 594 pt (A4 landscape) dan
  `portrait` 440 × 704 pt. Ukuran halaman TIDAK diturunkan dari rasio file
  desain, sehingga tiket tidak pernah menjadi pipih dan QR tidak mengecil.
- **Prinsip desain**: gambar yang diunggah Organizer adalah desain UTAMA tiket;
  sistem hanya menambahkan informasi dinamis yang sedikit. Tidak ada panel,
  kartu, atau latar tambahan di atas artwork.
- **Informasi tiket (7 baris, kiri atas, teks hitam tanpa panel)**:
  1. `E-TIKET [NAMA EVENT]` 34 pt (auto-fit 34→26 pt; nama panjang dibungkus
     maksimal 2 baris), 2. `Peserta: [NAMA PESERTA]` 23 pt bold (auto-fit
     23→17 pt agar nama panjang tetap satu baris), 3. `ID TIKET: [ID TIKET]`
     16 pt bold, 4. `Kategori: [KATEGORI]` 16 pt, 5. `Jadwal: [TANGGAL & WAKTU]`
     16 pt (WIB), 6. `Lokasi: [LOKASI]` 16 pt, 7. instruksi singkat penukaran
     tiket 14 pt. Bila area teks desain kustom lebih pendek, seluruh blok
     dikecilkan proporsional (hierarki tetap) agar tidak menimpa QR. Nomor
     registrasi, nomor order, tanggal terbit, dan kartu "berlaku untuk" TIDAK
     dicetak.
- **QR Code** default 220 pt (landscape) / 250 pt (portrait) tepat di bawah blok
  teks, modul putih opaque + quiet zone ≥ 2 modul. Alas putih hanya selebar
  QR + quiet zone + margin 6 pt (`QR_BACKING_PAD`), bukan kartu/panel.
  **Organizer dapat mengatur posisi X, posisi Y, dan ukuran QR** (fraksi 0..1);
  pengaturan disimpan di `ticket_design.qr` (mode `PUT` `qr_only: true`) dan
  dipakai apa adanya saat render. QR hanya digeser bila akan keluar halaman
  (ukurannya tidak diperkecil diam-diam) dan dinaikkan ke `QR_MIN_POINTS`
  (100 pt) bila diatur terlalu kecil agar tetap dapat dipindai.
- **Desain kustom** (event atau per kategori) digambar `contain` di dalam kanvas
  (rasio asli dipertahankan, sisa ruang menjadi mat ivory). Desain lama dengan
  rasio 2.5:1 tetap tercetak utuh; unggahan baru divalidasi mendekati rasio
  kanvas (landscape 1.25–1.62, portrait 0.50–0.85). Teks & QR memakai posisi
  `design.info` / `design.qr`.
- **Prioritas desain**: desain kategori → desain event → desain default sistem.
  Kandidat yang file-nya hilang dilewati (tidak langsung jatuh ke desain
  default), sehingga desain unggahan Organizer tetap dipakai bila masih ada.
- **ID tiket publik** `ETK-XXXXXX` (Crockford Base32 tanpa I/L/O/U) disimpan di
  `tickets.ticket_code`. `tickets.id` (UUID) tetap menjadi primary key/relasi,
  sehingga tidak ada perubahan schema. Tiket lama dirapikan otomatis saat
  tiket dibuka/dikirim, atau sekaligus dengan `npm run tickets:backfill-codes`;
  kode lama `TKT-<uuid>` tetap dapat divalidasi lewat `tickets.qr_code_data`.
- **Template desain** (`GET /api/ticket-design-template`) berisi latar/ornamen +
  penanda tipis area QR (garis putus-putus tanpa alas putih dan tanpa teks
  contoh) agar teks/alas putih dinamis tidak tercetak dua kali. Regenerasi:
  `powershell -ExecutionPolicy Bypass -File scripts/generate-ticket-template.ps1`.

### Events
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| GET | `/api/events/public` | Event yang dipublikasikan | Public |
| GET | `/api/events/mine` | Event milik Organizer login | Organizer |
| GET | `/api/events` | Semua event untuk moderasi | Admin |
| GET | `/api/events/:id` | Detail event publik atau milik pengguna berhak | Public/owner/Admin |
| POST | `/api/events` | Buat draft event | Organizer |
| PUT | `/api/events/:id` | Perbarui event yang statusnya dapat diedit | Owner/Admin |
| DELETE | `/api/events/:id` | Hapus draft event | Owner/Admin |
| POST | `/api/events/:id/submit-review` | Ajukan publikasi event; langsung `PUBLISHED` bila valid | Organizer |
| POST | `/api/events/:id/publish` | Publikasi event setelah validasi (perilaku sama dengan `submit-review`) | Organizer |
| GET/POST | `/api/events/:id/ticket-types` | Baca/buat kategori tiket | Public/Organizer |
| PUT/DELETE | `/api/events/:id/ticket-types/:ticketTypeId` | Ubah/hapus kategori tiket | Organizer |
| GET | `/api/ticket-types/:id` | Detail kategori tiket | Public |
| GET | `/api/events/:id/ticket-design` | Desain tiket event + per kategori (posisi QR, orientasi) | Owner/Admin |
| PUT | `/api/events/:id/ticket-design` | Unggah desain / simpan orientasi (`scope=event` atau `scope=ticket_type`); `qr_only: true` untuk menyimpan posisi & ukuran QR saja | Owner/Admin |
| DELETE | `/api/events/:id/ticket-design?scope=` | Hapus desain & orientasi (kembali ke default) | Owner/Admin |
| GET | `/api/ticket-design-template?format=pdf\|png&orientation=landscape\|portrait` | Unduh template desain tiket (ukuran + penanda QR) | Public |
| GET | `/api/events/:id/summary` | Ringkasan operasional event | Organizer/Admin |
| GET | `/api/events/:id/sales` | Seri tiket/check-in 7 hari | Organizer/Admin |
| GET/POST | `/api/events/:id/members` | Daftar/tambah staf event + izin | Owner |
| PUT | `/api/events/:id/members/:userId/permissions` | Ganti izin staf | Owner |
| DELETE | `/api/events/:id/members/:userId` | Hapus staf | Owner |
| GET/POST | `/api/events/:id/invitations` | Daftar/buat undangan staf | Owner/Admin |
| DELETE | `/api/events/:id/invitations/:invitationId` | Cabut undangan | Owner/Admin |
| POST | `/api/invitations/:token/accept` | Terima undangan (email harus cocok) | Private |
| GET | `/api/invitations/:token` | Pratinjau undangan publik (email disamarkan) | Public |
| GET | `/api/invitations/me` | Undangan pending milik pengguna | Private |
| GET | `/api/me/memberships` | Event yang diikuti pengguna sebagai staf + izinnya | Private |
| GET | `/api/organizer/overview` | Ringkasan event Organizer | Organizer |
| GET | `/api/organizer/events/summaries` | Ringkasan per event Organizer | Organizer |
| GET/PUT | `/api/organizer/profile` | Baca/perbarui profil Organizer login | Organizer |
| PUT | `/api/admin/events/:id/moderation` | Keputusan moderasi atomik dan audit | Admin |
| GET | `/api/admin/accounts` | Daftar akun | Admin |
| GET | `/api/admin/organizers` | Daftar akun Organizer | Admin |
| PUT | `/api/admin/accounts/:id/status` | Aktif/nonaktifkan akun | Admin |
| GET | `/api/admin/audit-logs` | Riwayat audit platform | Admin |
| GET | `/api/admin/settings` | Daftar pengaturan platform | Admin |
| PUT | `/api/admin/settings/:key` | Ubah satu pengaturan platform | Admin |
| GET | `/api/admin/overview` | Ringkasan konsol Admin | Admin |
| GET | `/api/admin/subscriptions` | Langganan seluruh Organizer | Admin |
| POST | `/api/admin/email/retry` | Kirim ulang email tiket yang tertunda | Admin |

### Tickets
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| GET | `/api/tickets/my-tickets` | Tiket milik user login; guest mengirim `order_id` + header `X-Order-Access-Token` | Private/order token |
| GET | `/api/tickets/:id` | Detail tiket milik user login atau `order_id` + header `X-Order-Access-Token` | Private/order token |
| GET | `/api/tickets/:id/pdf` | Unduh e-ticket PDF memakai desain Organizer + QR unik | Pemilik tiket/order token |
| POST | `/api/tickets/:id/email` | Kirim ulang email tiket | Pemilik tiket/order token |
| POST | `/api/tickets/validate` | Validasi QR tanpa mutasi; wajib izin petugas event | Private (staff) |
| POST | `/api/tickets/verify` | Verifikasi QR dan catat check-in (`check_ins` + `scan_logs`) secara atomik; 409 bila sudah dipakai | Private (staff) |

Endpoint legacy `POST /api/tickets` sudah dihapus dari `ticketRoutes.js`; tiket hanya
terbit melalui order yang sudah dibayar.

### Check-in
| Method | Endpoint | Deskripsi | Akses |
|---|---|---|---|
| POST | `/api/check-ins` | Check-in online idempoten (satu check-in per tiket) | Private (staff) |
| GET | `/api/check-ins/events/:eventId/check-ins` | Riwayat check-in event | Private (staff) |
| POST | `/api/check-ins/sync` | Sinkronisasi antrean check-in offline | Private (staff) |
| GET | `/api/events/:eventId/attendees` | Daftar peserta/tiket event | Owner/staff |
| GET | `/api/events/:id/attendees/export` | Export CSV peserta event | Owner/staff dengan izin |
| GET | `/api/events/:id/orders` | Daftar order event | Owner/staff |

### Notifikasi dan laporan dukungan
| Method | Endpoint | Deskripsi | Akses |
|---|---|---|---|
| GET | `/api/notifications` | Daftar notifikasi pengguna (`?unread=true`) | Private |
| POST | `/api/notifications/:id/read` | Tandai satu notifikasi dibaca | Private |
| POST | `/api/notifications/read-all` | Tandai semua notifikasi dibaca | Private |
| GET/POST | `/api/support-reports` | Daftar/buat laporan dukungan | Private |
| GET | `/api/support-reports/:id` | Detail laporan + aktivitas | Pelapor/admin/penanggung jawab |
| PUT/POST | `/api/support-reports/:id/status` | Ubah status | Admin/penanggung jawab |
| PUT/POST | `/api/support-reports/:id/priority` | Ubah prioritas | Admin/penanggung jawab |
| POST | `/api/support-reports/:id/reply` | Balasan publik | Pelapor/admin/penanggung jawab |
| POST | `/api/support-reports/:id/internal-note` | Catatan internal | Admin/penanggung jawab |

### Orders and simulated payments
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/orders` | Buat order dengan harga/kuota hasil validasi database; guest menerima token akses sekali | Public/Participant |
| GET | `/api/orders` | Riwayat order akun login | Private |
| GET | `/api/orders/:id` | Detail order; guest wajib menyertakan header `X-Order-Access-Token` | Owner/guest token |
| GET | `/api/payments/:orderId` | Status VA simulasi; guest wajib menyertakan header `X-Order-Access-Token` | Owner/guest token |
| POST | `/api/payments/simulate` | Simulasikan hasil pembayaran pada lingkungan yang diizinkan | Owner/guest token |

Endpoint simulasi dinonaktifkan secara default. Aktifkan hanya pada environment
non-produksi dengan `SIMULATED_PAYMENTS_ENABLED=true`; simulasi ini bukan
integrasi bank atau payment gateway.

### Plans, subscriptions, dan revenue
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| GET | `/api/plans` | Katalog paket aktif | Public |
| GET | `/api/plans/:id` | Detail paket | Public |
| GET | `/api/plans/admin/all` | Semua paket termasuk nonaktif | Admin |
| POST | `/api/plans/admin` | Buat paket | Admin |
| PUT | `/api/plans/admin/:id` | Ubah paket | Admin |
| DELETE | `/api/plans/admin/:id` | Hapus paket | Admin |
| GET | `/api/subscriptions/me` | Langganan Organizer login | Organizer |
| POST | `/api/subscriptions` | Berlangganan paket | Organizer |
| POST | `/api/subscriptions/cancel` | Batalkan langganan | Organizer |
| GET | `/api/subscriptions/payments` | Riwayat pembayaran langganan | Organizer |
| GET | `/api/revenue/me` | Pendapatan Organizer login | Organizer |
| GET | `/api/revenue/admin/summary` | Ringkasan pendapatan platform | Admin |
| GET | `/api/revenue/admin/transactions` | Daftar transaksi platform | Admin |

## Instalasi

```bash
cd backend
npm install
cp .env.example .env
# Isi DATABASE_URL, DIRECT_URL, JWT_SECRET, dan ALLOWED_ORIGINS.
npx prisma migrate status --schema prisma/schema.prisma
npx prisma validate --schema prisma/schema.prisma
npm run dev
```

Untuk database yang sudah memiliki tabel tetapi belum memiliki riwayat migrasi,
lakukan rekonsiliasi setelah memverifikasi
`prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script`
kosong:

```bash
npx prisma migrate resolve --applied <nama-migration>   # untuk setiap baseline
npx prisma migrate deploy
```

Jangan gunakan `prisma migrate reset` atau `db push` pada database berisi data.

## Roles, akun Admin, dan staf event

1. Isi `DATABASE_URL` (aplikasi) dan `DIRECT_URL` (migrasi) dengan kredensial
   PostgreSQL/Supabase. Jangan menaruh kredensial di Flutter atau repositori.
2. Jalankan `npx prisma migrate deploy` dan pastikan
   `npx prisma migrate status` menyatakan schema up to date.
3. Siapkan akun Admin pertama (tidak ada password default di source code):

   ```bash
   # backend/.env (jangan commit)
   ADMIN_EMAIL=admin@your-domain.test
   ADMIN_PASSWORD=<password kuat minimal 8 karakter>
   ADMIN_NAME=Administrator Platform
   ADMIN_USERNAME=admin
   ADMIN_RESET_PASSWORD=false
   ```

   ```bash
   npm run admin:provision
   ```

   Skrip bersifat idempotent: dijalankan berulang tidak membuat Admin duplikat
   dan tidak mengubah password kecuali `ADMIN_RESET_PASSWORD=true`. Akun
   tersimpan di tabel `profiles` dengan `role = 'admin'` dan hash bcrypt;
   mekanisme login sama dengan `POST /api/auth/login`. `npm start` juga
   menjalankan bootstrap ini bila kedua variabel terisi.

   Bila baris Admin sudah ada tetapi hash tersimpan tidak cocok dengan
   `ADMIN_PASSWORD`, bootstrap melaporkan `PASSWORD_MISMATCH` (login akan 401
   `Invalid credentials`). Selaraskan dengan memutar password sekali:

   ```bash
   # PowerShell
   $env:ADMIN_RESET_PASSWORD='true'; npm run admin:provision; Remove-Item Env:\ADMIN_RESET_PASSWORD
   ```

4. Akun Organizer dibuat lewat `POST /api/auth/register` (role selalu
   organizer). Tidak ada seed akun demo dengan password tetap. Registrasi
   membuat baris `profiles` **dan** `organizer_profiles` dalam satu transaksi;
   bila salah satu gagal, keduanya dibatalkan sehingga tidak ada akun tanpa
   profil Organizer. Akun lama yang terlanjur tanpa profil dapat dirapikan
   dengan `npm run repair:organizer-profiles` (idempotent, tidak menghapus akun).
5. Arahkan Flutter ke API. Tanpa `--dart-define=API_BASE_URL`, default mengikuti
   target: emulator Android `http://10.0.2.2:5000/api`, web/desktop/iOS
   simulator `http://127.0.0.1:5000/api`. Perangkat fisik tetap memerlukan
   `--dart-define=API_BASE_URL=http://<IP-LAN-host>:5000/api`.

Email akun Admin bukan "sertifikat" hak akses: role dibaca ulang dari database
pada setiap request (`authMiddleware`), sehingga perubahan role/disable berlaku
tanpa menunggu token kedaluwarsa. Jangan pernah memberi hak Admin berdasarkan
nama atau email yang dikirim klien.

`/api/auth/register` selalu membuat role organizer; role tidak diterima dari
input publik. Otorisasi event menggunakan role dari database dan `created_by`.
Staf event disimpan di `event_members` beserta izin granular di
`event_member_permissions`; undangan memakai `event_invitations` dengan hash
token dan masa berlaku.

### CORS pada development

`ALLOWED_ORIGINS` tetap menjadi daftar origin utama. Di luar `NODE_ENV=production`,
semua origin loopback (`http://localhost:<port>`, `http://127.0.0.1:<port>`,
`http://[::1]:<port>`) diizinkan otomatis. Ini diperlukan karena
`flutter run -d chrome` memakai port acak; tanpa pengecualian tersebut browser
memblokir seluruh request login/registrasi. Origin non-loopback tetap ditolak
(403), dan pada production hanya `ALLOWED_ORIGINS` yang berlaku.


## Variabel Environment (.env)

| Variabel | Deskripsi | Contoh |
|----------|-----------|--------|
| `PORT` | Port server | `5000` |
| `HOST` | Bind address | `0.0.0.0` |
| `NODE_ENV` | Environment | `development` |
| `DATABASE_URL` | Koneksi aplikasi (pooled) | `postgresql://...` |
| `DIRECT_URL` | Koneksi langsung untuk migrasi | `postgresql://...` |
| `JWT_SECRET` | Secret untuk sign JWT | nilai acak panjang |
| `JWT_EXPIRES_IN` | Masa berlaku token | `7d` |
| `TICKET_TOKEN_SECRET` | Secret HMAC token QR tiket; fallback ke `JWT_SECRET` bila kosong (produksi wajib terpisah) | nilai acak panjang |
| `APP_PUBLIC_URL` | URL publik aplikasi untuk `public_url` event dan tautan tiket | `http://localhost:3000` |
| `ALLOWED_ORIGINS` | Daftar origin CORS dipisah koma | `http://localhost:3000` |
| `CORS_ORIGIN` | Alias lama CORS (kompatibilitas) | `http://localhost:3000` |
| `EMAIL_PROVIDER` | Penyedia aktif: `brevo` (default), `smtp`, `resend` (lama), `none`. Kosong = otomatis (SMTP/Brevo lalu Resend) | `brevo` |
| `SMTP_HOST` | Host SMTP. Brevo: `smtp-relay.brevo.com`. Bila kosong dan `RESEND_API_KEY` juga kosong, email dinonaktifkan (status `PENDING` + alasan) | `smtp-relay.brevo.com` |
| `SMTP_PORT` | Port SMTP (Brevo: `587` STARTTLS, `465` TLS implisit) | `587` |
| `SMTP_SECURE` | Gunakan TLS langsung (port 465) | `false` |
| `SMTP_REQUIRE_TLS` | Wajibkan STARTTLS pada port non-secure (default aktif untuk Brevo) | `true` |
| `SMTP_USER` / `SMTP_PASS` | Kredensial SMTP Brevo: login SMTP (`xxxxx@smtp-brevo.com`) dan **SMTP key**, bukan password akun (hanya di `.env`) | nilai rahasia |
| `SMTP_ALLOW_LOCAL_RELAY` | Izinkan relay lokal tanpa autentikasi (uji) | `false` |
| `RESEND_API_KEY` | Kunci HTTPS API lama; hanya fallback bila SMTP belum dikonfigurasi | nilai rahasia |
| `EMAIL_FROM` | Alamat pengirim terverifikasi (wajib untuk transport nyata) | `no-reply@domain-anda.test` |
| `EMAIL_FROM_NAME` | Nama tampilan pengirim | `E-Ticket Event` |
| `EMAIL_ORGANIZER_FROM_DOMAINS` | Domain penyelenggara yang boleh dipakai sebagai `From` (dipisah koma; harus terverifikasi di penyedia). Kosong = penyelenggara hanya `Reply-To` | `eventku.com` |
| `EMAIL_REPLY_TO_ORGANIZER` | `false` untuk mematikan Reply-To dinamis ke penyelenggara | `true` |
| `EMAIL_RESEND_COOLDOWN_SECONDS` | Jeda minimal kirim ulang eksplisit | `60` |
| `EMAIL_SEND_CLAIM_SECONDS` | Masa klaim anti email ganda | `120` |
| `EMAIL_RETRY_BASE_DELAY_MS` | Jeda dasar backoff retry | `60000` |
| `VERIFY_EMAIL_TO` | Alamat inbox untuk `npm run verify:email` / `npm run verify:brevo` | `inbox-anda@domain.test` |
| `BREVO_API_KEY` | Opsional: API key Brevo untuk membaca event `delivered`/bounce pada `verify:brevo` | nilai rahasia |
| `RATE_LIMIT_WINDOW_MS` | Jendela rate limit | `900000` |
| `RATE_LIMIT_AUTH_MAX` / `RATE_LIMIT_SCAN_MAX` / `RATE_LIMIT_GLOBAL_MAX` | Batas request auth/scan/global per jendela | `20` / `600` / `1200` |
| `MAX_JSON_BODY` | Batas ukuran body JSON | `2mb` |
| `SIMULATED_PAYMENTS_ENABLED` | Aktifkan simulasi pembayaran non-produksi | `false` |
| `ALLOW_DESTRUCTIVE_TESTS` | Izinkan harness integrasi destruktif pada DB uji | `false` |
| `TEST_API_URL` | Base URL API untuk harness integrasi/E2E | `http://127.0.0.1:5000` |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` | Legacy `.env.example`; tidak dipakai backend (koneksi lewat `DATABASE_URL`) | — |
| `ADMIN_EMAIL` | Email akun Admin yang di-bootstrap ke tabel `profiles` | `admin@your-domain.test` |
| `ADMIN_PASSWORD` | Password awal Admin (minimal 8 karakter, hanya di `.env`) | nilai acak kuat |
| `ADMIN_NAME` | Nama tampilan Admin | `Administrator Platform` |
| `ADMIN_USERNAME` | Username login Admin (opsional) | `admin` |
| `ADMIN_RESET_PASSWORD` | Rotasi password Admin yang sudah ada saat bootstrap | `false` |
| `SEED_DEMO_ACCOUNTS` | Legacy; tidak lagi membuat akun dengan password tetap | `false` |

## Database Schema

Sumber kebenaran schema adalah `prisma/schema.prisma` dan migration di
`prisma/migrations/`. Database aktual memiliki 32 tabel aplikasi, 19 enum,
54 foreign key, dan 105 index aplikasi; seluruhnya cocok dengan schema
(`prisma migrate diff` kosong). Gunakan `node scripts/audit-db.js` untuk
memeriksa tabel, kolom, constraint, index, enum, function, RLS, dan riwayat
migrasi. Ringkasan relasi ada di `docs/DATABASE.md`.

Catatan keamanan (verifikasi read-only 23 November 2026, lihat
`../task/DATABASE_AUDIT_FINAL.md` (arsip)): RLS aktif pada **32/32** tabel aplikasi dengan
**0 policy** (deny-by-default untuk akses REST langsung) dan **0 grant** untuk
`anon`/`authenticated`; hanya `service_role` memiliki privilege. Pemilik tabel
adalah `postgres` (juga role koneksi backend), sehingga aktivasi RLS tidak
memutus backend. Otorisasi aplikasi tetap ditegakkan di middleware/controller
backend, bukan oleh RLS.

## Integrasi dengan Flutter (Frontend)

Di Flutter (`apps/lib/`), gunakan `http` untuk memanggil API (base URL diatur lewat
`--dart-define=API_BASE_URL=...`):

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator
// static const String baseUrl = 'http://localhost:5000/api'; // iOS Simulator
// static const String baseUrl = 'https://api-evticket.com/api'; // Production
```

Sertakan header `Authorization: Bearer <token>` untuk endpoint yang memerlukan autentikasi.