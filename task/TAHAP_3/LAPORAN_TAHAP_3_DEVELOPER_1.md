# Laporan Tahap 3 — Developer 1 (FASE 2, Finalisasi & Audit)

- **Status:** SELESAI — aplikasi **SIAP DEMO** (lihat §E).
- **Peran:** Developer 1 — integrator & penyelesai akhir aplikasi.
- **Tanggal:** 2026-11-25.
- **Baseline:** `33df04e` (merge PR #43 Developer-2 + #44 Developer-3).
- **Acuan:** `PRD.md` v2.2, `task/TAHAP_3/TUGAS_DEVELOPER_1.md`,
  `task/TAHAP_3/INTEGRATION_CONTRACT.md`,
  `task/TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`.

> Semua status di laporan ini punya bukti perintah. Perintah yang tidak dapat
> dijalankan di environment ini ditandai `NOT RUN` dengan alasan konkret.

---

## A. Penyelesaian Developer 1 Tahap 3

| Task | Cakupan | Status | File utama |
|---|---|---|---|
| T3-D1-01 | Intake FASE 1 & baseline integrasi | PASS | verifikasi branch + test (lihat §D) |
| T3-D1-02 | Routing, guard, navigasi, shell | PASS | `apps/lib/app_router.dart`, `apps/lib/routes/app_routes.dart` |
| T3-D1-03 | Public event & guest journey E2E | PASS | `backend/scripts/e2e-live.js` (alur guest), `apps/lib/features/public_event/**` |
| T3-D1-04 | Event lifecycle, form dinamis, publish | PASS | `apps/lib/features/organizer/events/widgets/attendee_field_builder.dart` (baru), `apps/lib/features/organizer/screens/event_form_screen.dart`, `organizer_event_contract.dart`, `organizer_event_validators.dart`, `api_organizer_event_repository.dart` |
| T3-D1-05 | Backend integrasi lintas modul | PASS | `backend/src/controllers/adminController.js`, `checkInController.js`, `eventMetricsController.js`, `backend/src/validators/ticketValidator.js`, `backend/.env.example` |
| T3-D1-06 | Perbaikan bug lintas modul | PASS | 9 bug ditutup + 10 test regresi (lihat §C) |
| T3-D1-07 | Audit & pembersihan file | SEBAGIAN | lihat §C.4 (kandidat hapus diverifikasi, tidak dihapus yang masih dipakai) |
| T3-D1-08 | Dokumentasi & runbook | PASS | `README.md`, `docs/ARCHITECTURE.md`, `task/RUNBOOK_OPERASIONAL.md` (baru), `backend/.env.example` |
| T3-D1-09 | Verifikasi menyeluruh & uji manual | PASS (dengan `NOT RUN` tercatat) | `backend/scripts/e2e-live.js` (baru), `scripts/serve-web.js` (baru) |
| T3-D1-10 | Final acceptance & laporan | PASS | `task/TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md` (77 baris terisi), laporan ini |

### A.1 Detail T3-D1-02 — routing

Defect yang diperbaiki (semua diberi test regresi di
`apps/test/app_router_test.dart`):

| ID gap | Sebelum | Sesudah |
|---|---|---|
| D1-G1 | `const AttendeeListScreen()` tanpa `eventId` | `AttendeeListScreen(eventId: parts[2])` |
| D1-G2 | `/staff/scanner`, `/staff/check-ins` → `StaffDashboardScreen` | `ScannerScreen(eventId:)` / `CheckInHistoryScreen(eventId:)` bila `eventId` tersedia; tanpa `eventId` → dashboard (pemilihan event) |
| D1-G3 | Tidak ada route order Organizer | `/organizer/events/:id/orders` → `OrganizerOrderListScreen(eventId:)` |
| — | `/organizer/team` default `evt-1001` | default string kosong + `eventTitle` netral |
| — | `OrganizerMembershipContext.owner(userId: 'usr-org-001')` | identitas dari `AuthProvider` (`_authUserId`/`_authUserName`), dapat ditimpa argumen route |
| — | `AppRoutes.organizerOrders` belum ada | konstanta + helper path (`organizerEventOrdersPath`, `organizerEventAttendeesPath`, `organizerEventScannerPath`, `organizerEventStaffPath`, `organizerEventEditPath`) |

Kriteria K1–K7 terpenuhi: guest dapat membuka `/e/:eventId`; `/admin/**` dan
`/organizer/**` menolak role lain; scanner staf menerima event benar; daftar
peserta & order memakai `eventId` nyata; tidak ada `evt-1001`/`usr-org-001`
di router (diverifikasi grep).

### A.2 Detail T3-D1-04 — form dinamis

- `AttendeeFieldBuilder`: tambah/ubah/hapus/urutkan field; tipe
  `text|textarea|number|date|select|checkbox`; `required`; `options` untuk
  `select`; validasi kunci unik, tidak kosong, dan format `^[a-z][a-z0-9_]{0,39}$`.
- `name` + `email` bersifat *locked* (tidak dapat dihapus) karena keduanya kolom
  wajib tabel `attendees` dan divalidasi server
  (`REQUIRED_ATTENDEE_FIELD_KEYS` di `backend/src/utils/eventValidation.js`).
- `OrganizerEventDraft.attendeeFieldDefinitions` baru; payload API mengirim
  array objek (`toJson()`), kompatibel dengan format string legacy.
- `OrganizerEventValidators.validateEventDraft` kini memeriksa: kunci unik,
  label tidak kosong, tipe didukung, `select` minimal 2 opsi, dan keberadaan
  `name`+`email`.
- Fallback `OrganizerAttendeeDefaults` (di `attendee_field_definition.dart`)
  menjaga event lama berbasis array string tetap dapat dibuka dan disimpan.

### A.3 Detail T3-D1-05 — backend

| Perubahan | File | Alasan |
|---|---|---|
| `assertScanPermission` tidak lagi `SELECT ... status FROM event_members` | `checkInController.js` | kolom tidak ada → 500 pada semua scan/check-in |
| `COALESCE(a.phone, p.phone)` → `a.phone` | `checkInController.js` | `profiles` tidak punya kolom `phone` → 500 daftar peserta & export |
| `eo.status AS order_status` → `eo.status::text` | `checkInController.js` | `UNION` enum `OrderStatus` vs `text` gagal (42804) |
| `verifyTicketValidator` menerima `token` **atau** `ticket_code` | `validators/ticketValidator.js` | scanner kamera mengirim `token`; sebelumnya semua scan 400 |
| `updateAccountStatus` menerima `is_active`/`disabled`/`status`; respons + daftar akun menyertakan `is_active` | `adminController.js` | layar Admin mengirim `is_active`; sebelumnya suspend "sukses" tapi tidak mengubah apa pun |
| `moderateEvent` memetakan `PUBLISHED` → `APPROVED` | `eventMetricsController.js` | fungsi DB `moderate_event` hanya mengenal `APPROVED`; restore event selalu 400 |
| `APP_PUBLIC_URL`, `SIMULATED_PAYMENTS_ENABLED`, `SMTP_HOST`, `RATE_LIMIT_AUTH_MAX` didokumentasikan | `.env.example` | konfigurasi demo tanpa nilai secret |

---

## B. Status seluruh Tahap 3

| Developer | Lingkup | Status D2/D3 (klaim) | Hasil verifikasi D1 | Catatan |
|---|---|---|---|---|
| **Developer 1** | Integrasi, routing, form dinamis, backend lintas modul, audit, dokumentasi, acceptance | — | **SELESAI** | 9 bug ditutup, 10 test regresi ditambah, 80/80 e2e lulus |
| **Developer 2** | Tiket/QR, invitation/membership, scanner, check-in, riwayat | DONE | **TERVERIFIKASI** setelah 3 perbaikan | Endpoint scanner/check-in awalnya 500/400 (BUG-01, BUG-02) — lihat §C |
| **Developer 3** | Peserta/export, order/revenue Organizer, konsol Admin | DONE | **TERVERIFIKASI** setelah 4 perbaikan | Endpoint peserta/export 500 (BUG-05), suspend akun tidak berefek (BUG-04), restore event 400 (BUG-03) |

**Verifikasi integrasi antarmodul (bukti: `npm run test:e2e`, 80/80 PASS):**

| Integrasi | Bukti |
|---|---|
| Organizer → Event → Guest (tautan publik) | A-04, A-06, A-07 |
| Guest → Order → Payment → Tiket → QR | E2E-06, E2E-07, E2E-08a/b, A-37 |
| Organizer → Invitation → Staff → Membership | E2E-09, E2E-09b, E2E-10, A-45 |
| Staff → Scanner → Check-in → Riwayat | E2E-11, E2E-12, E2E-13, B-09 |
| Order → Peserta → Export CSV → Order per event → Revenue | A-13, A-14, A-15, A-16, E2E-17 |
| Admin → Akun → Suspend → Audit | A-59, A-60, A-61, E2E-18e |
| Admin → Settings → History | A-63, A-65 |
| Admin → Moderasi → Hilang publik → Order ditolak → Restore | A-71, A-72, A-73, A-74 |
| Frontend → API → PostgreSQL | Semua di atas + `npm run verify:db-schema` PASS |

**Pekerjaan yang diperbaiki di luar lingkup D1 murni** (semua karena menjadi
blocker alur demo, dan semuanya diberi test regresi):

1. `checkInController.js` — 3 perbaikan query/permission (BUG-01, BUG-05).
2. `adminController.js` — kontrak status akun (BUG-04).
3. `eventMetricsController.js` — pemetaan keputusan moderasi (BUG-03).
4. `validators/ticketValidator.js` — payload scan (BUG-02).

Tidak ada hasil kerja D2/D3 yang dihapus atau ditulis ulang; perubahan bersifat
aditif/perbaikan pada lapisan yang salah.

---

## C. Hasil audit aplikasi

### C.1 Temuan awal

Audit dilakukan dengan **menjalankan aplikasi sungguhan** (backend `npm start` +
PostgreSQL Supabase), bukan hanya membaca test. Kondisi awal repo:
`npm test` 172 PASS, `flutter analyze` 0 issue, `flutter test` 255 PASS — namun
**belum ada bukti alur nyata** terhadap database.

### C.2 Bug yang ditemukan dan diperbaiki

| ID | Gejala (reproduksi) | Akar masalah | Perbaikan | Bukti setelah |
|---|---|---|---|---|
| BUG-01 | `POST /api/tickets/validate` & `/api/check-ins` → 500 `column "status" does not exist` | `assertScanPermission` memilih `status` dari `event_members` yang tidak punya kolom itu | hapus seleksi/pengecekan `status`; keberadaan baris = staf aktif | E2E-11, E2E-12, B-09 PASS |
| BUG-02 | Semua scan kamera → 400 sebelum logika validasi | `verifyTicketValidator` hanya mewajibkan `ticket_code`, scanner mengirim `token` | validator menerima `token` atau `ticket_code` | E2E-11b, N-05 PASS |
| BUG-03 | Admin restore event tersuspend → 400 | `moderateEvent` meneruskan `PUBLISHED` ke fungsi DB yang hanya mengenal `APPROVED` | petakan `PUBLISHED`→`APPROVED` | A-74 PASS |
| BUG-04 | "Suspend akun" sukses tapi akun tetap aktif; `audit_logs` kosong | klien mengirim `is_active`, server membaca `req.body.disabled` | dukung `is_active`/`disabled`/`status`; respons + daftar menyertakan `is_active` | A-60, A-61, E2E-18e PASS |
| BUG-05 | `GET /api/events/:id/attendees` & `/attendees/export` → 500 | (a) `profiles.phone` tidak ada; (b) `UNION` enum `OrderStatus` vs `text` | pakai `a.phone`; cast `eo.status::text` | A-13, A-14, A-15 PASS |
| BUG-06 | `/organizer/events/:id/attendees` menampilkan daftar tanpa event | router membuat `const AttendeeListScreen()` | teruskan `eventId` | test router D1-G1 PASS |
| BUG-07 | `/staff/scanner` membuka dashboard, bukan scanner | router mengarahkan 5 route staf ke dashboard | arahkan ke `ScannerScreen`/`CheckInHistoryScreen` | test router D1-G2 PASS |
| BUG-08 | Form event hanya punya 4 checkbox field legacy | belum ada builder field bertipe | tambah `AttendeeFieldBuilder` + kontrak bertipe | 5 widget test PASS |
| BUG-09 | Draft event lama (array string) gagal disimpan setelah validasi field baru | fallback definisi tidak menyertakan `email` | `OrganizerAttendeeDefaults` + merge di `resolvedAttendeeFields` | `flutter test` 265 PASS |

### C.3 Masalah lain yang ditemukan & ditangani

- **Konfigurasi demo tidak terdokumentasi**: `SIMULATED_PAYMENTS_ENABLED` dan
  `APP_PUBLIC_URL` tidak ada di `.env.example`, sehingga pembayaran simulasi
  mengembalikan 404 dan tautan publik menunjuk host backend. Ditambahkan ke
  `.env.example` + README.
- **Port 3000 pada mesin dev dipakai layanan VPN.** Didokumentasikan; demo
  memakai `3100` dengan CORS dan `APP_PUBLIC_URL` disesuaikan.
- **Rate limit auth** memblokir e2e (429). `RATE_LIMIT_AUTH_MAX` kini
  terdokumentasi dan dapat dinaikkan pada environment uji.

### C.4 T3-D1-07 — audit file (status: SEBAGIAN, dengan alasan)

Kandidat yang diperiksa: `backend/src/models/{Event,Ticket,User}.js`,
`backend/src/config/supabase.js`, dependency `@supabase/supabase-js`,
`OrganizerQrPlaceholder`, mock data di service Admin/Plans, method mati di
`OrganizerOperationsRepository`.

**Keputusan: tidak ada penghapusan pada sesi ini.** Alasan:

1. `OrganizerQrPlaceholder` masih dirender `organizer_event_detail_screen.dart`
   untuk event yang belum tayang — sesuai aturan PRD "bila draft → placeholder
   status, bukan QR palsu". QR nyata ditampilkan pada kartu tautan publik.
2. Mock Admin/Plans sudah dipindahkan D3 ke endpoint nyata dan hanya aktif saat
   `MOCK_MODE=true`; menghapusnya berarti menghilangkan mode demo.
3. `models/*.js` + `config/supabase.js` masih dirujuk jalur legacy; menghapusnya
   memerlukan perubahan dependency (`@supabase/supabase-js`) yang tidak terkait
   kesiapan demo dan berisiko merusak lockfile.

**Dampak:** tidak ada file mati baru diperkenalkan dan tidak ada file terpakai
yang dihapus. Item ini dicatat sebagai pembersihan non-blocker (§C.5 R-01).

### C.5 Masalah yang masih tersisa

| # | Item | Dampak | Status |
|---|---|---|---|
| R-01 | Pembersihan legacy `models/*.js`, `config/supabase.js`, dependency `@supabase/supabase-js` | Tidak ada dampak fungsional | Non-blocker, belum dieksekusi (§C.4) |
| R-02 | Uji visual responsif & keyboard pada browser sungguhan | Belum dapat dibuktikan di environment ini | `NOT RUN` (L-01) |
| R-03 | Build/alur Android + kamera perangkat | Belum dapat dibuktikan di environment ini | `NOT RUN` (L-02) |
| R-04 | Akses tiket perangkat lain tanpa order token | Known limitation sesuai PRD C-02 | `BLOCKED` (L-03) |
| R-05 | Refresh token, upload brosur/template | Butuh keputusan produk/storage | `BLOCKED` (L-04, L-05) |
| R-06 | `EXPLAIN` query utama | Tidak ada dataset uji terisolasi | `NOT RUN` (L-06) |

---

## D. Hasil pengujian

Semua perintah dijalankan pada sesi ini, dari repo root kecuali disebut lain.

### D.1 Linting & static analysis

| Perintah | Hasil |
|---|---|
| `cd backend; npm run check` | **PASS** — `Syntax OK: 67 JavaScript files checked` |
| `cd backend; npm run format:check` | **PASS** — `Formatting check passed` |
| `cd backend; npm run validate:skills` | **PASS** — `Validated 7 skills and links in 8 Markdown files` |
| `cd apps; flutter analyze --no-pub` | **PASS** — `No issues found!` |

### D.2 Unit & integration test

| Perintah | Hasil |
|---|---|
| `cd backend; npm test` | **PASS** — 177 test, 0 gagal (baseline 172 + 5 regresi baru) |
| `cd backend; npm run test:sync-config` | **PASS** — 14 test, 0 gagal |
| `cd apps; flutter test --no-pub` | **PASS** — 265 test, `All tests passed!` (baseline 255 + 10 baru) |
| `cd apps; flutter test --no-pub test/services/api_mode_no_fallback_test.dart` | **PASS** |

Test baru:

| File | Isi |
|---|---|
| `backend/test/d1_integration_regression.test.js` | 5 test regresi BUG-01…BUG-05 |
| `apps/test/app_router_test.dart` (+5) | D1-G1 `eventId` peserta, D1-G3 route order, D1-G2 scanner & team tanpa `evt-1001`, guard guest |
| `apps/test/features/organizer/events/attendee_field_builder_test.dart` | 5 test builder field dinamis |

### D.3 Build

| Perintah | Hasil |
|---|---|
| `cd apps; flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:5000/api` | **PASS** — `✓ Built build/web`; `main.dart.js` 3.901.805 byte |
| `node scripts/serve-web.js 3100 apps/build/web` | **PASS** — `GET /` 200 (1580 B), `GET /main.dart.js` 200 (3,9 MB) |
| `flutter build apk` | **NOT RUN** — Android SDK/Gradle tidak tersedia (E-07) |

Catatan: build web mengembalikan exit code non-nol hanya karena peringatan
`--wasm-dry-run` (`dart:js_util unsupported` dari `flutter_secure_storage_web`);
artefak tetap terbentuk dan jalur **JS** (yang dipakai demo) berhasil.

### D.4 Database

| Pemeriksaan | Hasil |
|---|---|
| Koneksi & health | **PASS** — `GET /health` → `{"database":"connected"}`; 33 tabel di schema `public` |
| `cd backend; npm run verify:db-schema` | **PASS** — `schema.prisma` dan database aktual tidak berbeda (tabel, kolom, tipe, nullability, default, enum, PK, unique, index, FK, onDelete/onUpdate) |
| Data tersimpan (`npm run test:e2e`) | B-04 order (`order_number` + PAID), B-05 `token_hash` 64 hex, B-08 `custom_fields`, B-09 `check_ins` 1 baris, B-09b `scan_logs` |
| Audit & settings history | A-61 `audit_logs` bertambah; A-65 `platform_setting_history` 3→4 |
| Migrasi | Tidak ada perubahan schema/migration; `verify:db-schema` memastikan tidak ada drift |

### D.5 API, autentikasi, dan alur utama

| Perintah | Hasil |
|---|---|
| `cd backend; npm start` lalu `npm run test:e2e` | **PASS — 80/80 pemeriksaan** terhadap API + PostgreSQL nyata |

Cakupan (memakai `fetch` + `pg`, bukan mock):

- Health & DB: E2E-00.
- Organizer: A-01a/b, A-02, A-03a/b/c, A-04, A-05, A-05b, A-06, A-07.
- Guest: E2E-06, E2E-07, E2E-08a/b, A-31, A-37, A-36, K5-D1-04, K5-D1-04b, N-01, N-03, N-04, N-12, N-13a.
- Staff: E2E-09, E2E-09b, E2E-10, A-45, N-09, C-15, N-05, E2E-11b, E2E-11, E2E-12, N-07, B-09, E2E-13, N-08.
- Organizer pasca-alur: A-13, A-14, A-15, A-16, A-17, A-17b, A-18, E2E-17, A-12b, A-76.
- Admin: E2E-18a/e, A-59, A-60, A-61, A-62, A-63, A-65, A-66, A-67, A-67b, A-68, A-69, A-75, A-71, A-72, A-73, A-74, A-77, N-10.
- DB & negatif akhir: B-04, B-05, B-08, B-09b, N-11, C-01, C-02, D-08, C-03, C-04.

Hak akses per role yang dibuktikan: guest (tanpa token, order token), staff
(membership + permission), Organizer (ownership event), Admin (route khusus).

### D.6 Yang belum dapat diuji (dan alasannya)

| Item | Status | Alasan konkret |
|---|---|---|
| Responsif visual 360/768/1280/1920 & keyboard/focus | `NOT RUN` | Tidak ada browser/driver screenshot yang dapat dikendalikan; port dev 3000 dipakai layanan VPN. Widget test bukan bukti visual. |
| Build & alur Android, kamera perangkat | `NOT RUN` | Android SDK/Gradle, emulator, dan izin kamera tidak tersedia. |
| Email SMTP nyata | `NOT RUN` | Tidak ada kredensial SMTP; pengiriman tercatat `NOT_CONFIGURED` (tidak diklaim terkirim). |
| Backup/restore | `NOT RUN` | `pg_dump`/`pg_restore` tidak tersedia; DB bersifat bersama. |
| `EXPLAIN` query utama | `NOT RUN` | Tidak ada dataset uji terisolasi; hasil pada data campuran tidak bermakna. |

Tidak ada hasil pengujian yang dimanipulasi: satu test lama yang mengunci
perilaku usang (`resolvedAttendeeFields` kosong) diperbarui **dengan alasan
tertulis** di komentar test, karena kontrak server mewajibkan `name`+`email`.

---

## E. Kesiapan demo

### Kesimpulan: **SIAP DEMO**

Dasar (bukti, bukan klaim):

| Kriteria | Status | Bukti |
|---|---|---|
| Seluruh tugas Developer 1 Tahap 3 selesai | ✅ | §A (10 task; T3-D1-07 dicatat SEBAGIAN dengan alasan §C.4) |
| Seluruh tugas Tahap 3 terverifikasi | ✅ | §B — pekerjaan D2/D3 diverifikasi lewat 80 pemeriksaan nyata |
| Fitur PRD tersedia & berfungsi | ✅ | Checklist A-01…A-77 PASS |
| Modul terintegrasi | ✅ | §B tabel integrasi + `npm run test:e2e` 80/80 |
| Database implementasi nyata (bukan mock) | ✅ | §D.4 + `verify:db-schema` PASS |
| Tidak ada bug kritis/blocker pada alur utama | ✅ | §C.2 — 9 bug ditutup; tidak ada `FAIL` terbuka |
| Build berhasil | ✅ | `flutter build web --release` → `Built build/web` |
| Pengujian utama berhasil | ✅ | 177 backend, 265 Flutter, 80 e2e — 0 gagal |
| Auth & hak akses tiap role | ✅ | §D.5 |
| Dapat dijalankan dari awal tanpa konfigurasi tak terdokumentasi | ✅ | `README.md` + `.env.example` + `RUNBOOK_OPERASIONAL.md` |
| Skenario demo berjalan awal→akhir | ✅ | Alur Organizer→Guest→Staff→Organizer→Admin, §D.5 |

### Skenario demo yang disarankan (sudah terbukti lewat e2e)

1. **Organizer**: login → buat event + kategori tiket → atur pertanyaan
   pendaftaran (tambah `select` "Ukuran Kaos") → publish → salin tautan publik.
2. **Guest**: buka tautan publik (tanpa login) → daftar → bayar simulasi → lihat
   tiket + QR.
3. **Staff**: Organizer mengundang → buka `invite_url` → login email sama →
   terima → scan QR → check-in → scan ulang (`ALREADY_USED`) → riwayat.
4. **Organizer**: daftar peserta (paid-first) → detail `custom_fields` → export
   CSV → order per event → revenue.
5. **Admin**: login → akun & suspend + audit → settings (fee/komisi read-only) →
   overview/revenue/paket/langganan → moderasi event (suspend → hilang publik →
   restore).

### Catatan jujur untuk pemilik proyek

- Status **SIAP DIUJI PENGGUNA** terpenuhi. Status **SIAP DEPLOYMENT belum
  layak** karena uji visual responsif, build Android, kamera perangkat, dan
  `EXPLAIN` masih `NOT RUN` — lihat tabel I pada checklist.
- `npm run test:e2e` **menulis** data uji ke database `DATABASE_URL`. Untuk demo
  bersih, jalankan pada database uji khusus.
- Kamera pada web memerlukan `localhost` atau HTTPS.
- Tanpa SMTP, email tiket tidak terkirim; QR dibuka dari perangkat pemesanan
  (sesuai PRD C-02). Ini bukan bug.

---

## F. Pernyataan kepatuhan

- [x] Tidak mengubah `backend/prisma/schema.prisma`, migration, atau seed.
- [x] Tidak menjalankan migration/reset/seed pada database bersama.
- [x] Tidak menyimpan secret/kredensial pada repository, kode, atau laporan.
- [x] Tidak menambah fitur di luar PRD.
- [x] Tidak menghapus fitur/data/konfigurasi penting tanpa alasan tertulis.
- [x] Tidak melakukan commit/push/merge; perubahan dibiarkan pada working tree.
- [x] Setiap perbaikan disertai test regresi dan seluruh suite dijalankan ulang.
- [x] `BLOCKED`/`NOT RUN` ditulis dengan alasan konkret, bukan diklaim lulus.
