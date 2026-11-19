# Pembagian Tugas Final — E-Ticket Event & QR Scanner

> **Dokumen kerja Fase 1.** Dasar audit: PRD `prd.md` (FR-01–FR-101), `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, source Flutter/Express, schema Prisma/migration yang ada, tes, dan status Git pada 2026-11-18. Perubahan working tree yang sudah ada sebelum audit ini tidak dianggap dibuat atau diverifikasi oleh audit ini.

## A. Ringkasan Hasil Audit

### Kondisi repository dan stack

- Frontend Flutter/Dart (Android/Web), Provider, `http`, `flutter_secure_storage`; source di `apps/lib/`, tes di `apps/test/`.
- Backend Node.js/CommonJS, Express 4, PostgreSQL via `pg` (`backend/src/config/db.js`), JWT, migration Prisma dan satu migration Supabase SQL lama. `backend/src/config/supabase.js` adalah alias kompatibilitas; Prisma schema/migration lokal **tidak membuktikan** status database deployment. Tidak menjalankan migration atau akses database pada audit ini.
- Ada implementasi route/controller/service untuk auth, event, order, payment simulasi, ticket, check-in, invitation, notification, plans, subscriptions, revenue, support reports dan admin. UI Flutter memiliki area public, participant, organizer/staff dan admin.
- Working tree telah berubah luas di semua area dan memiliki file untracked, termasuk `backend/prisma/`, controller/route baru, sejumlah tes, serta perubahan CI. Audit mengamati workspace saat ini dan tidak mengatribusikan perubahan tersebut ke sesi audit.

### Sudah tersedia di source (belum seluruhnya diverifikasi end-to-end)

- API terstruktur, koneksi PostgreSQL langsung, middleware auth/error/rate-limit/logging, validasi dan test unit/backend.
- Alur order dan pembayaran simulasi, ticket issuance, email delivery service berbasis konfigurasi, undangan/membership event, event/ticket-type, check-in dan token QR mempunyai implementasi source.
- Mode MOCK tersedia sebagai pilihan eksplisit di Flutter; bukan pengganti integrasi backend produksi.
- Prisma schema valid secara sintaksis; tersedia migration lokal berlapis dan dokumentasi rekonsiliasi DB.

### Gap dan masalah yang terbukti

1. **Flutter gagal dianalisis/dikompilasi:** `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart` menghasilkan 69 analyzer issues, termasuk State tanpa `build` dan banyak identifier (`_provider`, `widget`, `context`) di scope yang salah. `flutter test` juga gagal kompilasi modul ini.
2. **Flutter tests gagal:** selain compile failure, ada `MissingPluginException` untuk secure storage, kegagalan widget test dan `pumpAndSettle` timeout. Perlu isolasi plugin dengan test doubles dan regression tests.
3. **Backend checks lokal lulus:** `npm test` 26/26; `npm run check` memeriksa 61 file JS; `npm run format:check`; `npm run validate:skills` 7 skills/8 Markdown; `npm run prisma:validate` valid. Ini tidak membuktikan integrasi DB/provider.
4. **Status DB/deployment belum disahkan:** klaim historis docs mengenai introspeksi, fungsi DB, RLS/grants dan migration history tidak dapat dibuktikan dari file. Tidak menjalankan audit/mutasi remote tanpa environment uji eksplisit.
5. **QR/check-in belum production-ready menurut `docs/DATABASE.md`:** QR/scanner menggunakan bearer ticket code, bukan verifikasi hash token; expiry/replay/race/authorization perlu review dan tes sebelum klaim aman.
6. **Email bergantung SMTP:** tanpa host SMTP, service mencatat status pending/non-delivery, bukan bukti email terkirim. Perlu pengujian status delivery dan sandbox E2E.
7. **Kesesuaian fitur PRD belum terbukti menyeluruh:** keberadaan screen/API bukan bukti alur berfungsi. Coverage acceptance custom ticket design/template/QR placement, public links, order/payment/email, Staff permissions, Admin/business/support/audit, plan/subscription, serta state loading/error/empty perlu ditelusuri per kontrak dan test.

### Batasan audit

- Tidak mengakses service DB, SMTP, payment provider atau akun sungguhan; tidak membaca/menyalin nilai `.env`.
- E2E, build Android/Web, validasi perangkat/responsivitas, migration live dan policy/grants memerlukan environment uji khusus.
- Schema aktif ditentukan oleh runtime dan migration yang diterapkan, bukan sekadar keberadaan Prisma. `backend/prisma/` untracked pada saat audit.

## B. Daftar Pekerjaan

| ID | Pekerjaan / tujuan | File atau bagian proyek | Ketergantungan | Kriteria keberhasilan |
|---|---|---|---|---|
| T01 | Pulihkan baseline Flutter: diagnosis scope/class detail event dan perbaiki sekecil mungkin tanpa menghilangkan fitur/kerja lokal. | `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`, provider/widget terkait | — | `flutter analyze` tanpa error; test/build compile; loading/error/empty dan callback detail event tetap teruji. |
| T02 | Stabilkan fondasi tes Flutter: isolasi secure storage/HTTP dan benahi widget tests gagal/timeout. | `apps/test/**`, test setup session/storage/service, widget organizer/admin/report | T01 | `flutter test` lulus berulang; fixtures/test doubles tanpa jaringan atau plugin nyata. |
| T03 | Konfirmasi baseline database secara read-only: rekonsiliasi koneksi PostgreSQL, schema/migration source of truth dan klaim docs. | `backend/src/config/db.js`, `backend/prisma/**`, `backend/supabase/migrations/**`, `docs/DATABASE.md`, scripts audit | — | Schema-diff read-only terhadap DB test eksplisit atau status BLOCKED; tanpa migration/reset/remote write tanpa izin/keputusan deployment. |
| T04 | Rekonsiliasi dan amankan DB bila diperlukan berdasarkan bukti T03. | migration Prisma/Supabase, `backend/scripts/**`, dokumentasi DB | T03; keputusan pemilik DB | Migration kompatibel direview dan diuji pada DB disposable; grants/RLS minimum dan constraint transaksi sesuai; schema diff bersih. Jika tak perlu, dokumentasikan bukti. |
| T05 | Audit/tegakkan auth, role, membership, ownership pada endpoint privat: Participant, Organizer Owner, Staff permission event, Admin dan Guest token. | `backend/src/routes/**`, middleware/controller/service, `backend/test/**`, policy | T03 | Tes positive/negative auth, role, owner lain, membership/permission revoked dan guest token; request tak sah ditolak, response konsisten. |
| T06 | Lengkapi event/ticket category sesuai PRD: DRAFT, auto-validation/publish, OPEN/CLOSED, suspend Admin + alasan/audit, free/paid rule dan quota. | event/ticket-type API, SQL/migration bila perlu, Flutter organizer/admin | T04, T05, T01 | Transisi valid/invalid dan quota/concurrency diuji; hanya aktor berhak mengubah; suspension beralasan/audit; kontrak klien konsisten. |
| T07 | Tuntaskan publikasi dan desain tiket: public registration link/QR terpisah dari QR tiket, template PDF/PNG, validasi upload/area QR, versioning. | event API, storage/template service, organizer form/detail, public registration/ticket UI | T06, T05 | Format/ukuran/area QR tervalidasi; desain invalid tidak membuka registrasi; tiket mengacu versi desain; link publik tidak memberi akses staff. |
| T08 | Tuntaskan registrasi/order/pembayaran simulasi: satu order satu item/tiket/peserta, self/assisted, guest access/idempotency, hold/expiry/fee, status server-side. | order/payment API, SQL functions/migrations, Flutter registration/order/payment | T04, T05, T06 | Free/paid, success/fail/expired, duplicate/retry, oversell/concurrency, guest access dan spoof status diuji; tiket hanya terbit sekali sesuai state sah. |
| T09 | Tuntaskan ticket issuance/email: QR token terkait ticket/event, desain tiket, status email/retry tanpa duplikasi. | ticket/email/token service, schema, Flutter ticket/order | T08, T07 | Ticket state dan email pending/sent/failed/retry teruji; SMTP mati tidak diklaim sukses; token tidak terekspos pada log/response yang tidak perlu. |
| T10 | Amankan scanner/check-in online & sync: token/hash atau signed sesuai desain, expiry, event auth, replay/race, offline marking. | ticket token service, check-in controller/routes, migration bila perlu, Flutter scanner | T09, T05, T04 | Token tak dapat ditebak/dipakai lintas event; transaksi atomik mencegah check-in ganda; scan kedua ditolak/log; permission Staff ditegakkan; offline belum verified sampai sync server. |
| T11 | Tuntaskan Staff/invitation dan assisted registration: undangan panitia terpisah dari public link, acceptance/auth, event permission/revoke. | invitation/organizer API, auth/membership services, Flutter staff/organizer | T05, T06 | Invitation aman/expire/revoke/single-use; email penerima berhak; permission diuji tiap aksi dan revocation langsung berlaku. |
| T12 | Selesaikan dashboard Participant/Organizer dan operasi event: metrics, peserta/order, scan history, reports, profile, notification dan semua states. | Flutter `features/organizer`, `features/home`, `features/orders`; API metrics/report/notification | T06, T08, T10, T11, T01 | Data API sesuai role/event; gross/net/fee benar; filter/error/empty/loading/retry teruji; tidak memakai mock pada backend default. |
| T13 | Selesaikan paket, langganan dan transaksi platform: feature limits, subscription lifecycle, payment dan revenue/commission. | plan/subscription/revenue API, DB constraints, Flutter organizer/admin | T04, T05, T08 | Batas fitur allow/deny, lifecycle, konsistensi commission/transaksi dan sumber transaksi order vs subscription diuji; tidak mengklaim gateway riil. |
| T14 | Selesaikan Admin dan support/audit: dashboard, akun, moderation, plans, subscriptions, transactions/revenue, reports, settings/audit. | admin/report/revenue/plan/subscription APIs; `apps/lib/features/admin/**` | T05, T06, T13 | Endpoint admin-only; tindakan sensitif beralasan/tercatat; support data hanya terungkap sesuai izin; UI API-connected dengan states lengkap. |
| T15 | Integrasikan kontrak Flutter-backend: route/payload/error/pagination/status/guest token/base URL/mock mode. | Flutter network/services/providers/features; backend routes/serializers | T02, T05–T14 | Contract/service tests cocokkan JSON; backend default dan MOCK_MODE eksplisit; auth/network/timeout/error/retry tanpa data palsu. |
| T16 | Sempurnakan UX, accessibility dan layout narrow/wide Android/Web pada seluruh alur. | screens/widgets/theme/navigation | T01, T02, T07–T15 | Widget/layout tests state utama dan viewport sempit/lebar; semantics/keyboard/focus relevan; tanpa overflow alur kritis. Perangkat fisik dicatat terpisah. |
| T17 | Audit akhir, regression dan release readiness; trace FR dan catat gap. | seluruh workspace, CI, laporan akhir | T01–T16 | Backend+Flutter checks lulus; role/transaksi/QR/contract tests lulus; build target tersedia; schema aman; setiap FR punya bukti atau blocker. |

## C. Urutan Prioritas Pengerjaan

1. T01 → T02: pulihkan analisis/kompilasi dan tes Flutter.
2. T03 → T04: pastikan source-of-truth schema dan DB; ubah DB hanya jika bukti/otorisasi mengharuskan.
3. T05: tutup authorization/ownership sebelum mengandalkan endpoint bisnis.
4. T06 → T07: event/ticket foundation lalu publikasi/desain/link.
5. T08 → T09 → T10: order/payment, ticket/email, lalu QR/check-in aman.
6. T11: invitation/Staff setelah akses dan event foundation.
7. T12 → T13 → T14: operasi dashboard, paket/transaksi platform, Admin/support.
8. T15 → T16 → T17: integrasi, UX, audit akhir.

Pekerjaan yang ternyata telah benar dengan bukti test boleh ditutup tanpa perubahan. Jika urutan berubah karena ketergantungan baru, alasan wajib dicatat.

## D. Pembagian Menjadi Tahapan

| Tahap | Cakupan | Hasil yang dapat diuji |
|---|---|---|
| 1. Stabilkan workspace | T01–T02 | Flutter analyzer/test berjalan dan baseline regresi terukur. |
| 2. Data dan akses aman | T03–T05 | Schema target jelas, migration strategy aman, akses server tervalidasi. |
| 3. Event siap registrasi | T06–T07 | Owner dapat validasi/publish event, desain/link sesuai PRD. |
| 4. Transaksi hingga tiket | T08–T10 | Checkout idempotent, ticket/email status jujur, scanner/check-in aman. |
| 5. Tim dan operasi role | T11–T14 | Staff, Participant, Organizer dan Admin menyelesaikan alur lewat API. |
| 6. Integrasi dan release gate | T15–T17 | Kontrak, UX, checks/build dan traceability selesai atau blocker tercatat. |

## E. Checklist Penyelesaian

- [x] T01 — Pulihkan baseline Flutter yang dapat dianalisis/dibangun. Memindahkan kurung penutup class State yang terlalu awal pada detail event; `flutter analyze` lulus.
- [x] T02 — Stabilkan fondasi tes Flutter. Dua run full `flutter test --no-pub --dart-define=MOCK_MODE=true` lulus (`139` passed, `11` skipped yang sudah ada). Penyebab kegagalan Organizer: fixture screen tidak menyediakan `AuthProvider`; penyebab kegagalan Admin: test mengharapkan approval/revisi manual yang dilarang PRD §1.1/§6.3. Fixture diperbaiki dan assertion diselaraskan dengan PRD; test Organizer/Admin/API-mode terarah serta `flutter analyze` lulus. 11 skipped tetap dicatat, tidak diubah.
- [!] T03 — DB baseline & migration validation (Supabase read-only/no-write). Prisma Client diregenerasi dari schema; migration 004 diregenerasi dari function 003, hanya menambahkan cast `PaymentStatus` dan menjaga guest replay/no token rotation. Regression dan SQL function scenarios lulus. Docker PostgreSQL 16 disposable lokal loopback/tmpfs digunakan; 9 migration SQL deployed via temporary directory, checksum 9/9, official Prisma schema diff empty. API integration harness **11/11 PASS**; fixture cleanup diverifikasi 0. Seluruh 105 index names ditelusuri ke migration SQL; 44 tidak dimodelkan eksplisit Prisma. **Tetap `[!]`**: folder migration 005 kosong/tidak terlacak dan intent belum dapat dipastikan; status history terhadap seluruh 10 direktori repository masih belum resolvable. T04 belum dimulai. Tidak ada operasi tulis ke Supabase. Penyelesaian T03 menunggu keputusan owner/source tentang 005 dan statusnya didokumentasikan/direkonsiliasi sesuai bukti, lalu migrate status pada set final diverifikasi. Detail pada checkpoint laporan 2026-11-19.
- [ ] T04 — Rekonsiliasi/keamanan DB bila dibutuhkan berdasarkan bukti.
- [ ] T05 — Audit/tegakkan auth, role, membership, ownership.
- [ ] T06 — Event dan kategori tiket sesuai PRD.
- [ ] T07 — Publikasi, template/desain tiket, public links.
- [ ] T08 — Registrasi/order/pembayaran simulasi.
- [ ] T09 — Ticket issuance dan email delivery.
- [ ] T10 — Scanner/check-in aman dan sinkronisasi.
- [ ] T11 — Staff/invitation/assisted registration.
- [ ] T12 — Dashboard/operasi Participant dan Organizer.
- [ ] T13 — Plan/subscription/platform transactions.
- [ ] T14 — Admin, support, audit.
- [ ] T15 — Integrasi Flutter-backend dan API contracts.
- [ ] T16 — UX, accessibility, layout.
- [ ] T17 — Audit akhir, regression dan release readiness.

Checklist hanya diubah menjadi `[x]` jika implementasi dan tes terkait berhasil. Gunakan `[!]` untuk blocker/keputusan eksternal dan tulis alasannya.

## F. Kriteria Proyek Selesai

1. FR-01–FR-101 yang termasuk MVP dipetakan ke implementasi dan bukti test; prototype/deferred ditandai jujur.
2. Flutter analyze dan suite yang dijalankan lulus (catat skipped-existing), build target masih harus diverifikasi; backend test, syntax, format, skill/sync-config checks lulus.
3. Kontrak API dan role/ownership/permission (Guest, Staff scoped-event, Admin) diuji positive/negative di server.
4. Alur event → registrasi → order/payment → ticket/email → QR/check-in diuji dengan data sintetis/test DB terisolasi; idempotency, expiry, oversell, retry dan scan ulang terbukti.
5. Schema/migration konsisten, akses DB minimum, tanpa destructive/production action untuk validasi.
6. Alur memiliki loading/error/empty/unauthorized/retry states relevan dan diuji pada viewport/target build.
7. Provider eksternal, SMTP, DB live, deployment dan perangkat fisik hanya diklaim diuji jika hasil benar-benar ada.
8. `task/archive/LAPORAN_PENYELESAIAN.md` mencatat pekerjaan, hasil, perubahan, kegagalan/keterbatasan. Tidak mengklaim 100% bila requirement wajib belum diimplementasi atau diverifikasi.

## Validasi Fase 1

- PRD diperiksa pada kebutuhan FR-01–FR-101, role, event, registration, payment, ticket, scanner, plan, admin dan support; traceability rinci dilaksanakan melalui T05–T17.
- Tidak ada duplikasi: implementasi fitur, integrasi lintas-stack dan audit tes dibedakan.
- Urutan dependency diperhitungkan: data→authorization→event→order/payment→ticket→check-in→integrasi/release.
- Backend unit tests 26/26 **PASS**; syntax 61 file **PASS**; format **PASS**; skill validation **PASS**; Prisma validate **PASS**.
- Awal audit: Flutter analyze **FAIL** (69 issues). Setelah perbaikan minimal T01: Flutter analyze **PASS** (No issues found). Saat T02 ditemukan fixture organizer tanpa Provider dan test Admin meminta approval manual yang bertentangan PRD; sesudah perbaikan, full Flutter suite 2 kali **PASS** (139 passed, 11 skipped-existing), Organizer/Admin/API targeted **PASS**, analyze **PASS**. Test targeted yang dicoba pada nama file yang tidak ada tidak dihitung sebagai test lulus.
- Pada validasi Fase 1, DB live, external services, build/device E2E **NOT RUN**. Pembaruan T03 2026-11-19 di atas mencatat audit DB live read-only; migration/write/E2E tetap tidak dijalankan. T03 masih blocker dan T04 belum dituntaskan. Perubahan lokal sudah ada sebelum audit; hindari menghapus/menimpa kerja tersebut.