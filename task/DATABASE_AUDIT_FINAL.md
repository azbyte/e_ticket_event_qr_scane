# Audit Menyeluruh Database Schema, Pembersihan, Validasi & Sinkronisasi Supabase

- **Tanggal:** 2026-11-23
- **Objek audit:** `backend/prisma/schema.prisma`, seluruh migration Prisma, database Supabase PostgreSQL yang dipakai backend, integrasi backend (`pg`) dan Flutter.
- **Status akhir:** **READY WITH LIMITATIONS** (lihat bagian G).
- **Batas otoritas:** perubahan database dijalankan hanya sebatas menerapkan migration yang sudah ada di repository dan bersifat non-destruktif. Tidak ada DROP tabel/kolom/enum, tidak ada reset, tidak ada penghapusan data. Butir yang berpotensi destruktif dihentikan dan dicatat sebagai proposal (bagian C.3).

## Sumber acuan yang dibaca

1. `PRD.md` v2.2 (§§0–18) — requirement aktif.
2. `docs/DATABASE.md`, `docs/ARCHITECTURE.md`.
3. `task/DB_CHANGE_PROPOSAL.md` (DP-01…DP-03), `task/FINISHING_AUTHORITY.md`.
4. `backend/prisma/schema.prisma` (810 baris, 32 model + 19 enum) dan 9 migration.
5. Seluruh `backend/src/**` (controllers, services, routes, middleware, utils).
6. Seluruh `apps/lib/**` (services, providers, screens) untuk bukti sumber data.
7. Katalog database aktual (read-only) + riwayat `_prisma_migrations`.

---

## A. Ringkasan Audit

| Item | Jumlah |
|---|---|
| Tabel aplikasi di schema `public` | **32** (+ `_prisma_migrations` internal Prisma) |
| Kolom pada 32 tabel aplikasi | 302 (+8 kolom internal `_prisma_migrations` = 310) |
| Enum | 19 |
| Foreign key | 54 |
| Index (PK + unique + non-unique) | 105 |
| Function PL/pgSQL | 4 (`create_event_order`, `simulate_event_payment`, `expire_event_order_reservations`, `moderate_event`) |
| Trigger / view / sequence | 0 / 0 / 0 |
| Extension | 5 (`pgcrypto`, `uuid-ossp`, `plpgsql`, `supabase_vault`, `pg_stat_statements`) |
| Tabel **USED** (terbukti dipakai fitur) | **26** |
| Tabel **PARTIALLY USED** | **3** (`event_activity_logs`, `event_moderations`, `platform_transactions`) |
| Tabel **UNUSED** (tanpa pemakaian kode sama sekali) | **3** (`audit_logs`, `platform_settings`, `platform_setting_history`) |
| Tabel **REQUIRED BUT NOT IMPLEMENTED** | **4** (`audit_logs`, `platform_settings`, `platform_setting_history`, `event_activity_logs`) |
| Tabel perlu diperbaiki | **0** (tidak ada drift struktur) |
| Struktur ditambahkan | **0** |
| Struktur dihapus | **0** |
| Migration diterapkan | **1** (`20261118000400_restore_payment_status_enum_cast`) untuk menyelaraskan riwayat |
| Data berubah | **0 baris** (32 tabel dibandingkan sebelum/sesudah, identik) |

**Kondisi awal schema:** `schema.prisma` sudah valid dan database sudah **0 drift** terhadap schema. Tiga masalah nyata yang ditemukan bukan pada struktur tabel, melainkan pada: (1) riwayat migration yang belum lengkap (1 migration tertinggal), (2) dokumentasi RLS/grants yang usang, dan (3) celah integrasi aplikasi (beberapa fitur masih memakai data dummy) serta gap fungsional PRD (G-01…G-10).

---

## B. Laporan Penggunaan Schema

Status: **USED** = terbukti dipakai fitur; **PARTIALLY USED** = sebagian jalur saja; **UNUSED** = tidak ada pemakaian kode; **REQUIRED BUT NOT IMPLEMENTED** = dibutuhkan PRD tetapi belum ada implementasi backend.

| Database Object | Kegunaan (fitur PRD) | Bukti Penggunaan (backend → frontend) | Status |
|---|---|---|---|
| `profiles` | Akun/role/profil (§2); login, `/me`, admin account mgmt | `authController`, `authMiddleware`, `adminController`, `eventController`, `seedService`, `models/User.js` → `AuthService`, `AuthProvider` | USED |
| `organizer_profiles` | Profil Organizer 1:1 (§2.2) | `organizerProfileController` (GET/PUT `/api/organizer/profile`) → `organizer_service.dart` | USED |
| `event_categories` | Kategori event (§4) | `eventController.getCategory`, `eventMetricsController` → layar event Organizer/publik | USED |
| `events` | Event CRUD, status, publikasi, form fields, brosur (§3–5) | `eventController` (CRUD), `eventMetricsController`, `orderController`, `checkInController`, `ticketController`, `revenueController` → `event_service.dart`, `api_organizer_event_repository.dart` | USED |
| `ticket_types` | Kategori tiket: harga, kuota, periode jual, aktif (§4) | `ticketTypeController`, `orderController`, `checkInController`, `eventMetricsController`, `emailService` → `ticket_type_service.dart` | USED |
| `event_members` | Membership Staff per event (§2.3) | `eventController` (add/list/remove member), `eventInvitationController`, `checkInController` | USED |
| `event_member_permissions` | Permission granular Staff (§2.3/§6.2) | `eventController` (CRUD), `checkInController.assertScanPermission` | USED |
| `event_invitations` | Undangan Staff + expiry/revoke (§6.2) | `eventInvitationController` (create/list/revoke/accept/me) | USED |
| `event_invitation_permissions` | Permission yang menunggu acceptance (§6.2) | `eventInvitationController` | USED |
| `event_orders` | Order guest/akun, nomor stabil, idempotency, expiry (§7–8) | `orderController`, `paymentController` (via RPC), `revenueController`, `eventMetricsController`, `checkInController` → `order_service.dart`, `OrderModel` | USED |
| `order_items` | Item order + snapshot harga (§7) | `orderController`, `ticketController`, `ticketTypeController`, `checkInController`, `emailService`, `orderResponse` | USED |
| `attendees` | Data peserta per tiket (§7) | `orderController` (insert via RPC), `ticketController`, `checkInController`, `emailService` | USED |
| `order_payments` | Pembayaran simulasi VA, status, expiry (§8) | `paymentController`, `orderController`, `revenueController` → `payment_service.dart`, `PaymentModel` | USED |
| `platform_transactions` | Snapshot gross/fee/komisi/revenue (§8.1) | `revenueController`, `subscriptionController`, RPC `create_event_order`/`simulate_event_payment` | PARTIALLY USED (dibuat RPC; UI revenue masih dummy) |
| `tickets` | E-ticket, kode, QR token hash, status (§5/§9) | `ticketController`, `checkInController`, `eventMetricsController`, `models/Ticket.js`, RPC → `ticket_service.dart` | USED |
| `scan_logs` | Riwayat percobaan scan + hasil (§9) | `checkInController` (recordCheckIn, sync), `ticketController.verifyTicket` | USED |
| `check_ins` | Check-in sukses unik per tiket (§9) | `checkInController` (record/sync/list), `eventMetricsController` | USED |
| `ticket_email_deliveries` | Status/retry pengiriman e-ticket (§8) | `emailService` (sendTicketEmail, retryPendingDeliveries) | USED |
| `support_reports` | Laporan/komplain peserta & Organizer (§2.1) | `reportController` (CRUD + status/prioritas) | USED |
| `support_report_activities` | Balasan & catatan internal laporan | `reportController` | USED |
| `plans` | Katalog paket layanan (§8.1, C-03) | `planController` (admin CRUD), `subscriptionController`, `planRoutes` | USED |
| `plan_features` | Fitur/batas per paket | `planController`, `subscriptionController` | USED |
| `subscriptions` | Langganan Organizer (§8.1, C-03) | `subscriptionController`, `planController` | USED |
| `subscription_history` | Riwayat perubahan langganan | `subscriptionController` | USED |
| `subscription_payments` | Pembayaran langganan | `subscriptionController`, `revenueController` | USED |
| `notifications` | Notifikasi pengguna | `notificationController`, `notificationService`, `app.js` (email retry) → `notification_service.dart` | USED |
| `revoked_tokens` | Logout/revokasi JWT (§2) | `authController.logoutUser`, `authMiddleware` | USED |
| `event_moderations` | Keputusan moderasi + alasan (§3) | Function SQL `moderate_event` dipanggil `eventMetricsController`; dibaca `eventController` | PARTIALLY USED (alur auto-publish PRD belum) |
| `event_activity_logs` | Umpan aktivitas event | Hanya dibaca sebagai penghalang hapus di `eventController.deleteEvent`; tidak ada penulisan | PARTIALLY USED |
| `audit_logs` | Audit trail Admin (§2.1/§3) | Tidak ada kode backend; hanya dibersihkan oleh script uji | REQUIRED BUT NOT IMPLEMENTED |
| `platform_settings` | Konfigurasi platform Admin (§2.1) | Tidak ada kode backend | REQUIRED BUT NOT IMPLEMENTED |
| `platform_setting_history` | Histori perubahan konfigurasi | Tidak ada kode backend | REQUIRED BUT NOT IMPLEMENTED |


### B.1 Kolom yang tidak direferensikan kode

Pemindaian 302 kolom tabel aplikasi (310 termasuk `_prisma_migrations`) terhadap `backend/src` + `apps/lib` menemukan 19 kolom tanpa referensi langsung. Semuanya **tidak dihapus** karena beralasan:

| Kolom | Alasan dipertahankan |
|---|---|
| `_prisma_migrations.*` (7 kolom) | Metadata internal Prisma; wajib ada. |
| `attendees.custom_fields` | Menampung jawaban form dinamis (§4) — requirement PRD, G-07. |
| `audit_logs.actor_role`, `.entity_type`, `.entity_id` | Bagian audit trail Admin (§2.1/§3) yang belum diimplementasikan. |
| `event_categories.slug` | Kunci URL kategori; unik, dipakai script/seed. |
| `event_member_permissions.granted_at` | Jejak waktu pemberian izin (audit). |
| `event_moderations.admin_id` | Dipakai function SQL `moderate_event` (pemakaian tidak langsung). |
| `platform_setting_history.setting_key/.old_value/.new_value/.changed_at` | Bagian fitur konfigurasi Admin yang belum diimplementasikan. |
| `scan_logs.scanned_token_hash` | Disiapkan untuk verifikasi berbasis hash (G-05); saat ini NULL. |

---

## C. Laporan Perubahan

### C.1 Struktur dihapus

**Tidak ada.** Tidak ditemukan tabel/kolom/enum/index/constraint yang benar-benar tanpa tujuan **dan** aman dihapus. Kandidat "tidak dipakai kode" ternyata dibutuhkan PRD atau merupakan bagian fitur yang belum diimplementasikan (bagian B.1), sedangkan kandidat legacy (C.3) memerlukan keputusan FINISHING.

### C.2 Struktur ditambahkan

**Tidak ada.** Seluruh requirement MVP yang dapat direpresentasikan schema sudah tersedia:

| Kebutuhan PRD | Dukungan schema |
|---|---|
| Satu order = satu tiket/attendee/kategori | `event_orders` → `order_items` (unique `order_id,ticket_type_id`) → `attendees`; `quantity` divalidasi ketat di backend (`quantity = 1`) |
| Nomor pendaftaran stabil (§7/AC-09) | `event_orders.order_number` unique, tidak berubah oleh status payment |
| Auto-publish / suspend beralasan (§3) | `events.status`, `events.is_public`, `event_moderations.decision/note`, function `moderate_event` |
| Homogenitas harga kategori (§8) | `ticket_types.price` + validasi `validateTicketTypePricing` |
| Guest order access token ter-hash (§8.2) | `event_orders.guest_access_token_hash` unique |
| Simulasi VA + status payment (§8) | `order_payments.status/expires_at/paid_at` + enum `PaymentStatus` |
| QR/check-in sekali pakai (§9) | `tickets.token_hash` unique, `check_ins.ticket_id` unique, `scan_logs` |
| Invitation Staff scoped (§6.2) | `event_invitations`+`event_invitation_permissions`+`event_members`+`event_member_permissions` |
| Audit & konfigurasi Admin (§2.1) | `audit_logs`, `platform_settings`, `platform_setting_history` (belum dipakai kode) |
| Paket/langganan & transaksi (§8.1) | `plans`, `plan_features`, `subscriptions`, `subscription_history`, `subscription_payments`, `platform_transactions` |

### C.3 Struktur yang perlu diperbaiki tetapi BELUM diubah (menunggu persetujuan)

Semua butir berikut bersifat **destruktif atau mengubah kontrak** sehingga dihentikan sesuai instruksi:

| ID | Temuan | Dampak | Rekomendasi |
|---|---|---|---|
| C-01 | `event_orders.assisted_by_member_id`, `event_orders.registration_method`, enum `RegistrationMethod` (`ASSISTED`), `EventPermission.ASSIST_REGISTRATION` bertentangan dengan PRD (no assisted registration) | Bertentangan dengan DP-01; backend sudah menolak assisted di runtime | Hapus/ubah hanya setelah FINISHING menyetujui DP-01 + verifikasi data historis |
| C-02 | `events.price` (legacy) dan `events.total_tickets` masih ditulis `0` setiap create | Kolom legacy tanpa fungsi bisnis (harga asli ada di `ticket_types`) | Drop kolom setelah keputusan FINISHING |
| C-03 | `EventStatus` legacy (`PENDING_REVIEW`, `REVISION_REQUESTED`, `REJECTED`, `APPROVED`) + alur submit-review bertentangan dengan auto-publish (§3, G-02) | State machine ganda | Rekonsiliasi status + backfill data (DP-02) |
| C-04 | `tickets.qr_code_data` menyimpan `ticket_code` (bearer) — nilai bearer ada di DB dan berpotensi dipakai scan | Risiko keamanan G-05/F-10 | Pindahkan ke verifikasi berbasis `token_hash`; perubahan code + data |
| C-05 | `subscription_payments.method` bertipe `String` sedangkan `order_payments.method` memakai enum `PaymentMethod` | Inkonsistensi kontrak | Samakan tipe setelah keputusan C-03 |
| C-06 | Tidak ada kolom pilihan template tiket (§5) | Requirement PRD belum terwakili | Tambah kolom/relasi hanya setelah kontrak template ditetapkan (G-07) |
| C-07 | `events.attendee_fields` hanya array nama field, belum schema bertipe (label/type/required/options) | Validasi form dinamis (§4) belum lengkap | Perluas kontrak JSON setelah disepakati (G-07) |

Tidak satu pun dari C-01…C-07 memblokir alur MVP yang sudah berjalan, dan tidak ada yang diubah pada audit ini.


---

## D. Laporan Validasi Prisma

| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Validasi schema | `npx prisma validate --schema prisma/schema.prisma` | **PASS** — "The schema at prisma/schema.prisma is valid" |
| Generate client | `npx prisma generate --schema prisma/schema.prisma` | **PASS** — Prisma Client v6.19.0 (154 ms) |
| Status migration | `npx prisma migrate status --schema prisma/schema.prisma` | **PASS** — "Database schema is up to date!" (9/9 migration) |
| Drift struktur | `npx prisma migrate diff --from-schema-datasource … --to-schema-datamodel … --script` | **PASS** — `-- This is an empty migration.` |
| Sinkron function | `node scripts/diagnose-db-functions.js` | **PASS** — 4/4 function identik dengan migration terakhir |
| Sinkron schema menyeluruh | `node scripts/verify-schema-sync.js` | **PASS** — 32 tabel, 29 unique, 44 index, 19 enum, 54 FK semuanya SAMA |
| Unit/integration backend | `npm test` | **PASS** — 83/83 |
| Syntax & format | `npm run check`, `npm run format:check` | **PASS** — 61 file; format bersih |
| Skills/validator | `npm run validate:skills`, `npm run test:sync-config` | **PASS** — 7 skills; 14/14 |
| Flutter | `flutter analyze --no-fatal-infos`, `flutter test` | **PASS** — no issues; 187/187 |

**Relasi & constraint:** 54 foreign key terverifikasi; tidak ada FK yatim. Aksi referensial konsisten dengan prinsip retensi histori:

- `Cascade` hanya untuk objek turunan yang tidak punya nilai histori mandiri: `organizer_profiles`, `event_members`, `event_member_permissions`, `event_invitation_permissions`, `notifications`, `plan_features`.
- `Restrict` untuk data transaksional/histori: `event_orders`, `order_items`, `attendees`, `order_payments`, `tickets`, `check_ins`, `subscription*`, `support_report_activities`, `event_activity_logs`.
- `SetNull` untuk pelaku/penanggung opsional: `audit_logs.actor_id`, `tickets.user_id`, `scan_logs.scanned_by_user_id`, `check_ins.event_member_id`, `support_reports.reporter_id/assigned_to_id`, `event_invitations.accepted_by_id`, `subscription_history.changed_by_id`, `platform_setting_history.changed_by_id`.

Tidak ditemukan relasi yang memungkinkan inkonsistensi baru. Satu catatan: `platform_transactions` tidak memiliki CHECK "tepat satu sumber" (`order_payment_id` XOR `subscription_payment_id`) — dinyatakan sebagai kebutuhan di `docs/DATABASE.md`, belum ada di database. Ini memerlukan migration baru (`ALTER TABLE ... ADD CONSTRAINT`), bukan perubahan destruktif, tetapi mengubah skema → dicatat sebagai usulan (butuh persetujuan).

---

## E. Laporan Sinkronisasi Supabase

### E.1 Identifikasi koneksi (tanpa secret)

| Item | Nilai aman |
|---|---|
| Sumber konfigurasi | `backend/.env` → `DATABASE_URL` (dimuat `src/config/env.js` dan `src/config/db.js`) |
| Jenis host | Supabase pooler (`*.pooler.supabase.com:5432`) — project yang dipakai backend |
| Nama database / schema | `postgres` / `public` |
| Role koneksi | `postgres` (pemilik tabel) |
| Server | PostgreSQL 17.11 |
| Pool | **Satu** `new Pool()` di `src/config/db.js`; `src/config/supabase.js` hanya alias kompatibilitas tanpa client Supabase |
| Connection string lain / hardcoded | **Tidak ada** (pencarian `postgres://` di `backend/src` = 0 hasil) |

Project yang diaudit adalah project yang benar-benar dipakai backend (bukan project lain), karena backend membaca `DATABASE_URL` yang sama dan smoke test CRUD berhasil pada koneksi tersebut.

### E.2 Status kesesuaian schema

| Aspek | Aktual | Schema final | Status |
|---|---|---|---|
| Tabel aplikasi | 32 | 32 model | SAMA |
| Kolom | 302 | sesuai model | SAMA |
| Enum | 19 | 19 | SAMA |
| Foreign key | 54 | 54 | SAMA |
| Unique constraint/index | 29 | 29 | SAMA |
| Index non-unique | 44 | 44 | SAMA |
| Primary key | 32 | 32 | SAMA |
| Trigger/view/sequence | 0/0/0 | — | SAMA |
| Function | 4 | 4 (definisi migration) | SAMA (diverifikasi per baris) |

### E.3 Migration yang diterapkan

| Migration | Isi | Sifat | Status |
|---|---|---|---|
| `20261118000400_restore_payment_status_enum_cast` | 1 statement: `CREATE OR REPLACE FUNCTION public.create_event_order(...)` (menambahkan cast `::public."PaymentStatus"`) | **Non-destruktif**, idempotent (tanpa DROP/DML tabel) | **DITERAPKAN** via `prisma migrate deploy` |

Sebelum penerapan: snapshot logis seluruh 32 tabel diambil (hanya `event_categories` berisi 8 baris; tabel lain kosong). Sesudah penerapan: perbandingan baris-per-baris → **identik, 0 diff**, `_prisma_migrations` berisi **9 migration finished**.

Alasan penerapan: tanpa ini riwayat migration tidak konsisten dan setiap `checkout` gagal `500` (function versi lama menghasilkan tipe `text` untuk kolom enum `PaymentStatus`).

### E.4 RLS, policy, dan hak akses

| Item | Nilai aktual | Penilaian |
|---|---|---|
| RLS aktif | **32/32** tabel aplikasi | Baik (deny-by-default) |
| Policy | **0** | Tidak ada akses langsung klien; seluruh akses lewat backend |
| Grant `anon` | **0** | Tertutup |
| Grant `authenticated` | **0** | Tertutup |
| Grant `service_role` | 7 privilege × 33 objek | Wajar untuk service role |
| Pemilik tabel | `postgres` (= role backend) | Backend tidak terputus oleh RLS |

Tidak ada RLS yang dinonaktifkan untuk mengatasi error. Catatan: karena semua akses data melewati backend (`pg` sebagai pemilik tabel), RLS berfungsi sebagai lapisan pertahanan terhadap akses REST Supabase langsung, bukan sebagai otorisasi aplikasi — otorisasi tetap di middleware/controller backend.

### E.5 Integritas data

- Jumlah baris total sebelum & sesudah: **8** (hanya `event_categories`), 0 perubahan.
- Tidak ada penghapusan data pengguna/transaksi/order/tiket/event.
- Tidak ada `prisma migrate reset`, `db push --force-reset`, atau DROP DATABASE.


---

## F. Laporan Integrasi Aplikasi

### F.1 Backend → Supabase

| Pemeriksaan | Hasil |
|---|---|
| Koneksi database | **TERHUBUNG** — `GET /health` mengembalikan `200`, `database: connected` |
| Sumber query | Postgres langsung via `pg` (`src/config/db.js`), bukan mock |
| Mock repository menggantikan DB | **Tidak ada** di backend |
| Penyimpanan penting hanya di memory | **Tidak ada** untuk domain yang sudah diimplementasikan |
| Database lokal lain | **Tidak ada** (hanya satu `Pool`, satu `DATABASE_URL`) |
| Prisma runtime | Tidak dipakai runtime (sesuai desain); `prisma` hanya tooling schema/migration/client-generate |

### F.2 Frontend → backend

| Pemeriksaan | Hasil |
|---|---|
| Mode default | **API mode** — `AppConfig.mockMode` default `false` |
| Fallback mock saat API gagal | **Tidak ditemukan** (tidak ada `catch` yang mengembalikan data mock) |
| Form → backend | Terbukti: registrasi publik membuat order lewat `POST /api/orders`, pembayaran lewat `POST /api/payments/simulate`, tiket lewat `GET /api/tickets/my-tickets` |
| Reload data dari DB | Terbukti pada smoke test: data dibuat → dibaca ulang via API → status berubah (`pending` → `paid`) terbaca dari DB |

### F.3 Fitur yang sudah memakai database

Auth/session & role, Organizer event CRUD + kategori tiket, katalog event publik, registrasi guest + order + idempotency, pembayaran simulasi, penerbitan e-ticket/QR, check-in/scan, invitation Staff + permission, profil Organizer, paket/langganan (backend), laporan dukungan, notifikasi, riwayat audit token (logout).

### F.4 Fitur yang MASIH memakai data dummy (temuan)

| Fitur | File | Bukti |
|---|---|---|
| Admin dashboard (daftar event platform) | `features/admin/screens/admin_dashboard_screen.dart` | `_loadEvents()` fallback ke `MockOrganizerEventRepository.shared().listPlatformEvents()`; `admin_tab_controller.dart` membuat `const AdminDashboardScreen()` **tanpa** `eventsLoader` → selalu memakai mock |
| Admin revenue | `services/admin/admin_revenue_service.dart` | Tanpa `ApiService`; snapshot in-memory (padahal backend `revenueController` tersedia) |
| Admin paket layanan | `services/admin/admin_package_service.dart` | In-memory; backend `planController` tersedia |
| Admin langganan | `services/admin/admin_subscription_service.dart` | In-memory; backend `subscriptionController` tersedia |
| Admin pengaturan & audit log | `services/admin/admin_settings_service.dart`, `admin_audit_log_service.dart` | In-memory; tabel `platform_settings`/`audit_logs` belum dipakai backend |
| Rencana/langganan Organizer | `services/organizer_plans/organizer_plans_service.dart` | In-memory |
| Notifikasi Organizer | `services/organizer_notifications/organizer_notifications_service.dart` | In-memory |
| Membership Organizer | `services/organizer_membership/organizer_membership_service.dart` | In-memory |
| Dukungan Organizer | `services/organizer_support/organizer_support_service.dart` | In-memory |
| Aktivitas event | `services/organizer_operations/event_activity_service.dart` | In-memory (tabel `event_activity_logs` belum ditulis backend) |

Fitur-fitur di atas **tidak diubah** pada audit ini: wiring UI Admin/Organizer adalah pekerjaan fitur (Tahap 2/3) dan di luar wewenang perubahan minimal audit database. Dicatat sebagai limitation.

### F.5 Hasil pengujian CRUD terhadap Supabase

Dijalankan `node scripts/integration/stage1.db-smoke.cjs` terhadap Supabase (API loopback + DB nyata): **14/14 PASS**, cleanup **0 residu**.

| Domain | Operasi yang diuji | Hasil |
|---|---|---|
| Auth (`profiles`) | Create (register) → Read (`/me`) → Role dari DB | PASS |
| Event (`events`) | Create → Read publik → Update (approve) | PASS |
| Kategori tiket (`ticket_types`) | Create → Read publik (DTO kuota) → Update (sold/held oleh RPC) | PASS |
| Order (`event_orders`, `order_items`) | Create guest → Read (token) → idempotent replay | PASS |
| Attendee (`attendees`) | Create via RPC → Read via tiket | PASS |
| Payment (`order_payments`) | Create (pending) → Update status (paid) | PASS |
| Ticket (`tickets`) | Create via RPC → Read (kontrak + QR token) → scan validate | PASS |
| Check-in (`check_ins`, `scan_logs`) | Create check-in → duplicate ditolak 409 | PASS |
| Delete/cleanup | Hapus seluruh fixture uji | PASS (0 baris tersisa) |

Domain paket/langganan/laporan sudah diverifikasi pada level backend sebelumnya (`backend.integration.cjs`), namun tidak dijalankan ulang pada audit ini karena harness resminya menolak host non-loopback. Statusnya **NOT RUN (live)** pada audit ini.

---

## G. Kesimpulan Akhir

**Status: READY WITH LIMITATIONS**

Alasan:

1. **Schema valid & konsisten** — `prisma validate` PASS, `migrate diff` kosong, 32 tabel/310 kolom/19 enum/54 FK/105 index identik antara `schema.prisma` dan Supabase.
2. **Supabase sinkron** — `migrate status` "up to date" (9/9), function 4/4 identik dengan migration, riwayat migration kini lengkap setelah menerapkan 1 migration tertinggal.
3. **Integrasi backend terbukti** — CRUD nyata ke Supabase 14/14 PASS, data sebelum/sesudah identik, cleanup bersih.
4. **Keamanan dasar baik** — RLS 32/32 aktif, 0 policy, 0 grant `anon`/`authenticated`.
5. **Belum READY penuh karena:**
   - beberapa fitur UI Admin/Organizer masih memakai data dummy (F.4);
   - gap fungsional PRD masih terbuka: G-01 (assisted legacy), G-02 (auto-publish), G-05/F-10 (QR berbasis hash), G-06 (paid-first + export), G-07 (form dinamis/brosur/template), G-09 (expiry/email), G-10 (viewport);
   - butir skema yang perlu keputusan FINISHING (C.1, C.3) belum diubah, termasuk CHECK `platform_transactions` tepat-satu-sumber;
   - SMTP nyata, device/browser, dan uji concurrency belum dijalankan (**NOT RUN**).

**Langkah berikutnya untuk mencapai READY:** sambungkan layar Admin/Organizer ke endpoint backend yang sudah ada, tutup G-02/G-05/G-06/G-07, dan ajukan C-01…C-07 + CHECK `platform_transactions` sebagai migration baru setelah persetujuan FINISHING.


---

## H. Addendum verifikasi 2026-11-23 — akun Admin dan status implementasi object

Audit di atas tetap berlaku. Addendum ini mencatat perubahan setelah audit:

| Item | Kondisi aktual | Bukti |
|---|---|---|
| Baris `profiles` | **1** (akun Admin platform, `role = 'admin'`, `password_hash` bcrypt) | `npm run admin:provision` → `CREATED`; eksekusi ulang → `UNCHANGED` |
| Seeder password | Tidak ada password default di source code (`seedService.js` lama dihapus isinya) | `backend/src/services/seedService.js`, `adminBootstrapService.js` |
| Auth | Tabel `profiles` + bcrypt + JWT; tidak ada Supabase Auth | 15/15 skenario login/otorisasi PASS |
| Schema/migration | Tidak berubah: 32 tabel, 19 enum, 54 FK, 105 index, 9 migration applied | `verify-schema-sync.js` PASS, `migrate status` up to date |
| `audit_logs`, `platform_settings`, `platform_setting_history` | Masih **REQUIRED BUT NOT IMPLEMENTED** (tanpa endpoint) | lihat `TAHAP_2/RENCANA_KERJA.md` D3-3/D3-4 |
| `event_activity_logs` | Masih PARTIALLY USED (belum ada penulisan) | audit bagian B |

Temuan dan perbaikan rinci ada di
[`TAHAP_1/LAPORAN_DEVELOPER_4.md`](TAHAP_1/LAPORAN_DEVELOPER_4.md) bagian 9.


## Lampiran 1 — Audit enum (19)

| Enum | Nilai | Dipakai kode | Catatan |
|---|---|---|---|
| `EventFormat` | OFFLINE, ONLINE, HYBRID | Ya | Validasi `validateEventInput` |
| `EventStatus` | DRAFT, PENDING_REVIEW, REVISION_REQUESTED, APPROVED, PUBLISHED, REJECTED, SUSPENDED, COMPLETED, CANCELLED | Sebagian | Status legacy `PENDING_REVIEW/REVISION_REQUESTED/APPROVED/REJECTED` bertentangan dengan auto-publish (C.3 C-03) |
| `ModerationDecision` | APPROVED, REVISION_REQUESTED, REJECTED, SUSPENDED | Ya | Dipakai `moderate_event` |
| `EventPermission` | 9 nilai termasuk `ASSIST_REGISTRATION` | Ya (8 nilai) | `ASSIST_REGISTRATION` bertentangan dengan PRD no-assisted (C.3 C-01) |
| `InvitationStatus` | PENDING, ACCEPTED, EXPIRED, REVOKED | Ya | — |
| `RegistrationMethod` | SELF_SERVICE, ASSISTED | Tidak (selalu default) | Legacy assisted (C.3 C-01) |
| `OrderStatus` | PENDING_PAYMENT, PAID, EXPIRED, CANCELLED | Ya | `CANCELLED` belum ada kebijakan produk (OPEN) |
| `PaymentStatus` | PENDING, PAID, EXPIRED, FAILED, CANCELLED | Ya | `CANCELLED` belum dipakai jalur simulasi |
| `PaymentMethod` | SIMULATED_VIRTUAL_ACCOUNT | Ya | Satu nilai sesuai MVP |
| `ScanResult` | VALID, ALREADY_USED, INVALID, WRONG_EVENT, CANCELLED, REVOKED, PAYMENT_REQUIRED, NETWORK_ERROR | Sebagian | Yang ditulis hanya `VALID`; nilai lain disiapkan untuk hasil scan |
| `CheckInSource` | ONLINE, OFFLINE_SYNC | Ya | `OFFLINE_SYNC` = Post-MVP namun route sync masih ada (bukan bukti MVP) |
| `EmailDeliveryStatus` | PENDING, SENT, FAILED | Ya | `NOT_CONFIGURED` dipetakan ke PENDING di service |
| `PlanStatus` | ACTIVE, INACTIVE, ARCHIVED | Ya | — |
| `SubscriptionStatus` | ACTIVE, PENDING_PAYMENT, EXPIRED, CANCELLED, SUSPENDED | Sebagian | C-03 OPEN |
| `BillingInterval` | MONTHLY, YEARLY | Ya | — |
| `ReportCategory` | 9 nilai | Ya | — |
| `ReportStatus` | OPEN, IN_PROGRESS, WAITING_FOR_USER, RESOLVED, CLOSED | Ya | — |
| `ReportPriority` | LOW, MEDIUM, HIGH, URGENT | Ya | — |
| `ReportActivityVisibility` | PUBLIC, INTERNAL | Ya | Pemisahan balasan publik/internal |

Tidak ada nilai enum duplikat atau bertabrakan makna. Tidak ada enum yang sepenuhnya tidak diperlukan.

## Lampiran 2 — Audit index & constraint

- **105 index** = 32 PK + 29 unique + 44 non-unique. Tidak ditemukan index duplikat (tidak ada pasangan index dengan kolom & urutan identik).
- Index komposit utama sesuai pola query nyata: `events(status, event_date)`, `event_orders(event_id, status, created_at)`, `event_orders(purchaser_id, created_at)`, `tickets(event_id, status)`, `tickets(user_id, purchased_at)`, `notifications(user_id, read_at, created_at)`, `scan_logs(event_id, scanned_at)`, `support_reports(status, priority, created_at)`.
- **Unique** melindungi invariant bisnis: `event_orders.order_number`, `event_orders.idempotency_key`, `event_orders.guest_access_token_hash`, `tickets.ticket_code`, `tickets.token_hash`, `tickets.attendee_id`, `check_ins.ticket_id`, `order_items(order_id, ticket_type_id)`, `event_members(event_id, user_id)`, `plan_features(plan_id, key)`, `platform_transactions(order_payment_id)`, `platform_transactions(subscription_payment_id)`.
- **Tidak ada constraint duplikat** dan tidak ada constraint yang menghalangi alur sah.
- **Constraint yang belum ada** (usulan, bukan perubahan): `CHECK (num_nonnulls(order_payment_id, subscription_payment_id) = 1)` pada `platform_transactions`; `CHECK (sold + held <= quota)` pada `ticket_types`. Keduanya memerlukan migration baru + persetujuan.

## Lampiran 3 — Audit keamanan database

| Aspek | Kondisi | Penilaian |
|---|---|---|
| RLS | Aktif 32/32 tabel aplikasi | Baik |
| Policy | 0 | Deny-by-default untuk akses langsung klien |
| Grant `anon`/`authenticated` | 0 | Akses REST langsung tertutup |
| Grant `service_role` | Penuh (7 privilege) | Sesuai peran service |
| Otorisasi aplikasi | Middleware `authMiddleware`/`optionalAuth` + `roleMiddleware` + cek kepemilikan event/membership/permission di controller | Baik (server-authoritative) |
| Isolasi antar-Organizer | `getEventForOwner`, `ensureEventOwner`, filter `created_by`/`purchaser_id` | Baik; diuji pada `stage1_integration.test.js` |
| Token sensitif | `guest_access_token_hash` (SHA-256 + `timingSafeEqual`), `event_invitations.token_hash`, `support_reports.status_token_hash`, `revoked_tokens.token_hash` | Baik; raw token tidak disimpan |
| Kebocoran di response | `token_hash` di-strip oleh `presentTicket`; `guest_access_token_hash` tidak dikirim (`serializeOrder`) | Baik |
| Risiko sisa | `tickets.qr_code_data` menyimpan bearer `ticket_code`; scanner masih menerima kode bearer, bukan hash | Perlu perbaikan kode (G-05/F-10) |

## Lampiran 4 — Batasan audit

1. Tidak ada backup fisik (`pg_dump`) — hanya snapshot logis JSON 32 tabel sebelum perubahan (data 8 baris).
2. Uji paket/langganan/laporan ke DB live **NOT RUN** pada audit ini (harness resmi menolak host non-loopback; domain tersebut sudah diuji sebelumnya pada harness terpisah).
3. SMTP nyata, device Android/Web, dan uji konkurensi **NOT RUN**.
4. Perubahan bersifat minimal: 1 migration diterapkan + 2 file dokumentasi. Tidak ada file kode aplikasi yang diubah pada audit ini.

