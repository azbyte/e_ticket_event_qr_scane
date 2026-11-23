# Audit Aktual & Rekonsiliasi Roadmap Final

- **Tanggal audit:** 2026-11-23
- **Objek:** repository `e_ticket_event_qr_scane` (Flutter `apps/`, backend Express `backend/`), schema/migration Prisma, dokumen PRD v2.2, seluruh rencana/laporan Tahap 1–3, dan source code aktual.
- **Sifat pekerjaan:** audit + perencanaan ulang. **Tidak ada** perubahan source code, schema, migration, data, route, atau fitur pada pekerjaan ini.
- **Dokumen yang menggantikan rencana lama:** [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md), [`TAHAP_2/RENCANA_KERJA.md`](TAHAP_2/RENCANA_KERJA.md), [`TAHAP_3/RENCANA_KERJA.md`](TAHAP_3/RENCANA_KERJA.md).
- **Status dokumen lama:** `TAHAP_2/RENCANA_KERJA.md` dan `TAHAP_3/RENCANA_KERJA.md` versi 2026-11-23 sebelumnya sudah **tidak relevan** karena mengasumsikan sebagian besar pekerjaan Tahap 2 hanya "verifikasi endpoint". Audit ini membuktikan banyak gap inti justru belum memiliki penanggung jawab.

## 0. Metode dan bukti yang dijalankan

| Bukti | Perintah/metode | Hasil |
|---|---|---|
| Test backend | `cd backend; npm test` | **PASS 89/89** (dijalankan ulang sesi ini) |
| Analisis Flutter | `cd apps; flutter analyze --no-pub` | **PASS**, `No issues found` (dijalankan ulang sesi ini) |
| Test Flutter | `cd apps; flutter test --no-pub` | **PASS 188/188** (dijalankan ulang sesi ini) |
| Schema/migration/database | `task/DATABASE_AUDIT_FINAL.md` (2026-11-23) | 32 tabel, 19 enum, 54 FK, 105 index, 9 migration, 0 drift, smoke DB 14/14 |
| Inventaris route/controller | Pembacaan `backend/src/app.js`, seluruh `src/routes/*`, `src/controllers/*`, `src/services/*` | Route aktual dipetakan pada §2 |
| Inventaris Flutter | Pembacaan `apps/lib/**` (screens, services, providers, router, pubspec) | Mock/in-memory dipetakan pada §3 |
| Pencarian mock/dummy | `Select-String` pada `apps/lib` untuk `mock|dummy|in-memory|fixture` dan pembacaan tiap service terkait | Daftar pada §3.4 |

**Batas:** audit ini **tidak** menghubungi database produksi, tidak menjalankan migration, tidak mengubah data, dan tidak menjalankan device/emulator. Klaim "verified" untuk DB mengacu pada bukti `DATABASE_AUDIT_FINAL.md` dan laporan D4 Tahap 1; klaim UI/device yang belum dijalankan ditandai **NOT RUN**.

---

## 1. Ringkasan eksekutif

1. **Fondasi backend kuat, tetapi belum menjadi aplikasi yang selesai.** Auth JWT, event/kategori, order satu tiket, pembayaran simulasi, tiket, check-in atomik, invitation, laporan dukungan, paket/langganan, dan revenue sudah memiliki route/controller nyata. Backend 89 test lulus.
2. **Gap inti yang paling fatal: alur Participant guest tidak dapat dijalankan dari publik.** Router Flutter memaksa login pada semua route selain login/register (`apps/lib/app_router.dart:217-220`); tidak ada route `/e/:eventId`; `public_url` tidak pernah diisi backend; tombol registrasi hanya dapat dicapai setelah login. PRD §6.1/§7/AC-04 tidak terpenuhi.
3. **Auto-publish belum ada.** Event dibuat `DRAFT` (`eventController.js:210`), `submit-review` mengubah ke `PENDING_REVIEW` (`:347`), dan publikasi hanya lewat `PUT /api/admin/events/:id/moderation` (`eventMetricsController.js:119-158`). PRD §3/AC-01 terbalik: implementasi masih meminta persetujuan Admin.
4. **QR e-ticket masih gambar palsu.** `QrTicketDisplay` menggambar pola pseudo-QR (`qr_ticket_display.dart:41-73`, painter `:140-213`); `pubspec.yaml` tidak memuat library QR maupun kamera. `qrService.js` di backend tidak diimpor di mana pun. Tiket tidak dapat dipindai dari aplikasi.
5. **Scanner belum berupa kamera.** `ScannerScreen` hanya input manual + tombol simulasi (`scanner_screen.dart:130-226`), dan masih menawarkan **mode offline** (`:96-108`, `:213-226`) yang merupakan Post-MVP.
6. **Sebagian besar UI Organizer/Admin masih in-memory.** Membership, attendee list, export, laporan organizer, scanner organizer, assisted registration, accounts, audit log, settings, revenue, paket, langganan, notifikasi organizer, dan plans organizer memakai data mock (`§3.4`). Backend untuk sebagian besar domain itu **sudah ada**, sehingga pekerjaan utamanya adalah wiring + endpoint yang memang hilang.
7. **Daftar peserta dan export belum memenuhi AC-09.** Endpoint attendee hanya membaca `tickets` dan mengurutkan `purchased_at DESC` tanpa nomor registrasi (`checkInController.js:230-265`). Order pending/expired tidak muncul. Export hanya ada di repository mock.
8. **Admin governance belum nyata.** `audit_logs`, `platform_settings`, `platform_setting_history` tidak dipakai backend; tidak ada route admin audit/settings; suspend akun tidak mewajibkan alasan dan tidak menulis audit (`adminController.js:15-31`).
9. **Bug integrasi konkret:** riwayat check-in Flutter memanggil `/events/:id/check-ins` (`check_in_service.dart:116`) sedangkan backend menyediakan `/check-ins/events/:eventId/check-ins` (`checkInRoutes.js:11`) → 404 pada API mode.
10. **Rencana Tahap 2 lama tidak menutup gap di atas.** Rencana lama hanya memberi D1 invitation, D2 scanner/attendee, D3 admin/export; tidak ada owner untuk auto-publish, public link, QR nyata, kamera, audit/settings backend, revenue/paket/langganan UI, order monitoring organizer, dan notifikasi nyata.

**Kesimpulan:** proyek **belum MVP-complete**. Fondasi siap, tetapi 4 alur inti (publik → order → tiket/QR → scan; publikasi otomatis; staff E2E; admin governance) masih belum utuh.

---

## 2. Kondisi backend aktual (route & kontrak)

Route yang ter-mount di `backend/src/app.js`:

| Domain | Route aktual | Kondisi | Catatan |
|---|---|---|---|
| Auth | `POST /api/auth/register`, `/login`, `GET/PUT /me`, `POST /logout` | Nyata; role dibaca ulang dari DB tiap request (`authMiddleware.js:27-43`), token revoke dicek | Tidak ada refresh token (G-03) |
| Event | `GET /api/events/public`, `GET /` (admin), `/mine`, `/:id`, `/:id/summary`, `/:id/sales`; `POST/PUT/DELETE`; `POST /:id/submit-review` | Nyata | **Belum auto-publish**; create selalu `DRAFT`; submit-review → `PENDING_REVIEW` |
| Ticket type | `GET /api/events/:eventId/ticket-types`; `POST/PUT/DELETE` | Nyata + validasi harga homogen, kuota, sales window, `is_active` | Perubahan harga ditolak; kuota hanya boleh naik |
| Order | `POST /api/orders` (optionalAuth), `GET /` (auth), `GET /:id` (optionalAuth) | Nyata; quantity=1 & 1 attendee dipaksa (`orderController.js:91-99`); idempotency + token guest hash | RPC `create_event_order` memaksa event `is_public` + status APPROVED/PUBLISHED, kategori aktif, sales window, kuota |
| Payment | `GET /api/payments/:orderId`, `POST /api/payments/simulate` | Nyata; simulasi hanya non-production (`paymentController.js:38`) | Status payment/order terpisah; guest token diterima |
| Ticket | `GET /api/tickets/my-tickets`, `/:id`, `POST /:id/email`, `POST /validate`, `POST /verify` | Nyata; token QR = HMAC deterministik, DB menyimpan SHA-256 (`ticketTokenService.js`) | `verify` menandai `used` **tanpa** membuat record `check_ins` (`ticketController.js:129-153`) |
| Check-in | `POST /api/check-ins`, `GET /events/:eventId/check-ins`, `POST /sync` | Nyata; transaksi + `FOR UPDATE` + unique `check_ins.ticket_id` | `/sync` offline ada (Post-MVP); Flutter memanggil path yang salah |
| Attendee | `GET /api/events/:eventId/attendees` | Nyata tetapi **hanya tiket**, urut `purchased_at DESC`, tanpa nomor registrasi/status payment | Tidak memenuhi AC-09 |
| Invitation | `POST/GET/DELETE /api/events/:eventId/invitations`, `POST /api/invitations/:token/accept`, `GET /api/invitations/me` | Nyata; email match, expiry, status, permission disalin ke membership | Link memakai header `Origin`; tidak ada listing membership untuk Staff; `ASSIST_REGISTRATION` masih diizinkan |
| Members | `GET/POST/PUT/DELETE /api/events/:id/members...` | Nyata, owner-only | Tidak ada endpoint "membership saya" |
| Admin | `GET /accounts`, `/organizers`, `PUT /accounts/:id/status`, `PUT /events/:id/moderation` | Nyata | Tidak ada audit/settings; suspend tanpa alasan/audit; moderation masih approval |
| Revenue | `GET /api/revenue/me`, `/admin/summary`, `/admin/transactions` | Nyata, membaca `platform_transactions` | UI Admin/Organizer masih mock |
| Plan | `GET /api/plans`, `/:id`, `/admin/all`, `POST/PUT/DELETE /admin` | Nyata | UI Admin/Organizer mock |
| Subscription | `GET /api/subscriptions/me`, `POST /`, `/cancel`, `/payments` | Nyata untuk Organizer | Tidak ada route daftar langganan untuk Admin |
| Support | `GET/POST /api/support-reports`, `/:id`, status/priority/reply/internal-note | Nyata | UI Admin memakai API; wrapper Organizer mock |
| Notification | `GET /api/notifications`, `/:id/read`, `/read-all` | Nyata | Service notifikasi Organizer selalu mock |
| Organizer metrics | `GET /api/organizer/overview`, `/events/summaries` | Nyata | Dipakai dashboard Organizer |

**Catatan kontrak:** seluruh route di atas **tidak diubah** pada pekerjaan ini. Rencana Tahap 2 hanya menambah route baru dan mengubah perilaku yang bertentangan dengan PRD (auto-publish, moderation suspend-only) dengan menjaga bentuk response yang ada.

### 2.1 Detail database yang relevan

- Model produk sudah tersedia: `events` (termasuk `public_url`, `registration_qr_url`, `attendee_fields` JSON), `ticket_types`, `event_orders` (`order_number` stabil), `order_items`, `attendees` (`custom_fields` JSON), `order_payments`, `tickets` (`token_hash`), `check_ins`, `scan_logs`, `event_members`/permissions, `event_invitations`/permissions, `audit_logs`, `platform_settings`/history, `plans`, `subscriptions`, `platform_transactions`, `support_reports`.
- Fungsi SQL `create_event_order` menetapkan `service_fee = 5000` (jika subtotal > 0), komisi `5%`, `grand_total = subtotal + fee`, dan langsung `PAID` + tiket untuk order gratis (`migration 20261113000400`, baris 225-231, 290-300).
- **Tiket gratis tidak menulis `ticket_hash` saat dibuat.** Backfill hanya terjadi ketika tiket dibuka pemilik (`presentTicket(includeToken: true)`) atau setelah pembayaran berbayar (`paymentController.js:79-84`). Bila peserta tidak membuka tiket terlebih dahulu, scan tiket gratis gagal.
- `events.public_url` dan `registration_qr_url` tidak pernah diisi oleh `createEvent`/`updateEvent`/`moderate_event` (moderate hanya mempertahankan nilai lama). Akibatnya link publik selalu `null`.

---

## 3. Kondisi Flutter aktual

### 3.1 Route publik dan peran

- `AuthGate` mengarahkan pengguna tidak login ke `LoginScreen` (`apps/lib/app.dart:44-50`).
- `AppRouter.generateRoute` menolak semua route selain `/`, `/login`, `/register`, `/access-denied` bila belum login (`app_router.dart:217-220`).
- `AppRoutes.registration = '/registration/:eventId'` didefinisikan (`routes/app_routes.dart:15`) tetapi **tidak ada case** di router; permintaan akan jatuh ke "Halaman tidak ditemukan" (atau login lebih dulu).
- Tidak ada route `/e/:eventId` (public link), `/invite/:token` (accept invitation), atau `/staff` khusus membership.

**Dampak:** Participant guest tidak bisa membuka event/registrasi dari tautan publik; Staff hasil invitation tidak memiliki jalur UI menuju workspace-nya (role profil tetap `organizer` karena register selalu organizer, `authController.js:47-50`).

### 3.2 Halaman yang sudah memakai API nyata

| Area | Bukti |
|---|---|
| Auth (login/register/me/logout) | `services/auth/auth_service.dart`, `providers/auth_provider.dart` |
| Event publik & Organizer CRUD | `services/event/event_service.dart`, `services/organizer_events/api_organizer_event_repository.dart`; factory default API (`organizer_event_repository_factory.dart:6-7`) |
| Order/payment/ticket data | `services/order`, `services/payment`, `services/ticket/ticket_service.dart` (mock hanya `MOCK_MODE=true`) |
| Dashboard Organizer | `OrganizerShellService` → `OrganizerEventRepository` API |
| Dashboard Admin (daftar event) | `admin_dashboard_screen.dart:77-86` memakai repository API (D3-1 selesai) |
| Laporan dukungan Admin | `ReportProvider` → `ReportService` (API branch) |
| Notifikasi utama | `NotificationService` (API branch; mock hanya `MOCK_MODE`) |

### 3.3 Halaman/komponen yang belum memenuhi MVP

| Area | Bukti | Masalah |
|---|---|---|
| QR e-ticket | `features/tickets/widgets/qr_ticket_display.dart:41-73` | Pola QR palsu, bukan QR yang dapat dipindai |
| Scanner | `features/scanner/screens/scanner_screen.dart:115-226` | Tidak ada kamera; input manual; mode offline ditawarkan |
| Scanner Organizer | `features/organizer/operations/organizer_scanner_screen.dart:148` | Judul "Mock"; memakai `OrganizerOperationsRepository` in-memory |
| Riwayat check-in | `features/check_in/screens/check_in_history_screen.dart` + `check_in_service.dart:116` | Path API salah → 404 |
| Daftar peserta/export | `features/organizer/screens/attendee_list_screen.dart:35-56`, `organizer_operations_repository.dart:776-813` | Data mock, event default `evt-1001`, CSV mock |
| Team/staff | `features/organizer/membership/team_management_screen.dart:30`, `services/organizer_membership/organizer_membership_service.dart:79-171` | In-memory; tidak memakai invitation API |
| Staff dashboard | `features/staff/screens/staff_dashboard_screen.dart:35-61` | Assignment dari mock membership |
| Akun Admin | `features/admin/screens/account_management_screen.dart:84-120` | `_mockAccounts`, aksi lokal |
| Audit log Admin | `services/admin/admin_audit_log_service.dart:11-75` | In-memory; tidak ada API |
| Settings Admin | `services/admin/admin_settings_service.dart:14-51` | In-memory; fixedFee 2.500 (bertentangan dengan Rp5.000) |
| Revenue Admin | `services/admin/admin_revenue_service.dart:12-136` | In-memory; dashboard memakai snapshot |
| Paket Admin | `services/admin/admin_package_service.dart:14-87` | In-memory; backend plan tersedia |
| Langganan Admin | `services/admin/admin_subscription_service.dart:15-142` | In-memory; tidak ada endpoint admin list |
| Laporan Organizer | `features/organizer/operations/organizer_report_screen.dart:30-31` | Memakai repository mock |
| Notifikasi Organizer | `services/organizer_notifications/organizer_notifications_service.dart:68-74` | **Selalu** mengembalikan mock, bahkan API mode |
| Plans Organizer | `services/organizer_plans/organizer_plans_service.dart` | In-memory |
| Support Organizer | `services/organizer_support/organizer_support_service.dart:100-116` | Daftar keluhan mock; tidak memakai `ReportService` API |
| Assisted registration | `features/organizer/operations/assisted_registration_screen.dart`, `organizer_operations_repository.dart:369-515` | Fitur **di luar MVP** masih dapat diakses dari daftar peserta |
| Offline check-in | `scanner_screen.dart`, `check_in_service.dart:198-227`, `organizer_operations_repository.dart:620-712` | Post-MVP namun ditawarkan sebagai alur sukses |

### 3.4 Daftar mock/in-memory yang wajib diganti di Tahap 2

1. `admin_audit_log_service.dart` — audit log Admin.
2. `admin_settings_service.dart` — settings platform + riwayat.
3. `admin_revenue_service.dart` — transaksi/revenue.
4. `admin_package_service.dart` — paket layanan.
5. `admin_subscription_service.dart` — langganan.
6. `account_management_screen.dart` — daftar akun.
7. `organizer_membership_service.dart` — membership/invitation.
8. `organizer_operations_repository.dart` — attendee, scanner, report, export, assisted, offline.
9. `organizer_plans_service.dart` — paket/langganan Organizer.
10. `organizer_support_service.dart` — daftar keluhan Organizer.
11. `organizer_notifications_service.dart` — notifikasi shell Organizer.
12. `scanner_service.dart` + `check_in_service.dart` — mock hanya boleh aktif di `MOCK_MODE`; UI offline harus dihapus dari alur MVP.
13. `qr_ticket_display.dart` — QR palsu.
14. `admin_dashboard_screen.dart` — angka revenue/peserta/grafik hardcoded (`:38-43`, `:289-291`, `:643-676`).

> Catatan: `mock_organizer_event_repository.dart` dan `mock_attendee_repository.dart` **boleh tetap ada** sebagai mode demo eksplisit (`MOCK_MODE=true`). Yang dilarang adalah mock yang aktif pada API mode atau menjadi satu-satunya implementasi.

---

## 4. Audit kelengkapan fitur per role

**Legenda status:** COMPLETED & VERIFIED · IMPLEMENTED BUT NOT VERIFIED · PARTIALLY IMPLEMENTED · NOT IMPLEMENTED · BLOCKED · NO LONGER REQUIRED.
"Verified" berarti ada bukti test/DB; "implemented" berarti source ada tetapi belum diuji E2E pada sesi ini.

### 4.1 Admin

| # | Fitur | Status | Bukti / gap |
|---|---|---|---|
| A-01 | Login & autentikasi Admin | **COMPLETED & VERIFIED** | `authController`, `authMiddleware`; bukti 15/15 skenario D4 Tahap 1 §9.2 + provisioning admin; test backend lulus |
| A-02 | Dashboard statistik platform | **PARTIALLY IMPLEMENTED** | Daftar event dari API (`admin_dashboard_screen.dart:77-86`), tetapi total organizer/peserta/order/tiket dari mock dan angka periode hardcoded (`:38-43`), grafik statis (`:643-676`), revenue dari mock |
| A-03 | Manajemen akun (list/suspend) | **PARTIALLY IMPLEMENTED** | Backend `GET /admin/accounts`, `PUT /accounts/:id/status` nyata; UI `_mockAccounts`; suspend tanpa alasan/audit (`adminController.js:15-31`) |
| A-04 | Monitoring & pemantauan event | **PARTIALLY IMPLEMENTED** | `GET /api/events` admin-only; UI moderasi API; tetapi alur approval bertentangan dengan PRD dan default filter `pendingReview` |
| A-05 | Suspend event dengan alasan + audit | **PARTIALLY IMPLEMENTED** | RPC `moderate_event` menulis `event_moderations` + `audit_logs` untuk suspend; tidak ada UI khusus "suspend-only"; approval masih dominan |
| A-06 | Monitoring transaksi & revenue | **PARTIALLY IMPLEMENTED** | Backend `/api/revenue/admin/summary` & `/transactions` nyata; `AdminRevenueService` in-memory; dashboard/chart mock |
| A-07 | Monitoring pengguna/penyelenggara | **PARTIALLY IMPLEMENTED** | Daftar akun backend tanpa metrik event/order; UI mock |
| A-08 | Audit logs | **NOT IMPLEMENTED** | Tidak ada route/controller; `audit_logs` hanya ditulis oleh RPC moderasi; UI in-memory |
| A-09 | Platform settings + history | **NOT IMPLEMENTED** | Tidak ada route/controller; tabel `platform_settings`/history tidak dipakai; UI in-memory dengan fee 2.500 (salah) |
| A-10 | Pengelolaan paket layanan | **PARTIALLY IMPLEMENTED** | Backend `/api/plans/admin/*` lengkap; UI `AdminPackageService` in-memory |
| A-11 | Pengelolaan langganan | **PARTIALLY IMPLEMENTED** | Backend hanya sisi Organizer; tidak ada daftar langganan Admin; UI in-memory; C-03 OPEN |
| A-12 | Laporan/keluhan/dukungan | **IMPLEMENTED BUT NOT VERIFIED** | Backend `reportController` lengkap; UI Admin via `ReportProvider` → `ReportService` API; belum diuji E2E pada sesi ini |
| A-13 | Profil Admin | **COMPLETED & VERIFIED** | `admin_profile_screen.dart` membaca `AuthProvider`; logout nyata |

### 4.2 Organizer

| # | Fitur | Status | Bukti / gap |
|---|---|---|---|
| O-01 | Registrasi/login Organizer | **COMPLETED & VERIFIED** | `POST /api/auth/register` menetapkan role organizer; test auth lulus |
| O-02 | Dashboard Organizer | **IMPLEMENTED BUT NOT VERIFIED** | `OrganizerShellService` + `ApiOrganizerEventRepository` (`/organizer/overview`, `/events/summaries`); widget test ada; belum diuji live pada sesi ini |
| O-03 | Pembuatan event | **IMPLEMENTED BUT NOT VERIFIED** | `POST /api/events` + validasi; Flutter `EventFormScreen` via API repository |
| O-04 | Pengelolaan/perubahan event | **IMPLEMENTED BUT NOT VERIFIED** | `PUT/DELETE /api/events/:id`, ownership test; status edit dibatasi |
| O-05 | Validasi event & publikasi otomatis | **PARTIALLY IMPLEMENTED** | Validasi ada, tetapi publikasi masih `PENDING_REVIEW` + approval Admin; **PRD §3 tidak terpenuhi** |
| O-06 | Kategori tiket (harga/kuota/periode/aktif) | **IMPLEMENTED BUT NOT VERIFIED** | `ticketTypeController` + validasi; Flutter API; backend test |
| O-07 | Status event & penjualan | **PARTIALLY IMPLEMENTED** | Status legacy (DRAFT/PENDING/APPROVED/PUBLISHED/SUSPENDED) belum diselaraskan dengan lifecycle PRD |
| O-08 | Public registration link | **NOT IMPLEMENTED** | `public_url` tidak pernah diisi; UI menampilkan tautan demo (`organizer_event_contract.dart:493-498`); tidak ada route publik Flutter |
| O-09 | Staff invitation/access link | **PARTIALLY IMPLEMENTED** | Backend create/list/revoke/accept lengkap; link memakai `Origin` (`eventInvitationController.js:72-80`); UI team masih mock; tidak ada deep link |
| O-10 | Manajemen Staff & membership | **PARTIALLY IMPLEMENTED** | Backend members CRUD; UI `TeamManagementScreen`/`StaffManagementScreen` memakai `OrganizerMembershipService` mock |
| O-11 | Pengelolaan peserta | **PARTIALLY IMPLEMENTED** | Backend attendee endpoint hanya tiket & belum paid-first; UI mock, event default `evt-1001` |
| O-12 | Monitoring order & pembayaran | **NOT IMPLEMENTED** | Tidak ada endpoint order per event; tidak ada layar order Organizer |
| O-13 | Revenue & laporan | **PARTIALLY IMPLEMENTED** | Backend `/api/revenue/me`, `/events/:id/summary`; `OrganizerReportScreen` memakai repository mock dengan harga hardcoded |
| O-14 | Export data peserta | **PARTIALLY IMPLEMENTED** | Hanya CSV di repository mock; tidak ada export dari data API; urutan belum paid-first |
| O-15 | Paket & langganan Organizer | **PARTIALLY IMPLEMENTED** | Backend plan/subscription nyata; `OrganizerPlansService` in-memory; C-03 OPEN |
| O-16 | Pusat bantuan/laporan Organizer | **PARTIALLY IMPLEMENTED** | `OrganizerSupportService` daftar keluhan mock; backend support API tersedia |
| O-17 | Notifikasi Organizer | **PARTIALLY IMPLEMENTED** | `OrganizerNotificationService` selalu mock; endpoint `/api/notifications` tersedia |

### 4.3 Staff

| # | Fitur | Status | Bukti / gap |
|---|---|---|---|
| S-01 | Akses berbasis event yang diikuti | **PARTIALLY IMPLEMENTED** | Backend `assertScanPermission` memeriksa membership + permission; UI assignment mock; user dengan membership tidak diarahkan ke workspace staff (`_homeForRole` hanya `role == 'staff'`) |
| S-02 | Invitation & membership | **PARTIALLY IMPLEMENTED** | Backend accept + membership + permission; tidak ada endpoint "membership saya"; tidak ada deep link |
| S-03 | Hak akses sesuai permission | **PARTIALLY IMPLEMENTED** | Backend memeriksa `SCAN_TICKET`/`CHECK_IN_TICKET`; daftar peserta memakai permission scan (bukan `VIEW_PARTICIPANTS`); UI memakai mock context |
| S-04 | Akses data peserta sesuai kewenangan | **PARTIALLY IMPLEMENTED** | Endpoint sama dengan organizer; permission belum dipetakan per operasi |
| S-05 | Pemindaian QR | **PARTIALLY IMPLEMENTED** | Input token manual; tidak ada kamera; dua implementasi scanner (mock & API) |
| S-06 | Validasi tiket | **IMPLEMENTED BUT NOT VERIFIED** | `/tickets/validate` memeriksa token hash, event, status, payment, permission; unit test backend |
| S-07 | Check-in peserta | **IMPLEMENTED BUT NOT VERIFIED** | `recordCheckIn` transaksi + `FOR UPDATE` + unique; test duplicate 409; belum E2E device |
| S-08 | Riwayat check-in | **PARTIALLY IMPLEMENTED** | Endpoint ada; Flutter memanggil path salah → 404 |
| S-09 | Pencegahan tiket berulang | **IMPLEMENTED BUT NOT VERIFIED** | `check_ins.ticket_id` unique + lock + `ON CONFLICT DO NOTHING`; test ada |
| S-10 | Offline scanning | **NO LONGER REQUIRED (MVP)** | Route `/sync` & UI offline ada; PRD menetapkan Post-MVP. Tidak boleh dihitung sebagai MVP |

### 4.4 Participant

| # | Fitur | Status | Bukti / gap |
|---|---|---|---|
| P-01 | Registrasi via public link | **PARTIALLY IMPLEMENTED** | `RegistrationScreen` ada dan memakai API, tetapi hanya dapat dibuka setelah login; tidak ada route publik/tautan |
| P-02 | Pengisian data peserta | **PARTIALLY IMPLEMENTED** | Hanya nama/email/telepon; `attendee_fields` belum bertipe dan tidak dirender; `custom_fields` tidak ditulis |
| P-03 | Pemilihan tiket | **COMPLETED & VERIFIED** | UI membatasi 1 tiket (`registration_screen.dart:229-266`); backend menolak quantity != 1; test |
| P-04 | Pembuatan order | **COMPLETED & VERIFIED** | `POST /api/orders` + idempotency + harga server; backend test; smoke DB D4 |
| P-05 | Pembayaran simulasi | **COMPLETED & VERIFIED** | `POST /api/payments/simulate`, VA, status; test; smoke DB |
| P-06 | Status pembayaran | **IMPLEMENTED BUT NOT VERIFIED** | `PaymentScreen`/`PaymentStatusScreen` + status; belum diuji E2E UI pada sesi ini |
| P-07 | E-ticket | **PARTIALLY IMPLEMENTED** | Data tiket nyata, tetapi QR palsu; template belum ada |
| P-08 | QR Code | **NOT IMPLEMENTED (fungsional)** | Pola pseudo-QR; token tersedia dari API tetapi tidak dirender sebagai QR valid |
| P-09 | Akses tiket | **PARTIALLY IMPLEMENTED** | Dapat diakses setelah checkout (order token di secure storage); tautan email `appPublicUrl/tickets/:id` tidak dapat diotorisasi tanpa token |
| P-10 | Riwayat pendaftaran | **NOT IMPLEMENTED (MVP)** | Guest tidak punya dashboard; `GET /orders` memerlukan JWT; PRD memang tidak mewajibkan dashboard |
| P-11 | Informasi event | **COMPLETED & VERIFIED** | `GET /api/events/public`, `GET /api/events/:id`; Flutter event list/detail API |
| P-12 | Pengalaman Web & Mobile | **PARTIALLY IMPLEMENTED** | Flutter Web/Android; belum ada bukti build/device/browser pada sesi ini |

### 4.5 Platform & sistem pendukung

| # | Fitur | Status | Bukti / gap |
|---|---|---|---|
| X-01 | Authentication & authorization | **COMPLETED & VERIFIED** | JWT, reload role/disabled, revoked token; test |
| X-02 | Refresh token/session lifecycle | **NOT IMPLEMENTED** | G-03; tidak ada route refresh |
| X-03 | Validasi request | **PARTIALLY IMPLEMENTED** | Auth/event/ticket/order valid; dynamic form (tipe/required) belum |
| X-04 | Persistensi database | **COMPLETED & VERIFIED** | 32 tabel, 0 drift, smoke 14/14 (D4) |
| X-05 | Transaction handling | **COMPLETED & VERIFIED** | RPC + transaksi manual pada check-in/permission; test |
| X-06 | Error handling | **PARTIALLY IMPLEMENTED** | Middleware error ada; state UI tidak merata; beberapa error API tidak dipetakan |
| X-07 | Email notification | **IMPLEMENTED BUT NOT VERIFIED** | `emailService` + `ticket_email_deliveries` + retry admin; SMTP nyata belum diuji |
| X-08 | QR generation & verification | **PARTIALLY IMPLEMENTED** | Verifikasi token hash nyata; generation gambar QR tidak ada (server `qrService` dead code) |
| X-09 | File upload (brosur) | **NOT IMPLEMENTED** | Hanya `poster_url` teks; tidak ada storage/validasi |
| X-10 | API security | **PARTIALLY IMPLEMENTED** | Helmet/CORS/rate limit/token hash; audit admin belum; `verify` bypass check_ins; docs keamanan usang |
| X-11 | Responsive web | **PARTIALLY IMPLEMENTED** | Shell Organizer/Admin responsif; belum ada bukti viewport/browser; breakpoint G-10 |
| X-12 | Logging & audit | **PARTIALLY IMPLEMENTED** | Request logger + scan logs; `audit_logs` hanya dari moderasi |
| X-13 | Configuration | **PARTIALLY IMPLEMENTED** | `config/env.js`, simulated payment flag; belum ada panduan production |
| X-14 | Integrasi frontend–backend | **PARTIALLY IMPLEMENTED** | Banyak alur inti sudah API; beberapa mock masih aktif dan beberapa path salah |
| X-15 | Offline scanner/sync | **NO LONGER REQUIRED (MVP)** | Post-MVP; route `/sync` dan UI offline harus dinonaktifkan dari alur MVP |
| X-16 | Payment gateway/refund | **NO LONGER REQUIRED (MVP)** | Hanya simulasi VA |
| X-17 | Assisted registration | **NO LONGER REQUIRED (MVP)** | UI & permission masih ada; jangan diekspos |

### 4.6 Rekap status

| Status | Jumlah baris fitur |
|---|---:|
| COMPLETED & VERIFIED | 13 |
| IMPLEMENTED BUT NOT VERIFIED | 13 |
| PARTIALLY IMPLEMENTED | 34 |
| NOT IMPLEMENTED | 7 |
| BLOCKED (eksternal/DB/produk) | 0 pada audit ini; item template/upload menjadi BLOCKED pada rencana |
| NO LONGER REQUIRED | 5 |

Angka ini menunjukkan masalah utama bukan "belum ada kode", melainkan **integrasi dan penyelesaian alur**.

---

## 5. Rekonsiliasi keputusan produk

Keputusan acuan: mandat pemilik proyek (A–J) + PRD v2.2. Kolom "implementasi" adalah bukti source, bukan klaim.

| # | Keputusan | Implementasi aktual | Status | Rekomendasi |
|---|---|---|---|---|
| 1 | Satu order = tepat satu tiket/peserta/kategori | Backend menolak quantity != 1, multi-item, multi-attendee (`orderController.js:91-129`); UI membatasi 1 (`registration_screen.dart:229-266`) | **SESUAI** | Pertahankan; tambah regression test |
| 2 | Registrasi hanya via public link, bukan manual/assisted | Backend menolak `assisted` (`orderController.js:76-79`), tetapi UI assisted masih dapat dibuka dan permission `ASSIST_REGISTRATION` masih ada | **BELUM SESUAI** | Sembunyikan dari alur MVP; jangan hapus kode; tandai Post-MVP |
| 3 | Setelah event berhasil dibuat tersedia dua link berbeda (publik & staff) | `public_url` tidak pernah diisi; link staff hanya dibuat saat invitation dan memakai `Origin`; UI menampilkan tautan demo | **BELUM SESUAI** | Isi `public_url` saat publish + endpoint/URL staff invitation; tampilkan dua panel terpisah |
| 4 | Dua link berbeda mekanisme akses | Public link belum ada; invitation memerlukan JWT + email cocok (sudah benar di backend); deep link Flutter belum ada | **SEBAGIAN** | Implementasi route publik tanpa auth; route `/invite/:token` dengan login/email match |
| 5 | Pembayaran simulasi VA + status | RPC + endpoint + status; guest token (C-02) dipakai sebagai interpretasi | **SESUAI (asumsi C-02)** | Catat C-02 sebagai asumsi; jangan klaim keputusan final |
| 6 | Moderasi event otomatis, bukan approval Admin | Masih `submit-review` → `PENDING_REVIEW` → approval Admin | **BERTENTANGAN** | Ubah validasi→publish otomatis; Admin hanya suspend/reinstate beralasan |
| 7 | Offline scanner bukan MVP | Route `/sync` ada; UI scanner menawarkan mode offline dan sukses lokal | **BERTENTANGAN (UI)** | Hapus opsi offline dari alur MVP; route sync boleh tetap sebagai Post-MVP tidak diekspos |
| 8 | Fee Rp5.000 + 5% | Backend menerapkan 5.000 + 5% (`migration ...:225-227`); UI registrasi menampilkan 5.000; **settings Admin mock memakai 2.500** | **KONFLIK DATA** | Hapus 2.500 dari UI; tampilkan nilai CONFIRMED read-only; formula tetap C-01 |
| 9 | Export/daftar peserta paid-first lalu nomor pendaftaran | Endpoint urut `purchased_at DESC`, tanpa nomor registrasi; export mock | **BELUM SESUAI** | Tambah `order_number` + status payment pada response, urut paid-first lalu `order_number`; export memakai set yang sama |
| 10 | Menonaktifkan jenis tiket menghentikan order baru, order lama tetap selesai | RPC menolak kategori `is_active=false` untuk order baru (`:191`); pembayaran order lama tidak memeriksa `is_active` | **SESUAI** | Tambah test regresi: nonaktifkan setelah order dibuat → order tetap bisa dibayar sampai expiry |

### 5.1 Konflik keputusan yang perlu dicatat (bukan diputuskan diam-diam)

| ID | Konflik | Dampak | Rekomendasi |
|---|---|---|---|
| K-01 | PRD §3 auto-publish vs implementasi approval Admin; UI moderasi menyebut "publikasi tetap otomatis" tetapi backend tidak | Alur inti event salah; Admin menjadi bottleneck | Terapkan auto-publish; pertahankan status legacy hanya untuk data lama |
| K-02 | Fee 5.000 (PRD/DB) vs 2.500 (Admin settings mock) | Angka platform salah di UI | Perbaiki UI; nilai fee dari backend, bukan mock |
| K-03 | "Setelah event dibuat" dua link vs PRD "link publik untuk event Published" | Kapan link aktif | Asumsi: event harus lolos validasi/publish dulu; link tersedia setelah publish; tombol tampil nonaktif saat Draft |
| K-04 | Staff sebagai role vs membership | Register selalu `organizer`; staff tidak punya workspace | Jangan ubah role; gunakan membership-based staff workspace + endpoint "membership saya" |
| K-05 | C-02 guest payment authority | Belum final | Implementasi saat ini: guest token order-scoped; catat sebagai asumsi, jangan jadikan klaim final |
| K-06 | C-01 formula fee | Belum final | Tampilkan nilai server apa adanya; jangan menghitung payout final di UI baru |
| K-07 | C-03 plan gate | Belum final | Katalog/CRUD boleh; jangan menambah paywall/entitlement |
| K-08 | Expiry order 24 jam hardcoded | PRD menyebut TECHNICAL GAP | Dokumentasikan 24 jam sebagai default teknis yang dapat dikonfigurasi; jangan klaim keputusan produk |
| K-09 | Brosur upload & template tiket | Belum ada storage/kolom | Implementasi default ticket + URL poster; upload/template selector = proposal DB (Stage 3/FINISHING) |
| K-10 | Dynamic form `attendee_fields` hanya array nama vs PRD field bertipe/required | Validasi form belum lengkap | Perluas JSON (tanpa migration) + tulis `attendees.custom_fields`; update kontrak |

---

## 6. Risiko teknis

| ID | Risiko | Probabilitas | Dampak | Mitigasi |
|---|---|---|---|---|
| R-01 | Tiket gratis tidak pernah mendapat `token_hash` bila tidak dibuka | Tinggi | Scan gagal, peserta tidak bisa masuk | Backfill hash saat order gratis dibuat; test regresi |
| R-02 | Dua jalur check-in (`/tickets/verify` vs `/check-ins`) | Tinggi | Tiket berstatus used tanpa `check_ins`; laporan/riwayat tidak konsisten | Satukan ke satu service check-in; `verify` mendelegasikan |
| R-03 | Path API check-in salah di Flutter | Tinggi | Riwayat check-in selalu error | Perbaiki path + contract test |
| R-04 | QR palsu / tanpa kamera | Tinggi | Seluruh alur tiket–scan tidak dapat didemokan | Render QR nyata + kamera; uji di Android & Web |
| R-05 | `public_url` null | Tinggi | Registrasi publik mustahil | Generate saat publish; test tautan |
| R-06 | Approval Admin vs auto-publish | Tinggi | Event tidak pernah tayang tanpa admin | Implementasi auto-publish; regression AC-01 |
| R-07 | Staff role/membership routing | Sedang | Staff tidak menemukan scanner | Workspace berbasis membership + endpoint memberships |
| R-08 | Permission attendee memakai `SCAN_TICKET` | Sedang | Staff dengan `VIEW_PARTICIPANTS` ditolak; sebaliknya akses berlebih | Petakan permission per operasi |
| R-09 | Mock tetap aktif di API mode | Tinggi | Demo terlihat jalan tetapi data hilang | Gate "no mock in API mode" per layar + test |
| R-10 | Dua sumber fee (5.000 vs 2.500) | Sedang | Kesalahan angka platform | Satu sumber dari backend; hapus mock |
| R-11 | `ASSIST_REGISTRATION` masih ada | Rendah | Fitur non-MVP diekspos | Sembunyikan UI; dokumentasikan Post-MVP |
| R-12 | Kamera di Flutter Web butuh HTTPS/permission | Sedang | Scan web gagal di deployment | Uji di origin aman; fallback input manual |
| R-13 | Dynamic form menulis `custom_fields` tanpa RPC | Sedang | Data form tidak atomik | Transaksi/kompensasi; atau proposal perluasan RPC ke FINISHING |
| R-14 | Email link tidak dapat membuka tiket tanpa token | Sedang | Harapan pengguna tidak terpenuhi | Dokumentasikan batasan; jangan klaim "email terkirim" tanpa SMTP |
| R-15 | Test hijau tetapi integrasi UI–API tidak diuji | Tinggi | Regresi lolos ke demo | Stage 3 E2E API nyata + smoke |
| R-16 | Dokumentasi usang (DATABASE.md menyebut scanner bearer) | Sedang | Keputusan teknis salah | Update dokumen di Stage 3 |

---

## 7. Dokumentasi yang perlu diperbarui

| Dokumen | Kondisi | Tindakan |
|---|---|---|
| `docs/DATABASE.md` baris 198-203 | Menyatakan scanner masih bearer code dan `token_hash` belum dipakai | Perbarui: scanner memakai `token_hash`; `qr_code_data` legacy tetap ada |
| `docs/DATABASE.md` bagian audit/settings | Menyebut tabel belum dipakai | Perbarui setelah endpoint audit/settings dibuat |
| `README.md` / `backend/README.md` | Daftar endpoint belum memuat endpoint baru (settings/audit/staff memberships/organizer orders) | Perbarui di Stage 3 |
| `task/PRD_TRACEABILITY_MATRIX.md` | Status `BLOCKED` lama, owner lama, tidak sesuai roadmap baru | Tandai superseded; regenerasi di Stage 3 |
| `task/TECHNICAL_GATE_CLOSURE.md`, `FASE_1C/1D/1E` | Historis | Jangan diubah; jangan dipakai sebagai status |
| `task/DATABASE_AUDIT_FINAL.md` F.4 | Menyebut dashboard Admin selalu mock | Perbarui catatan setelah Tahap 2 (D3-1 sudah sebagian) |
| `task/TAHAP_1/*` | FROZEN untuk D1; laporan D2/D3/D4 historis | Jangan diubah |
| `task/TAHAP_2/LAPORAN_DEVELOPER_3.md` | Mencatat progress lama D3-1 | Pertahankan sebagai riwayat; rencana baru menggantikan |
| `task/TAHAP_2/RENCANA_KERJA.md`, `TAHAP_3/RENCANA_KERJA.md` | Digantikan dokumen baru | Sudah diperbarui pada pekerjaan ini |

---

## 8. Alasan perubahan roadmap

1. **Rencana lama berbasis asumsi "endpoint sudah ada, tinggal verifikasi".** Audit menunjukkan endpoint banyak yang ada, tetapi UI-nya mock dan beberapa endpoint inti tidak ada (membership saya, order per event, audit, settings, admin subscriptions).
2. **Rencana lama tidak memiliki owner untuk gap inti.** Auto-publish, public link, QR nyata, kamera, paid-first, dan admin audit/settings tidak muncul di task D1–D3 lama.
3. **Pembagian lama memecah domain secara artifisial.** Invitation di D1, scanner di D2, attendee/export di D3 membuat satu alur Staff harus melewati tiga developer dan satu file `app_router.dart` tanpa owner.
4. **Tahap 3 lama menampung fitur wajib.** Dynamic form, ticket presentation, dan guest journey E2E adalah MVP; tidak boleh ditunda ke Tahap 3.
5. **Risiko konflik file tinggi pada rencana lama.** `app_router.dart`, `eventRoutes.js`, `organizer_operations_repository.dart`, dan `checkInController.js` dipakai beberapa alur tanpa owner tunggal.
6. **Prinsip baru:** satu developer = satu alur end-to-end (backend + Flutter + test), file shared memiliki satu owner, dependency ditulis eksplisit, dan setiap AC punya task.

---

## 9. Keputusan rekonsiliasi & asumsi yang dipakai roadmap

Keputusan ini **tidak mengubah produk**, hanya memilih interpretasi paling aman dari PRD/mandat. Catat sebagai asumsi yang perlu dikonfirmasi bila pemilik produk berbeda pendapat.

| ID | Keputusan teknis | Dasar |
|---|---|---|
| D-01 | Event tetap dibuat `DRAFT`; publikasi terjadi saat organizer meminta validasi, dan sistem langsung `PUBLISHED` bila valid. Endpoint lama `POST /api/events/:id/submit-review` dipertahankan sebagai alias perilaku baru; route `/publish` ditambahkan | PRD §3 + K-03 |
| D-02 | `public_url` dihitung dari `APP_PUBLIC_URL` + `/e/:id` saat publish (dan fallback saat serialize), bukan kolom baru | Kolom sudah ada; hindari perubahan DB |
| D-03 | Admin hanya boleh `SUSPENDED` dan `PUBLISHED` (reinstate) dengan alasan; `APPROVED/REJECTED/REVISION_REQUESTED` tidak lagi ditawarkan untuk event baru | PRD §2.1/§3 |
| D-04 | Staff tidak diubah role-nya; akses staff ditentukan membership. Workspace staff tersedia untuk semua user terautentikasi yang punya membership aktif | PRD §2.3 + K-04 |
| D-05 | Dynamic form disimpan sebagai JSON objek di `events.attendee_fields`; jawaban peserta disimpan di `attendees.custom_fields`. Tidak ada migration | Kolom JSON sudah ada |
| D-06 | QR ditampilkan di Flutter dari token tiket; library QR (`qr_flutter`) dan kamera (`mobile_scanner`) ditambahkan sebagai dependency karena belum ada alternatif internal | PRD §5/§9; R-04 |
| D-07 | Offline scanner dihapus dari alur MVP (UI), route `/sync` dipertahankan tidak diekspos | PRD §9 |
| D-08 | Assisted registration disembunyikan dari navigasi; kode tidak dihapus | Mandat "jangan menghapus fitur" + PRD "bukan MVP" |
| D-09 | Fee yang ditampilkan = nilai server (5.000 + 5%); UI tidak menghitung payout final; settings Admin tidak boleh menimpa nilai ini selama C-01 terbuka | PRD §8.1 + K-02 |
| D-10 | Daftar peserta = gabungan order/attendee dengan status payment; urut `PAID` dulu, lalu `order_number`; export memakai set yang sama | PRD §7/AC-09 |
| D-11 | Expiry order tetap 24 jam sebagai default teknis yang dapat dikonfigurasi; bukan keputusan produk | K-08 |
| D-12 | Template tiket: hanya desain default dari record; kolom pemilihan template diusulkan ke FINISHING, tidak dikarang | PRD §5 + G-07 |
| D-13 | Poster hanya URL tervalidasi; upload file ditunda sampai storage disahkan | PRD §4 + G-07 |
| D-14 | Email tetap best-effort; klaim "terkirim" hanya bila transport SMTP nyata terbukti | PRD §8 + X-07 |

---

## 10. Definisi proyek selesai

### 10.1 Tiga tingkat keberhasilan

| Tingkat | Syarat minimum | Boleh diklaim jika |
|---|---|---|
| **MVP SELESAI** | AC-01–AC-10 lulus dengan bukti backend + UI; tidak ada fitur inti mock/in-memory; seluruh alur role berjalan di API nyata; test wajib lulus | Semua checklist §10.2 bagian A–D tercentang |
| **SIAP DIUJI PENGGUNA** | MVP selesai + data seed/demo terkontrol, panduan penguji, known issues, error/empty/loading konsisten, build Web & Android tersedia | Checklist A–E tercentang; tidak ada P0 |
| **SIAP DEPLOYMENT/PRODUCTION** | Siap uji + konfigurasi production, SMTP nyata, HTTPS/CORS, secret rotation, backup/restore, monitoring/log, smoke test, runbook, security review | Checklist A–F tercentang; seluruh NOT RUN kritis ditutup atau diterima tertulis |

**Tidak boleh** menyatakan production-ready bila email, kamera/device, atau deployment belum diuji. Gunakan status **NOT RUN** dengan alasan spesifik.

### 10.2 Checklist final

#### A. Fitur & alur (MVP)
- [ ] A1 Organizer register/login, membuat event, mengisi kategori tiket, meminta validasi → event otomatis `PUBLISHED` tanpa admin.
- [ ] A2 Event invalid tidak muncul publik dan menampilkan error yang dapat diperbaiki.
- [ ] A3 `public_url` dan staff invitation link tersedia, berbeda, dan dapat disalin.
- [ ] A4 Guest membuka public link tanpa akun, melihat event/kategori/form, mengisi satu peserta.
- [ ] A5 Order tepat 1 tiket/1 peserta/1 kategori; quantity lain ditolak server.
- [ ] A6 Harga dari server; order lama tidak berubah saat harga kategori berubah.
- [ ] A7 Event gratis langsung menerbitkan tiket tanpa pembayaran; event berbayar hanya setelah simulasi `PAID`.
- [ ] A8 Client tidak dapat memaksa status `PAID`.
- [ ] A9 Tiket menampilkan QR nyata yang dapat dipindai; token tidak membocorkan PII.
- [ ] A10 Organizer mengundang Staff dengan email + permission + expiry; email lain ditolak; revoke berlaku.
- [ ] A11 Staff menerima invitation, login, diarahkan ke scanner event yang benar.
- [ ] A12 Scanner kamera online memvalidasi tiket; duplicate/wrong event/unpaid/no permission ditolak tanpa check-in.
- [ ] A13 Check-in tercatat satu kali; dua scan bersamaan hanya satu sukses.
- [ ] A14 Staff melihat riwayat check-in event-nya.
- [ ] A15 Organizer melihat daftar peserta (PAID dulu, nomor registrasi) dan detail peserta.
- [ ] A16 Organizer mengekspor CSV dengan set/urutan identik layar.
- [ ] A17 Organizer melihat order/payment per event dan statusnya.
- [ ] A18 Organizer melihat revenue/laporan dari data server.
- [ ] A19 Admin melihat akun, menonaktifkan dengan alasan, dan perubahan tercatat di audit log.
- [ ] A20 Admin melihat/mengubah settings platform + history; fee tetap nilai CONFIRMED.
- [ ] A21 Admin melihat revenue/transaksi, paket, dan langganan dari API.
- [ ] A22 Admin menangguhkan event dengan alasan; event suspended tidak menerima order baru.
- [ ] A23 Admin menangani laporan/keluhan (status, prioritas, balasan, catatan internal).
- [ ] A24 Notifikasi pengguna (Organizer/Admin) berasal dari API.

#### B. Integrasi & data
- [ ] B1 Tidak ada layar in-scope yang memakai mock saat `MOCK_MODE=false`.
- [ ] B2 Semua data penting tersimpan di PostgreSQL dan terbaca ulang setelah reload.
- [ ] B3 Tidak ada endpoint tanpa pemakai atau halaman tanpa endpoint.
- [ ] B4 Nomor order stabil sebelum/sesudah payment.
- [ ] B5 `ticket_hash` tersedia untuk tiket gratis maupun berbayar.
- [ ] B6 `audit_logs` terisi untuk aksi Admin; `platform_settings` punya history.
- [ ] B7 `event_activity_logs`/audit tidak diklaim bila belum ditulis.

#### C. Keamanan & otorisasi
- [ ] C1 Cross-owner event ditolak 403/404; admin-only 403 untuk role lain.
- [ ] C2 Staff hanya event membership-nya; permission diperiksa tiap request.
- [ ] C3 Invitation expired/revoked/reused/wrong email ditolak.
- [ ] C4 Guest token tidak dapat membaca/membayar order lain.
- [ ] C5 QR token tidak muncul di log/URL publik; `token_hash` tidak dikirim ke klien.
- [ ] C6 Rate limit & body limit aktif; CORS sesuai environment.
- [ ] C7 CSV escaping mencegah formula injection.
- [ ] C8 Tidak ada secret di repo/Flutter/log.

#### D. Kualitas otomatis
- [ ] D1 `npm test` PASS (termasuk test baru Tahap 2).
- [ ] D2 `npm run check`, `npm run format:check`, `npm run validate:skills`, `npm run test:sync-config` PASS.
- [ ] D3 `flutter analyze` PASS.
- [ ] D4 `flutter test` PASS (termasuk widget test QR, scanner, attendee, admin).
- [ ] D5 Test regresi AC-01–AC-10 tersedia dan lulus.

#### E. UX & platform
- [ ] E1 Loading/empty/error/unauthorized/retry/success ada di layar kritis.
- [ ] E2 Web sempit/lebar tanpa overflow; keyboard/focus berfungsi.
- [ ] E3 Android build & alur inti berjalan.
- [ ] E4 Pesan error dapat ditindaklanjuti dan berbahasa Indonesia.
- [ ] E5 Tidak ada klaim palsu ("terkirim", "terverifikasi") tanpa bukti.

#### F. Operasional & rilis
- [ ] F1 Dokumentasi instalasi, environment, migration, seed admin.
- [ ] F2 Runbook operasional (start/health/backup/restore/rotasi token/email retry).
- [ ] F3 Konfigurasi production: `SIMULATED_PAYMENTS` nonaktif, SMTP nyata, HTTPS, CORS, JWT/TICKET secret kuat.
- [ ] F4 Smoke test production-like lulus.
- [ ] F5 Tidak ada migration tertunda; backup sebelum deploy.
- [ ] F6 Known limitations & risiko tercatat.

---

## 11. Batas audit ini

- Tidak ada perubahan kode aplikasi, schema, migration, atau data.
- Tidak ada fitur yang dihapus/diubah kontraknya.
- Perubahan hanya pada dokumen perencanaan/roadmap (daftar di §7).
- Status `COMPLETED & VERIFIED` untuk DB/auth mengacu pada bukti laporan 2026-11-23; pemeriksaan live DB tidak diulang pada sesi ini.
- Semua task Tahap 2/3 dirancang agar developer dapat mulai tanpa menunggu approval teknis, tetapi **tetap dilarang** mengubah DB tanpa otorisasi FINISHING.










