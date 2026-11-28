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
- Undangan staf berbasis **nama + kode akses** (mekanisme aktif) memakai
  `invite_url = {APP_PUBLIC_URL}/staff-access/{invitationId}`. Tautan hanya
  mengidentifikasi undangan dan **tidak** memberi akses scanner; kode akses
  wajib dimasukkan pada halaman tersebut dan divalidasi backend.
- Route Flutter `/e/:eventId`, `/e/:eventId/register`, `/e/:eventId/payment/:orderId`,
  `/e/:eventId/ticket/:ticketId`, dan `/registration/:eventId` dapat dibuka guest;
  `/invite/:token` memaksa login lalu kembali ke halaman undangan (alur email
  lama). `/staff-access/:invitationId` dan `/staff-access/scanner` publik di
  router, tetapi halaman scanner menolak tanpa sesi staf yang valid dan backend
  menolak setiap request tanpa sesi.
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
  **`brevo`** (SMTP relay Brevo `smtp-relay.brevo.com` port 587 + STARTTLS,
  penyedia aktif), `smtp` (relay generik), `resend` (jalur HTTPS API lama,
  fallback bila SMTP belum diisi), `json` (hanya `NODE_ENV=test`), atau
  `disabled`. `smtpStatus()` memvalidasi `EMAIL_PROVIDER`, `SMTP_PORT`, pasangan
  `SMTP_USER`/`SMTP_PASS`, `EMAIL_FROM`, dan menolak relay non-loopback tanpa
  kredensial — tanpa mencetak nilai rahasia. Kredensial Brevo (`SMTP_USER` login
  SMTP, `SMTP_PASS` SMTP key) hanya dibaca dari environment.
- Kegagalan transport diklasifikasikan per tahap (`dns`, `connect`, `tls`,
  `auth`, `sender`, `send`) dan saran tindakannya ikut disimpan pada
  `last_error`, sehingga penyebab seperti SMTP key salah atau `EMAIL_FROM` belum
  diverifikasi di Brevo tidak tersembunyi.
- Status pengiriman disimpan di `ticket_email_deliveries` dan dibedakan:
  `PENDING` (belum dikirim/antre), `SENDING` (sedang berjalan), `SENT` (diterima
  transport), `FAILED` (+`last_error`), serta `NOT_CONFIGURED` pada respons API.
  Status pembayaran tidak pernah disamakan dengan status pengiriman email.
- **Anti email ganda lintas proses**: sebelum mengirim, `claimDelivery()`
  mengambil klaim atomik per `(ticket_id, recipient)` lewat satu `UPDATE`
  bersyarat + advisory lock. Baris `SENT` tidak pernah diklaim ulang oleh
  pengiriman otomatis (hanya oleh kirim ulang eksplisit setelah cooldown), baris
  `PENDING` dalam masa klaim (`EMAIL_SEND_CLAIM_SECONDS`, default 120 detik)
  dianggap sedang dikirim. Klaim kedaluwarsa otomatis bila proses berhenti di
  tengah jalan, sehingga worker retry dapat mengambil alih tanpa menggandakan
  email. Baris `SENT` juga tidak pernah diturunkan menjadi `FAILED`.
- Penerima selalu `attendees.email` pada tiket yang bersangkutan; alamat
  penyelenggara diambil dari `events.created_by` → `profiles.email`. `From`
  memakai alamat penyelenggara hanya bila diizinkan penyedia (sama dengan
  `SMTP_USER`/`EMAIL_FROM`, atau domainnya ada di
  `EMAIL_ORGANIZER_FROM_DOMAINS`); selain itu `From` = `EMAIL_FROM` terverifikasi
  dan penyelenggara menjadi `Reply-To`. Tidak ada kredensial email pribadi
  penyelenggara yang disimpan.
- Lampiran PDF memakai desain & orientasi tiket. Retry memakai backoff
  (`EMAIL_RETRY_BASE_DELAY_MS` × nomor percobaan), dibatasi 5 percobaan
  otomatis, menghormati `next_attempt_at`, dan tersedia lewat worker periodik,
  `POST /api/admin/email/retry`, `POST /api/tickets/:id/email`, dan
  `npm run retry:emails` — tanpa membuat tiket/transaksi baru.
- Tombol kirim ulang memakai jalur eksplisit (`force`): mengirim ulang tiket
  yang sama (nomor tiket & PDF tidak berubah) dengan cooldown
  `EMAIL_RESEND_COOLDOWN_SECONDS`; kegagalan kirim ulang tidak menurunkan status
  `SENT` yang sudah ada. `DELIVERED` tidak pernah diklaim karena tidak ada bukti
  inbox.

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
| Staff | undang oleh Organizer (nama) → kode akses unik → buka tautan undangan → masukkan kode akses → scanner event itu → check-in → riwayat |
| Admin | login hasil provisioning → akun/suspend + audit → settings + history → overview/revenue/paket/langganan → moderasi event |

**QR, check-in, dan token**

QR memuat token opaque hasil HMAC (`ticketTokenService`); database hanya
menyimpan `token_hash`. Validasi dan check-in bersifat server-authoritative:
`VALID`, `ALREADY_USED`, `WRONG_EVENT`, `PAYMENT_REQUIRED`, `CANCELLED`,
`REVOKED`. Check-in menulis satu baris `check_ins` + `scan_logs` dalam satu
transaksi; percobaan kedua tidak menambah baris.

**E-tiket PDF**

Satu renderer (`ticketDesignService.buildTicketPdf` → `ticketPdfRenderer`) melayani
unduhan manual (`GET /api/tickets/:id/pdf`) dan lampiran email
(`emailService.buildPdfAttachment`), untuk event gratis maupun berbayar. Kanvas
tetap per orientasi (`landscape` 842 × 594 pt, `portrait` 440 × 704 pt) sehingga
satu sistem koordinat dipakai editor, pratinjau, template, dan PDF.

Sumber kebenaran geometri adalah `ticketDesignLayout`:

- setiap elemen (`title`, `ticket_id`, `instruction`, `qr`) disimpan sebagai
  fraksi kanvas 0..1 + ukuran huruf **pt kanvas** di `ticket_design.layout`;
- `resolveLayout()` menghitung bounding box tiap elemen (pembungkusan teks,
  penurunan ukuran huruf proporsional, dan pemotongan elipsis sebagai upaya
  terakhir) sehingga editor dan renderer memakai perhitungan yang sama;
- `findOverlaps()`/`validateLayout()` mendeteksi elemen bertumpuk dan elemen di
  luar kanvas; endpoint simpan **menolak** konfigurasi yang bertabrakan sehingga
  PDF tidak pernah memuat tulisan yang tertutup QR Code.

Nilai default (diukur dari `docs/references/desain_tiket_referensi.png`):
judul `E-TIKET [NAMA ACARA]` Times New Roman Bold 50 pt di kiri 4,45%/atas
2,86%; `ID TIKET: ...` 30 pt regular di atas 14,70%; instruksi penukaran 30 pt
regular di atas 21,65%; QR Code x 5,95%, y 32,60%, sisi 42,31% tinggi kanvas;
pembagian panel pink/krem 55,8% lebar kanvas. Hanya tiga teks dinamis itu yang
dicetak (nama peserta, kategori, jadwal, dan lokasi tidak dicetak) agar tata
letak sesuai referensi.

Font ditangani `ticketFontService`: berkas TTF Times New Roman (env
`TICKET_FONT_REGULAR`/`TICKET_FONT_BOLD`, aset `backend/assets/fonts/`, atau font
sistem) didaftarkan ke PDFKit sehingga **tertanam** di PDF; bila tidak tersedia,
dipakai base-14 `Times-Roman`/`Times-Bold` yang metriknya identik agar tata letak
tidak bergeser. Berkas TTF tidak di-commit karena berlisensi Microsoft.

Posisi & ukuran elemen diatur Organizer lewat
`PUT /api/events/:id/ticket-design` dengan `layout_only: true` (tanpa unggah
ulang berkas; juga berlaku saat belum ada berkas desain). Desain dipilih dengan
urutan kategori → event → default sistem; kandidat yang filenya hilang dilewati
agar desain unggahan tidak tergantikan desain default. Desain kustom digambar
`contain` sehingga rasio asli terjaga. ID publik tiket `ETK-XXXXXX` disimpan pada
`tickets.ticket_code` (kolom unik yang sudah ada) sementara `tickets.id` tetap
primary key, sehingga tidak ada perubahan schema; kode lama `TKT-<uuid>` tetap
dapat divalidasi lewat `tickets.qr_code_data`. Nama lampiran/unduhan mengikuti
`E-TIKET Nama Peserta.pdf` dari `attendees.name`.

Editor Flutter (`TicketDesignPanel` + `TicketCanvasPreview`) memakai cermin
perhitungan yang sama (`apps/lib/models/ticket_layout_model.dart`): pratinjau
menggambar teks pada ukuran pt, QR pada kotak hasil `resolve()`, bounding box
setiap elemen, penanda merah untuk elemen bertabrakan, slider posisi, input
angka untuk ukuran huruf (pt), dan tombol reset ke default. Validasi klien dan server identik, sehingga konfigurasi
yang terlihat benar di editor juga benar di PDF.

**Undangan staf berbasis nama + kode akses**

- Organizer hanya memasukkan **nama staf**. Backend (`staffInvitationController`)
  membuat kode akses 8 karakter dari alfabet tanpa karakter ambigu
  (`0/O/1/I/L`), lalu menyimpannya sebagai:
  - `event_invitations.access_code_hash` — SHA-256 untuk verifikasi
    constant-time, dengan **indeks unik global** sehingga dua staf (pada event
    yang sama maupun berbeda) tidak mungkin berbagi kode;
  - `event_invitations.access_code_cipher` — ciphertext AES-256-GCM
    (`STAFF_ACCESS_SECRET`) agar Organizer dapat menampilkan kembali kode milik
    event-nya tanpa menyimpan plaintext.
- `event_invitations.staff_name` menyimpan nama staf; `email` menjadi nullable
  karena staf tidak wajib punya akun. Undangan lama (email-based) tetap valid,
  dan dapat dimigrasikan dengan menekan "Buat Kode Baru" (regenerate).
- Tautan `/staff-access/{invitationId}` hanya membuka halaman autentikasi.
  `POST /api/staff-access/validate` memeriksa hash kode, status undangan
  (`PENDING`/`ACCEPTED`, bukan `REVOKED`), masa berlaku, dan event undangan,
  lalu menerbitkan JWT sesi staf (`typ: staff_access`, `sid`, `event_id`) dengan
  masa berlaku `STAFF_SESSION_TTL`.
- `staffAuthMiddleware` memverifikasi token dan **memuat ulang undangan** pada
  setiap request, sehingga pencabutan/kedaluwarsa langsung berlaku. Token dikirim
  lewat header `X-Staff-Session` (dipisah dari `Authorization` akun) dan dapat
  dicabut melalui `revoked_tokens` saat logout.
- `assertScanPermission`/`assertMemberPermission` menerima sesi staf hanya bila
  `event_id` token sama dengan event yang diakses (tidak ada akses lintas event)
  dan undangan memiliki permission yang diminta (`SCAN_TICKET`,
  `CHECK_IN_TICKET`, dst.). Endpoint `/api/tickets/validate`, `/api/tickets/verify`,
  `/api/check-ins*`, dan daftar peserta memakai `staffOrUserAuth` sehingga JWT
  Organizer/Admin tetap berjalan seperti sebelumnya.
- Check-in oleh staf tanpa akun dicatat pada `check_ins.staff_invitation_id`
  (kolom baru) sementara `actor_user_id` boleh `NULL`; riwayat menampilkan nama
  staf dari undangan.

**Keputusan produk yang ditegakkan**

- C-01: komisi 5% dan fixed fee Rp 5.000 read-only bagi Admin (audit dicatat).
- C-02: publikasi event otomatis saat valid; tidak ada approval manual Admin.
- C-03: pengelolaan langganan Admin bersifat read-only.


## Alur kerja

1. Baca `AGENTS.md`, PRD, README dan modul terdampak. Periksa status/diff Git.
2. Hindari perubahan bisnis, database dan dependency saat tugas hanya tooling.
   Developer 1–3 tidak mengubah atau menjalankan perubahan DB; proposal kebutuhan
   database diserahkan kepada FINISHING sesuai aturan di `AGENTS.md` (folder `task/`
   bersifat arsip, tidak dibaca default).
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
