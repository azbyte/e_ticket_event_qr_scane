# Arsitektur dan panduan pengembangan

## Kondisi aktual

Repository berisi aplikasi Flutter di `apps/` dan API Node.js di `backend/`.
Flutter menargetkan Android/Web, menggunakan Provider, HTTP, secure storage, dan
API backend secara default (`MOCK_MODE=true` untuk demo/mock eksplisit). Backend
menggunakan JavaScript CommonJS, Express 4, JWT, koneksi PostgreSQL langsung
(`pg`), validasi `express-validator`, serta QR generator. Struktur backend aktual
berada di `backend/src/{config,controllers,middleware,models,routes,services,utils,validators}`.

Alur umum API adalah routes → middleware (auth/role/validation) → controllers →
services/models → PostgreSQL (`src/config/db.js`). Sumber schema yang ditetapkan
adalah `backend/prisma/schema.prisma`, dan migration Prisma berada di
`backend/prisma/migrations/`. SQL legacy berada di
`backend/prisma/legacy-migrations/` — di luar `migrations/` karena Prisma
memperlakukan setiap subfolder `migrations/` sebagai migration yang dijalankan.
SQL legacy dipertahankan untuk fungsi/riwayat tertentu; ini bukan baseline schema
pengganti dan tidak boleh dijalankan/dihapus tanpa rekonsiliasi serta otorisasi
FINISHING. Saat diperlukan, dokumentasikan fungsi/status migration legacy
berdasarkan pemeriksaan yang aman. Verifikasi schema lokal dengan `node
backend/scripts/audit-db.js` dan `npx prisma migrate status`. README backend
memuat ringkasan endpoint; kode dan migration tetap menjadi sumber kebenaran.

Flutter mengorganisasi kode di `apps/lib/` menjadi `core`, `features`, `models`,
`providers`, dan `services`. UI menggunakan tema/material yang telah ada.
Mode demo dan API tetap terpisah. Tidak semua modul saat ini sudah memiliki
endpoint backend; API mode harus menampilkan error, bukan memakai data mock
sebagai fallback.

### Lifecycle event dan tautan publik (Tahap 2, Developer 1)

- Publikasi event tidak lagi menunggu approval Admin. `POST /api/events/:id/publish`
  (alias `POST /api/events/:id/submit-review`) memvalidasi event + kategori tiket
  lewat `backend/src/utils/eventValidation.js`; hasil valid menetapkan
  `status = PUBLISHED`, `is_public = true`, `submitted_at`, dan `public_url`.
  Hasil tidak valid mempertahankan `DRAFT`, `is_public = false`, dan menyimpan
  alasan pada `review_note` (dikembalikan sebagai `validation_errors`).
- `public_url` hanya terisi untuk event `PUBLISHED` (atau `APPROVED` legacy) dan
  `is_public = true`; `APP_PUBLIC_URL` menjadi basis tautan `/e/{eventId}`.
- Undangan panitia memakai `invite_url = {APP_PUBLIC_URL}/invite/{rawToken}`,
  terpisah dari tautan pendaftaran publik.
- Route Flutter `/e/:eventId`, `/e/:eventId/register`, `/e/:eventId/payment/:orderId`,
  `/e/:eventId/ticket/:ticketId`, dan `/registration/:eventId` dapat dibuka guest;
  `/invite/:token` memaksa login lalu kembali ke halaman undangan.
- `attendee_fields` event berbentuk array objek
  `{ key, label, type, required, options }` (kompatibel array string legacy) dan
  jawaban peserta disimpan pada `attendees.custom_fields` dalam transaksi order
  yang sama.

### Integrasi Tahap 3 (Developer 1 – FASE 2)

Bagian ini merangkum hasil integrasi lintas modul yang sudah diverifikasi
terhadap API + PostgreSQL nyata (`cd backend; npm run test:e2e`, 80 pemeriksaan).

**Routing dan guard Flutter (`apps/lib/app_router.dart`)**

- `/organizer/events/:id/attendees` meneruskan `eventId` nyata (sebelumnya
  `const AttendeeListScreen()` tanpa event).
- `/organizer/events/:id/orders` tersedia dan meneruskan `eventId`.
- `/staff/scanner` dan `/staff/check-ins` membuka layar scanner/riwayat dengan
  `eventId` bila argumen tersedia; tanpa argumen diarahkan ke dashboard staf
  (pemilihan event), bukan lagi ke dashboard tanpa scanner.
- Konteks membership Organizer berasal dari identitas sesi (`AuthProvider`);
  tidak ada lagi `evt-1001`/`usr-org-001` hardcoded di router. Permission tetap
  divalidasi server (`POST /api/tickets/validate`, `POST /api/check-ins`).

**Navigasi Organizer (`features/organizer/shell/organizer_shell.dart`)**

- Navigasi utama tepat tiga tujuan: Dashboard (`/organizer`), Scan QR
  (`/organizer/scan`), dan Profil (`/organizer/profile`). Mobile memakai
  `NavigationBar`; Web/desktop memakai sidebar dengan tujuan yang sama. Drawer
  dan avatar profil pada AppBar dihapus, ikon notifikasi dipertahankan.
- `/organizer/scan` menampilkan daftar event milik Organizer dari repository
  backend sebagai titik masuk kamera pemindai; validasi tiket tetap dilakukan
  per event di server (`POST /api/tickets/validate`, `POST /api/check-ins`).
- Halaman turunan (Event Saya, detail event, Tim & Staf, Paket, Bantuan) tidak
  menampilkan bottom navigation dan kembali melalui tombol kembali. Akses Tim &
  Staf berada pada detail event, sedangkan Paket dan Bantuan berada pada tab
  Profil.
- `OrganizerTabController` kini hanya meneruskan ke
  `OrganizerDashboardScreen` agar tidak ada bottom navigation kedua yang
  tumpang tindih.

**Form peserta dinamis**

- `AttendeeFieldBuilder` (`features/organizer/events/widgets/`) menyediakan
  tambah/ubah/hapus/urutkan field, tipe
  `text|textarea|number|date|select|checkbox`, penanda wajib, dan opsi `select`.
- `name` dan `email` bersifat wajib dan tidak dapat dihapus karena keduanya
  kolom tabel `attendees` dan divalidasi server
  (`REQUIRED_ATTENDEE_FIELD_KEYS`).
- Event lama yang hanya menyimpan array string tetap dapat dibuka: fallback
  `OrganizerAttendeeDefaults` menyertakan `name` + `email`.
- Form publik (`public_registration_screen.dart`) merender semua tipe dan
  server mengulang validasi wajib/tipe/opsi sebelum order dibuat.

**Pengiriman e-ticket (PDF) melalui email**

- Tiket terbit di dalam transaksi order/pembayaran; pengiriman email
  **dijadwalkan**, bukan ditunggu. `src/services/emailQueue.js` menjalankan
  pengiriman pada tick berikutnya (`setImmediate`) dengan penjaga in-flight per
  tiket sehingga respons pendaftaran/pembayaran tidak bergantung pada kecepatan
  SMTP dan tidak ada email ganda. Tidak ada dependensi runtime baru.
- `src/services/emailService.js` menentukan transport dari environment:
  `smtp` (host nyata + konfigurasi valid), `json` (hanya `NODE_ENV=test`), atau
  `disabled`. `smtpStatus()` memvalidasi `SMTP_PORT`, pasangan
  `SMTP_USER`/`SMTP_PASS`, dan `EMAIL_FROM` tanpa mencetak nilai rahasia.
- Status pengiriman disimpan di `ticket_email_deliveries` dan dibedakan:
  `PENDING` (belum dikirim/antre), `SENDING` (sedang berjalan), `SENT` (diterima
  transport), `FAILED` (+`last_error`), serta `NOT_CONFIGURED` pada respons API.
  Status pembayaran tidak pernah disamakan dengan status pengiriman email.
- Penerima selalu `attendees.email` pada tiket yang bersangkutan; lampiran PDF
  memakai desain & orientasi tiket. Retry dibatasi 5 percobaan otomatis,
  menghormati `next_attempt_at`, dan tersedia lewat worker periodik,
  `POST /api/admin/email/retry`, `POST /api/tickets/:id/email`, dan
  `npm run retry:emails` — tanpa membuat tiket/transaksi baru.

**Backend (perbaikan integrasi)**

- `checkInController.assertScanPermission` tidak lagi memilih
  `event_members.status` (kolom tidak ada) — sebelumnya seluruh scan/check-in
  gagal 500.
- Query daftar peserta/export CSV tidak lagi memakai `profiles.phone` serta
  meng-cast `event_orders.status::text` agar `UNION` enum/text valid.
- `verifyTicketValidator` menerima `token` (scanner kamera) maupun `ticket_code`
  (input manual); sebelumnya hanya `ticket_code` sehingga semua scan ditolak 400.
- `updateAccountStatus` menerima `is_active` (dipakai layar Admin), `disabled`,
  dan `status`; respons akun menyertakan `is_active`.
- `moderateEvent` memetakan keputusan `PUBLISHED` ke `APPROVED` agar Admin dapat
  memulihkan event yang ditangguhkan melalui fungsi DB `moderate_event`.

**Alur per role (ringkas)**

| Role | Alur |
|---|---|
| Organizer | register/login → event → kategori tiket → publish otomatis → tautan publik/QR → peserta → export CSV → order per event → revenue → staff/membership |
| Guest | `/e/:eventId` → daftar (field dinamis) → order 1 tiket → bayar simulasi/gratis → tiket + QR |
| Staff | undang oleh Organizer → login email cocok → terima undangan → scanner → check-in → riwayat |
| Admin | login hasil provisioning → akun/suspend + audit → settings + history → overview/revenue/paket/langganan → moderasi event |

**QR, check-in, dan token**

QR memuat token opaque hasil HMAC (`ticketTokenService`); database hanya
menyimpan `token_hash`. Validasi dan check-in bersifat server-authoritative:
`VALID`, `ALREADY_USED`, `WRONG_EVENT`, `PAYMENT_REQUIRED`, `CANCELLED`,
`REVOKED`. Check-in menulis satu baris `check_ins` + `scan_logs` dalam satu
transaksi; percobaan kedua tidak menambah baris.

**Keputusan produk yang ditegakkan**

- C-01: komisi 5% dan fixed fee Rp 5.000 read-only bagi Admin (audit dicatat).
- C-02: publikasi event otomatis saat valid; tidak ada approval manual Admin.
- C-03: pengelolaan langganan Admin bersifat read-only.


## Alur kerja

1. Baca `AGENTS.md`, PRD, README dan modul terdampak. Periksa status/diff Git.
2. Hindari perubahan bisnis, database dan dependency saat tugas hanya tooling.
   Developer 1–3 tidak mengubah atau menjalankan perubahan DB; proposal kebutuhan
   database diserahkan kepada FINISHING sesuai `task/FINISHING_AUTHORITY.md`.
3. Gunakan fixtures sintetis; jalankan test demo dengan
   `flutter test --dart-define=MOCK_MODE=true`. Tes API tanpa fallback dijalankan
   dengan `flutter test test/services/api_mode_no_fallback_test.dart
   --dart-define=MOCK_MODE=false`. Tidak perlu Supabase untuk unit/widget test.
4. Frontend, dari `apps/`: `flutter pub get`, `flutter analyze`, `flutter test`.
5. Backend, dari `backend/`: `npm ci`, `npm test`,
   `npm run test:sync-config`,
   `npm run check`, `npm run format:check`, `npm run validate:skills`.
6. Tinjau diff, periksa secret dan dokumentasi, catat hasil/batasan.

Git hook `.githooks/pre-push` dapat diaktifkan per clone dengan
`git config core.hooksPath .githooks`. Hook menjalankan seluruh pemeriksaan kode
sebelum push dan memerlukan dependency lokal yang telah disiapkan. GitHub Actions
menjalankan quality workflow pada semua push dan pull request; maintainer harus
menjadikan status `PR Quality Gate` required melalui branch protection/ruleset
agar kegagalan memblokir merge. Konflik sinkronisasi branch dilaporkan dengan
daftar file dan instruksi resolusi pada ringkasan job.

`npm run lint` adalah alias kompatibilitas untuk `npm run check` dan tidak
dijalankan terpisah oleh CI. `npm run format:check` memeriksa trailing
whitespace dan JSON, bukan formatter penuh. `npm run validate:skills` memeriksa
frontmatter, nama skill unik, dan target link relatif pada katalog/skill.
ESLint/Prettier belum dipasang: instalasi dicoba tetapi registry npm tidak
tersedia pada sesi audit.

## UI quality

Gunakan design tokens/theme dan widgets proyek sebelum menambah komponen baru.
Periksa Android/web layout sempit dan lebar, teks panjang, fokus/keyboard,
semantics/label, kontras, serta loading/error/empty/success state. Belum ada
visual regression runner atau audit accessibility otomatis yang dikonfigurasi.

## Batas integrasi dan keamanan

Supabase, kamera scanner, payment, autentikasi provider, API end-to-end dan
deployment memerlukan konfigurasi/layanan yang tidak disediakan untuk test lokal.
Jangan mengekspos `SUPABASE_SERVICE_ROLE_KEY` atau `JWT_SECRET` ke Flutter.
Otorisasi harus ditegakkan di server; role UI bukan boundary keamanan.
