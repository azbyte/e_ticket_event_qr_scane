# TUGAS DEVELOPER 2 — TAHAP 3 (FASE 1)

- **Peran:** Developer 2 — Ticketing, Staff Workspace, Scanner & Check-in.
- **Fase:** FASE 1, berjalan **paralel** dengan Developer 3.
- **Branch:** `Developer-2-T3`.
- **Mulai:** setelah membaca dokumen ini; tidak menunggu Developer 1.
- **Selesai:** seluruh task T3-D2-01…T3-D2-07 + laporan + bukti perintah.
- **Otorisasi:** perintah pemilik proyek kepada Developer 2 adalah otorisasi implementasi.

> Dokumen ini dapat langsung dipakai sebagai instruksi kerja. Tidak perlu membaca ulang laporan analisis utama kecuali untuk memperjelas temuan.

---

## 1. Tujuan pekerjaan

Menyelesaikan seluruh alur **tiket → QR → undangan staff → workspace staff → scan → check-in → riwayat** sehingga:

1. Setiap layar memakai API nyata pada `MOCK_MODE=false`.
2. Tidak ada data mock, `evt-1001`, nama staff, atau judul event hardcoded pada alur produksi.
3. QR tiket benar-benar dapat dipindai dan hanya berisi token opaque.
4. Staff hanya dapat mengakses event tempat ia memiliki membership dan permission.
5. Check-in tercatat tepat satu kali, tahan terhadap request bersamaan, dan riwayatnya benar.
6. Seluruh perilaku di atas terbukti dengan test backend/Flutter dan bukti perintah.

---

## 2. Kondisi awal proyek yang relevan

### 2.1 Baseline

- Commit: `78e19f0` (`update/featur`).
- `cd backend; npm test` → **PASS 163 test**.
- `cd apps; flutter analyze --no-pub` → **0 issue**.
- `cd apps; flutter test --no-pub` → **PASS 238 test**.

Jalankan ulang baseline di branch Anda dan catat hasilnya pada laporan. Bila berbeda, selidiki sebelum mengubah kode.

### 2.2 Yang sudah tersedia (jangan dibangun ulang)

| Komponen | Bukti |
|---|---|
| QR nyata | `apps/lib/features/tickets/widgets/qr_ticket_display.dart` memakai `QrImageView` dari `qr_flutter` |
| Kamera | `apps/lib/features/scanner/**` memakai `mobile_scanner`; input manual sebagai fallback |
| Validasi & check-in backend | `backend/src/controllers/checkInController.js` — `validateTicket`, `recordCheckIn`, `commitCheckIn`, `listEventCheckIns` |
| Verifikasi tiket | `backend/src/controllers/ticketController.js` — `verifyTicket` memanggil `commitCheckIn` |
| Invitation & membership | `backend/src/controllers/eventInvitationController.js` — create/list/revoke/accept, `myMemberships` |
| Endpoint membership | `backend/src/routes/meRoutes.js` → `GET /api/me/memberships` |
| Halaman undangan | `apps/lib/features/staff/screens/accept_invitation_screen.dart` |
| Service membership API | `apps/lib/services/organizer_membership/organizer_membership_service.dart` (mock hanya `MOCK_MODE`) |
| Token service | `backend/src/services/ticketTokenService.js` (HMAC + SHA-256) |

### 2.3 Gap yang harus diselesaikan D2

| # | Gap | File/bukti | Target |
|---|---|---|---|
| D2-G1 | `OrganizerScannerScreen` memakai `OrganizerOperationsRepository` (mock) | `organizer_scanner_screen.dart:33-34` | Pindah ke `ScannerService`/`CheckInService` |
| D2-G2 | `CheckInService` masih menyimpan antrean offline + `sync` | `check_in_service.dart:40-41, 197-230` | Hapus dari alur MVP |
| D2-G3 | Default `evt-1001` pada layar check-in/scanner | `check_in_screen.dart:13`, `check_in_history_screen.dart:13`, `app_router.dart:81` | Wajib `eventId` dari membership/argumen |
| D2-G4 | Staff dashboard memakai nama/judul/event default | `staff_dashboard_screen.dart:19-22` | Ambil dari `AuthProvider` + membership |
| D2-G5 | Team/staff management default `evt-1001` | `team_management_screen.dart:18`, `staff_management_screen.dart:14` | Wajib `eventId`; tampilkan `invite_url` |
| D2-G6 | `invite_url` belum ditampilkan di UI team | `eventInvitationController.js` sudah mengirim | Tampilkan + tombol salin |
| D2-G7 | Permission `ASSIST_REGISTRATION` masih ditawarkan | form undangan | Hapus dari pilihan MVP |
| D2-G8 | Riwayat check-in belum memakai event nyata + filter | `check_in_history_screen.dart` | Event dari membership, filter tanggal/status |
| D2-G9 | State QR tiket belum lengkap (unpaid/used/denied) | `ticket_detail_screen.dart` | State eksplisit |
| D2-G10 | Belum ada test regresi tiket–scan D2 di Tahap 3 | `apps/test/**` | Test baru |
| D2-G11 | Backfill `token_hash` tiket gratis belum diuji | `ticketTokenService.js` | Test + verifikasi |
| D2-G12 | Hasil scan `CANCELLED`/`REVOKED` belum diuji UI | `scan_result_screen.dart` | Test widget |

> Temuan baru wajib ditambahkan ke laporan dengan file/baris. Jangan mengandalkan daftar ini saja.

### 2.4 Yang bukan tanggung jawab D2

- `app_router.dart`, `app.dart`, `routes/app_routes.dart` (D1).
- `backend/src/app.js` (D1).
- `pubspec.yaml` (D1).
- `README.md`, `docs/**`, `backend/README.md` (D1).
- Peserta/export/order/revenue/Admin (D3).
- Event lifecycle/publish/public link (D1).

---

## 3. Fitur yang harus dikerjakan

### T3-D2-01 — Audit awal & bukti baseline

**Tujuan:** memastikan titik awal dan menemukan gap tambahan sebelum mengubah kode.

**Pekerjaan:**
1. Jalankan baseline:
   ```powershell
   cd backend; npm test
   cd apps; flutter analyze --no-pub
   cd apps; flutter test --no-pub
   ```
2. Catat commit, hasil, dan jumlah test.
3. Baca file D2-G1…D2-G12; verifikasi setiap baris masih benar.
4. Cari `mock`, `evt-1001`, `org-001`, `dummy`, `in-memory` pada file milik D2:
   ```powershell
   Get-ChildItem apps/lib/features/tickets,apps/lib/features/scanner,apps/lib/features/check_in,apps/lib/features/staff,apps/lib/features/organizer/membership,apps/lib/services/ticket,apps/lib/services/scanner,apps/lib/services/check_in,apps/lib/services/organizer_membership -Recurse -Include *.dart |
     Select-String -Pattern "mock|evt-1001|org-001|dummy|in-memory"
   ```
5. Tulis daftar gap final pada laporan §2.

**Kriteria:** baseline tercatat; daftar gap final tersedia.

---

### T3-D2-02 — Tiket, QR, dan akses tiket

**Tujuan:** tiket menampilkan QR nyata dari token, hanya untuk pemilik, dengan state yang jelas.

**File yang dikerjakan:**
- `apps/lib/features/tickets/widgets/qr_ticket_display.dart`
- `apps/lib/features/tickets/screens/ticket_detail_screen.dart`
- `apps/lib/features/tickets/screens/ticket_list_screen.dart`
- `apps/lib/models/ticket/ticket_model.dart`
- `apps/lib/services/ticket/ticket_service.dart`
- `backend/src/controllers/ticketController.js`
- `backend/src/services/ticketTokenService.js`
- test baru di `apps/test/features/tickets/**` dan `backend/test/ticket_token_tahap3.test.js`

**Pekerjaan:**
1. Pastikan QR dirender dari `ticket.token` (bukan pola pseudo). Bila `token` null/kosong, tampilkan state “Tiket belum aktif” — jangan render QR kosong.
2. Payload QR hanya token. Tidak boleh memuat email, telepon, harga, nama event, atau `token_hash`.
3. Jangan pernah menulis token ke log, `print`, analytics, pesan error, atau URL.
4. State tiket:
   - `pending`/belum dibayar → QR tidak ditampilkan, pesan “Selesaikan pembayaran”.
   - `active` → QR tampil.
   - `used` → QR tampil tetapi diberi status “Sudah check-in” + waktu.
   - `cancelled`/`revoked` → QR tidak ditampilkan, pesan status.
   - akses ditolak → state 403/404 dengan pesan aman.
5. `TicketListScreen(orderId:)` harus tetap mendukung parameter `orderId` (dipakai D1 pasca-checkout).
6. Pastikan `GET /api/tickets/my-tickets` dan `GET /api/tickets/:id` mengembalikan `token` hanya untuk pemilik/admin. Test negatif: user lain → 403/404, `token` tidak ada.
7. Pastikan `token_hash` tersedia untuk tiket gratis:
   - Cek `ensureTokenHash`/backfill di `ticketTokenService.js`.
   - Test: tiket gratis yang belum pernah dibuka tetap dapat divalidasi/di-scan.
8. UI responsif: QR tidak overflow pada 360 px; ukuran menyesuaikan lebar; sediakan `Semantics`/label “QR tiket”.
9. Test widget: QR muncul untuk tiket aktif, tidak muncul untuk pending, label status untuk used/cancelled/revoked.

**Kriteria keberhasilan:**
- K1 QR berasal dari token asli dan dapat dipindai (dibuktikan bersama T3-D2-04).
- K2 Payload QR tidak memuat PII/harga/`token_hash`.
- K3 Tiket gratis dan berbayar sama-sama memiliki hash.
- K4 Akses tiket pihak lain ditolak.
- K5 State pending/used/cancelled/revoked tampil benar.
- K6 Test backend + widget PASS.

---

### T3-D2-03 — Invitation, membership, dan workspace staff

**Tujuan:** Organizer mengundang staff lewat API; staff menerima undangan dan masuk ke workspace event yang benar.

**File yang dikerjakan:**
- `apps/lib/features/organizer/membership/team_management_screen.dart`
- `apps/lib/features/organizer/screens/staff_management_screen.dart`
- `apps/lib/features/staff/screens/staff_dashboard_screen.dart`
- `apps/lib/features/staff/screens/accept_invitation_screen.dart`
- `apps/lib/services/organizer_membership/organizer_membership_service.dart`
- `apps/lib/services/organizer_membership/invitation_service.dart`
- `backend/src/controllers/eventInvitationController.js`
- `backend/src/routes/invitationsRoutes.js`
- `backend/src/routes/meRoutes.js`
- test baru `backend/test/event_invitation_tahap3.test.js`, `apps/test/features/staff/**`, `apps/test/features/organizer/membership/**`

**Pekerjaan:**
1. Hapus default `evt-1001` dan judul event palsu. `eventId` wajib berasal dari konteks event yang dipilih.
2. Team management memakai API:
   - daftar member (`GET /api/events/:eventId/members` atau endpoint yang tersedia),
   - undang (`POST /api/events/:eventId/invitations`),
   - cabut (`DELETE /api/events/:eventId/invitations/:invitationId`),
   - ubah permission/keluarkan member bila endpoint tersedia.
3. Form undangan:
   - email wajib valid,
   - permission minimal satu,
   - expiry wajib/opsional sesuai kontrak backend,
   - **tidak** menawarkan `ASSIST_REGISTRATION`,
   - tampilkan `invite_url` setelah dibuat + tombol salin,
   - tampilkan status pending/accepted/revoked/expired.
4. Halaman `/invite/:token`:
   - pratinjau `GET /api/invitations/:token` (tanpa PII lengkap),
   - wajib login; setelah login kembali ke halaman undangan,
   - tombol terima memanggil `POST /api/invitations/:token/accept`,
   - email tidak cocok → pesan 403 yang jelas,
   - expired/revoked/reused → pesan 410/403,
   - sukses → arahkan ke workspace staff event tersebut (scanner bila punya `SCAN_TICKET`).
5. Staff dashboard:
   - nama staff dari `AuthProvider`, bukan konstanta,
   - daftar event dari `GET /api/me/memberships`,
   - hanya event `ACTIVE` dan belum expired,
   - tampilkan permission yang dimiliki,
   - tombol Scanner/Riwayat/Peserta hanya muncul bila permission sesuai,
   - empty state “Belum ada undangan aktif” + retry,
   - error state bila API gagal (tanpa fallback mock).
6. Jangan menampilkan event yang bukan membership user, meskipun ID diketahui.
7. Navigasi internal dari dashboard ke scanner/riwayat boleh memakai `Navigator.push` dengan `eventId`; jangan mengedit router.

**Kriteria keberhasilan:**
- K1 Undangan tercatat di DB dengan token hash.
- K2 Hanya email yang cocok dapat menerima.
- K3 Expired/revoked/reused ditolak.
- K4 Permission tersalin ke membership.
- K5 Membership muncul di `/api/me/memberships`; staff diarahkan ke event yang benar.
- K6 `invite_url` tampil dan berbeda dari `public_url`.
- K7 Tidak ada `evt-1001` pada alur produksi D2.
- K8 Test backend positive/negative + widget PASS.

---

### T3-D2-04 — Scanner kamera & validasi tiket online

**Tujuan:** Staff memindai QR dengan kamera, sistem memvalidasi ke backend, dan hasilnya ditampilkan jujur.

**File yang dikerjakan:**
- `apps/lib/features/scanner/screens/scanner_screen.dart`
- `apps/lib/features/scanner/screens/scan_result_screen.dart`
- `apps/lib/features/scanner/widgets/camera_scanner_view.dart`
- `apps/lib/features/scanner/widgets/scanner_placeholder.dart` (hapus bila tidak dipakai)
- `apps/lib/features/organizer/operations/organizer_scanner_screen.dart`
- `apps/lib/services/scanner/scanner_service.dart`
- `apps/lib/services/check_in/check_in_service.dart`
- `apps/lib/providers/check_in_provider.dart`
- `backend/src/controllers/checkInController.js`
- test baru `apps/test/features/scanner/**`

**Pekerjaan:**
1. `ScannerScreen` menerima `eventId` wajib. Tidak ada fallback `evt-1001`.
2. Kamera:
   - minta izin kamera,
   - state izin ditolak + tombol coba lagi,
   - fallback input kode manual,
   - kamera berhenti saat layar tidak aktif,
   - Web: izin kamera hanya pada origin aman; tampilkan pesan bila tidak tersedia.
3. Alur scan:
   - pindai QR → `POST /api/tickets/validate` dengan `{ token, event_id }`,
   - bila valid → konfirmasi → `POST /api/check-ins` (atau `verify`) untuk mencatat check-in,
   - tampilkan hasil `VALID`, `ALREADY_USED`, `WRONG_EVENT`, `PAYMENT_REQUIRED`, `CANCELLED`, `REVOKED`, `INVALID`.
4. Cegah double-submit: lock tombol/proses sampai respons selesai.
5. Tidak ada mode offline, antrean offline, atau tombol simulasi pada `MOCK_MODE=false`.
6. `OrganizerScannerScreen`:
   - judul bukan “Mock”,
   - memakai `ScannerService`/`CheckInService`, **bukan** `OrganizerOperationsRepository`,
   - event dan permission dari konteks nyata.
7. `CheckInService`:
   - hapus antrean offline dan `syncPendingCheckIns` dari alur MVP,
   - API hanya; error diteruskan ke UI,
   - mock hanya bila `MOCK_MODE=true`.
8. `ScanResultScreen` menampilkan data minimum: kode tiket, nama peserta, kategori, waktu check-in, pesan. Tidak menampilkan token/email lengkap/harga.

**Kriteria keberhasilan:**
- K1 Kamera terbuka dan mengenali QR tiket.
- K2 Hasil validasi sesuai backend untuk semua status.
- K3 Tidak ada mode offline/tombol simulasi pada alur MVP.
- K4 Event berasal dari membership/argumen, bukan hardcoded.
- K5 Double-submit tidak menghasilkan dua check-in.
- K6 Widget test scanner + permission PASS.

---

### T3-D2-05 — Check-in tunggal & riwayat

**Tujuan:** satu jalur check-in yang konsisten, anti-duplikasi, dan riwayat nyata.

**File yang dikerjakan:**
- `apps/lib/features/check_in/screens/check_in_screen.dart`
- `apps/lib/features/check_in/screens/check_in_history_screen.dart`
- `apps/lib/services/check_in/check_in_service.dart`
- `apps/lib/providers/check_in_provider.dart`
- `backend/src/controllers/checkInController.js`
- `backend/src/controllers/ticketController.js`
- test baru `apps/test/features/check_in/**`

**Pekerjaan:**
1. Hapus default `evt-1001` pada layar check-in dan riwayat. Event dipilih dari membership atau diteruskan sebagai argumen.
2. Riwayat memakai `GET /api/check-ins/events/:eventId/check-ins` (bukan path lama `/events/:eventId/check-ins`).
3. Riwayat menampilkan: nama peserta, kode tiket, kategori, waktu check-in, petugas, hasil scan.
4. Filter: tanggal, kategori, pencarian; pagination bila tersedia.
5. State: loading, empty (“Belum ada check-in”), error + retry, unauthorized.
6. Pastikan `POST /api/tickets/verify` **selalu** membuat `check_ins` (bukan hanya mengubah status tiket). Test:
   - verify tiket valid → satu baris `check_ins` + satu `scan_logs`,
   - verify ulang → `409`, tidak ada baris baru,
   - dua request bersamaan → satu sukses, satu `ALREADY_USED`.
7. Pastikan `check_ins.ticket_id` unik dan transaksi memakai `SELECT ... FOR UPDATE`.
8. `CheckInProvider` tidak lagi memiliki default event/offline sync; state error diteruskan.

**Kriteria keberhasilan:**
- K1 Scan valid membuat tepat satu `check_ins` + satu `scan_logs`.
- K2 Scan ulang `ALREADY_USED` tanpa baris baru.
- K3 `verify` tidak mengubah status tanpa `check_ins`.
- K4 Riwayat memuat data nyata dan dapat difilter.
- K5 Test konkurensi backend PASS; widget test riwayat PASS.

---

### T3-D2-06 — Backend tiket/check-in: konsolidasi & keamanan

**Tujuan:** menutup risiko token/otorisasi dan memastikan satu sumber kebenaran check-in.

**File yang dikerjakan:**
- `backend/src/controllers/checkInController.js`
- `backend/src/controllers/ticketController.js`
- `backend/src/services/ticketTokenService.js`
- `backend/src/validators/ticketValidator.js`
- test baru `backend/test/ticket_token_tahap3.test.js`, `backend/test/checkin_rules.test.js` (perluasan)

**Pekerjaan:**
1. Pastikan `findTicketByRawToken`/`findTicketByIdentifier` memakai perbandingan hash yang aman (constant-time) dan tidak membocorkan apakah token ada.
2. `assertScanPermission`:
   - user terautentikasi,
   - akun aktif,
   - membership `ACTIVE` dan belum expired,
   - permission `SCAN_TICKET` atau `CHECK_IN_TICKET`,
   - event scope cocok.
3. `validateTicket` mengembalikan status yang benar untuk: token palsu, event salah, order belum `PAID`, tiket `used/cancelled/revoked`, permission kurang.
4. `recordCheckIn`:
   - transaksi,
   - `FOR UPDATE`,
   - insert `check_ins` dengan `ON CONFLICT (ticket_id) DO NOTHING`,
   - update tiket `used`,
   - insert `scan_logs`,
   - rollback pada error.
5. `verifyTicket` mendelegasikan ke `commitCheckIn` (jangan menduplikasi logika).
6. Jangan pernah mengirim `token_hash` ke klien atau menulis token mentah ke log.
7. Pastikan respons `validate`/`verify` tidak memuat email lengkap/harga.
8. Rate limit scan tetap aktif (`scanLimiter`).

**Kriteria keberhasilan:**
- K1 Token palsu/unknown → `INVALID`/404 tanpa check-in.
- K2 Event salah → `WRONG_EVENT` tanpa check-in.
- K3 Belum bayar → `PAYMENT_REQUIRED` tanpa check-in.
- K4 Tiket used → `ALREADY_USED`, tanpa baris baru.
- K5 Permission kurang → 403.
- K6 Tidak ada token/hash pada log/respons.
- K7 Test backend PASS.

---

### T3-D2-07 — Regresi, bukti bebas mock, dan laporan

**Tujuan:** membuktikan hasil D2 lengkap dan tidak meninggalkan mock pada mode API.

**Pekerjaan:**
1. Tambah test regresi minimal:
   - tiket gratis → scan → check-in → duplikat → riwayat,
   - tiket berbayar → PAID → scan → check-in,
   - tiket event lain → `WRONG_EVENT`,
   - tiket belum dibayar → `PAYMENT_REQUIRED`,
   - staff tanpa permission → 403,
   - invitation expired/revoked/email salah → ditolak,
   - membership staff → workspace event benar.
2. Jalankan:
   ```powershell
   cd backend; npm test
   cd backend; npm run check
   cd backend; npm run format:check
   cd apps; flutter analyze --no-pub
   cd apps; flutter test --no-pub
   cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart
   ```
3. Cari sisa mock/hardcoded pada file D2 dan lampirkan hasilnya.
4. Tulis laporan sesuai §11.

**Kriteria:** seluruh perintah PASS; tidak ada mock aktif pada `MOCK_MODE=false`; laporan lengkap.

---

## 4. Daftar file dan folder tanggung jawab

Ringkasan (detail ada di `FILE_OWNERSHIP.md` Bagian 2):

**Backend**
```
backend/src/controllers/checkInController.js
backend/src/controllers/ticketController.js
backend/src/controllers/eventInvitationController.js
backend/src/routes/checkInRoutes.js
backend/src/routes/ticketRoutes.js
backend/src/routes/invitationsRoutes.js
backend/src/routes/meRoutes.js
backend/src/services/ticketTokenService.js
backend/src/validators/ticketValidator.js
backend/test/checkin_rules.test.js
backend/test/event_invitation_tahap3.test.js
backend/test/ticket_token_tahap3.test.js
```

**Flutter**
```
apps/lib/features/tickets/**
apps/lib/features/scanner/**
apps/lib/features/check_in/**
apps/lib/features/staff/**
apps/lib/features/organizer/membership/**
apps/lib/features/organizer/screens/staff_management_screen.dart
apps/lib/features/organizer/operations/organizer_scanner_screen.dart
apps/lib/services/ticket/**
apps/lib/services/scanner/**
apps/lib/services/check_in/**
apps/lib/services/organizer_membership/**
apps/lib/providers/check_in_provider.dart
apps/lib/models/ticket/**
apps/lib/models/check_in/**
```

**Test Flutter**
```
apps/test/developer_2_flow_test.dart
apps/test/features/organizer/shell/organizer_membership_test.dart
apps/test/features/organizer/operations/attendee_access_widget_test.dart
apps/test/features/tickets/**
apps/test/features/scanner/**
apps/test/features/check_in/**
apps/test/features/staff/**
apps/test/features/organizer/membership/**
```

---

## 5. File yang tidak boleh diubah

Daftar lengkap ada di `FILE_OWNERSHIP.md` Bagian 2.4. Ringkasannya:

- **Routing/aplikasi:** `apps/lib/app.dart`, `app_router.dart`, `main.dart`, `routes/app_routes.dart`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `core/**`.
- **Domain D1:** `providers/auth_provider.dart`, `event_provider.dart`, `order_provider.dart`, `payment_provider.dart`; `services/api/**`, `auth/**`, `event/**`, `order/**`, `payment/**`, `public_event/**`, `organizer_events/**`; `features/auth/**`, `events/**`, `home/**`, `orders/**`, `payments/**`, `public_event/**`, `registration/**`, `organizer/events/**`, `organizer/screens/event_form_screen.dart`, `event_management_screen.dart`; `models/event/**`, `order/**`, `payment/**`, `user/**`.
- **Domain D3:** `features/admin/**`, `reports/**`, `notifications/**`, `organizer/screens/attendee_list_screen.dart`, `organizer_order_list_screen.dart`, `organizer_dashboard_screen.dart`, `organizer/operations/**` (kecuali `organizer_scanner_screen.dart`), `organizer/shell/**`, `plans/**`, `support/**`; `services/admin/**`, `organizer_operations/**`, `organizer_plans/**`, `organizer_support/**`, `organizer_notifications/**`, `organizer_shell/**`, `report/**`, `notification/**`; `providers/report_provider.dart`, `notification_provider.dart`; `models/admin/**`, `report/**`.
- **Backend D1:** `src/app.js`, `config/**`, `middleware/**`, `controllers/authController.js`, `eventController.js`, `orderController.js`, `paymentController.js`, `ticketTypeController.js`, `organizerProfileController.js`; route auth/event/order/payment/ticketType; service auth/email/adminBootstrap/seed; utils eventResponse/eventValidation/eventSummary/orderResponse/response/validators/constants/logger; `validators/authValidator.js`.
- **Backend D3:** seluruh controller/route/service admin, plan, subscription, revenue, report, notification, eventMetrics; `utils/auditLog.js`; `services/notificationService.js`.
- **Test lintas domain:** `apps/test/stage1_integration_test.dart`, `stage2_integration_test.dart`, `app_router_test.dart`, `widget_test.dart`, `services/api_mode_no_fallback_test.dart`, `helpers/test_mock_server.dart`; test admin/reports/notifications; test `attendee_operations_test.dart`; test shell/plans.
- **Dokumentasi/konfigurasi:** `README.md`, `backend/README.md`, `docs/**`, `task/**`, `.github/**`, `.githooks/**`, `backend/package.json`, `backend/package-lock.json`.
- **Database:** `backend/prisma/**`, `backend/supabase/**` (mutlak).

---

## 6. Kontrak API dan database yang harus diikuti

### 6.1 Endpoint yang dipakai

| Kebutuhan | Endpoint | Catatan |
|---|---|---|
| Tiket saya | `GET /api/tickets/my-tickets` | `token` hanya pemilik |
| Detail tiket | `GET /api/tickets/:id` | `order_id` opsional untuk guest |
| Kirim ulang email | `POST /api/tickets/:id/email` | Jangan klaim terkirim tanpa status provider |
| Validasi | `POST /api/tickets/validate` | Body `{ token, event_id }` |
| Verifikasi/check-in | `POST /api/tickets/verify` | Harus membuat `check_ins` |
| Check-in | `POST /api/check-ins` | Idempotent; 409 duplikat |
| Riwayat | `GET /api/check-ins/events/:eventId/check-ins` | Filter/pagination |
| Undangan | `POST/GET/DELETE /api/events/:eventId/invitations` | `invite_url` aditif |
| Pratinjau undangan | `GET /api/invitations/:token` | Publik, data minimal |
| Terima undangan | `POST /api/invitations/:token/accept` | Email harus cocok |
| Membership saya | `GET /api/me/memberships` | `{ memberships: [...] }` |
| Member event | `GET/POST/PUT/DELETE /api/events/:id/members...` | Owner-only |

### 6.2 DTO

Ikuti `INTEGRATION_CONTRACT.md` Bagian 3.5–3.9 (Ticket, Attendee, ScanResult, Membership, Invitation). Jangan mengubah nama field atau enum.

### 6.3 Database

- **Dilarang** mengubah schema, migration, seed, atau SQL.
- Tabel yang relevan: `tickets`, `check_ins`, `scan_logs`, `event_members`, `event_member_permissions`, `event_invitations`, `event_invitation_permissions`.
- `check_ins.ticket_id` unik; `scan_logs` mencatat percobaan.
- `tickets.token_hash` wajib ada untuk semua tiket.
- Bila memerlukan index/perubahan skema: tulis proposal di laporan dan `task/DB_CHANGE_PROPOSAL.md` (hanya D1 yang boleh menyentuh dokumen itu; D2 cukup melaporkan).

---

## 7. Batasan pekerjaan

1. Tidak menambah dependency. `qr_flutter` dan `mobile_scanner` sudah tersedia.
2. Tidak mengubah kontrak response/error.
3. Tidak mengubah role/permission yang sudah ada.
4. Tidak menghapus fitur non-MVP; cukup tidak mengekspos assisted registration/offline.
5. Tidak mengedit file D1/D3.
6. Tidak menjalankan migration/seed/reset.
7. Tidak menyimpan token/secret pada log/test fixture/dokumen.
8. Tidak mengklaim PASS tanpa perintah.
9. Tidak menunda pekerjaan karena menunggu D1/D3. Gunakan kontrak dan catat permintaan integrasi.

---

## 8. Ketentuan integrasi dengan Developer 3

1. **Tidak ada file yang sama.** D2 tidak mengedit `organizer_operations_repository.dart`, `attendee_list_screen.dart`, `organizer_order_list_screen.dart`, `organizer_report_screen.dart`, atau file admin.
2. **Scanner vs repository.** D2 memindahkan `OrganizerScannerScreen` ke `ScannerService`/`CheckInService`. D3 akan menghapus method scanner/offline/assisted yang mati di repository **setelah** D2 selesai. D2 tidak boleh menghapus method tersebut.
3. **Backend attendee/export/orders.** Fungsi `listEventAttendees`, `exportEventAttendeesCsv`, dan `getEventOrders` berada di `checkInController.js` (milik D2). Bila D3 menemukan bug, D2 memperbaiki berdasarkan spesifikasi D3. D2 tidak mengubah bentuk response yang dipakai D3.
4. **DTO yang dipakai bersama.** `registration_number`, `order_number`, `payment_status`, `order_status`, `custom_fields`, `checked_in_at` harus tetap ada. Jangan menghapus field lama.
5. **Permission.** D2 memakai `SCAN_TICKET`/`CHECK_IN_TICKET`; D3 memakai `VIEW_PARTICIPANTS`/`EXPORT_PARTICIPANTS`/`VIEW_ORDERS`. Jangan menukar permission antar operasi.
6. **Event suspended.** D2 tidak perlu mengubah event lifecycle; cukup menampilkan error dari backend bila event tidak tersedia.
7. **Serah terima.** D2 menulis di laporan:
   - file repository yang sudah tidak dipakai untuk scanner (agar D3 bisa menghapus),
   - endpoint yang berubah (bila ada),
   - route yang perlu ditambahkan D1,
   - test yang gagal karena file D3 (bila ada).

---

## 9. Pengujian wajib

### 9.1 Perintah

| Pemeriksaan | Perintah | Kriteria |
|---|---|---|
| Backend test | `cd backend; npm test` | PASS, 0 gagal |
| Backend sintaks | `cd backend; npm run check` | PASS |
| Backend format | `cd backend; npm run format:check` | PASS |
| Flutter analyze | `cd apps; flutter analyze --no-pub` | 0 issue |
| Flutter test | `cd apps; flutter test --no-pub` | PASS |
| Mode API | `cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | PASS |

### 9.2 Skenario wajib

| ID | Skenario | Harapan | Bukti |
|---|---|---|---|
| D2-T01 | Tiket aktif menampilkan QR dari token | QR tampil; token tidak di log | Widget test |
| D2-T02 | Tiket pending/cancelled/revoked | QR tidak tampil; pesan status | Widget test |
| D2-T03 | Akses tiket user lain | 403/404; tanpa token | Backend test |
| D2-T04 | Tiket gratis tanpa membuka tiket | `token_hash` ada; scan valid | Backend test |
| D2-T05 | Undangan dibuat | `invite_url` ada; DB token hash | Backend test |
| D2-T06 | Email tidak cocok | 403 | Backend test |
| D2-T07 | Undangan expired/revoked/reused | 403/410 | Backend test |
| D2-T08 | Staff membuka dashboard | Hanya event membership | Widget test |
| D2-T09 | Scan valid | Satu `check_ins` + satu `scan_logs` | Backend test |
| D2-T10 | Scan ulang | `ALREADY_USED`, tanpa baris baru | Backend test |
| D2-T11 | Scan event lain | `WRONG_EVENT`, tanpa check-in | Backend test |
| D2-T12 | Scan tiket belum bayar | `PAYMENT_REQUIRED`, tanpa check-in | Backend test |
| D2-T13 | Staff tanpa permission | 403 | Backend test |
| D2-T14 | Dua scan bersamaan | Satu sukses, satu `ALREADY_USED` | Backend test |
| D2-T15 | Riwayat check-in | Data nyata, filter | Widget test |
| D2-T16 | Mode API gagal | Error + retry; tanpa mock | Widget test |
| D2-T17 | Layout 360 px | Tidak overflow | Widget test |

### 9.3 Bukti bebas mock

```powershell
Get-ChildItem apps/lib/features/tickets,apps/lib/features/scanner,apps/lib/features/check_in,apps/lib/features/staff,apps/lib/features/organizer/membership -Recurse -Include *.dart |
  Select-String -Pattern "evt-1001|org-001|mock|dummy|in-memory"
```

Hasil yang diperbolehkan hanya:
- mock yang dibungkus `if (AppConfig.mockMode)`,
- fixture demo yang tidak dipakai pada `MOCK_MODE=false`.

Lampirkan output dan penjelasan setiap temuan.

---

## 10. Kriteria selesai

D2 dinyatakan selesai bila **semua** berikut benar:

- [ ] T3-D2-01…T3-D2-07 selesai.
- [ ] Seluruh kriteria K pada setiap task terpenuhi.
- [ ] `npm test`, `npm run check`, `npm run format:check` PASS.
- [ ] `flutter analyze` 0 issue; `flutter test` PASS.
- [ ] `MOCK_MODE=false` test PASS.
- [ ] Tidak ada `evt-1001`/`org-001`/mock aktif pada alur produksi D2.
- [ ] Tidak ada file D1/D3 yang diubah.
- [ ] Tidak ada schema/migration/seed yang diubah.
- [ ] Laporan lengkap dan dapat dibaca D1 tanpa bertanya.
- [ ] Daftar permintaan integrasi untuk D1 tersedia.
- [ ] Branch sudah rebase ke baseline dan siap di-merge.

---

## 11. Format laporan hasil pekerjaan

Buat `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_2.md` dengan struktur berikut. Nomor heading **di dalam blok** adalah struktur file laporan, bukan lanjutan nomor dokumen ini.

```markdown
# Laporan Tahap 3 — Developer 2 (FASE 1)

- Status: DONE / PARTIAL / BLOCKED
- Branch: Developer-2-T3
- Baseline commit:
- Commit akhir:
- PR: <link/ID>

## 1. Ringkasan
## 2. Baseline & temuan awal
| ID | Temuan | File | Status awal | Status akhir |

## 3. Hasil per task
### T3-D2-01 ...
- Pekerjaan:
- File diubah:
- Bukti:
- Status: PASS/FAIL/BLOCKED/NOT RUN

## 4. File dibuat/diubah/dihapus
## 5. Endpoint dipakai/diubah
## 6. Database & dependency
- Perubahan schema: tidak ada / (jelaskan)
- Dependency baru: tidak ada / (jelaskan)

## 7. Bukti pengujian
| Perintah | Hasil | Jumlah test | Catatan |

## 8. Status platform
| Platform | Status | Bukti/alasan |
| API | | |
| DB | | |
| Web | | |
| Android/kamera | | |
| Email | | |

## 9. Permintaan integrasi untuk Developer 1
| # | Kebutuhan | File | Alasan | Usulan |

## 10. Risiko & catatan untuk Developer 3
## 11. Pernyataan kepatuhan
- [ ] Tidak mengubah schema/migration/seed
- [ ] Tidak mengedit file D1/D3
- [ ] Tidak ada secret/token di laporan
```

---

## 12. Permintaan integrasi yang sudah diketahui (untuk D1)

D2 tidak mengedit router. Daftar berikut **wajib** disalin/diperbarui di laporan:

| # | Kebutuhan | File target | Detail |
|---|---|---|---|
| 1 | `/staff/scanner` harus membuka `ScannerScreen(eventId:)`, bukan `StaffDashboardScreen` | `app_router.dart` | Saat ini `case AppRoutes.staffScanner` → `StaffDashboardScreen()` |
| 2 | `/staff/check-ins` harus membuka `CheckInHistoryScreen(eventId:)` | `app_router.dart` | Saat ini diarahkan ke dashboard |
| 3 | `/staff/:eventId` meneruskan `eventId` | `app_router.dart` | Sudah ada; pastikan guard membership |
| 4 | `/organizer/team` tidak boleh memakai default `evt-1001` | `app_router.dart` | Butuh `eventId`/konteks |
| 5 | `/organizer/events/:id/scanner` meneruskan konteks membership nyata | `app_router.dart` | Saat ini membuat `OrganizerMembershipContext.owner('usr-org-001')` |
| 6 | `/e/:eventId/ticket/:ticketId` meneruskan `orderId` | `app_router.dart` | Untuk akses guest |
| 7 | Route `/staff` untuk user dengan membership tetapi role bukan `staff` | `app_router.dart` | Gunakan membership, bukan role global |
| 8 | Hapus fallback `evt-1001` pada `app_router.dart:81` | `app_router.dart` | Tampilkan error state |

---

## 13. Jebakan yang harus dihindari

1. **Mengedit `app_router.dart` “hanya satu baris”.** Dilarang. Catat di laporan.
2. **Mengedit `organizer_operations_repository.dart` untuk scanner.** Dilarang; pindah ke `ScannerService`.
3. **Menggunakan `ScaffoldMessenger` untuk error API tanpa retry.** Sediakan state error yang dapat diulang.
4. **Menampilkan QR untuk tiket pending.** Membingungkan dan berpotensi disalahgunakan.
5. **Menulis token ke `print`/`debugPrint` saat debugging.** Hapus sebelum commit.
6. **Mengandalkan `ticket_code` sebagai pengganti token.** QR memakai token; kode manual hanya fallback.
7. **Membuat check-in lokal saat API gagal.** PRD: tidak ada check-in offline.
8. **Menambah permission baru.** Gunakan permission yang sudah ada.
9. **Mengubah response `listEventAttendees` tanpa koordinasi D3.** Field hanya boleh ditambah.
10. **Mengklaim scan PASS tanpa device/kamera.** Tulis `NOT RUN` dengan alasan bila tidak tersedia.







