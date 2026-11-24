# TUGAS DEVELOPER 3 — TAHAP 3 (FASE 1)

- **Peran:** Developer 3 — Peserta, Export, Back-office Organizer, Konsol Admin.
- **Fase:** FASE 1, berjalan **paralel** dengan Developer 2.
- **Branch:** `Developer-3-T3`.
- **Mulai:** setelah membaca dokumen ini; tidak menunggu Developer 1.
- **Selesai:** seluruh task T3-D3-01…T3-D3-09 + laporan + bukti perintah.
- **Otorisasi:** perintah pemilik proyek kepada Developer 3 adalah otorisasi implementasi.

> Dokumen ini dapat langsung dipakai sebagai instruksi kerja. Tidak perlu membaca ulang laporan analisis utama kecuali untuk memperjelas temuan.

---

## 1. Tujuan pekerjaan

Menyelesaikan seluruh alur **peserta → export → order/revenue Organizer → konsol Admin** sehingga:

1. Setiap layar memakai API nyata pada `MOCK_MODE=false`.
2. Tidak ada data mock, `evt-1001`, `org-001`, angka fee 2.500, atau angka statistik hardcoded pada alur produksi.
3. Daftar peserta dan export memakai set/urutan yang sama (paid-first lalu nomor registrasi).
4. Aksi Admin (suspend, settings, paket) tercatat di audit log; fee/komisi mengikuti keputusan produk (read-only).
5. Seluruh perilaku di atas terbukti dengan test backend/Flutter dan bukti perintah.

---

## 2. Kondisi awal proyek yang relevan

### 2.1 Baseline

- Commit: `78e19f0` (`update/featur`).
- `cd backend; npm test` → **PASS 163 test**.
- `cd apps; flutter analyze --no-pub` → **0 issue**.
- `cd apps; flutter test --no-pub` → **PASS 238 test**.

Jalankan ulang baseline di branch Anda dan catat hasilnya.

### 2.2 Yang sudah tersedia (jangan dibangun ulang)

| Komponen | Bukti |
|---|---|
| Endpoint peserta | `GET /api/events/:eventId/attendees` — paid-first, `registration_number`, `payment_status`, `custom_fields` |
| Endpoint export | `GET /api/events/:id/attendees/export` — CSV + escaping |
| Endpoint order event | `GET /api/events/:id/orders` |
| Admin akun | `GET /api/admin/accounts`, `PUT /api/admin/accounts/:id/status` |
| Admin audit | `GET /api/admin/audit-logs` |
| Admin settings | `GET /api/admin/settings`, `PUT /api/admin/settings/:key` |
| Admin overview | `GET /api/admin/overview` |
| Admin subscriptions | `GET /api/admin/subscriptions` |
| Admin plans | `GET /api/plans/admin/all`, `POST/PUT/DELETE /api/plans/admin*` |
| Revenue | `/api/revenue/me`, `/api/revenue/admin/summary`, `/api/revenue/admin/transactions` |
| Organizer metrics | `/api/organizer/overview`, `/api/organizer/events/summaries` |
| Support | `/api/support-reports` + status/priority/reply/internal-note |
| Notifikasi | `/api/notifications`, `/:id/read`, `/read-all` |
| Layanan Admin | `admin_audit_log_service`, `admin_settings_service`, `admin_subscription_service` sudah punya cabang API |

### 2.3 Gap yang harus diselesaikan D3

| # | Gap | File/bukti | Target |
|---|---|---|---|
| D3-G1 | `AdminRevenueService` 100% in-memory | `admin_revenue_service.dart` | Rewrite API |
| D3-G2 | `AdminPackageService` 100% in-memory | `admin_package_service.dart` | Rewrite API |
| D3-G3 | `OrganizerPlansService` 100% in-memory | `organizer_plans_service.dart` | Rewrite API / read-only C-03 |
| D3-G4 | Export peserta dibuat lokal | `attendee_list_screen.dart` → `_repo.exportAttendeesCsv` | Pakai endpoint export |
| D3-G5 | Report Organizer fallback ke mock | `organizer_operations_repository.dart` `catch (_) { return getEventReport(...) }` | Hapus fallback |
| D3-G6 | Admin audit/settings fallback diam-diam | `admin_audit_log_service.dart:141-142`, `admin_settings_service.dart:81-82` | Error state |
| D3-G7 | Dashboard Admin memakai `fallbackRevenue`/konstanta | `admin_dashboard_screen.dart:63-87` | API saja |
| D3-G8 | Moderasi default `pendingReview` + approve/reject | `event_moderation_screen.dart:38, 335, 403` | Suspend/restore saja |
| D3-G9 | Notifikasi fallback mock | `organizer_notifications_service.dart:101` | Error state |
| D3-G10 | Organizer dashboard `org-001` hardcoded | `organizer_dashboard_screen.dart:46` | AuthProvider |
| D3-G11 | `OrganizerOperationsRepository` mock selalu diinisialisasi | `organizer_operations_repository.dart:218, 236-348` | Mock hanya MOCK_MODE |
| D3-G12 | Judul event default `Tech Innovation Summit 2026` | `attendee_list_screen.dart:99` | Data event nyata |
| D3-G13 | Aksi langganan Admin lokal (suspend/extend/activate) tanpa endpoint | `subscription_management_screen.dart` | Read-only bila tidak didukung |
| D3-G14 | FAQ support menyebut mode offline | `organizer_support_service.dart` | Perbaiki teks |
| D3-G15 | Belum ada test regresi D3 di Tahap 3 | `apps/test/**` | Test baru |

> Temuan baru wajib ditambahkan ke laporan dengan file/baris.

### 2.4 Yang bukan tanggung jawab D3

- `app_router.dart`, `app.dart`, `routes/app_routes.dart` (D1).
- `backend/src/app.js` (D1).
- `pubspec.yaml` (D1).
- `README.md`, `docs/**`, `backend/README.md` (D1).
- Tiket, QR, scanner, check-in, membership staff (D2).
- Event lifecycle/publish/public link (D1).

---

## 3. Fitur yang harus dikerjakan

### T3-D3-01 — Audit awal & bukti baseline

**Pekerjaan:**
1. Jalankan baseline:
   ```powershell
   cd backend; npm test
   cd apps; flutter analyze --no-pub
   cd apps; flutter test --no-pub
   ```
2. Verifikasi D3-G1…D3-G15.
3. Cari mock/hardcoded pada file D3:
   ```powershell
   Get-ChildItem apps/lib/features/admin,apps/lib/features/reports,apps/lib/features/notifications,apps/lib/features/organizer/operations,apps/lib/features/organizer/shell,apps/lib/features/organizer/plans,apps/lib/features/organizer/support,apps/lib/services/admin,apps/lib/services/organizer_operations,apps/lib/services/organizer_plans,apps/lib/services/organizer_support,apps/lib/services/organizer_notifications,apps/lib/services/organizer_shell,apps/lib/services/report,apps/lib/services/notification -Recurse -Include *.dart |
     Select-String -Pattern "mock|evt-1001|org-001|2\.500|2500|dummy|in-memory"
   ```
4. Catat daftar gap final di laporan §2.

**Kriteria:** baseline tercatat; daftar gap final tersedia.

---

### T3-D3-02 — Daftar & detail peserta

**Tujuan:** Organizer melihat peserta nyata, paid-first, dengan nomor registrasi dan status jelas.

**File:**
- `apps/lib/features/organizer/screens/attendee_list_screen.dart`
- `apps/lib/features/organizer/operations/organizer_attendee_detail_screen.dart`
- `apps/lib/services/organizer_operations/organizer_operations_repository.dart`
- test baru `apps/test/features/organizer/operations/attendee_operations_tahap3_test.dart`

**Pekerjaan:**
1. Hapus default `'Tech Innovation Summit 2026'` dan konteks owner hardcoded. Judul event dari data event yang dipilih.
2. Event dipilih dari daftar event Organizer (bukan `evt-1001`). Bila belum ada event → empty state.
3. Muat peserta dari API:
   - `refreshAttendeesFromApi(eventId)` atau service khusus,
   - tampilkan loading/error/empty,
   - **jangan** menampilkan data mock bila API gagal.
4. Tampilkan paid-first:
   - kelompok `PAID` lebih dahulu,
   - dalam kelompok, `order_number` menaik,
   - badge status pembayaran/order/tiket,
   - `registration_number` terlihat.
5. Filter/pencarian di server bila endpoint mendukung; bila tidak, filter lokal **hanya** pada data API yang sudah dimuat (bukan data mock).
6. Detail peserta menampilkan:
   - data peserta, event, kategori, order number, registration number,
   - status pembayaran/order/tiket,
   - `custom_fields` (label dari `attendee_fields` event),
   - waktu check-in.
7. Permission:
   - `VIEW_PARTICIPANTS` untuk daftar/detail,
   - `EXPORT_PARTICIPANTS` untuk tombol export,
   - tanpa permission → state akses ditolak.
8. Sembunyikan tombol “Registrasi Terbantu” (non-MVP). Jangan hapus layarnya.
9. Jangan memakai `OrganizerMembershipContext.owner` hardcoded; gunakan konteks membership nyata.

**Kriteria:**
- K1 Response memuat `order_number`, `registration_number`, `payment_status`.
- K2 Order `PENDING` tampil setelah `PAID`.
- K3 Urutan dalam kelompok = `order_number` menaik.
- K4 Staff tanpa `VIEW_PARTICIPANTS` → 403.
- K5 Tidak ada `evt-1001`/judul default pada alur produksi.
- K6 Test backend + widget PASS.

---

### T3-D3-03 — Export CSV

**Tujuan:** export berasal dari endpoint server dan identik dengan layar.

**File:**
- `apps/lib/features/organizer/screens/attendee_list_screen.dart`
- `apps/lib/services/organizer_operations/organizer_operations_repository.dart` (hapus export lokal)
- test baru `apps/test/features/organizer/operations/attendee_export_tahap3_test.dart`

**Pekerjaan:**
1. Ganti `_repo.exportAttendeesCsv(...)` dengan pemanggilan `GET /api/events/:id/attendees/export` memakai `ApiClient` + JWT.
2. Verifikasi:
   - jumlah baris = jumlah peserta pada layar (dengan filter yang sama),
   - urutan identik,
   - header kolom sesuai kontrak,
   - escaping koma/kutip/newline dan formula injection (`=`, `+`, `-`, `@`) dilakukan server.
3. UI export:
   - loading saat mengunduh,
   - error + retry bila gagal,
   - preview isi CSV + tombol salin,
   - di Web: unduh file CSV bila memungkinkan (tanpa dependency baru; gunakan conditional import `dart:html`/`dart:io` yang aman),
   - di Android: simpan ke clipboard + tampilkan preview; catat keterbatasan di laporan bila file save belum tersedia.
4. Hapus method `exportAttendeesCsv` lokal setelah tidak ada pemakai; jangan hapus kelas/model.
5. Permission `EXPORT_PARTICIPANTS` wajib; tanpa permission → 403/akses ditolak.
6. Jangan membuat CSV dari data mock.

**Kriteria:**
- K1 CSV berasal dari endpoint.
- K2 Isi/urutan identik dengan layar.
- K3 Formula injection aman.
- K4 Permission dicek.
- K5 Bukti file CSV/preview dilampirkan.
- K6 Test widget/backend PASS.

---

### T3-D3-04 — Order & revenue Organizer

**Tujuan:** Organizer melihat order/pembayaran dan laporan dari data server, tanpa fallback mock.

**File:**
- `apps/lib/features/organizer/screens/organizer_order_list_screen.dart`
- `apps/lib/features/organizer/operations/organizer_report_screen.dart`
- `apps/lib/features/organizer/screens/organizer_dashboard_screen.dart`
- `apps/lib/services/organizer_operations/organizer_operations_repository.dart`
- `apps/lib/services/organizer_shell/organizer_shell_service.dart`
- test baru `apps/test/features/organizer/operations/organizer_report_tahap3_test.dart`

**Pekerjaan:**
1. Order list:
   - `eventId` wajib; event dipilih dari daftar event Organizer,
   - `GET /api/events/:id/orders`,
   - tampilkan order number, peserta, kategori, nominal, status payment/order, metode, waktu,
   - filter status/tanggal + pencarian,
   - pagination bila tersedia,
   - detail order (dialog/screen) tanpa data mock,
   - error + retry; empty state.
2. Report Organizer:
   - gunakan `/api/events/:id/summary`, `/api/revenue/me`, `/api/organizer/overview`,
   - **hapus** `catch (_) { return getEventReport(eventId); }`,
   - jangan menghitung komisi/fee lokal (5%/2.500); tampilkan nilai server,
   - filter periode,
   - loading/error/empty.
3. Dashboard Organizer:
   - hapus `getDashboardMetrics('org-001')`; gunakan user dari `AuthProvider`,
   - metrik dari `/organizer/overview` + `/organizer/events/summaries`,
   - tidak ada angka konstanta,
   - error state bila API gagal.
4. `OrganizerShellService` hanya API; mock hanya `MOCK_MODE=true`.
5. Pastikan nominal uang diformat konsisten (Rp, ribuan) dan tidak overflow.

**Kriteria:**
- K1 Order per event tampil dengan status nyata.
- K2 Tidak ada fallback mock saat API gagal.
- K3 Angka revenue/komisi/fee berasal dari API.
- K4 Tidak ada `org-001`.
- K5 Widget test + backend test PASS.

---

### T3-D3-05 — Admin akun, audit, settings

**Tujuan:** Admin mengelola akun, melihat audit, dan mengubah settings dengan batas produk yang jelas.

**File:**
- `apps/lib/features/admin/screens/account_management_screen.dart`
- `apps/lib/features/admin/screens/audit_log_screen.dart`
- `apps/lib/features/admin/screens/admin_settings_screen.dart`
- `apps/lib/services/admin/admin_audit_log_service.dart`
- `apps/lib/services/admin/admin_settings_service.dart`
- `backend/src/controllers/adminController.js`
- `backend/src/controllers/auditLogController.js`
- `backend/src/controllers/platformSettingsController.js`
- `backend/src/utils/auditLog.js`
- test baru `backend/test/admin_tahap3_governance.test.js`, `apps/test/features/admin/**` (perluasan)

**Pekerjaan:**
1. Akun:
   - hapus fallback `_accounts = List.from(_mockAccounts)` saat API gagal,
   - tampilkan loading/error/empty,
   - daftar akun + metrik event/order,
   - suspend wajib alasan (minimal 5 karakter) + konfirmasi,
   - aktivasi akun,
   - setiap aksi menulis audit (`SUSPEND_ACCOUNT`/`ACTIVATE_ACCOUNT`),
   - pagination/pencarian.
2. Audit log:
   - hapus fallback lokal (`catch` → cache),
   - filter aktor/aksi/entity/tanggal,
   - pagination,
   - tampilkan alasan dan detail,
   - error + retry.
3. Settings:
   - hapus fallback default saat API gagal,
   - `service_fee` = 5.000 dan `commission_rate` = 5% **read-only** selama C-01,
   - key lain dapat diubah via `PUT /api/admin/settings/:key`,
   - setiap perubahan menulis `platform_setting_history` + audit,
   - tampilkan history,
   - validasi tipe/nilai,
   - jangan menampilkan 2.500.
4. Backend:
   - pastikan suspend tanpa alasan → 400,
   - pastikan perubahan fee/komisi ditolak dengan pesan keputusan produk belum final,
   - pastikan audit/settings hanya admin.
5. Jangan mengubah skema; bila butuh kolom baru → proposal.

**Kriteria:**
- K1 Suspend tanpa alasan → 400.
- K2 Setelah suspend, `audit_logs` bertambah dengan aktor & alasan.
- K3 Audit log dapat difilter & dipaginasi.
- K4 Perubahan setting menulis history.
- K5 Fee/komisi read-only.
- K6 Tidak ada 2.500 pada UI.
- K7 Test backend + widget PASS.

---

### T3-D3-06 — Admin dashboard, revenue, paket, langganan

**Tujuan:** seluruh konsol bisnis Admin memakai API, tanpa angka konstanta.

**File:**
- `apps/lib/features/admin/screens/admin_dashboard_screen.dart`
- `apps/lib/features/admin/screens/transaction_revenue_screen.dart`
- `apps/lib/features/admin/screens/package_management_screen.dart`
- `apps/lib/features/admin/screens/subscription_management_screen.dart`
- `apps/lib/services/admin/admin_revenue_service.dart`
- `apps/lib/services/admin/admin_package_service.dart`
- `apps/lib/services/admin/admin_subscription_service.dart`
- `apps/lib/models/admin/**`
- `backend/src/controllers/adminOverviewController.js`
- `backend/src/controllers/revenueController.js`
- `backend/src/controllers/planController.js`
- `backend/src/controllers/subscriptionController.js`
- test baru `backend/test/organizer_revenue_tahap3.test.js`, `apps/test/features/admin/**` (perluasan)

**Pekerjaan:**
1. Dashboard Admin:
   - hapus `fallbackRevenue` dan angka konstanta (`admin_dashboard_screen.dart:38-43, 63-87, 643-676`),
   - semua kartu/grafik dari `/api/admin/overview`,
   - filter periode `from`/`to`,
   - loading/error/empty,
   - tidak ada data mock saat API gagal.
2. Revenue Admin:
   - tulis ulang `AdminRevenueService` memakai `/api/revenue/admin/summary` dan `/api/revenue/admin/transactions`,
   - filter periode/pencarian,
   - tampilkan gross, komisi, service fee, net sesuai server,
   - jangan menghitung ulang payout.
3. Paket:
   - tulis ulang `AdminPackageService` memakai `/api/plans/admin/all` + CRUD,
   - validasi form (nama, harga, limit),
   - setiap perubahan menulis audit,
   - jangan menampilkan jumlah subscriber palsu bila tidak ada di API.
4. Langganan:
   - daftar dari `/api/admin/subscriptions`,
   - detail/status,
   - aksi perpanjangan/aktivasi/suspend hanya bila endpoint tersedia; bila tidak → tombol disabled + penjelasan C-03,
   - **hapus** aksi lokal yang mengubah state tanpa API.
5. Model: sesuaikan parsing JSON; jangan mengubah nama field kontrak.

**Kriteria:**
- K1 Kartu dashboard = nilai API.
- K2 Tidak ada konstanta angka bisnis pada layar.
- K3 Transaksi & ringkasan dari API.
- K4 Perubahan paket menulis audit.
- K5 Aksi langganan tidak didukung → read-only.
- K6 Test backend + widget PASS.

---

### T3-D3-07 — Admin moderasi, laporan, notifikasi, plans/support Organizer

**Tujuan:** moderasi sesuai PRD (suspend-only), laporan/notifikasi nyata, plans/support Organizer memakai API.

**File:**
- `apps/lib/features/admin/screens/event_moderation_screen.dart`
- `apps/lib/features/admin/screens/report_management_screen.dart`
- `apps/lib/features/reports/**`
- `apps/lib/features/notifications/**`
- `apps/lib/features/organizer/plans/**`
- `apps/lib/features/organizer/support/**`
- `apps/lib/features/organizer/shell/organizer_shell.dart`
- `apps/lib/services/organizer_notifications/organizer_notifications_service.dart`
- `apps/lib/services/organizer_plans/organizer_plans_service.dart`
- `apps/lib/services/organizer_support/organizer_support_service.dart`
- `apps/lib/services/report/report_service.dart`
- `apps/lib/services/notification/notification_service.dart`
- `backend/src/controllers/eventMetricsController.js`
- `backend/src/controllers/notificationController.js`
- `backend/src/controllers/reportController.js`
- test baru `apps/test/features/admin/**`, `apps/test/features/organizer/shell/**`

**Pekerjaan:**
1. Moderasi event:
   - default filter bukan `pendingReview`; gunakan semua/published/suspended,
   - hapus tombol approve/reject untuk event baru,
   - aksi hanya **Suspend** dan **Pulihkan**, keduanya wajib alasan,
   - setelah suspend: event hilang dari publik dan menolak order baru,
   - setiap aksi menulis audit,
   - endpoint lama tetap ada untuk data legacy, tetapi tidak diekspos.
2. Laporan:
   - Admin: daftar/filter, status, prioritas, balasan, catatan internal via API,
   - Organizer: gunakan `ReportService` API; hapus mock list,
   - status token ditampilkan dengan benar,
   - error/empty state.
3. Notifikasi:
   - hapus fallback `return _mockItems` saat API gagal,
   - unread count dari API,
   - mark read/all read via API,
   - shell Organizer menampilkan badge dari API,
   - error state + retry.
4. Plans Organizer:
   - katalog dari `/api/plans`,
   - langganan dari `/api/subscriptions/me`,
   - transaksi dari `/api/subscriptions/payments`,
   - C-03: jangan membuat paywall/entitlement; pembelian hanya bila endpoint & aturan tersedia; bila tidak → read-only,
   - hapus `_mockTransactions` dan `_currentSubscription` palsu.
5. Support Organizer:
   - daftar/keluhan dari `ReportService` API,
   - FAQ: hapus jawaban yang menyebut mode offline (Post-MVP),
   - form keluhan memakai API.
6. Jangan mengubah skema/permission.

**Kriteria:**
- K1 Suspend tanpa alasan → 400; dengan alasan → `SUSPENDED` + audit.
- K2 Event suspended tidak muncul publik; order baru ditolak.
- K3 Notifikasi dari API; unread konsisten.
- K4 Laporan Admin/Organizer berjalan pada data nyata.
- K5 Plans/support tidak memakai mock.
- K6 Test backend + widget PASS.

---

### T3-D3-08 — Konsolidasi repository operasional & pembersihan mock

**Tujuan:** repository operasional hanya memuat data API; mock hanya untuk `MOCK_MODE=true`; jalur mati dihapus.

**File:**
- `apps/lib/services/organizer_operations/organizer_operations_repository.dart`
- `apps/lib/services/mock/mock_attendee_repository.dart`
- `apps/lib/features/organizer/operations/assisted_registration_screen.dart` (tidak diekspos)
- test baru/perluasan `apps/test/features/organizer/operations/**`

**Pekerjaan:**
1. Hapus `_initMockAttendees()` dari jalur API; mock hanya diinisialisasi bila `MOCK_MODE=true`.
2. Hapus fallback diam-diam:
   - `catch (_) { return getEventReport(...) }`,
   - `catch` yang mengembalikan data mock,
   - data mock yang tetap tampil setelah API gagal.
3. Setelah D2 mengonfirmasi `OrganizerScannerScreen` tidak lagi memakai repository:
   - hapus method scanner mock, offline queue, `syncOfflineQueue`,
   - hapus method assisted registration dari alur (layar tetap ada, tidak diekspos),
   - hapus `evt-1001` dan fixture terkait.
4. Jangan menghapus kelas model yang masih dipakai layar.
5. Pastikan `mock_attendee_repository.dart` hanya dipakai `MOCK_MODE=true`.
6. Cari sisa `mock|evt-1001|org-001|2500` pada file D3 dan lampirkan hasil.

**Kriteria:**
- K1 Tidak ada data mock pada `MOCK_MODE=false`.
- K2 Tidak ada jalur mati scanner/offline/assisted yang dipanggil.
- K3 `flutter analyze` dan `flutter test` PASS setelah penghapusan.
- K4 Bukti grep dilampirkan.

---

### T3-D3-09 — Regresi, bukti bebas mock, dan laporan

**Pekerjaan:**
1. Tambah test regresi minimal:
   - daftar peserta paid-first + nomor registrasi,
   - export identik layar + escaping formula,
   - order per event,
   - revenue/overview dari API,
   - suspend akun + audit,
   - settings + history,
   - suspend event + audit + hilang dari publik,
   - laporan Admin/Organizer,
   - notifikasi API,
   - paket CRUD + audit.
2. Jalankan:
   ```powershell
   cd backend; npm test
   cd backend; npm run check
   cd backend; npm run format:check
   cd apps; flutter analyze --no-pub
   cd apps; flutter test --no-pub
   cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart
   ```
3. Tulis laporan sesuai §11.

**Kriteria:** seluruh perintah PASS; tidak ada mock aktif pada `MOCK_MODE=false`; laporan lengkap.

---

## 4. Daftar file dan folder tanggung jawab

Ringkasan (detail ada di `FILE_OWNERSHIP.md` Bagian 3):

**Backend**
```
backend/src/controllers/adminController.js
backend/src/controllers/auditLogController.js
backend/src/controllers/platformSettingsController.js
backend/src/controllers/adminOverviewController.js
backend/src/controllers/planController.js
backend/src/controllers/subscriptionController.js
backend/src/controllers/revenueController.js
backend/src/controllers/reportController.js
backend/src/controllers/notificationController.js
backend/src/controllers/eventMetricsController.js
backend/src/routes/adminRoutes.js
backend/src/routes/planRoutes.js
backend/src/routes/subscriptionRoutes.js
backend/src/routes/revenueRoutes.js
backend/src/routes/reportRoutes.js
backend/src/routes/notificationRoutes.js
backend/src/routes/organizerRoutes.js
backend/src/utils/auditLog.js
backend/src/services/notificationService.js
backend/test/admin_platform_tahap2.test.js
backend/test/event_attendees_order.test.js
backend/test/event_export.test.js
backend/test/admin_tahap3_governance.test.js
backend/test/organizer_revenue_tahap3.test.js
```

**Flutter**
```
apps/lib/features/admin/**
apps/lib/features/reports/**
apps/lib/features/notifications/**
apps/lib/features/organizer/screens/attendee_list_screen.dart
apps/lib/features/organizer/screens/organizer_order_list_screen.dart
apps/lib/features/organizer/screens/organizer_dashboard_screen.dart
apps/lib/features/organizer/operations/assisted_registration_screen.dart
apps/lib/features/organizer/operations/organizer_activity_log_screen.dart
apps/lib/features/organizer/operations/organizer_attendee_detail_screen.dart
apps/lib/features/organizer/operations/organizer_report_screen.dart
apps/lib/features/organizer/shell/**
apps/lib/features/organizer/plans/**
apps/lib/features/organizer/support/**
apps/lib/services/admin/**
apps/lib/services/organizer_operations/**
apps/lib/services/organizer_plans/**
apps/lib/services/organizer_support/**
apps/lib/services/organizer_notifications/**
apps/lib/services/organizer_shell/**
apps/lib/services/report/**
apps/lib/services/notification/**
apps/lib/services/mock/mock_attendee_repository.dart
apps/lib/providers/report_provider.dart
apps/lib/providers/notification_provider.dart
apps/lib/models/admin/**
apps/lib/models/report/**
```

**Test Flutter**
```
apps/test/features/admin/**
apps/test/features/reports/**
apps/test/features/notifications/**
apps/test/features/organizer/operations/attendee_operations_test.dart
apps/test/features/organizer/operations/attendee_operations_tahap3_test.dart
apps/test/features/organizer/operations/attendee_export_tahap3_test.dart
apps/test/features/organizer/operations/organizer_report_tahap3_test.dart
apps/test/features/organizer/shell/organizer_shell_test.dart
apps/test/features/organizer/shell/organizer_plans_and_support_test.dart
```

---

## 5. File yang tidak boleh diubah

Daftar lengkap ada di `FILE_OWNERSHIP.md` Bagian 3.4. Ringkasannya:

- **Routing/aplikasi:** `app.dart`, `app_router.dart`, `main.dart`, `routes/app_routes.dart`, `pubspec.yaml`, `pubspec.lock`, `core/**`.
- **Domain D1:** provider auth/event/order/payment; service api/auth/event/order/payment/public_event/organizer_events; fitur auth/events/home/orders/payments/public_event/registration/organizer events; model event/order/payment/user; backend event/order/payment/ticketType/auth.
- **Domain D2:** `features/tickets/**`, `scanner/**`, `check_in/**`, `staff/**`, `organizer/membership/**`, `staff_management_screen.dart`, `organizer_scanner_screen.dart`; service ticket/scanner/check_in/organizer_membership; provider check_in; model ticket/check_in; backend `checkInController.js`, `ticketController.js`, `eventInvitationController.js`, route terkait, `ticketTokenService.js`, `ticketValidator.js`.
- **Test lintas domain:** stage1/stage2 integration, app_router, widget_test, api_mode_no_fallback, helpers, test D2.
- **Dokumentasi/konfigurasi:** `README.md`, `backend/README.md`, `docs/**`, `task/**`, `.github/**`, `.githooks/**`, `backend/package.json`, `backend/package-lock.json`.
- **Database:** `backend/prisma/**`, `backend/supabase/**` (mutlak).

---

## 6. Kontrak API dan database yang harus diikuti

### 6.1 Endpoint yang dipakai

| Kebutuhan | Endpoint | Catatan |
|---|---|---|
| Daftar peserta | `GET /api/events/:eventId/attendees` | Paid-first, `registration_number` |
| Detail peserta | data dari daftar / endpoint terkait | Jangan mengarang endpoint |
| Export CSV | `GET /api/events/:id/attendees/export` | `text/csv`; escaping server |
| Order per event | `GET /api/events/:id/orders` | Filter status/tanggal |
| Summary event | `GET /api/events/:id/summary` | Revenue event |
| Revenue Organizer | `GET /api/revenue/me` | — |
| Overview Organizer | `GET /api/organizer/overview` | — |
| Summaries Organizer | `GET /api/organizer/events/summaries` | — |
| Akun Admin | `GET /api/admin/accounts`, `PUT /api/admin/accounts/:id/status` | `reason` wajib |
| Audit | `GET /api/admin/audit-logs` | Filter + pagination |
| Settings | `GET /api/admin/settings`, `PUT /api/admin/settings/:key` | Fee read-only |
| Overview Admin | `GET /api/admin/overview` | — |
| Revenue Admin | `GET /api/revenue/admin/summary`, `/admin/transactions` | — |
| Paket | `GET /api/plans`, `/api/plans/admin/all`, `POST/PUT/DELETE /api/plans/admin*` | — |
| Langganan Admin | `GET /api/admin/subscriptions` | Read-only bila aksi tidak ada |
| Langganan Organizer | `GET /api/subscriptions/me`, `/payments` | — |
| Laporan | `GET/POST /api/support-reports`, `/:id`, status/priority/reply/internal-note` | — |
| Notifikasi | `GET /api/notifications`, `/:id/read`, `/read-all` | — |
| Moderasi event | `PUT /api/admin/events/:id/moderation` | Suspend/restore + alasan |

### 6.2 DTO

Ikuti `INTEGRATION_CONTRACT.md` Bagian 3.6 dan 3.10 (Attendee, Account, Audit, Setting, Overview, Plan, Subscription, Revenue, Report, Notification). Jangan mengubah nama field.

### 6.3 Database

- **Dilarang** mengubah schema, migration, seed, atau SQL.
- Tabel relevan: `event_orders`, `order_items`, `attendees`, `order_payments`, `tickets`, `audit_logs`, `platform_settings`, `platform_setting_history`, `plans`, `subscriptions`, `platform_transactions`, `support_reports`, `notifications`.
- Query read-only untuk verifikasi diperbolehkan bila environment tersedia.
- Kebutuhan index/perubahan skema → proposal, bukan implementasi.

---

## 7. Batasan pekerjaan

1. Tidak menambah dependency; `pubspec.yaml` milik D1.
2. Tidak mengubah kontrak response/error.
3. Tidak mengubah role/permission.
4. Tidak membuat paywall/entitlement (C-03).
5. Tidak mengubah fee/komisi (C-01).
6. Tidak menghapus fitur; assisted registration disembunyikan.
7. Tidak mengedit file D1/D2.
8. Tidak menjalankan migration/seed/reset.
9. Tidak menyimpan token/secret.
10. Tidak mengklaim PASS tanpa perintah.

---

## 8. Ketentuan integrasi dengan Developer 2

1. **Tidak ada file yang sama.** D3 tidak mengedit `checkInController.js`, `ticketController.js`, `eventInvitationController.js`, route D2, atau file frontend D2.
2. **Backend peserta/export/order** berada di `checkInController.js` (milik D2). D3 hanya memakai endpoint. Bila ada bug:
   - tulis spesifikasi + bukti (request/response),
   - D2 memperbaiki bila masih FASE 1,
   - bila tidak, D1 menyelesaikan di FASE 2.
3. **Repository operasional** dimiliki D3. D3 menghapus jalur mati scanner/offline/assisted **setelah** D2 mengonfirmasi `OrganizerScannerScreen` sudah pindah ke `ScannerService`.
4. **DTO peserta** tidak boleh diubah. Field baru hanya aditif dan disepakati.
5. **Permission** tidak boleh ditukar. Peserta memakai `VIEW_PARTICIPANTS`, export `EXPORT_PARTICIPANTS`, order `VIEW_ORDERS`.
6. **Event suspended**: D3 menampilkan status dan menonaktifkan aksi order; backend tetap sumber kebenaran.

---

## 9. Pengujian wajib

### 9.1 Perintah

| Pemeriksaan | Perintah | Kriteria |
|---|---|---|
| Backend test | `cd backend; npm test` | PASS |
| Backend sintaks | `cd backend; npm run check` | PASS |
| Backend format | `cd backend; npm run format:check` | PASS |
| Flutter analyze | `cd apps; flutter analyze --no-pub` | 0 issue |
| Flutter test | `cd apps; flutter test --no-pub` | PASS |
| Mode API | `cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | PASS |

### 9.2 Skenario wajib

| ID | Skenario | Harapan | Bukti |
|---|---|---|---|
| D3-T01 | Peserta paid-first | PAID dulu, lalu order_number naik | Backend test |
| D3-T02 | Nomor registrasi stabil | Sama sebelum/sesudah bayar | Backend test |
| D3-T03 | Export = layar | Jumlah/urutan identik | Bukti CSV |
| D3-T04 | Formula injection | Diawali `'`/di-escape | Backend test |
| D3-T05 | Order per event | Status & nominal benar | Widget test |
| D3-T06 | Revenue Organizer | Angka dari API | Widget test |
| D3-T07 | Suspend akun tanpa alasan | 400 | Backend test |
| D3-T08 | Suspend akun dengan alasan | Audit bertambah | Backend test |
| D3-T09 | Settings fee | Read-only | Backend/widget |
| D3-T10 | Settings lain | History bertambah | Backend test |
| D3-T11 | Dashboard Admin | Angka = API | Widget test |
| D3-T12 | Paket CRUD | API + audit | Backend test |
| D3-T13 | Langganan tidak didukung | Read-only | Widget test |
| D3-T14 | Suspend event | Hilang publik + order ditolak | Backend test |
| D3-T15 | Notifikasi API gagal | Error + retry | Widget test |
| D3-T16 | Laporan Admin/Organizer | Status/balasan nyata | Widget/backend |
| D3-T17 | Mode API gagal | Tidak ada mock | Widget test |
| D3-T18 | Layout 360/1280 | Tidak overflow | Widget test |

### 9.3 Bukti bebas mock

```powershell
Get-ChildItem apps/lib/features/admin,apps/lib/features/reports,apps/lib/features/notifications,apps/lib/features/organizer/operations,apps/lib/features/organizer/shell,apps/lib/features/organizer/plans,apps/lib/features/organizer/support,apps/lib/services/admin,apps/lib/services/organizer_operations,apps/lib/services/organizer_plans,apps/lib/services/organizer_support,apps/lib/services/organizer_notifications,apps/lib/services/organizer_shell,apps/lib/services/report,apps/lib/services/notification -Recurse -Include *.dart |
  Select-String -Pattern "mock|evt-1001|org-001|2500|2\.500|dummy|in-memory"
```

Lampirkan output dan penjelasan setiap temuan.

---

## 10. Kriteria selesai

- [ ] T3-D3-01…T3-D3-09 selesai.
- [ ] Seluruh kriteria K pada setiap task terpenuhi.
- [ ] `npm test`, `npm run check`, `npm run format:check` PASS.
- [ ] `flutter analyze` 0 issue; `flutter test` PASS.
- [ ] `MOCK_MODE=false` test PASS.
- [ ] Tidak ada `evt-1001`, `org-001`, `2.500`, atau mock aktif pada alur produksi D3.
- [ ] Tidak ada file D1/D2 yang diubah.
- [ ] Tidak ada schema/migration/seed yang diubah.
- [ ] Laporan lengkap dan dapat dibaca D1 tanpa bertanya.
- [ ] Daftar permintaan integrasi untuk D1 tersedia.
- [ ] Branch sudah rebase dan siap di-merge.

---

## 11. Format laporan hasil pekerjaan

Buat `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_3.md` dengan struktur berikut. Nomor heading **di dalam blok** adalah struktur file laporan, bukan lanjutan nomor dokumen ini.

```markdown
# Laporan Tahap 3 — Developer 3 (FASE 1)

- Status: DONE / PARTIAL / BLOCKED
- Branch: Developer-3-T3
- Baseline commit:
- Commit akhir:
- PR: <link/ID>

## 1. Ringkasan
## 2. Baseline & temuan awal
| ID | Temuan | File | Status awal | Status akhir |

## 3. Hasil per task
### T3-D3-01 ...
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
| Android | | |
| Email | | |

## 9. Permintaan integrasi untuk Developer 1
| # | Kebutuhan | File | Alasan | Usulan |

## 10. Catatan untuk Developer 2
## 11. Pernyataan kepatuhan
- [ ] Tidak mengubah schema/migration/seed
- [ ] Tidak mengedit file D1/D2
- [ ] Tidak ada secret/token di laporan
```

---

## 12. Permintaan integrasi yang sudah diketahui (untuk D1)

D3 tidak mengedit router. Daftar berikut **wajib** disalin/diperbarui di laporan:

| # | Kebutuhan | File target | Detail |
|---|---|---|---|
| 1 | Route `/organizer/events/:id/orders` | `app_router.dart` | Belum ada; tambahkan `OrganizerOrderListScreen(eventId:)` |
| 2 | `/organizer/events/:id/attendees` meneruskan `eventId` | `app_router.dart` | Saat ini `const AttendeeListScreen()` tanpa `eventId` |
| 3 | Navigasi dari detail event ke daftar peserta/order | `organizer_event_detail_screen.dart` | Tombol/menu baru |
| 4 | `/organizer/events/:id/scanner` memakai konteks membership nyata | `app_router.dart` | Saat ini owner hardcoded |
| 5 | `/admin/*` guard untuk role admin | `app_router.dart` | Sudah ada; verifikasi |
| 6 | Hapus fallback `evt-1001` pada router | `app_router.dart` | Tampilkan error state |
| 7 | Dokumentasi endpoint peserta/export/order/admin | `backend/README.md` | D1 mengisi dari laporan D3 |
| 8 | Dokumentasi fee 5.000/5% read-only | `docs/ARCHITECTURE.md` | D1 |

---

## 13. Jebakan yang harus dihindari

1. **Mengedit `checkInController.js` untuk memperbaiki attendee/export.** Dilarang; itu milik D2. Laporkan.
2. **Mengedit `app_router.dart`.** Dilarang; catat kebutuhan.
3. **Menampilkan data mock setelah API gagal.** Harus error + retry.
4. **Menghitung komisi/payout lokal.** Gunakan nilai server.
5. **Menampilkan fee 2.500.** Nilai CONFIRMED adalah 5.000 + 5%, dan read-only.
6. **Membuat aksi langganan lokal.** Bila endpoint tidak ada, read-only.
7. **Mengaktifkan kembali approve/reject event.** PRD: auto-publish + suspend-only.
8. **Menghapus field lama pada response peserta.** Hanya boleh menambah.
9. **Menganggap test otomatis sebagai bukti UI nyata.** Sertakan bukti manual/CSV.
10. **Menghapus file test di `apps/test`/`backend/test`.** Dilarang.








