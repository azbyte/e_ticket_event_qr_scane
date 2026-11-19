# PROJECT ASSESSMENT — E-Ticket Event

**Tanggal:** 18 November 2026. **Batas:** analisis working tree yang ada; tidak ada kode, schema, database, konfigurasi, atau file lain diubah. Working tree sudah memuat perubahan lokal sebelum audit. Tidak menjalankan migration, reset, seed, ataupun operasi DB.

## 1. Ringkasan kondisi proyek

Proyek memiliki Flutter Android/Web dan API Express/PostgreSQL dengan cakupan event, moderasi, tiket, order, pembayaran simulasi, staff/membership, check-in, report, notification, plan/subscription, revenue, dan audit. Prisma schema serta migration memodelkan domain yang luas. Akan tetapi, halaman/endpoint/tabel tidak dengan sendirinya membuktikan alur end-to-end. Integrasi Flutter beragam; mode API default, sementara mode mock eksplisit tersedia. Beberapa layar/service Admin dan operasi masih memakai data lokal.

**Penilaian:** fondasi MVP substansial ada, tetapi kesiapan operasional belum terbukti. Alur create/moderate event dan order→simulated payment→ticket didukung source, namun perlu tes integrasi. Area yang paling belum mantap: hubungan UI ke API, dashboard Admin, Staff UX, email/notifikasi, offline scanner, monetisasi, dan verifikasi keamanan/migration pada environment hidup.

Status: **SELESAI** = terbukti sampai cakupan yang disebut; **SEBAGIAN** = implementasi ada, alur belum lengkap/teruji; **MOCK** = demonstrasi lokal; **BELUM ADA** = tidak ditemukan; **BERMASALAH** = blocker/ketidaksesuaian; **LEGACY** = kompatibilitas lama; **TIDAK RELEVAN** = di luar MVP saat ini. **BELUM DIVERIFIKASI** adalah batas bukti, bukan status tambahan.

## 2. Kondisi arsitektur frontend dan backend

| Lapisan | Temuan | Batas bukti |
|---|---|---|
| Flutter | `apps/lib/` memakai core/features/models/providers/services, Provider, HTTP, secure storage; router di `apps/lib/app_router.dart`. Factory repository Organizer memilih mock/API. | Tes demo lokal lulus; bukan bukti API/perangkat live. |
| Backend | CommonJS, Express 4; routes/controllers/middleware/services; query PostgreSQL lewat `pg` (`backend/src/config/db.js`), Prisma schema/migrations tersedia. | Sebagian besar operasi memakai SQL langsung; semua model Prisma belum tentu dipakai. |
| Data | `backend/prisma/schema.prisma`, migration Prisma dan satu migration Supabase legacy. Model mencakup profile, event, member/permission, invitations, ticket_types, orders, attendees, payments, tickets, check-ins, plans, reports, settings, audit, notifications. | Database hidup, migration status, jumlah tabel, dan privilege **BELUM DIVERIFIKASI**. |
| Auth | JWT diverifikasi; `authMiddleware.js` membaca role/status terkini dari profil DB, menolak disabled/revoked token. `roleMiddleware.js` membatasi role global. | Konfigurasi dan perilaku deployment **BELUM DIVERIFIKASI**. |
| Payment | `paymentController.js` menyediakan simulasi VA yang dapat dimatikan konfigurasi. | Bukan transaksi bank, gateway, payout atau refund nyata. |
| Supabase/RLS | Ada migration RLS/grants, tetapi dokumentasi arsitektur menyebut PostgreSQL `pg` dan Prisma. | Efek migration pada DB live **BELUM DIVERIFIKASI**; migration file bukan bukti keamanan aktif. |

**Konflik dokumentasi:** PRD bagian awal/akhir menyebut UI prototype dummy dan larangan backend/API; source dan `docs/ARCHITECTURE.md` mendeskripsikan backend aktif serta Flutter API-mode default. `backend/README.md` juga memuat rincian Supabase/RLS yang tidak dapat dianggap kondisi live. PRD perlu keputusan pemutakhiran; source/migration aktual lebih relevan untuk perilaku sekarang.

## 3. Role, pengguna dan hak akses

Role global yang disepakati PRD (`prd.md` §2): `PARTICIPANT`, `ORGANIZER`, `ADMIN`. Field role DB bertipe teks. `OWNER` dan `STAFF` adalah membership per-event, bukan role global. Tabel yang terkait: `event_members`, `event_member_permissions`, `event_invitations`, `event_invitation_permissions`.

| Role/pengguna | Tanggung jawab dan hak | Batas akses | UI dan status |
|---|---|---|---|
| Admin | Pengelola platform: akun, moderasi event, support, pengawasan. | Tidak melihat password/credential; bukan pengelola harian semua event. | `features/admin/screens/` mencakup dashboard, akun, moderasi, package, subscription, revenue, report, audit/settings. Route admin dan role middleware nyata; beberapa service layar lokal/mock. SEBAGIAN. |
| Organizer / Owner event | Membuat/mengelola event sendiri, tiket, peserta, order, staff dan laporan event. | Hanya event milik sendiri; tidak memutuskan moderasi sebagai Admin. | Banyak halaman organizer; event/order/ticket/membership endpoints ada. Ownership harus diuji per operasi. SEBAGIAN. |
| Staff | Akun Organizer yang menerima undangan untuk satu event dengan izin terbatas. | Bukan hak penuh Organizer; tidak otomatis boleh mengundang staff, melihat order/pembayaran atau mengubah event. | `staff_dashboard_screen.dart`, operasi/scanner. Backend membership dan permission ada. Mapping role/route UI perlu konsolidasi. SEBAGIAN. |
| Participant | Menemukan event, checkout, membayar simulasi, memakai tiket dan membuat laporan. | Tidak mengakses data peserta lain atau endpoint tugas petugas. | Auth/event/registration/order/payment/ticket/report screens dan endpoints ada. Guest checkout didukung route optional-auth. SEBAGIAN. |

Backend menegakkan auth/role pada route yang relevan; router Flutter juga memblokir UI, tetapi UI guard bukan boundary keamanan. `checkInController.assertScanPermission` mengizinkan owner/Admin atau event member dengan `SCAN_TICKET`/`CHECK_IN_TICKET`. Controller per endpoint tetap perlu diuji untuk ownership/permission yang benar.

**Kontradiksi Staff:** PRD dan schema menganggap Staff membership per-event; Flutter `app_router.dart` mempunyai staff routes dan `_homeRouteForRole` mengenal nilai `staff`. Jangan menyimpulkan Staff role global berfungsi. Rekomendasi: satu akun Organizer, dashboard/tugas Staff ditentukan membership aktif yang diperoleh dari backend.

## 4. Inventaris fitur per role dan Feature Matrix

“Ada” berarti artefak source dikenali, bukan bukti fungsi produksi. Database “ada/model” bukan bukti bahwa DB live sudah termigrasi.

| Role | Fitur | Frontend | Backend | Database | Status | Keterangan |
|---|---|---|---|---|---|---|
| Admin | Dashboard | Ada | Ringkasan organizer ada; dashboard platform belum dipastikan tersambung | event/order/transaction | SEBAGIAN | Layar ada; feed real belum terbukti. |
| Admin | Akun/organizer/status | `account_management_screen.dart` | `/admin/accounts`, `/organizers`, `/accounts/:id/status` | profiles | SEBAGIAN | Route admin ada; alur UI/end-to-end belum tervalidasi. |
| Admin | Moderasi event | `event_moderation_screen.dart` | `PUT /admin/events/:id/moderation` | events/event_moderations | SEBAGIAN | Implementasi route/schema ada; tes lifecycle dari UI ke DB belum. |
| Admin | Event global | UI admin | `GET /events` admin, detail | events/categories | SEBAGIAN | Koneksi layar/filter belum terbukti. |
| Admin | Support/report | `report_management_screen.dart` | list/detail/status/priority/reply/internal note | support_reports/activities | SEBAGIAN | Backend ada; route memerlukan auth. Guest report PRD tidak terlihat. |
| Admin | Paket layanan | `package_management_screen.dart` | plan CRUD admin | plans/plan_features | MOCK | Service layar mengandung state lokal; API tidak membuktikan layar terhubung. |
| Admin | Subscription | screen tersedia | subscription organizer; operasi Admin lengkap belum ditemukan | subscriptions/payments/history | MOCK/SEBAGIAN | Model dan UI ada; koneksi/enforcement belum terbukti. |
| Admin | Pendapatan/transaksi | `transaction_revenue_screen.dart` | `/revenue/admin/summary`, `/transactions` | platform_transactions | MOCK/SEBAGIAN | Service revenue secara eksplisit berisi transaksi mock. |
| Admin | Settings/audit log | screens tersedia | API khusus tidak teridentifikasi pada route list | platform_settings/history/audit_logs | MOCK/SEBAGIAN | Model/UI ada, persistence API belum dibuktikan. |
| Organizer | Profil/dashboard | screen tersedia | `/organizer/overview`, summaries; auth profile | profiles/organizer_profiles | SEBAGIAN | Koneksi layar belum menyeluruh. |
| Organizer | CRUD event dan event milik | management/form/detail | `/events`, `/events/mine`, PUT/DELETE | events/categories | SEBAGIAN | API repository dan mock repo keduanya ada; ownership perlu test. |
| Organizer | Submit/revisi moderasi | event form/detail | `POST /events/:id/submit-review` | events/event_moderations | SEBAGIAN | Endpoint tersedia; lifecycle UI belum end-to-end teruji. |
| Organizer | Tiket, harga, kuota | ticket type form | CRUD `/events/:eventId/ticket-types` | ticket_types | SEBAGIAN | Capacity/hold/expiry/race belum terbukti. |
| Organizer | Peserta/order/metric | attendee/order/dashboard | attendee, order, event summary/sales | attendees/orders/items | SEBAGIAN | API ada; granular VIEW_PARTICIPANTS perlu dites per event. |
| Organizer | Registrasi dibantu | assisted registration | order method/permission | orders/attendees/members | SEBAGIAN | Domain ada; staff flow terhubung belum terbukti. |
| Organizer | Kelola Staff/permission | team/staff screens | invitations, members, permissions | invitation/member tables | SEBAGIAN | Backend tersedia, UI dan acceptance live belum diuji. |
| Organizer | Link peserta publik/QR | event detail/preview | public event/detail/ticket-types/order | events/ticket_types | SEBAGIAN | Bukan link invitation; QR/link yang benar-benar bisa dibagikan belum diverifikasi. |
| Organizer | Laporan/aktivitas/support | screens tersedia | report/metrics; event activity belum merata | reports/logs | SEBAGIAN | API dan UI tidak terbukti semua tersambung. |
| Organizer | Plan/subscription/revenue | screens/service | subscription dan revenue endpoints | plans/subscriptions/transactions | SEBAGIAN | Harga/komisi masih keputusan terbuka; beberapa tampilan mock. |
| Staff | Menerima/lihat invitation | staff dashboard | `GET /invitations/me`, `POST /invitations/:token/accept` | invitations/members | SEBAGIAN | Controller memeriksa hash token, status, expiry, email. Pengiriman undangan tak terbukti. |
| Staff | Event/peserta sesuai izin | dashboard/attendee | event/attendee routes | events/attendees/permissions | SEBAGIAN | Periksa setiap endpoint dengan permission spesifik; role UI tidak cukup. |
| Staff | Registrasi dibantu | assisted screen | order backend | orders/attendees | SEBAGIAN | Alur penuh belum diverifikasi. |
| Staff | QR scan/check-in online | scanner/history | validate/verify/check-in | tickets/check_ins/logs | SEBAGIAN | Permission server ada; kamera/perangkat belum diuji. |
| Staff | Offline scan/sync | scanner/local queue | `POST /check-ins/sync` | check_ins/logs | SEBAGIAN | Konflik, replay, multi-device dan policy terbuka. |
| Participant | Registrasi/login/profil | auth screens | `/auth/register`, login/me/logout | profiles | SEBAGIAN | Backend ada; README menyebut register umum membuat Organizer; kebutuhan akun Participant perlu diputuskan. |
| Participant/guest | Jelajah/detail event | list/detail | `/events/public`, detail, ticket types | events/categories/ticket_types | SEBAGIAN | Endpoint publik tersedia; keseluruhan UI/runtime belum diuji. |
| Participant/guest | Registrasi dan order | registration/order | `POST /orders` optional auth | orders/items/attendees | SEBAGIAN | Guest checkout didukung route; capacity/runtime belum diverifikasi. |
| Participant/guest | Pembayaran VA | payment/status screen | get/simulate payment | order_payments/orders | SEBAGIAN | Simulasi saja, bukan bank/gateway nyata. |
| Participant/guest | E-ticket/riwayat/email | ticket/order/QR screens | my-tickets/detail/email/order | tickets/orders/email delivery | SEBAGIAN | API/token store ada; guest access dan provider email belum end-to-end. |
| Participant | Check-in | QR display | scan/check-in untuk petugas | tickets/check_ins | SEBAGIAN | Participant memakai tiket; bukan pemanggil hak petugas. |
| Participant | Notifikasi | notification screen | list/read/read-all | notifications | SEBAGIAN | Endpoint/model ada; UI/provider delivery belum diverifikasi. |
| Participant/guest | Laporan dan status | report screens | report routes memakai auth | reports/activities | SEBAGIAN | PRD guest/token status tak cocok dengan route yang diperiksa. |

### Tautan peserta vs tautan Staff

1. **Public participant registration link:** `/events/public`, detail event, ticket types dan guest order mendukung discovery/registrasi. QR/link publik yang dibuat dan dibagikan oleh UI belum diverifikasi lengkap.
2. **Staff invitation/access link:** event invitation punya token hash, expiry, permission, acceptance melalui akun dengan email cocok. Routes: create/list/revoke di event, accept/me di invitations. Email delivery belum terbukti. Tidak boleh digabung dengan link peserta.

### Guest checkout

`orderRoutes.js`, payment/ticket routes memakai `optionalAuth` pada sebagian operasi; jadi backend mendukung order tanpa akun. Ini berbeda dari login/register. Belum dibuktikan semua pemulihan tiket guest dan UI-nya aman/mudah.

## 5. Fitur selesai, sebagian, mock, belum ada, bermasalah, legacy

### Selesai terbatas

- Auth middleware backend memverifikasi JWT dan role/status database terkini, disabled user dan revoked token.
- Schema/migration memodelkan domain inti, membership, order, tiket, report, subscription dan audit.
- Simulasi payment secara eksplisit dapat dibatasi konfigurasi.
- Tes demo Flutter lulus 139, 11 skipped. Backend unit tests 17/17; syntax 61 file dan skill validation lulus.

Tidak ada klaim bahwa seluruh alur produksi selesai: DB/provider/perangkat tidak diuji.

### Sebagian

Event create→review→publish; ticket type→order→payment→ticket; assisted registration; Staff invite→permission; scanner→check-in; report, notification dan dashboard. Implementasi API/schema/UI ditemukan, tetapi integrasi, ownership, state kegagalan atau runtime belum terbukti lengkap.

### Mock

- `MOCK_MODE=true` memilih mode demo eksplisit; factory Organizer memisahkan mock/API.
- `apps/lib/services/admin/admin_revenue_service.dart` mencatat mock transactions dan local snapshot.
- Service package/subscription dan sejumlah operasi memakai data lokal; fixtures attendee/check-in digunakan pada mode demo.
- Tes demo membuktikan simulasi lokal, bukan persistensi server.

### Belum tersedia atau belum diverifikasi

- Gateway pembayaran, payout/refund otomatis (di luar MVP menurut PRD).
- Live email/undangan/notifikasi, kamera, deployment, offline multi-device: **BELUM DIVERIFIKASI**.
- Guest report/status-token: route `reportRoutes.js` memasang `authMiddleware`; tidak ditemukan route publik khusus.
- API persistent Admin settings/audit UI: model/screen ada, endpoint dedicated tidak tampak di daftar routes.
- Integrasi penuh UI Admin/Staff, RLS dan migration pada DB live: **BELUM DIVERIFIKASI**.

### Masalah, duplikasi, legacy

| Temuan | Bukti/risiko | Saran |
|---|---|---|
| PRD prototype bertentangan dengan source API | PRD melarang backend; arsitektur/source mengaktifkan backend. | BERMASALAH; minta keputusan dan selaraskan dokumen. |
| Staff route seakan role global | PRD/schema menyatakan membership; router mengenal role `staff`. | PERBAIKI pemetaan route terhadap membership; jangan tambah role global diam-diam. |
| Revenue/package layar local berdampingan dengan API | Service Admin menunjukkan mock snapshot. | PERBAIKI indikator DEMO/API dan sambungkan sebelum dipakai operasional. |
| Guest report PRD vs auth routes | Route report wajib login. | PERLU KEPUTUSAN; desain guest/token dan anti-abuse terlebih dahulu. |
| `/tickets/validate` dan `/tickets/verify` | Dua endpoint serupa terpasang. | LEGACY/duplikasi potensial; periksa pemanggil sebelum gabung/hapus. |
| Detail ticket-type per event dan `/ticket-types/:id` | Potensi overlap. | Evaluasi consumer; belum ada bukti cukup untuk menghapus. |
| QR field legacy dan token baru | `docs/DATABASE.md` menyebut payload lama dipertahankan. | LEGACY; jangan hapus sampai semua client/backfill/scan terverifikasi. |
| Monetisasi cukup kompleks, keputusan bisnis terbuka | Paket, komisi, fee, subscription dibangun sebelum harga/policy final. | SEDERHANAKAN/tunda enforcement; jangan anggap angka contoh final. |
| `backend/package.json` BOM | `format:check` dan Prisma CLI gagal parse manifest. | BERMASALAH sebagai blocker verifikasi; perbaikan tidak termasuk audit. |

Tidak ada alasan berbukti untuk menghapus fitur hanya karena belum selesai. Endpoint duplikat perlu consumer inventory dahulu. Admin memantau keuangan platform dan Organizer melihat transaksi event sendiri adalah tanggung jawab berbeda, bukan duplikasi yang harus dihapus.

## 6. Evaluasi pembagian role

Prinsip PRD logis: Admin mengawasi platform; Organizer mengelola event milik sendiri; Staff membantu sesuai permission; Participant mencari event dan memakai tiket. Backend sudah punya role middleware, owner `created_by`, membership dan permission. Gap: staff UX/route tidak selaras; UI guard bukan keamanan; perlu bukti bahwa setiap endpoint peserta/order/export/report memeriksa owner/member permission. Admin harus punya akses pengawasan terukur, bukan mengoperasikan event sebagai organizer. Participant tidak boleh memperoleh data attendee lain.

## 7. Rekomendasi fitur

### Dipertahankan

**PERTAHANKAN:** tiga role global; owner/staff membership; event dan moderasi; tiket/kuota; guest checkout sesuai keputusan; simulasi payment berlabel; e-ticket; invitation/permission Staff; online check-in; order history; support dan audit dasar. Ini mengisi manfaat MVP.

### Diselesaikan / diperbaiki

1. Uji event draft→submit→admin decision→public visibility.
2. Uji checkout→kuota/expiry→payment success/fail→ticket access/email.
3. Uji ownership/authorization negatif antar pengguna/event untuk semua route terkait.
4. Uji invitation token, expiry, email match, permission, revoke dan acceptance bersamaan.
5. Pastikan permission berbeda untuk melihat peserta, melihat order, assisted registration dan scan/check-in.
6. Uji scan: tiket paid, event cocok, ulang/race, audit; baru kemudian kebijakan offline terbatas.
7. Pisahkan UI API/mock dengan penanda jelas; Admin revenue/package harus tidak menampilkan mock seolah nyata.
8. Putuskan guest report/status-token; selaraskan API/UI dengan keputusan itu.
9. Uji email, notification, migration dan RLS di environment uji sintetis.
10. Selaraskan PRD/README/arsitektur serta hilangkan blocker BOM pada quality checks melalui pekerjaan terpisah.

### Disederhanakan/digabung

- **SEDERHANAKAN** subscription/enforcement/pendapatan sampai tarif dan komisi disepakati; jadikan nonaktif/read-only bila belum siap.
- Mulai dari check-in online; offline hanya antrean terbatas setelah aturan perangkat, retensi dan konflik disepakati.
- **GABUNGKAN** kontrak validate/verify hanya setelah client lama ditemukan; pertahankan route compatibility selama masih dipakai.
- Jangan menggabungkan tautan peserta dan Staff: tujuan, permission dan risiko berbeda.

### Dihapus

Belum ada fitur/source yang aman direkomendasikan untuk dihapus. Gateway/payout/refund nyata, AI/live chat, multi-currency, referral, offline konsistensi penuh dan analitik lanjutan berstatus **TIDAK RELEVAN untuk MVP saat ini**, bukan otomatis harus dihapus dari roadmap/schema.

## 8. Prioritas berikutnya

### Prioritas 1 — wajib untuk MVP

- Environment uji dan schema/migration read-only tervalidasi.
- Alur event/moderasi serta checkout/simulated payment/e-ticket dites integrasi.
- Ownership, role, Staff permission dan negative access dites server-side.
- Staff invite link dan public registration link diuji sebagai dua alur berbeda.
- Online check-in: pembayaran, event, permission, duplicate/race.
- Guest account/report policy diputuskan.
- Perbaiki blocker manifest supaya Prisma/format check berjalan, lalu jalankan Flutter analyze dan API-mode tests.

Alasan: transaksi tiket dan pembatasan akses adalah fungsi pokok sekaligus titik risiko data/keamanan.

### Prioritas 2 — operasional

API-backed dashboard attendee/order/revenue; support dan audit persisten; email/notifikasi dan retry; expiry/kuota serta rekonsiliasi; tes scanner Android/Web dan konfigurasi deployment.

### Prioritas 3 — tambahan

Offline terbatas setelah kebijakan, ekspor/analitik, notifikasi eksternal dan subscription enforcement setelah keputusan bisnis.

### Tidak perlu dilanjutkan sekarang

Payment gateway/payout/refund nyata, kupon/referral kompleks, AI/live chat, WhatsApp/SMS, multi-currency/bahasa, offline multi-device konsisten penuh, pemecahan Admin sub-role, iOS rilis resmi; mengikuti batas PRD §16.

## 9. Scope produk akhir yang disarankan

**Role final:** Participant, Organizer, Admin global; Staff/Owner membership event. Organizer dapat menjadi Owner event A dan Staff di event B.

- **Participant/guest:** jelajah event publik, pilih tiket, checkout, simulated VA, akses e-ticket/order. Akun wajib atau optional harus diputuskan.
- **Organizer:** kelola event dan tiket sendiri; submit review; lihat peserta/order/metric sendiri; undang/revoke staff dan pilih permission; assisted registration tidak melewati pembayaran.
- **Staff:** terima invitation khusus dengan akun/email sesuai; akses event dan tugas yang diizinkan saja; scan/assisted registration hanya bila berizin.
- **Admin:** moderasi, akun dasar, support, audit dan monitoring platform. Aktifkan monetisasi hanya setelah fee/paket disetujui.

**Alur:** Organizer membuat event dan tiket → submit → Admin menyetujui/menolak dengan alasan → event publik dan link/QR dibagikan → Participant checkout guest/akun sesuai kebijakan dan simulasi pembayaran → e-ticket → Organizer mengundang Staff lewat link berbeda dan memberi permission → petugas berizin scan/check-in → Organizer melihat operasional, Admin menangani platform/support.

## 10. Pertanyaan keputusan pengguna

1. Apakah PRD akan diperbarui untuk mencakup backend/API yang sekarang ada atau kembali ke prototype-only?
2. Guest checkout jadi alur utama atau akun wajib? Bagaimana recovery tiket/retensi order guest?
3. Apakah laporan tanpa akun diperlukan; bagaimana token status/anti-abuse?
4. Invitation Staff dikirim lewat email, tautan manual, atau keduanya?
5. Data apa yang termasuk `VIEW_PARTICIPANTS`; bolehkah Staff melihat email/telepon dan order?
6. Kapan offline check-in diperlukan; berapa batas cache/perangkat/expiry/retensi?
7. Berapa expiry order, aturan pembatalan/refund dan kapasitas maksimum?
8. Apakah paket/komisi/fee bagian MVP; berapa nilainya dan siapa menanggung biaya?
9. Revenue Organizer berarti gross sales atau dana bersih/payout?
10. Apakah klien masih memakai `/tickets/validate` dan `/tickets/verify`; siapa memakai ticket-type detail global?
11. Environment uji mana yang disetujui untuk validasi DB/API tanpa data pribadi/produksi?

## 11. Hasil pemeriksaan dan referensi

- PRD: `prd.md`; arsitektur: `docs/ARCHITECTURE.md`; schema: `backend/prisma/schema.prisma`; migration: `backend/prisma/migrations/` dan `backend/supabase/migrations/`.
- Bootstrap: `backend/src/app.js`; auth/role: `backend/src/middleware/authMiddleware.js`, `roleMiddleware.js`; routes: `backend/src/routes/`; permission check: `backend/src/controllers/checkInController.js`; invitations: `eventInvitationController.js`; payment: `paymentController.js`.
- Flutter: `apps/lib/app_router.dart`, `apps/lib/core/config/app_config.dart`, `apps/lib/services/organizer_events/` dan `apps/lib/features/`.
- **PASS:** backend `npm test` (17/17); `npm run check` (61 JS files); `npm run validate:skills`; Flutter `flutter test --dart-define=MOCK_MODE=true` (139 lulus, 11 skipped).
- **FAIL:** `npm run format:check` dan `npm run prisma:validate` gagal sebelum memeriksa karena `backend/package.json` BOM UTF-8 ditolak parser JSON.
- **NOT RUN:** `flutter analyze`, Flutter API-mode tests, integration/API/DB tests, live migration/RLS, scanner perangkat, email/provider, deployment. Tidak ada koneksi database atau data aktual yang digunakan.

Unit/widget test bukan bukti keamanan menyeluruh, database hidup, migration diterapkan, integrasi provider, concurrency atau production readiness. Semua hal tersebut tetap **BELUM DIVERIFIKASI**.
