# Laporan validasi Developer 4 - Tahap 1

- **Status:** **GO** - Tahap 1 tervalidasi terhadap **database yang terhubung** (PostgreSQL 17.11)
  melalui API lokal: 14/14 smoke integrasi PASS, schema sync PASS, unit/widget test PASS.
- **Baseline commit, branch dan PR yang divalidasi:** branch `update/featur` pada `b0bd245`
  (Merge PR #38 Developer-3). PR Tahap 1: D1 branch `Developer-1` (merge PR #28 `6a4299b`,
  artefak auth masuk lewat `871691d`/`73b1809`), D2 PR #37 (`ec3cf38`), D3 PR #38 (`b0bd245`).
  Kondisi working tree divalidasi setelah finishing D4 (bagian 6).
- **Laporan D1/D2/D3 diperiksa:** ya - `LAPORAN_DEVELOPER_1.md`, `LAPORAN_DEVELOPER_2.md`,
  `LAPORAN_DEVELOPER_3.md`. Artefak D1 Tahap 1 (FROZEN) tidak diubah.
- **File ownership diff:** PASS - bagian 2 (satu selisih terdokumentasi di laporan D2/D3).
- **Kontrak API/data/import:** PASS setelah finishing D4 - matriks di bagian 3.
- **Finishing perubahan dan alasan:** 4 file backend + 2 script uji + 2 file test (bagian 6).
- **Test/build command dan hasil:** PASS - bagian 4 (jumlah aktual, skip dijelaskan).
- **Integrasi DB/API/email/device:** DB live **PASS** (14/14, cleanup 0 residu), API live **PASS**
  (Express loopback `127.0.0.1`), email `json` transport **PASS** (bukan SMTP nyata),
  perangkat/browser **NOT RUN** (bagian 7).
- **Temuan dan pemilik perbaikan (hand-back):** bagian 5 (F-09 drift DB sudah diperbaiki;
  F-10/F-11 diteruskan ke D3).
- **Risiko sisa:** bagian 7.
- **Baseline berikutnya diizinkan:** **ya** - acceptance Tahap 1 PASS pada DB nyata.

**Catatan otorisasi DB:** pemilik proyek (2026-11-23) menyatakan database pada `backend/.env`
adalah database uji DAN database yang dipakai. Karena itu D4 menjalankan smoke test ke database
tersebut dengan fixture ber-prefix `IT4_` yang **seluruhnya dihapus kembali** (tanpa seed, tanpa
perubahan schema tabel). Satu perbaikan level database diperlukan agar alur berjalan:
`CREATE OR REPLACE FUNCTION public.create_event_order` (F-09) - tanpa DROP/DML, definisinya identik
dengan migration `20261118000400_restore_payment_status_enum_cast`.

> **Verifikasi ulang 2026-11-23:** Tahap 1 diperiksa kembali pada kondisi aktual (schema,
> migration, test, Flutter) dan akun Admin di-provision ke database. Ringkasan, temuan
> F-12..F-16, serta sisa temuan F-10/F-11/F-17..F-19 ada di bagian 9 laporan ini.

## 1. Ringkasan PR/commit yang divalidasi

| Developer | Branch | Merge ke `update/featur` | Cakupan |
|---|---|---|---|
| D1 | `Developer-1` | Merged PR #28 `6a4299b`; artefak auth Tahap 1 masuk lewat `871691d` dan `73b1809` | Auth/session, role server-authoritative, `X-Order-Access-Token` store |
| D2 | `Developer-2` | PR #37 `ec3cf38` | Event CRUD/ownership, kategori tiket, validasi harga/kuota, state UI |
| D3 | `Developer-3` | PR #38 `b0bd245` | Order single-ticket, guest payment, tiket/QR, UI registrasi |

`b0bd245` adalah titik integrasi yang diperiksa; tidak ada branch developer lain yang di-merge
ulang atau di-revert pada pekerjaan ini.

## 2. Hasil file ownership

| Developer | Path di PR | Allow-list `FILE_OWNERSHIP.md` | Hasil |
|---|---|---|---|
| D1 | `backend/src/middleware/authMiddleware.js`, `authController.js`, `authService.js`, `apps/lib/features/auth/**`, `providers/auth_provider.dart`, `services/auth/auth_service.dart`, `core/**`, `models/user/**` | Sesuai + Amendment A-1 (OR-1..OR-4) | PASS |
| D2 | `eventController.js`, `ticketTypeController.js`, `apps/lib/features/events/**`, `features/organizer/events/**`, `backend/test/event_*`, `ticket_type_*`, `apps/test/features/organizer/events/**` | Sesuai | PASS |
| D2/D3 | `backend/test/order_migration_regression.test.js` (2 baris, normalisasi CRLF/LF) | Di luar allow-list, **dicatat** di laporan D2 dan D3 | PASS dengan catatan: test-only, alasan platform/CI |
| D3 | `orderController.js`, `paymentController.js`, `apps/lib/features/{registration,orders,payments,tickets}/**`, `backend/test/order_*`, `payment_*` | Sesuai | PASS |
| D4 | `backend/test/stage1_integration.test.js`, `backend/test/stage1_ticket_type_status.test.js`, `apps/test/stage1_integration_test.dart`, `backend/scripts/integration/stage1.db-smoke.cjs`, `backend/scripts/diagnose-db-functions.js`, laporan ini, finishing minimum bagian 6 | Sesuai (test + report + script uji); finishing `ticketTypeController.js` dicatat bagian 6 | PASS dengan catatan |

Tidak ada dua PR yang menyentuh file test bersama selain `order_migration_regression.test.js` yang
perubahannya identik dan terdokumentasi. Tidak ada perubahan schema/migration/SQL di repository dan
tidak ada seed data (`SEED_DEMO_ACCOUNTS=false`).

## 3. Matriks kontrak integrasi (auth -> event/kategori -> order/payment/tiket)

| Area | Backend | Konsumen Flutter | Hasil | Bukti |
|---|---|---|---|---|
| Login/`me`/logout, role dari DB | `authController`, `authMiddleware`, `authService` | `AuthService`, `AuthProvider`, `ApiClient` | PASS | `auth_contract.test.js`; smoke DB (role `organizer`, payload kosong 400) |
| Role gate organizer/admin | `roleMiddleware` | alur Organizer | PASS | `stage1_integration.test.js`; smoke DB |
| Public event list/detail + serialisasi | `eventController`, `serializeEvent` | `EventService`, `EventProvider`, `EventModel` | PASS | smoke DB (event approved tampil publik); `apps/test/stage1_integration_test.dart` |
| Kategori tiket (DTO harga/kuota) | `ticketTypeController.toTicketTypeDto` | `TicketTypeService`, `TicketTypeModel` | PASS | smoke DB (`remaining_quota` 50 lalu 49) |
| Kategori tiket, status event diizinkan | `TICKET_TYPE_MUTABLE_EVENT_STATUSES` | form kategori Organizer | PASS (diperbaiki D4, F-09a) | `stage1_ticket_type_status.test.js`; smoke DB (Draft/Approved 201, Suspended 409) |
| Order guest: 1 tiket/1 attendee, harga server | `orderController` + RPC `create_event_order` | `OrderService`, `OrderProvider` | PASS | smoke DB (multi/assist 400, total 25000) |
| Kontrak response order | `serializeOrder` | `OrderModel` | PASS (diperbaiki D4, F-01) | smoke DB; `order_response.test.js` |
| Token akses guest | hash SHA-256 + `timingSafeEqual` | `OrderAccessTokenStore` | PASS | smoke DB (hash DB = SHA-256 token, token palsu 404) |
| Idempotency checkout | RPC + fingerprint | retry klien | PASS | smoke DB (replay 1 order/1 payment, token tidak dirotasi) |
| Pembayaran simulasi | `paymentController` + `simulate_event_payment` | `PaymentService`, `PaymentProvider`, `PaymentModel` | PASS | smoke DB (pending -> paid, simulasi ulang 400) |
| Pembacaan tiket order | `ticketController` + `presentTicket` | `TicketService`, `TicketProvider`, `TicketModel` | PASS (diperbaiki D4, F-02) | smoke DB (`order_id`, attendee, status `valid`) |
| Check-in/scan | `checkInController` | scanner Organizer | PASS | smoke DB (check-in 201, `checked_in`, scan kedua 409) |
| Route surface | `eventRoutes`, `orderRoutes`, `paymentRoutes`, `ticketRoutes`, `checkInRoutes` | service Flutter | PASS | guard route + smoke DB memakai path nyata |


## 4. Perintah pemeriksaan dan hasil aktual

Dijalankan 2026-11-23 di Windows, Node.js v22.17.1, Flutter 3.47.2 (CI menargetkan Node 22 /
Flutter 3.47.9), terhadap database pada `backend/.env`.

| # | Perintah (working dir) | Hasil | Jumlah |
|---|---|---|---|
| 1 | `node scripts/verify-schema-sync.js` (`backend/`, read-only) | PASS | 32 tabel SAMA, 29 unique, 44 index, 19 enum, 54 FK, RLS 32/33, tanpa drift Prisma |
| 2 | `node scripts/diagnose-db-functions.js` (`backend/`, read-only) | PASS (setelah F-09) | 4/4 function SAMA dengan migration terakhir |
| 3 | `node scripts/integration/stage1.db-smoke.cjs` (`backend/`, API loopback + DB nyata) | **PASS** | **14/14** + cleanup PASS (0 residu) |
| 4 | `npm test` (`backend/`) | PASS | 83 lulus, 0 gagal (62 -> 83: +16 integrasi, +5 status kategori) |
| 5 | `node --test test/stage1_integration.test.js` (`backend/`) | PASS | 16/16 |
| 6 | `node --test test/stage1_ticket_type_status.test.js` (`backend/`) | PASS | 5/5 |
| 7 | `npm run check` (`backend/`) | PASS | 61 file JS |
| 8 | `npm run format:check` (`backend/`) | PASS | trailing whitespace + JSON valid |
| 9 | `npm run validate:skills` (`backend/`) | PASS | 7 skill, 8 file Markdown |
| 10 | `npm run test:sync-config` (`backend/`) | PASS | 14/14 |
| 11 | `flutter analyze --no-fatal-infos --no-pub` (`apps/`) | PASS | No issues found |
| 12 | `flutter test --no-pub` (`apps/`, MOCK_MODE default false) | PASS | 187 lulus, 0 gagal |
| 13 | `flutter test --dart-define=MOCK_MODE=true --no-pub` (`apps/`) | PASS | 173 lulus, 14 skipped (grup API-mode di-skip pada mode demo) |
| 14 | `flutter test test/stage1_integration_test.dart --dart-define=MOCK_MODE=false --no-pub` | PASS | 8/8 |
| 15 | `flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=false --no-pub` | PASS | 11/11 |

### 4.1 Rincian smoke test DB nyata (14/14 PASS)

| # | Skenario | Bukti |
|---|---|---|
| 1 | Health API + koneksi DB | `200`, PostgreSQL 17.11, `current_database()` terbaca |
| 2 | Schema: RPC + tabel inti | `create_event_order`, `simulate_event_payment`, `expire_event_order_reservations` ada; 33 tabel |
| 3 | Auth role dari DB + payload invalid | `/api/auth/me` role `organizer`; `POST /api/events {}` -> 400 |
| 4 | Event draft + kategori tiket saat Draft | 201, `organizer_id` = owner, `remaining_quota` 50 |
| 5 | Submit review -> approve -> publik | 200/200, event muncul di `/api/events/public`; tambah kategori pada `APPROVED` 201; `SUSPENDED` 409 |
| 6 | DTO kategori publik | `price` 25000, `remaining_quota` 50, `is_available` true |
| 7 | Order guest: validasi + kontrak + hash token | items/attendees salah -> 400; order `pending_payment`, `total_amount` 25000, `grand_total` 30000, `guest_access_token_hash` = SHA-256 token, response tanpa hash |
| 8 | Replay idempoten | `idempotent_replay` true, order sama, token tidak dirotasi, 1 order + 1 payment |
| 9 | Token order salah vs benar | token palsu -> 404, token benar -> 200 |
| 10 | Payment simulasi | token palsu -> 404; sukses -> `paid`, `paid_at` terisi, 1 tiket terbit, email transport `json`; simulasi ulang -> 400 |
| 11 | Tiket: kontrak + scan | `order_id`/`attendee_name`/`attendee_email` terisi, status `valid`, QR token 43 char, `token_hash` DB = SHA-256 token, scan `VALID` |
| 12 | Check-in + scan kedua | `POST /api/check-ins` 201 -> `checked_in`; `POST /api/tickets/verify` ulang -> 409 `Ticket already used`, `tickets.status='used'`, `used_at` terisi |
| 13 | Kuota setelah paid | `sold` 1, `held` 0, `remaining_quota` 49 |
| 14 | Cleanup fixture | 0 event/user/tiket tersisa (prefix `IT4_` terhapus seluruhnya) |

Tidak ada pemeriksaan yang diubah agar terlihat PASS. Tidak ada test lama yang dihapus atau
dilonggarkan.


## 5. Temuan, perbaikan, dan hand-back

| ID | Temuan | Dampak | Status | Pemilik tindak lanjut |
|---|---|---|---|---|
| F-01 | `orderController` mengembalikan baris mentah DB (`subtotal`, `order_items`, `order_payments`, status `PENDING_PAYMENT`) padahal `OrderModel` membaca `total_amount`, `items`, `payment`, status lowercase; `serializeOrder` sudah ada dan diuji tetapi tidak dipakai | Order list menampilkan total Rp 0, 0 tiket, badge status salah; detail order kosong | **SELESAI** (D4, bagian 6), terverifikasi pada DB nyata | D3 (review perubahan) |
| F-02 | `ticketController` tidak menyertakan `attendee_name`/`attendee_email`/`order_id` dan mengembalikan status legacy `active`/`used`; `TicketModel` memakai `valid`/`checked_in` | E-ticket guest menampilkan peserta/ID pesanan kosong dan badge "TIDAK AKTIF" untuk tiket sah | **SELESAI** (D4, bagian 6), terverifikasi pada DB nyata | Maintainer (ticketController tanpa owner Tahap 1) / D3 review |
| F-03 | `OrderPayment`/`OrderStatus`/`Ticket.status` legacy tetap memakai nilai uppercase/`active` di DB | Konsumen yang membaca kolom mentah harus menormalisasi; jangan hapus nilai legacy tanpa FINISHING | Terbuka (dokumentasi) | FINISHING |
| F-04 | Integrasi DB/API live belum dijalankan pada validasi awal | RPC, constraint, dan transaksi belum terbukti end-to-end | **SELESAI** - smoke 14/14 pada DB terhubung + API loopback | - |
| F-05 | Email tiket diuji pada `json` transport (render lokal); SMTP nyata tidak tersedia | Status `SENT` nyata tidak dapat diklaim | **NOT RUN** (SMTP nyata); pemanggilan email per order berhasil pada `json` | FINISHING |
| F-06 | `POST /api/payments/simulate` mengizinkan pemilik order login atau token guest; C-02 masih OPEN DECISION | Tidak ada eskalasi lintas order (token order-scoped diuji pada DB nyata), kebijakan produk belum final | Asumsi tercatat | Product owner / FINISHING |
| F-07 | Expiry order 24 jam adalah perilaku implementasi (G-09 OPEN) | Jangan jadikan 24 jam sebagai acceptance produk | Asumsi tercatat | Product owner |
| F-08 | Sign-off keamanan QR/check-in (G-05/G-08) belum dapat diberikan | Threat review/concurrency belum lengkap (scan ganda sudah ditolak 409 pada DB nyata) | **BLOCKED** (di luar scope integrasi Tahap 1) | FINISHING |
| F-09 | **Dua defect integrasi ditemukan oleh uji DB nyata.** (a) owner tidak dapat menambah kategori tiket pada event `APPROVED`/`PUBLISHED` (409) sehingga event hasil moderasi tidak bisa dijual; (b) function `public.create_event_order` di database masih versi lama (tanpa cast `::public."PaymentStatus"`) sehingga **setiap checkout gagal 500** (`column "status" is of type "PaymentStatus" but expression is of type text`) padahal migration `20261118000400` tercatat applied | Alur event -> kategori -> order -> payment -> tiket tidak dapat dijalankan sama sekali pada database nyata | **SELESAI** (D4, bagian 6): aturan status diperluas + `CREATE OR REPLACE FUNCTION` dari migration terakhir | D2 (review aturan status), FINISHING (drift DB) |
| F-10 | Tiket dari RPC memakai `ticket_code` sebagai `qr_code_data`; scanner hanya menerima **token QR opaque** (`token_hash`), bukan `ticket_code`. Tiket **gratis** terbit tanpa `token_hash` sampai `ensureOrderTokenHashes` dijalankan, dan backfill itu hanya ada pada jalur `simulate_event_payment` | Tiket gratis berisiko tidak dapat di-scan; label `qr_code_data` menyesatkan | **Terbuka - diteruskan** (bukan blocker integrasi Tahap 1; jalur berbayar terbukti PASS pada DB nyata) | D3 (`ticketTokenService`/`paymentController`) |
| F-11 | `POST /api/tickets/verify` mengembalikan **409** saat tiket sudah dipakai (bukan 200 + `ALREADY_USED` seperti `POST /api/tickets/validate`) | Klien harus menangani 409; PRD bagian 9 mensyaratkan scan ganda ditolak, jadi perilakunya sah, hanya perlu konsisten di UI | Terbuka (dokumentasi kontrak) | D3 |


## 6. Perubahan D4 (finishing minimum) dan alasannya

Tidak ada perubahan route, method, payload request, status code, schema/migration/SQL di repository,
dependency, atau flow bisnis baru. Perubahan hanya pada layer response/presentasi, aturan status yang
tidak lengkap, file uji, dan satu function di database.

| File | Perubahan | Alasan | Dampak kompatibilitas |
|---|---|---|---|
| `backend/src/controllers/orderController.js` | Memakai `serializeOrder` pada `createOrder` (termasuk replay), `getOrder`, dan `listMyOrders` | Menyelaraskan response dengan kontrak `OrderModel` (`order_response.test.js`) dan menyembunyikan `guest_access_token_hash`/`idempotency_*` | Envelope tetap (`order`, `data`, `orders`); field mentah DB tidak dikirim; tidak ada konsumen Flutter yang memakainya |
| `backend/src/controllers/ticketController.js` | Join `attendees` + `order_items` (`attendee_name`, `attendee_email`, `attendee_phone`, `order_id`) dan `presentTicketForClient` (normalisasi status via `normalizeTicketStatus`) | Menyelaraskan response dengan `TicketModel` tanpa mengubah kolom legacy | Aditif; `token_hash` tetap tidak dikirim; check-in/verify tidak berubah |
| `backend/src/controllers/checkInController.js` | Mengekspor `normalizeTicketStatus` yang sudah ada | Menghindari duplikasi helper | Tidak ada perubahan perilaku |
| `backend/src/controllers/ticketTypeController.js` | `TICKET_TYPE_MUTABLE_EVENT_STATUSES` (DRAFT..PUBLISHED) dan `TICKET_TYPE_LOCKED_EVENT_STATUSES` (SUSPENDED/COMPLETED/CANCELLED) menggantikan `EDITABLE_EVENT_STATUSES` yang hanya `DRAFT` | F-09a: tanpa ini owner tidak dapat menyiapkan penjualan pada event `APPROVED`/`PUBLISHED`, alur Tahap 1 putus | Invarian harga/kuota tetap; event SUSPENDED/COMPLETED/CANCELLED tetap 409; admin tidak terpengaruh; diuji `stage1_ticket_type_status.test.js` |
| `backend/test/stage1_integration.test.js` (baru) | Test integrasi controller/middleware/service dengan lapisan `pg` in-memory | Bukti integrasi tanpa DB | Test-only; `pool.connect` sengaja gagal agar tidak membuka koneksi |
| `backend/test/stage1_ticket_type_status.test.js` (baru) | 5 test aturan status kategori tiket | Regresi F-09a | Test-only |
| `apps/test/stage1_integration_test.dart` (baru) | Test kontrak JSON model + alur service/provider guest | Bukti sisi klien | Test-only; grup API-mode di-skip saat `MOCK_MODE=true` |
| `backend/scripts/integration/stage1.db-smoke.cjs` (baru) | Smoke end-to-end ke DB terhubung via API loopback, fixture `IT4_` + cleanup | F-04: bukti integrasi nyata | Script uji; menolak jalan tanpa `NODE_ENV=test`; hanya menghapus baris buatannya |
| `backend/scripts/diagnose-db-functions.js` (baru) | Diagnostik read-only definisi function DB vs migration terakhir; `--export` | F-09b + pencegahan drift | Read-only, tanpa DDL/DML |
| **Database uji (di luar repo)** | `CREATE OR REPLACE FUNCTION public.create_event_order(...)` dengan definisi dari `20261118000400_restore_payment_status_enum_cast` | F-09b: drift function membuat semua checkout 500 | Tanpa DROP/DML; definisi identik dengan migration; diverifikasi `diagnose-db-functions.js` 4/4 SAMA |

Batasan: F-01/F-02/F-09a menyentuh file di luar kolom D4 karena defect integrasi tidak dapat ditutup
dari file test. Semua dijaga minimum dan dicatat untuk direview pemilik file (D2/D3/maintainer).
Perubahan DB hanya `CREATE OR REPLACE` pada function sesuai arahan pemilik proyek untuk memakai
database tersebut; tidak mengubah data maupun schema tabel.


## 7. Risiko sisa dan batas bukti

1. **Concurrency belum diuji.** Replay berurutan dan scan ganda sudah terbukti pada DB nyata; request
   paralel dengan idempotency key sama dan dua check-in bersamaan belum diuji beban.
2. **Email nyata NOT RUN.** Pemanggilan email per order berjalan (`transport: json`), tetapi SMTP
   sungguhan dan status `SENT` tidak diklaim.
3. **Android/Web/device NOT RUN.** Tidak ada build APK/web atau uji viewport; verifikasi UI tetap pada
   widget test.
4. **Keamanan QR/check-in belum di-sign-off** (G-05/G-08); C-01/C-02/G-09 tetap OPEN; perilaku yang
   dipakai adalah interpretasi paling aman yang dicatat D3.
5. **Status tiket legacy** `active`/`used` tetap ada di DB; normalisasi hanya pada presentasi.
6. **F-10 (tiket gratis tanpa `token_hash`)** belum diperbaiki; hanya jalur berbayar yang terbukti
   dapat di-scan pada DB nyata.
7. `npm run format:check` hanya memeriksa trailing whitespace/JSON, bukan formatter penuh.
8. `EventService` tidak menerima injeksi `ApiService`, sehingga alur HTTP event publik diuji lewat
   kontrak `EventModel` + guard route backend; `EventProvider` publik diverifikasi pada
   `event_provider_test.dart`.
9. Database uji tidak berisolasi (host bukan loopback, nama bukan pola `*test*`), sehingga harness
   resmi `scripts/integration/backend.integration.cjs` yang menolak target non-loopback **tidak
   dipakai**. Penggantinya `stage1.db-smoke.cjs` dengan cleanup berbasis ID/prefix dan verifikasi
   0 baris sisa setelah setiap run.

## 8. Keputusan baseline

**GO** - seluruh acceptance Tahap 1 PASS, termasuk pada database nyata (smoke 14/14) dan schema sync.
Syarat tindak lanjut:

- perubahan D4 (bagian 6) direview pemilik file (D2/D3/maintainer) sebelum merge;
- F-10 dan F-11 diteruskan ke D3; SMTP nyata serta device/browser dilengkapi pada FINISHING (F-05);
- klaim keamanan QR/check-in tetap dibatasi pada bukti yang ada (F-08).

Evidence GO: bagian 4 (15 perintah PASS), smoke DB 14/14 dengan cleanup 0 residu,
`verify-schema-sync` PASS, `diagnose-db-functions` 4/4 SAMA, tidak ada contract mismatch terbuka pada
jalur auth -> event/kategori -> order/payment/tiket, dan semua NOT RUN dijelaskan beserta pemiliknya.

## 9. Verifikasi ulang Tahap 1 dan bootstrap akun Admin (2026-11-23, tindak lanjut)

Verifikasi dilakukan terhadap kondisi aktual repository + database, bukan hanya laporan.
Perintah dijalankan ulang pada working tree setelah finishing D4.

| # | Pemeriksaan | Hasil | Bukti |
|---|---|---|---|
| 1 | `npx prisma validate` | **PASS** | "The schema at prisma/schema.prisma is valid" |
| 2 | `npx prisma migrate status` | **PASS** | 9 migration, "Database schema is up to date!" |
| 3 | `node scripts/verify-schema-sync.js` | **PASS** | 32 tabel, 29 unique, 44 index, 19 enum, 54 FK SAMA; diff dua arah kosong |
| 4 | `node scripts/diagnose-db-functions.js` | **PASS** | 4/4 function identik dengan migration terakhir |
| 5 | `npm test` | **PASS** | 89/89 (sebelumnya 83; +6 test bootstrap Admin) |
| 6 | `npm run check`, `npm run format:check` | **PASS** | 62 file JS; format bersih |
| 7 | `flutter analyze --no-fatal-infos` | **PASS** | No issues found |
| 8 | `flutter test` (API mode default) | **PASS** | 188/188 |
| 9 | `flutter test --dart-define=MOCK_MODE=true` | **PASS** | 173 lulus, 14 skipped (grup API-mode) |
| 10 | Login Admin end-to-end ke DB nyata (API loopback) | **PASS** | 15/15 skenario, lihat 9.2 |

### 9.1 Temuan yang diperbaiki pada verifikasi ini

| ID | Temuan | Bukti | Perbaikan | Status |
|---|---|---|---|---|
| F-12 | `seedService.js` menyimpan password akun demo **plaintext di source code** (`admin@event.com`/`Admin123!`, `organizer@event.com`/`Organizer123!`) dan menulis ulang password/role profil yang sudah ada saat `SEED_DEMO_ACCOUNTS=true`. Bertentangan dengan aturan "jangan menanamkan password/secret di source code" dan berisiko menimpa role akun nyata. | `backend/src/services/seedService.js` (sebelum perubahan), `backend/README.md` tabel demo credentials | Seeder diganti bootstrap berbasis environment (`ADMIN_EMAIL`/`ADMIN_PASSWORD`), bcrypt cost 12, idempotent, tidak pernah menaikkan role akun yang sudah ada, tidak pernah menulis password ke log | **SELESAI** |
| F-13 | Database tidak memiliki **satu pun** baris `profiles` (0 akun), sehingga tidak ada akun Admin yang dapat login; halaman login Admin hanya dapat "berhasil" di mode demo frontend. | Query read-only: `profile_total = 0`, `admins = []` | Akun Admin dibuat sebagai record `profiles` (`role = 'admin'`, hash bcrypt) melalui `npm run admin:provision`; kredensial hanya di `backend/.env` (gitignored). Dijalankan dua kali: `CREATED` lalu `UNCHANGED` (tidak ada duplikat) | **SELESAI** |
| F-14 | Flutter `auth_service.dart` menyimpan password persona demo di source code (`Admin123!`, `Organizer123!`). | `apps/lib/services/auth/auth_service.dart` (sebelum perubahan) | Password dihapus dari source; mode demo hanya memilih persona tanpa kredensial tersimpan dan tetap gated `MOCK_MODE=true`. Login Admin sebenarnya selalu lewat API. | **SELESAI** |
| F-15 | `backend/README.md` mendokumentasikan demo credentials yang tidak ada lagi dan menyatakan RLS **belum** aktif, sedangkan kondisi aktual 32/32 RLS aktif, 0 policy, 0 grant `anon`/`authenticated`. | `backend/README.md` §"Roles, demo accounts", §"Database Schema" | Dokumentasi diselaraskan: prosedur provisioning Admin, tabel variabel `ADMIN_*`, dan status RLS aktual | **SELESAI** |
| F-16 | Dashboard Admin selalu memuat daftar event dari `MockOrganizerEventRepository` (tidak pernah API) walau `GET /api/events` (admin-only) sudah tersedia. | `apps/lib/features/admin/screens/admin_dashboard_screen.dart` | Loader default memakai `createOrganizerEventRepository().listPlatformEvents()` (API default, mock hanya `MOCK_MODE=true`); error state + tombol coba lagi, tanpa fallback mock; test baru menutup jalur error | **SELESAI (Tahap 2, scope D3)** |

### 9.2 Bukti login Admin end-to-end (DB nyata + API loopback)

15/15 skenario PASS, tanpa mencetak password/token:

1. `/health` 200, `database: connected`.
2. Login dengan password salah -> **401**.
3. Login kredensial benar -> **200**, JWT diterima, `user.role = admin`.
4. Response login tidak memuat `password_hash`.
5. `GET /api/auth/me` -> 200, role `admin`.
6. `GET /api/admin/accounts` (admin) -> **200**.
7. `GET /api/events` (admin, semua event) -> **200**.
8. `POST /api/auth/register` -> 201, role `organizer` (role tidak dapat dikirim klien).
9. Organizer -> `GET /api/admin/accounts` **403**.
10. Organizer -> `GET /api/events` (admin-only) **403**.
11. Organizer -> `GET /api/events/mine` **200**.
12. Admin -> `GET /api/events/mine` **403** (tidak mewarisi hak Organizer).
13. Tanpa token -> `GET /api/admin/accounts` **401**.
14. Database: email Admin ada **tepat 1 baris**, `role = 'admin'`, `password_hash` berformat bcrypt.
15. Fixture organizer uji dihapus kembali; 0 residu.

### 9.3 Temuan yang masih tersisa (belum diselesaikan pada verifikasi ini)

| ID | Temuan | Dampak | Pemilik tindak lanjut |
|---|---|---|---|
| F-10 | Tiket gratis dari RPC belum memiliki `token_hash` sampai `ensureOrderTokenHashes` dijalankan (jalur `simulate_event_payment`), sedangkan scanner memverifikasi `token_hash`. | Tiket gratis berisiko tidak dapat di-scan. | D3 (lanjutan) / FINISHING |
| F-11 | `POST /api/tickets/verify` mengembalikan 409 untuk tiket yang sudah dipakai, `POST /api/tickets/validate` mengembalikan 200 + `ALREADY_USED`. | Klien harus menangani dua bentuk. | D3 |
| F-17 | `AccountManagementScreen` Admin masih memakai daftar akun in-memory (`_mockAccounts`), sehingga akun Admin/Organizer nyata di database tidak tampil dan suspend tidak memanggil `PUT /api/admin/accounts/:id/status`. | Monitoring akun Admin belum memakai data nyata; audit log hanya in-memory. | Tahap 2 D3 (lihat `TAHAP_2/RENCANA_KERJA.md`) |
| F-18 | Tabel `platform_settings`, `platform_setting_history`, `audit_logs` belum memiliki endpoint backend; layar Pengaturan/Audit Admin masih in-memory. | Requirement konfigurasi & audit trail Admin (§2.1/§3) belum terpenuhi. | Tahap 2 D3 + keputusan produk untuk kunci konfigurasi |
| F-19 | `AdminRevenueService`, `AdminPackageService`, `AdminSubscriptionService`, layanan Organizer (plans/notifications/membership/support), dan `EventActivityService` masih in-memory walau endpoint backend sebagian tersedia. | Dashboard keuangan/paket/langganan/aktivitas belum menampilkan data database. | Tahap 2/3 (lihat rencana rekonsiliasi) |

Catatan: F-12..F-16 tidak mengubah schema, migration, maupun data pengguna; F-13 menambah **satu** profil Admin baru sesuai permintaan pemilik proyek. Tidak ada reset, DROP, atau penghapusan data.

## 10. Asumsi yang perlu konfirmasi

1. Header guest order tetap `X-Order-Access-Token` dan token tidak pernah dikirim ke URL (sesuai
   implementasi D3 dan `INTEGRATION_CONTRACT.md`).
2. Response order memakai `serializeOrder` sebagai satu-satunya kontrak publik; field mentah DB tidak
   dianggap API publik.
3. Normalisasi status tiket (`active` -> `valid`, `used` -> `checked_in`) adalah kontrak presentasi,
   bukan perubahan data.
4. Perubahan D4 dianggap bagian dari peran integrator (field laporan "Finishing perubahan dan
   alasan"), bukan implementasi fitur baru.
5. Database pada `backend/.env` dianggap database uji yang boleh menerima fixture sementara sesuai
   pernyataan pemilik proyek; seluruh fixture dihapus setelah run dan tidak ada seed data.
6. `CREATE OR REPLACE FUNCTION` pada `create_event_order` dianggap pemulihan drift menuju sumber repo,
   bukan perubahan kontrak baru (definisi identik dengan migration terakhir).

