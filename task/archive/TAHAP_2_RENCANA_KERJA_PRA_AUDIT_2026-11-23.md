# Rencana kerja Tahap 2 — hasil rekonsiliasi (2026-11-23)

Dokumen ini **menggantikan asumsi rencana Tahap 2 lama** sebagai daftar pekerjaan
aktif. Isi teknis per developer tetap mengacu pada
[`DEVELOPER_1_TASK.md`](DEVELOPER_1_TASK.md), [`DEVELOPER_2_TASK.md`](DEVELOPER_2_TASK.md),
[`DEVELOPER_3_TASK.md`](DEVELOPER_3_TASK.md), [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md),
dan [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md).

Basis rekonsiliasi: verifikasi Tahap 1 tanggal 2026-11-23
([`../TAHAP_1/LAPORAN_DEVELOPER_4.md`](../TAHAP_1/LAPORAN_DEVELOPER_4.md) bagian 9),
[`../DATABASE_AUDIT_FINAL.md`](../DATABASE_AUDIT_FINAL.md), schema
`backend/prisma/schema.prisma` (32 model, 19 enum, 9 migration applied), serta kondisi
kode aktual.

## A. Kondisi awal yang sudah terverifikasi (jangan dikerjakan ulang)

| Kapabilitas | Bukti | Status |
|---|---|---|
| Auth JWT + role server-authoritative (`authMiddleware` memuat ulang role/disabled dari `profiles` tiap request) | 15/15 skenario login/otorisasi pada DB nyata (D4 Tahap 1 §9.2) | SELESAI |
| Akun Admin nyata di `profiles` (role `admin`, bcrypt) + provisioning idempotent `npm run admin:provision` | `CREATED` lalu `UNCHANGED`; login 200 role admin | SELESAI |
| Event CRUD/ownership, kategori tiket, order guest, simulasi payment, tiket/QR, check-in online | Smoke D4 14/14 + `stage1.db-smoke.cjs` | SELESAI (Tahap 1) |
| Endpoint invitation, membership/permission, attendee list, check-in/scan, admin accounts & moderation, plans, subscriptions, revenue, support reports, notifications | Route/controller ada di `backend/src/routes/*` dan schema | TERSEDIA (belum semua diverifikasi E2E dari Flutter) |
| Dashboard Admin memuat event platform dari `GET /api/events` (admin-only), error/retry tanpa fallback mock | `apps/lib/features/admin/screens/admin_dashboard_screen.dart` + test | SELESAI (D3 Tahap 2, lihat `LAPORAN_DEVELOPER_3.md`) |

## B. Pekerjaan yang dihapus dari rencana lama (tidak lagi relevan)

1. **Membuat/menyeed akun Admin atau Organizer demo** — sudah diganti provisioning
   berbasis environment; seed password tetap dihapus dari backend dan Flutter.
2. **Menambah route/login Admin baru atau sistem auth kedua** — mekanisme `profiles`
   + bcrypt + JWT sudah dipakai; tidak ada Supabase Auth di proyek ini.
3. **Membuat endpoint attendee/check-in/invitation dari nol** — endpoint sudah ada;
   pekerjaan yang tersisa adalah verifikasi kontrak + wiring UI/export.
4. **Migrasi/schema baru untuk Tahap 2** — tidak diperlukan; seluruh objek Tahap 2
   sudah ada di schema dan database (0 drift). Kebutuhan baru tetap lewat
   `../DB_CHANGE_PROPOSAL.md`.

## C. Pekerjaan tersisa

### C.1 Developer 1 — Invitation/membership (prioritas setelah Admin)

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| D1-1 | Trace `create/list/revoke/accept` invitation + cek email-match, expiry, revoked, membership aktif, permission scoped | `eventInvitationController.js`, `eventController.js` (members), `apps/lib/features/organizer/membership/**`, `services/organizer_membership/**` | — | Endpoint menolak invitation invalid/expired/revoked/email mismatch; acceptance membuat satu `event_members` + permission | `backend/test/*invitation*` baru + widget test |
| D1-2 | Wiring layar team/membership Organizer ke API (bukan in-memory) | `services/organizer_membership/organizer_membership_service.dart`, `team_management_screen.dart`, `staff_management_screen.dart` | D1-1 | Daftar anggota/undangan berasal dari API; loading/empty/error/retry | widget test dengan fake service + analyze |
| D1-3 | Deep-link acceptance/redirect scanner | `app_router.dart` (minimum), `invitationsRoutes` | D1-2 | Link acceptance memerlukan login + email cocok; sukses -> scanner event | manual/NOT RUN bila device tidak tersedia |

### C.2 Developer 2 — Scanner/check-in & attendee source

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| D2-1 | Verifikasi server: token hash, event scope, permission, ticket eligible/paid, duplicate scan, atomic check-in | `checkInController.js`, `ticketTokenService.js`, `ticketController.js` | — | Scan valid 1x sukses; duplikat/wrong event/unpaid/no permission ditolak tanpa check-in | unit + pola `stage1.db-smoke` |
| D2-2 | Pastikan tiket gratis menerima `token_hash` saat penerbitan (F-10) | `ticketTokenService.js`, `paymentController.js`, RPC pemanggil | D2-1 | Tiket gratis dapat di-scan tanpa backfill manual | unit + DB smoke |
| D2-3 | UI scanner: permission/camera/error/loading/sukses, retry; tanpa offline-success | `organizer_scanner_screen.dart`, `services/scanner/**` | D2-1 | State jelas, tidak ada klaim offline; token tidak di-log | widget test + analyze |
| D2-4 | Attendee source `GET /api/events/:eventId/attendees`: paid-first, nomor registrasi stabil, event/permission filter | `checkInController.listEventAttendees` | — | Urutan & field sesuai AC-09 | unit test controller |

### C.3 Developer 3 — Attendee UI/export, Admin persistence

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| D3-1 | Dashboard Admin event platform dari API | `admin_dashboard_screen.dart` | — | **SELESAI**; error/retry, tanpa mock | 3 widget test PASS |
| D3-2 | `AccountManagementScreen` memakai `GET /api/admin/accounts` + `PUT /api/admin/accounts/:id/status` (bukan `_mockAccounts`) | `account_management_screen.dart` + service admin akun | D3-1 | Akun Admin/Organizer nyata tampil; suspend/aktifkan persist; alasan wajib; error/retry | widget test fake client + analyze |
| D3-3 | Audit log nyata: endpoint `GET /api/admin/audit-logs` membaca `audit_logs`, menulis entri pada suspend; ganti `AdminAuditLogService` in-memory | `adminController.js`/route admin, `admin_audit_log_service.dart`, `audit_log_screen.dart` | D3-2 | Aksi Admin tercatat dengan actor+reason; layar membaca database | unit + widget test |
| D3-4 | Pengaturan platform: `GET/PUT /api/admin/settings` + history (`platform_settings`, `platform_setting_history`) | `adminController.js`, route admin, `admin_settings_service.dart`, `admin_settings_screen.dart` | D3-3 | Nilai tersimpan; perubahan mencatat history + audit | unit + widget test |
| D3-5 | Export attendee (CSV) dari payload attendee yang sama dengan UI; escaping aman | `attendee_list_screen.dart` + helper export | D2-4 | Set/urutan identik UI, CSV escape benar | unit test CSV + widget test |
| D3-6 | Revenue/paket/langganan Admin: ganti snapshot in-memory dengan `GET /api/revenue`, `/api/plans`, `/api/subscriptions` (C-03 OPEN → tanpa entitlement baru) | `admin_revenue_service.dart`, `admin_package_service.dart`, `admin_subscription_service.dart` | D3-3 | Angka dari API; tidak mengklaim formula final | unit + widget test |

## D. Urutan implementasi dan gate

1. **D3-2 → D3-3 → D3-4** — Admin memakai data nyata; audit/config menutup gap
   `REQUIRED BUT NOT IMPLEMENTED` pada `audit_logs`/`platform_settings`.
2. **D2-1 → D2-2 → D2-3** — keamanan scan lebih dulu, lalu UX scanner.
3. **D2-4 → D3-5** — attendee source lalu export (parity set/urutan).
4. **D1-1 → D1-2 → D1-3** — invitation/membership; deep-link terakhir.
5. **D3-6** terakhir karena bergantung keputusan C-03 (kerjakan read-only).

### Gate integrasi Tahap 2

- `npm test`, `npm run check`, `npm run format:check`, `npm run validate:skills`,
  `npm run test:sync-config` PASS di `backend/`.
- `flutter analyze --no-fatal-infos` dan `flutter test` PASS di `apps/`.
- Tidak ada jalur API yang jatuh ke mock; otorisasi negatif (organizer,
  participant, tanpa token) terbukti 401/403 di backend.
- Bukti DB/API nyata dicatat terpisah dari widget/unit test; device/browser yang
  tidak tersedia dicatat **NOT RUN** dengan alasan spesifik.
- Tidak ada perubahan schema/migration; kebutuhan DB ditulis di
  `../DB_CHANGE_PROPOSAL.md` dan tidak memblokir pekerjaan non-DB.


