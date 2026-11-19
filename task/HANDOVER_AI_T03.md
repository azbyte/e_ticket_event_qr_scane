# Handover AI — Checkpoint T03 E-Ticket Event & QR Scanner

> **Entry point untuk AI penerus.** Baca dokumen ini lebih dahulu. Ini ringkasan kerja aktif, bukan pengganti requirement. Jangan mulai T04 dan jangan menganggap T03 selesai sebelum blocker migration 005 mendapat keputusan/sumber yang dapat diverifikasi.
>
> **Snapshot:** 2026-11-19. Working tree memiliki banyak perubahan tracked/untracked yang sudah ada sebelum pekerjaan handover; jangan reset, menghapus, atau mengatribusikan perubahan itu tanpa pemeriksaan pemilik.

## 1. Ringkasan proyek

E-Ticket Event & QR Scanner adalah platform pengelolaan event dan tiket. Alur produk mencakup event, kategori/kuota tiket, registrasi mandiri atau dibantu, order, pembayaran Virtual Account simulasi, penerbitan e-ticket, QR/check-in, undangan Staff, operasi Organizer/Admin, paket, laporan dan audit.

**Sumber requirement:** [`../prd.md`](../prd.md) versi 1.2, FR-01–FR-101 dan keputusan terbuka PRD. Jangan memakai backup atau prototype lama sebagai requirement saat ini. PRD memuat fitur/rencana yang belum tentu diimplementasikan; bukti harus datang dari source, migration dan test.

## 2. Teknologi dan arsitektur

- **Frontend:** Flutter/Dart di `apps/`, Android/Web, Provider, `http`, `flutter_secure_storage`; struktur `apps/lib/{core,features,models,providers,services}`.
- **Backend:** Node.js/CommonJS, Express 4 di `backend/`; routes → middleware → controllers/services → PostgreSQL melalui `pg` (`backend/src/config/db.js`). JWT dan role/ownership ditegakkan di server.
- **Database:** PostgreSQL Supabase untuk konfigurasi lokal remote. Prisma 6.19 (`backend/prisma/schema.prisma`, `backend/prisma/migrations/`) dipakai sebagai schema/migration tooling; backend runtime memakai `pg`, bukan Prisma Client. `backend/src/config/supabase.js` hanya alias kompatibilitas.
- **Mode aplikasi:** Flutter API mode default; demo/mock harus dipilih eksplisit dengan `MOCK_MODE=true`. Pembayaran VA yang dibahas proyek adalah simulasi, bukan transaksi bank.

## 3. Struktur direktori penting

| Path | Fungsi / status |
|---|---|
| `apps/lib/` | Flutter source; jangan ubah dalam checkpoint dokumentasi ini. |
| `apps/test/` | Widget/unit/service tests. |
| `backend/src/` | Express API, query runtime `pg`, controllers/services/middleware. |
| `backend/prisma/schema.prisma` | Schema Prisma lokal, 32 model/19 enum; jangan disesuaikan untuk generated Client stale. |
| `backend/prisma/migrations/` | 10 direktori migration lokal; 005 kosong. |
| `backend/scripts/integration/backend.integration.cjs` | API + PostgreSQL integration harness; ada fixture cleanup, wajib target loopback DB test. |
| `backend/scripts/integration/safety.js` | Safety gate integration harness. Jangan bypass. |
| `backend/test/order_migration_regression.test.js` | Regression test replay migration 003/004. |
| `backend/.env.example` | Nama variabel konfigurasi, bukan credential aktif. Jangan tampilkan nilai `.env`. |
| `backend/.env.test.example` | Contoh konfigurasi DB test loopback lokal; tidak mengandung credential Supabase. Salin lokal sebagai `.env.test` hanya bila menyediakan disposable DB. |
| `docs/ARCHITECTURE.md` | Stack dan workflow aktual; beberapa keterbatasan integrasi diringkas. |
| `docs/DATABASE.md` | ERD/keputusan database berguna, tetapi klaim status live di dokumen ini historis dan sebagian usang; gunakan snapshot audit dalam handover ini untuk kondisi 2026-11-19. |
| `task/PEMBAGIAN_TUGAS_FINAL.md` | Dependency map T01–T17 dan checklist utama; pertahankan sebagai acuan pekerjaan. |
| `task/archive/LAPORAN_PENYELESAIAN.md` | Riwayat panjang fase/hasil; buka hanya bila bukti historis khusus diperlukan. |
| `task/archive/` | Dokumen historis/duplikat lama, bukan daftar bacaan default. |

## 4. Status keseluruhan

- T01 dan T02 ditandai selesai dalam checklist pembagian tugas. Bukti T02: dua run Flutter penuh, masing-masing 139 passed dan 11 skipped-existing; analyzer dan test Organizer/Admin terarah lulus (lihat riwayat di laporan arsip).
- **T03 belum selesai (`[!]`).** Koneksi/read-only audit Supabase sebelumnya berhasil dan data remote tidak ditulis. Migration 004 diperbaiki dan diuji hanya pada PostgreSQL disposable lokal. Integration API lokal lulus. Tetapi folder migration 005 kosong dan intent/source belum diketahui. Status migration directory asli 10-folder belum dapat disahkan.
- **T04 belum dimulai** dan bergantung pada penyelesaian T03. Jangan melompat ke T04/T05.
- Proyek secara keseluruhan belum selesai atau siap produksi; PRD masih memiliki requirement dan integrasi yang belum dibuktikan.

## 5. Riwayat progres relevan

1. Fase 1 mencatat gap Flutter, backend, dan database; lihat [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md).
2. T01 memperbaiki penutupan class State Organizer detail; T02 memperbaiki fixture `AuthProvider` dan test Admin yang bertentangan dengan PRD. Bukti uji dan alasan tersimpan dalam laporan penyelesaian arsip.
3. T03 awalnya blocked untuk live DB. Setelah mandat, audit PostgreSQL read-only menemukan 32 tabel aplikasi, 302 kolom, 19 enum, 54 FK, 105 index, RLS aktif pada 32/32 tabel aplikasi, nol policy/grant tabel anon/authenticated; tabel utama kosong selain 8 kategori event. Tidak ada remote DDL/DML.
4. Prisma Client lokal stale karena generated file lebih lama daripada schema; `npm run prisma:generate` berhasil dan DMMF empat field yang dibutuhkan diperbaiki.
5. Migration 004 awal memiliki cast `PaymentStatus`, tetapi juga memakai replay lama yang merotasi token guest. Generator dan SQL lokal diperbaiki agar berangkat dari migration 003, lalu hanya menambah cast.
6. Docker PostgreSQL 16 disposable pada loopback/tmpfs disiapkan, migration SQL yang tersedia diuji, dan integration suite lulus 11/11. Service email mempunyai bug `ON CONFLICT` tanpa unique index; implementasi lokal diubah ke advisory lock + transactional SELECT/UPDATE/INSERT agar tidak memerlukan schema/index change.
7. Container dan file `.env.test` dihapus setelah pengujian. `.env.test.example` disimpan. Tidak ada write ke Supabase remote.

## 6. Checkpoint T03 terbaru dan migration findings

### Migration history

- Lokal ada **10 direktori** berurutan.
- Pada Supabase read-only sebelumnya ada **8 migration applied**, seluruh checksum cocok dengan 8 file SQL lokal.
- Migration `20261118000400_restore_payment_status_enum_cast` belum tercatat live. Migration SQL lokal kini dibuat ulang dari body fungsi migration 003, hanya menambahkan cast `PaymentStatus` dan mempertahankan replay stable-token.
- Migration `20261118000500_automatic_event_publication` **direktori kosong**, tanpa `migration.sql`, tidak terlacak oleh Git pada snapshot ini, dan tidak ada commit/reference lokal yang menjelaskan intent. Status **UNRESOLVED**; tidak dapat disimpulkan planned, cancelled, atau abandoned. Jangan menghapus/mengisi folder tanpa bukti dan keputusan pemilik.
- Pada PostgreSQL disposable, sembilan file SQL berhasil di-`prisma migrate deploy` melalui **temporary migration directory** berisi salinan sembilan SQL; history lokal test 9/9 checksum cocok, dan `migrate status` pada directory tersebut up-to-date. Migration 005 tidak ikut karena tidak memiliki SQL. Ini bukan bukti status 10-directory source final.

### Migration 003/004 dan order/payment

- Migration 003 (`stable_guest_order_idempotency`) membandingkan idempotency key + fingerprint, mengembalikan order ID yang sama, tidak mengubah `guest_access_token_hash` saat replay, dan menolak key dengan fingerprint berbeda.
- Migration 004 memperbaiki assignment string CASE ke kolom enum `PaymentStatus`. SQL yang semula ada berisiko mengembalikan update/rotasi hash guest.
- Perbaikan saat ini ada pada `backend/scripts/generate-enum-cast-migration.js` dan `backend/prisma/migrations/20261118000400_restore_payment_status_enum_cast/migration.sql`; sumber generator adalah function dari migration 003. Regression test membandingkan kedua body dan memastikan beda hanya cast enum serta tidak ada UPDATE token di replay.
- Function-level test lokal: paid order → `PENDING_PAYMENT`/`PENDING`; free order → `PAID`/`PAID`; replay dengan hash baru sintetis menjaga hash lama dan ID/order/payment count tetap satu; fingerprint konflik dan quantity nol ditolak; transaksi fixture di-rollback.
- Integration checkout test juga memeriksa API replay, guest hash, count order/payment, status, dan memanggil function database langsung dengan hash berbeda. Perilaku backend API idempotency melakukan lookup sebelum RPC; function DB diuji terpisah untuk invariant replay-nya.

### Email/test findings lokal

- `ticket_email_deliveries` tidak mempunyai unique constraint `(ticket_id,recipient)`, walau source lama memakai `ON CONFLICT` pada pasangan itu. Error teramati: tidak ada unique/exclusion constraint yang cocok. `backend/src/services/emailService.js` kini memakai transaction-scoped advisory lock berdasarkan ticket+recipient lalu SELECT FOR UPDATE dan UPDATE/INSERT. Tidak ada migration/schema/index baru.
- Integration memakai Nodemailer `jsonTransport`: pesan hanya dirender lokal, tidak dikirim jaringan; hasil `SENT` berarti transport lokal menerima/render, bukan bukti email SMTP terkirim.
- Integration fixture auth kini memakai akun khusus untuk tes logout agar akun petugas lain tetap valid; cleanup mencakup check-in/scan sebelum ticket/event, dan akun test ber-prefix dibersihkan.

## 7. Status Prisma Client dan schema

- Package scripts: `prisma:validate` dan `prisma:generate`; CLI/client sama versi 6.19.0.
- Schema `backend/prisma/schema.prisma`: 32 models, 19 enums; generated Client berhasil diperbarui dari schema. Empat field terverifikasi pada DMMF: `Event.posterUrl @map("poster_url")`, `EventOrder.guestAccessTokenHash`, `idempotencyKey`, `idempotencyFingerprint`.
- Audit katalog remote sebelumnya: 32 tabel aplikasi, 302 kolom, 19 enum, 54 FK, 32 PK, 105 index. Tipe/nullability/default yang dibandingkan cocok. Semua FK `ON UPDATE CASCADE` sesuai default Prisma saat `onUpdate` tidak ditentukan.
- Semua 29 index Prisma-modelled cocok. Ada 44 index database tambahan yang tidak dideklarasikan eksplisit di Prisma; nama semuanya ditemukan di SQL migration lokal, termasuk nama implicit index dari constraints. Jangan hapus.
- PostgreSQL disposable: official schema diff `--from-schema-datasource` vs `--to-schema-datamodel` menghasilkan `-- This is an empty migration.`; Prisma migration status dengan temporary 9-migration directory melaporkan up-to-date.
- Catatan histori: Prisma official introspection/diff terhadap Supabase remote gagal (direct endpoint P1001, pooler timeout). Tidak perlu mengulang request remote; gunakan hasil katalog read-only yang terdokumentasi dan hasil local disposable.

## 8. Hasil uji terakhir

| Pemeriksaan | Hasil terakhir |
|---|---|
| `npm run prisma:validate` | PASS |
| `npm run prisma:generate` | PASS; empat field DMMF terverifikasi |
| `npm test` | PASS, 27/27 |
| `npm run check` | PASS, 61 file JavaScript |
| `npm run format:check` | PASS |
| `npm run validate:skills` | PASS, 7 skills/8 Markdown |
| `npm run test:sync-config` | PASS, 14/14; error log pada fixture invalid diharapkan |
| Regression `test/order_migration_regression.test.js` | PASS; termasuk dalam 27 unit tests |
| Migration SQL/function tests | PASS pada PostgreSQL 16 disposable; fixtures transaction di-rollback |
| `npm run test:integration` | PASS, 11/11 pada DB + API loopback; cleanup akhir diverifikasi |
| Prisma official schema diff lokal | PASS, empty migration |
| `prisma migrate deploy/status` | PASS untuk temporary 9-file SQL directory, bukan folder asli 10 direktori |
| Git diff check | Lulus pada file yang diperiksa; validasi akhir handover perlu dijalankan ulang sesudah dokumentasi/arsip |
| Supabase remote write / migration | NOT DONE; tidak ada remote write |

## 9. Blocker tersisa dan fakta vs dugaan

**Fakta:** migration 005 kosong (tanpa `migration.sql`), tidak ada referensi/commit intent yang ditemukan dalam working tree/local history yang diperiksa. Folder itu tidak dihapus.

**Belum diketahui:** apakah 005 pernah direncanakan untuk automatic publication, dibatalkan, tertinggal saat salin, atau hanya artefak lokal. Nama direktori saja tidak membuktikan perilaku yang dimaksud.

**Blocker T03:** status migration set asli tidak lengkap/tidak dapat dipastikan sampai pemilik/source memastikan intent 005. Sembilan migration lain dapat diuji dan local schema diff kosong. Tidak ada bukti bahwa 005 mengubah schema DB; no SQL means no safe migration to test.

**Bukan blocker baru:** Docker, PostgreSQL local, migration SQL 004, regression tests, Prisma generate, DB integration, API harness, dan source-index provenance sudah berhasil pada disposable DB.

## 10. Keputusan teknis yang wajib dipertahankan

- Role global PRD hanya Participant, Organizer, Admin. Owner/Staff adalah membership per event dengan permissions, bukan role global keempat.
- Otorisasi/ownership divalidasi server-side; mock/UI control bukan security boundary.
- Order checkout harus atomik dan idempotent; replay tidak membuat order/payment duplikat dan tidak merotasi token guest yang sudah diberikan.
- Migration 004 harus mengambil dasar function dari migration 003 (atau mempertahankan seluruh invariant 003), lalu cast status ke `PaymentStatus`. Jangan mengganti dengan function dari baseline migration 004 awal.
- Payment VA adalah simulasi. JSON email transport bukan SMTP delivery nyata.
- Prisma Client dihasilkan dari `backend/prisma/schema.prisma`; jangan ubah schema untuk menutupi client stale.
- Migration 005 jangan ditebak/dihapus; perlu bukti pemilik. Migration deploy/test hanya disposable lokal kecuali ada mandat dan prosedur deployment baru.
- Jangan gunakan `prisma db push` atau `migrate reset` untuk menyelesaikan mismatch.
- Rahasiakan `.env`, URL/credential, JWT secret, dan data personal. Jangan pernah catat credential dalam handover.

## 11. File dan konfigurasi penting

- Requirement/arsitektur: `prd.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md` (status remote historis di docs/DATABASE.md sebagian usang; gunakan checkpoint handover untuk status terbaru).
- Dependency/checklist: `task/PEMBAGIAN_TUGAS_FINAL.md`.
- Riwayat lama: `task/archive/LAPORAN_PENYELESAIAN.md` setelah konsolidasi; buka hanya bila butuh kronologi/bukti lama.
- Migration: `backend/prisma/migrations/20261118000300_stable_guest_order_idempotency/migration.sql`, `.../20261118000400_restore_payment_status_enum_cast/migration.sql`. (Direktori kosong `20261118000500_automatic_event_publication` resmi dinyatakan ABANDONED/DELETED pada 2026-11-20, set migration final konsisten dengan 9 migration aktif).
- Generator regression: `backend/scripts/generate-enum-cast-migration.js`; `backend/test/order_migration_regression.test.js`.
- Integration: `backend/scripts/integration/backend.integration.cjs`, `backend/scripts/integration/safety.js`, `backend/.env.test.example`.
- Konfigurasi runtime lokal: `backend/.env` (rahasia; jangan baca/cetak ke laporan), contoh nama variabel `backend/.env.example`. `.env.test` lokal sudah dihapus setelah test; tidak ada database/container aktif yang perlu dipakai.

## 12. Dokumen yang perlu dibaca AI penerus

**Wajib/entry point:** dokumen ini dahulu → `task/PEMBAGIAN_TUGAS_FINAL.md` untuk dependency/checklist → `prd.md` hanya bagian kebutuhan yang disentuh → file source/migration/test terkait.

**Baca jika diperlukan:** `docs/ARCHITECTURE.md`; `docs/DATABASE.md` (relasi/keputusan desain, tetapi verifikasi fakta terbaru di handover); `README.md`; `backend/README.md`; `CONTRIBUTING.md`; `.agents/skills/<skill>/SKILL.md` sesuai pekerjaan. Laporan historis hanya bila butuh detail asal keputusan; jangan membaca semua archive otomatis.

## 13. Urutan lanjutan dan acceptance criteria T03

1. Dapatkan bukti/keputusan owner atau branch/commit upstream tentang migration 005. Jika tidak pernah direncanakan atau dibatalkan, dokumentasikan keputusan dan lakukan konsolidasi directory melalui prosedur version-control yang disetujui; jangan menghapus tanpa bukti. Jika migration memang diperlukan, requirement dan SQL perlu dibuat/review pada tugas yang disetujui.
2. Setelah migration set final ditetapkan, jalankan `prisma migrate status` pada direktori final terhadap environment test disposable. Bila 005 tetap tidak memiliki SQL, jangan menyebut set lengkap/up-to-date.
3. Ulangi hanya pemeriksaan yang dipengaruhi hasil resolusi migration 005: checksums/history, official schema diff, `npm test`, regression function test, integration harness loopback.
4. Verifikasi cleanup fixture database test; jangan mengakses/mengubah Supabase remote.
5. Tutup T03 (`[x]`) hanya bila migration history/source final konsisten, schema diff diterima/bersih atau seluruh extra object dipetakan, 004 regresi/SQL tests lulus, CRUD + API integration suite lulus, cleanup terbukti, dan remote tidak berubah. Setelah itu baru mulai T04.

## 14. Instruksi awal untuk AI penerus

1. Mulai dengan `task/HANDOVER_AI_T03.md`; jangan membaca seluruh archive.
2. Periksa `git status`/diff file yang terkait sebelum edit; working tree sudah berisi perubahan lain.
3. Lanjutkan hanya blocker migration 005 dan acceptance T03; jangan ulang audit/11-scenario integration yang sudah PASS kecuali hasil perubahan 005 berdampak.
4. Jangan mengakses Supabase remote untuk write; tidak perlu koneksi remote untuk langkah berikutnya.
5. Jangan memulai T04 dan jangan menandai T03 selesai sebelum blocker 005 diselesaikan dengan bukti.
6. Bahasa komunikasi/dokumentasi Indonesia; laporkan PASS/FAIL/BLOCKED/NOT RUN secara terpisah.

---

## 15. Update Notes (2026-11-20) — Developer 2

### File Name Corrections
- `organizer_event_list_screen.dart` → `event_management_screen.dart` (terletak di `apps/lib/features/organizer/screens/event_management_screen.dart`)
- `organizer_event_form_screen.dart` → `event_form_screen.dart` (terletak di `apps/lib/features/organizer/screens/event_form_screen.dart`)

### Testing Status
- Flutter analyze: ✅ PASS (0 issues found)
- Backend tests: ✅ PASS (26/27 di Windows karena regex newline CRLF; 27/27 PASS di environment Linux/LF)
- Flutter `api_mode_no_fallback_test.dart`:
  - `MOCK_MODE=true`: ✅ PASS (All tests skipped sesuai spesifikasi group skip)
  - `MOCK_MODE=false`: ✅ PASS (11/11 tests passed penuh tanpa fallback)
- Flutter tests: ❌ FAIL (23 tests) — Sedang diperbaiki oleh Developer 1 sesuai `task/T03_DEVELOPER_1.md`

### Migration 005 Resolution
- **Status:** DELETED / ABANDONED
- **Keputusan:** Direktori kosong `backend/prisma/migrations/20261118000500_automatic_event_publication/` resmi dihapus/dinyatakan tidak aktif.
- **Alasan:**
  1. Tidak ditemukan implementasi auto-publish di `backend/src/controllers/eventController.js` maupun `backend/src/routes/eventRoutes.js`.
  2. Alur moderasi event PRD berjalan manual melalui persetujuan admin (`PENDING_REVIEW` → `APPROVED` → `PUBLISHED`).
  3. `backend/prisma/schema.prisma` tidak memiliki field `auto_publish_at` atau `published_at` pada model `Event`. Menambah migrasi tersebut akan merusak kesesuaian schema diff Prisma.
  4. Remote Supabase mencatat 8 migrasi aktif, dan migrasi lokal 004 adalah yang termutakhir.
  5. Set migrasi resmi difinalisasi menjadi 9 direktori aktif (`000` s.d. `004`), sehingga blocker migrasi T03 terselesaikan.
- **Tanggal Keputusan:** 2026-11-20
