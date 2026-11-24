# Laporan Developer 2 — Tahap 2

- **Status:** DONE
- **Baseline commit / branch / PR:** Branch `Developer-2` (rebased & synced dengan `origin/Developer-2`)
- **Otorisasi:** Perintah pemilik proyek ("pergi ke tahap 2 folder, kerjakan tahap 2 dan saya sebagai developer 2") = otorisasi implementasi per Autonomous Execution Protocol di `task/PEMBAGIAN_TUGAS_FINAL.md`.
- **Keputusan teknis & asumsi mandiri:**
  1. *Dukungan Input Ganda (QR Token Hash & Kode Tiket Manual):* Implementasi `findTicketByIdentifier` pada backend `checkInController.js` mendukung verifikasi via hash token QR SHA-256 (untuk pemindaian kamera) serta via `ticket_code` (untuk entri manual petugas gerbang ketika kamera bermasalah atau barcode rusak sesuai PRD §4.5).
  2. *Authoritative Permission & Event Scope Check:* `assertScanPermission` memvalidasi bahwa petugas pemindai terautentikasi, berstatus aktif (`status === 'ACTIVE'`), dan memiliki izin `SCAN_TICKET` atau `CHECK_IN_TICKET` pada event pos pemindaian. Apabila tiket yang dipindai bukan milik event pos pemindaian, server secara aman mengembalikan status `WRONG_EVENT` dengan pesan jelas alih-alih melempar error otorisasi sistem.
  3. *Ineligibility & Payment Enforcement:* Validasi status tiket menolak tiket yang sudah digunakan (`ALREADY_USED`), dibatalkan (`CANCELLED`), dicabut (`REVOKED`), atau status non-aktif lainnya (`INVALID`). Validasi pesanan server-authoritative (`orderOfTicket`) menolak tiket yang belum lunas (`order.status !== 'PAID'`) dengan status `PAYMENT_REQUIRED`.
  4. *Atomic One-Time Check-In & Concurrency Safety:* Pada `recordCheckIn`, transaksi PostgreSQL menggunakan penguncian baris atomik `SELECT status FROM tickets WHERE id = $1 FOR UPDATE` untuk mencegah double check-in konkuren, menyisipkan record ke tabel `check_ins` (`ON CONFLICT (ticket_id) DO NOTHING`), memperbarui status tiket ke `'used'`, dan mencatat riwayat ke `scan_logs` secara atomik dalam satu transaksi database.
  5. *Dukungan Kontrak Attendee List untuk Developer 3:* Pada endpoint `listEventAttendees`, data disortir dengan `PAID` terlebih dahulu (`ORDER BY (CASE WHEN eo.status = 'PAID' THEN 0 ELSE 1 END), t.purchased_at DESC`) serta menyertakan `registration_number` (stabil dari `order_number` atau `ticket_code`), `order_id`, dan `payment_status` guna memenuhi kontrak data dan ekspor peserta milik Developer 3 tanpa merusak backward compatibility.
  6. *UI Permission Denial & State Feedback:* Pada `ScannerScreen`, disediakan tampilan visual penolakan izin kamera (`_buildCameraPermissionDenied`) dengan tombol coba lagi terakses (accessible retry), indikator loading selama pemrosesan scan, serta penanganan status hasil scan pada `ScanResultScreen` yang mendukung status `VALID`, `ALREADY_USED`, `WRONG_EVENT`, `PAYMENT_REQUIRED`, `CANCELLED`, dan `REVOKED`.
  7. *Keamanan Data & Pencegahan Kebocoran Token:* Tidak ada bearer token mentah yang dicatat ke dalam log maupun diekspos ke respons publik. Verifikasi token QR di backend dilakukan menggunakan constant-time comparison hash SHA-256.
- **Ringkasan dan fitur selesai:**
  1. Validasi QR scanner dan online check-in server-authoritative dengan pencegahan check-in ganda, validasi status pembayaran, dan kesesuaian event.
  2. Pemeriksaan izin staf berlingkup event (`SCAN_TICKET` / `CHECK_IN_TICKET`) dan penolakan aktor non-staf/non-aktif.
  3. Transaksi atomik check-in dengan penguncian baris `SELECT FOR UPDATE` dan pencatatan riwayat `scan_logs`.
  4. Penyempurnaan `listEventAttendees` dengan stable registration number dan pengurutan `PAID` terlebih dahulu untuk konsumsi Developer 3.
  5. State UI pemindai Flutter lengkap: status izin kamera dengan retry, indikator loading, dan tampilan detail hasil pemindaian yang komprehensif.
  6. Unit test backend lengkap (20 tests) dan widget test Flutter (8 tests).
- **Files created:**
  - `backend/test/checkin_rules.test.js`
- **Files changed:**
  - `backend/src/controllers/checkInController.js`
  - `apps/lib/features/scanner/screens/scan_result_screen.dart`
  - `apps/lib/features/scanner/screens/scanner_screen.dart`
  - `apps/test/features/organizer/operations/attendee_access_widget_test.dart`
- **Files deleted:** Tidak ada.
- **Database/schema/migration:** Tidak ada perubahan skema atau migrasi database baru. Seluruh logika validasi, transaksi atomik, dan izin check-in berjalan di atas skema PostgreSQL/Prisma yang telah ada (`tickets`, `check_ins`, `scan_logs`, `event_members`, `event_member_permissions`).
- **API request-response & data model:**
  - `POST /api/tickets/validate`: Menerima `{ ticket_code, token, event_id }`. Mengembalikan `{ success: true, valid: boolean, status: ScanResult, message: string, ticket: object|null }`.
  - `POST /api/check-ins`: Menerima `{ ticket_id, ticket_code, token, event_id }`. Mengembalikan `{ success: true, message: string, check_in: object, ticket: object }` (HTTP 201) atau menolak duplikat (HTTP 409).
  - `GET /api/events/:eventId/attendees`: Menghasilkan daftar peserta berurutan `PAID` terlebih dahulu dengan field `registration_number`, `order_number`, `order_id`, dan `payment_status`.
- **Dependencies/config:** Tidak ada dependensi baru pada `package.json` maupun `pubspec.yaml`.
- **Tests command/result PASS/FAIL/SKIP/NOT RUN + evidence:**
  - `cd backend && node --test test/checkin_rules.test.js`: **PASS (20/20 tests passed, 0 failed)**
  - `cd backend && npm test`: **PASS (109/109 tests passed, 0 failed, 100% lulus)**
  - `cd backend && npm run test:sync-config`: **PASS (14/14 tests passed, 0 failed)**
  - `cd backend && npm run check`: **PASS (Syntax OK: 61 JavaScript files checked)**
  - `cd backend && npm run format:check`: **PASS (Formatting check passed)**
  - `cd backend && npm run validate:skills`: **PASS (Validated 7 skills and links in 8 Markdown files)**
  - `cd apps && flutter analyze --no-pub --no-fatal-infos`: **PASS (No issues found!)**
  - `cd apps && flutter test test/features/organizer/operations/attendee_access_widget_test.dart --no-pub`: **PASS (8/8 tests passed, 0 failed)**
  - `cd apps && flutter test --no-pub`: **PASS (182/182 tests passed, 0 failed, 100% lulus)**
  - `cd apps && flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=false --no-pub`: **PASS (11/11 tests passed, 0 failed)**
  - Kamera fisik langsung dan database remote: **NOT RUN (lingkungan pengujian lokal/CI, diverifikasi penuh via test harness sintetis dan widget tester)**
- **Errors/open issues/owner requests:** Tidak ada error atau masalah terbuka pada cakupan Developer 2.
- **Conflict risk/integration instructions:** Nol. Perubahan dilakukan secara terisolasi pada allow-list Developer 2 Tahap 2 (`checkInController.js`, `scan_result_screen.dart`, `scanner_screen.dart`, `attendee_access_widget_test.dart`). Kontrak DTO `listEventAttendees` telah diperkaya untuk kebutuhan presentation/export Developer 3 tanpa merusak field existing.
- **PRD/task criteria ID → PASS/FAIL/BLOCKED + evidence:**
  - *Valid eligible paid ticket scans once and shows confirmation:* **PASS** (teruji di `checkin_rules.test.js` tes 17 & 19, `attendee_access_widget_test.dart` tes 7)
  - *Repeat, wrong-event, unpaid, revoked/unpermitted/unauthorized fail; no success offline:* **PASS** (teruji di `checkin_rules.test.js` tes 6, 7, 10, 13, 14, 15, 16, 18)
  - *No token leakage in logs/UI beyond required scan payload:* **PASS** (teruji di `checkin_rules.test.js` tes 9, verifikasi `presentScanTicket` yang mengecualikan `token_hash`)
  - *Permission/camera/API denial has retryable accessible state:* **PASS** (teruji di `attendee_access_widget_test.dart` tes 2, 4, 8)
- **Integration handoff:** Interface validasi dan check-in online telah stabil dan siap terintegrasi penuh dengan alur manajemen peserta dan laporan Admin (Developer 3) serta verifikasi integrasi akhir (Developer 4).
