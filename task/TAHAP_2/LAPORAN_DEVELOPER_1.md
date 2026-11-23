# Laporan Developer 1 — Tahap 2 (Publishable Event & Public Registration)

- **Status:** DONE (seluruh task D1-1 … D1-5 selesai; tidak ada blocker eksternal).
- **Baseline commit:** `781434f` (`update/featur`, HEAD saat mulai). Working tree bersih sebelum mulai.
- **Branch kerja:** `update/featur` (perubahan belum di-commit; siap direview/di-PR).
- **Otorisasi:** perintah pemilik proyek = otorisasi implementasi. Tidak ada approval teknis tambahan yang diminta.
- **Lingkup:** backend (event lifecycle, tautan, order/payment/tiket guest) + Flutter (router publik, landing publik, registrasi guest, pembayaran) + test.

## 1. Keputusan teknis & asumsi mandiri

1. **Basis tautan publik** memakai `APP_PUBLIC_URL` (sudah ada di `backend/src/config/env.js`, default `http://localhost:5000`). Tidak menambah konfigurasi baru.
2. **Penyimpanan alasan validasi** memakai kolom `events.review_note` yang sudah ada (JSON array string). Tidak ada perubahan schema; serializer mengembalikannya sebagai `validation_errors: string[]` dan UI menampilkannya sebagai daftar. `review_note` teks biasa (catatan moderator lama) tetap didukung.
3. **`POST /api/events/:id/publish`** mengembalikan `200` bila tayang dan **`422`** bila tidak valid (event tetap `DRAFT`, `is_public=false`). `POST /api/events/:id/submit-review` dipertahankan sebagai alias perilaku baru (auto-publish) sesuai RENCANA_KERJA §C D1-2 butir 2.
4. **Create event tetap `DRAFT`** karena pada saat create belum ada kategori tiket; validasi dijalankan dan alasannya dikembalikan (`published:false`). Event tayang setelah Organizer menambah kategori tiket lalu menekan “Terbitkan event”. Ini interpretasi paling aman dari AC-01 tanpa mengubah alur pengisian kategori tiket.
5. **`attendee_fields`** kini `[{key,label,type,required,options}]` dengan kompatibilitas penuh array string legacy. `name` dan `email` selalu `required` karena merupakan kolom wajib tabel `attendees`.
6. **Jawaban field dinamis** disimpan ke `attendees.custom_fields` (JSONB) melalui `UPDATE` di dalam transaksi yang sama dengan `create_event_order` (RPC belum menulis kolom itu). Proposal perubahan RPC dicatat sebagai **DP-04**.
7. **Route `/registration/:eventId`** dijadikan publik (tujuan tautan pendaftaran), sedangkan `/admin/**` dan `/organizer/**` tetap butuh login + role.
8. **`/invite/:token`** memaksa login lalu kembali ke halaman undangan (`LoginScreen(redirectRoute:)`). Halaman penerimaan lengkap (kecocokan email, accept, redirect scanner) adalah milik D2; D1 menyediakan route + gerbang login + placeholder navigasi.
9. **Status `CANCELLED`** ditambahkan ke `AppConstants.paymentStatus*` agar UI membedakan `PENDING/PAID/EXPIRED/FAILED/CANCELLED` sesuai kontrak §1.4.

## 2. Ringkasan hasil per task

### D1-1 — Fondasi routing publik & kepemilikan route — PASS
- `routes/app_routes.dart`: konstanta + helper path `/e/:eventId`, `/e/:eventId/register`, `/e/:eventId/order|payment/:orderId`, `/e/:eventId/ticket/:ticketId`, `/invite/:token`, `/staff/:eventId`.
- `app_router.dart`: parsing segmen baru, `_isPublicPath()` (publik: `/`, `/login`, `/register`, `/access-denied`, `/e/**`, `/invite/**`, `/registration/**`), `_isInvitationPath()` → login dengan redirect, `case AppRoutes.registration` (tidak 404), `/staff/:eventId` → `StaffDashboardScreen(eventId:)`.
- Bukti: `apps/test/app_router_test.dart` (6 test baru) — K1 guest `/e/...` bukan login; K2 guest `/admin/dashboard` ditolak; K3 `/invite/token-abc` → `LoginScreen.redirectRoute` lalu setelah login `InvitationEntryScreen`; K4 `/registration/:eventId` merender `RegistrationScreen`; `/staff/:eventId` merender dashboard staf.

### D1-2 — Auto-publish (validasi → `PUBLISHED`) — PASS
- `backend/src/utils/eventValidation.js` (baru): `validateEventForPublish`, `resolvePublishTransition`, `parseValidationNote`, normalisasi/validasi `attendee_fields`, `validateAttendeeAnswers`, `splitCustomFieldAnswers` — murni tanpa DB sehingga dapat diuji.
- `eventController.js`: `applyPublishTransition()` (menulis `status`, `is_public`, `review_note`, `submitted_at`, `public_url`), `publishEvent` + alias `submitForReview`, create event menjalankan validasi, edit event `PUBLISHED/APPROVED` memicu validasi ulang (invalid → `DRAFT`).
- `eventRoutes.js`: `POST /:id/publish` (organizer) + alias `submit-review`.
- `eventResponse.js`: `validation_errors` dari `review_note`.
- Flutter: `organizer_event_detail_screen.dart` menampilkan tombol **“Terbitkan event”** (mode API) dengan dialog konfirmasi, snackbar hasil, dan kotak “Catatan validasi / revisi” berisi daftar alasan; aksi “Ajukan moderasi/simulasi moderator” hanya tampil pada `MOCK_MODE`.
- Bukti: `backend/test/event_auto_publish.test.js` (13 test) — K1 event lengkap lolos; K2 tanpa kategori aktif → alasan; K4 edit tayang → `DRAFT`; `apps/test/features/organizer/events/event_publish_validation_test.dart` (2 test) — K6 alasan tampil + tombol Terbitkan ada.
- K3 (`GET /api/events/public` tidak memuat event invalid): filter publik tetap `is_public = true AND status IN ('APPROVED','PUBLISHED')`; event invalid tidak pernah mendapat `is_public = true`.

### D1-3 — Dua tautan: `public_url` + staff invitation URL — PASS
- `eventResponse.js`: `buildPublicUrl`, `publicUrlFor` (null kecuali tayang), `serializeEvent` selalu mengirim `public_url`; `APPROVED` legacy tetap dianggap tayang.
- `eventInvitationController.js`: response pembuatan undangan menambah **`invite_url = {APP_PUBLIC_URL}/invite/{rawToken}`** (aditif; `invitation_link` lama tidak diubah).
- Flutter: `organizer_event_contract.dart` — `registrationUrl` tidak lagi memakai tautan demo pada mode API (`''` bila belum tayang) + getter `hasPublicLink`; detail event kini dua panel terpisah: **“Tautan Pendaftaran Peserta”** (tombol salin nonaktif bila belum tayang, key `event-public-link-copy`) dan **“Tautan Undangan Panitia”** (tombol ke pengelolaan undangan, key `event-staff-invite-open`).
- Bukti: `backend/test/event_public_links.test.js` (6 test) — K1 public_url absolut, K2 draft → null, K3 invite_url ≠ public_url; `apps/test/features/organizer/events/event_public_links_test.dart` (2 test) — dua panel + tombol salin aktif/nonaktif.

### D1-4 — Landing publik + registrasi guest + checkout — PASS
- Baru: `services/public_event/public_event_service.dart` (`PublicEventService`, `PublicEventData`, `PublicEventUnavailableException`), `features/public_event/screens/public_event_screen.dart`, `public_registration_screen.dart`, `invitation_entry_screen.dart`.
- Landing publik: judul, deskripsi, jadwal, lokasi/online, poster, `public_info`, kategori tiket (harga, sisa kuota, status tersedia), tombol “Daftar Sekarang” (nonaktif bila tidak ada kategori yang dapat dipesan).
- Registrasi guest: pilih **tepat satu** kategori (radio), field peserta mengikuti `attendee_fields` event (text/textarea/number/date/select/checkbox), ringkasan harga dari data server, `POST /api/orders` via `OrderProvider` + idempotency key; `order_access_token` disimpan `OrderService` (secure storage).
- Navigasi: order gratis → `TicketListScreen(orderId:)`; order berbayar → `PaymentScreen(orderId:)`.
- `event_detail_screen.dart`: tombol “Daftar Sekarang” hanya aktif untuk event tayang dengan kategori yang dapat dipesan (K5).
- Bukti: `apps/test/features/public_event/public_event_screen_test.dart` (6 test: loading/error/unavailable/ready/empty/sold-out) dan `public_registration_screen_test.dart` (6 test: loading/unavailable, submit tanpa kategori, validasi field wajib, payload satu order–satu tiket–`custom_fields`, kategori habis).

### D1-5 — Perbaikan order/payment/tiket guest + dynamic attendee data — PASS
- Kontrak `attendee_fields` bertipe (kompatibel array string legacy) di `eventValidation.js` + `AttendeeFieldDefinition` (Flutter).
- Validasi saat create/update event (`validateEventInput` → `validateAttendeeFields`) dan saat membuat order (`validateAttendeeAnswers` sebelum RPC; field wajib/tipe/opsi/field tak dikenal ditolak `400`).
- Jawaban disimpan ke `attendees.custom_fields` (JSONB) di dalam transaksi order yang sama (`persistAttendeeCustomFields`), tanpa perubahan schema.
- `token_hash` dipastikan tersedia untuk tiket order gratis langsung setelah order dibuat (`ensureOrderTokenHashes`) dan setelah pembayaran sukses (sudah ada di `paymentController`).
- UI pembayaran: `PENDING/PAID/EXPIRED/FAILED/CANCELLED` dengan judul, penjelasan, dan aksi berbeda (retry hanya untuk `FAILED`); VA hanya tampil saat `PENDING`; “Lihat E-Ticket” membawa `orderId`.
- `emailService.js`: tautan email menuju `/e/{eventId}/ticket/{ticketId}` (bukan `/tickets/:id` yang tidak ada di router); token akses guest tidak pernah masuk URL.
- Bukti: `backend/test/attendee_dynamic_fields.test.js` (6 test), `event_auto_publish.test.js` (bagian normalisasi field), `apps/test/features/organizer/events/event_model_contract_test.dart` (8 test), `order_payment_screen_test.dart` (FAILED vs EXPIRED).

## 3. File yang dibuat / diubah

**Backend (baru):** `src/utils/eventValidation.js`, `test/event_auto_publish.test.js`, `test/event_public_links.test.js`, `test/attendee_dynamic_fields.test.js`.
**Backend (diubah):** `src/controllers/eventController.js`, `src/controllers/eventInvitationController.js`, `src/controllers/orderController.js`, `src/routes/eventRoutes.js`, `src/services/emailService.js`, `src/utils/eventResponse.js`, `test/stage1_integration.test.js`.
**Flutter (baru):** `lib/models/event/attendee_field_definition.dart`, `lib/services/public_event/public_event_service.dart`, `lib/features/public_event/screens/{public_event_screen,public_registration_screen,invitation_entry_screen}.dart`, `test/features/public_event/*`, `test/features/organizer/events/{event_public_links_test,event_publish_validation_test,event_model_contract_test}.dart`.
**Flutter (diubah):** `lib/app_router.dart`, `lib/routes/app_routes.dart`, `lib/models/event/event_model.dart`, `lib/services/organizer_events/organizer_event_contract.dart`, `lib/features/organizer/events/screens/organizer_event_detail_screen.dart`, `lib/features/organizer/screens/event_form_screen.dart`, `lib/features/events/screens/event_detail_screen.dart`, `lib/features/registration/screens/registration_screen.dart`, `lib/features/payments/screens/{payment_screen,payment_status_screen}.dart`, `lib/providers/order_provider.dart`, `lib/core/constants/app_constants.dart`, `lib/features/auth/screens/login_screen.dart`, `test/app_router_test.dart`, `test/features/orders/order_payment_screen_test.dart`.
**Dokumentasi:** `docs/ARCHITECTURE.md` (bagian lifecycle event & tautan publik), `task/DB_CHANGE_PROPOSAL.md` (DP-04), laporan ini.

**Perubahan di luar allow-list (minimum, terdokumentasi):**
- `lib/core/constants/app_constants.dart`: menambah `paymentStatusCancelled` (konstanta aditif; kontrak §1.4 menyebut `CANCELLED`).
- `lib/features/auth/screens/login_screen.dart`: parameter opsional `redirectRoute` (backward compatible) untuk K3 `/invite/:token`.
- `lib/providers/order_provider.dart`: tipe `attendees` menjadi `List<Map<String, dynamic>>` agar `custom_fields` dapat dikirim (D1-5).


## 4. Database, API, dan dependensi

- **Database:** tidak ada perubahan schema/migration/seed/SQL. `attendees.custom_fields` dan `events.public_url`/`review_note` sudah ada. Kebutuhan RPC dicatat sebagai **DP-04** di `task/DB_CHANGE_PROPOSAL.md` (belum diimplementasikan).
- **Endpoint baru:** `POST /api/events/:id/publish` (organizer, `200`/`422`).
- **Endpoint berubah perilaku:** `POST /api/events/:id/submit-review` kini alias auto-publish (bukan lagi `PENDING_REVIEW`).
- **Field tambahan (aditif, tidak memecah kontrak):** `GET /api/events/:id` & `/events/public` & `/events/mine` → `public_url`, `validation_errors`; `POST /api/events/:id/publish|submit-review` → `published`, `validation_errors`; `POST /api/events/:eventId/invitations` → `invite_url`; `POST /api/orders` menerima `attendees[].custom_fields` (opsional) dan menolak field wajib yang kosong.
- **Tidak berubah:** bentuk `POST /api/orders` (`{order, order_access_token}`), `GET /api/tickets/:id?order_id=`, `POST /api/payments/simulate`, `GET /api/events/public` (tetap hanya `APPROVED`/`PUBLISHED` + `is_public`).
- **Dependensi:** tidak ada dependency Flutter/Node baru.

## 5. Bukti pengujian (perintah dijalankan pada working tree ini)

| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Backend test | `cd backend; npm test` | **PASS** — 112 test, 0 fail (baseline 89 + 23 baru) |
| Backend sintaks | `cd backend; npm run check` | **PASS** — 62 file JavaScript |
| Backend format | `cd backend; npm run format:check` | **PASS** — tanpa trailing whitespace |
| Skill/doc link | `cd backend; npm run validate:skills` | **PASS** — 7 skill, 8 markdown |
| Flutter analisis | `cd apps; flutter analyze` | **PASS** — No issues found |
| Flutter test | `cd apps; flutter test` | **PASS** — 220 test (baseline 188 + 32 baru) |

**Platform/lingkungan:** API/DB nyata **NOT RUN** (tidak ada kredensial/DB uji pada sesi ini; verifikasi memakai unit test murni + fake DB in-memory pada `stage1_integration.test.js`). Uji perangkat Android/Web manual **NOT RUN** untuk D1 (D1 tidak menyentuh kamera); layout diuji lewat widget test dengan viewport sempit/lebar. Pengiriman email SMTP **NOT RUN** (tanpa kredensial); perubahan hanya teks/tautan.


## 6. Kriteria keberhasilan → status

| Task | Kriteria | Status | Bukti |
|---|---|---|---|
| D1-1 | K1 `/e/{eventId}` guest bukan login | PASS | `app_router_test` |
| D1-1 | K2 `/admin/dashboard` guest ditolak | PASS | `app_router_test` |
| D1-1 | K3 `/invite/{token}` → login → kembali | PASS | `app_router_test` (`redirectRoute`) |
| D1-1 | K4 `/registration/{eventId}` tidak 404 | PASS | `app_router_test` |
| D1-1 | K5 widget test aturan route | PASS | 6 test |
| D1-2 | K1 event lengkap → `PUBLISHED` tanpa Admin | PASS | `event_auto_publish.test.js`, `event_publish_validation_test.dart` |
| D1-2 | K2 tanpa kategori → `DRAFT` + alasan | PASS | idem |
| D1-2 | K3 event invalid tidak muncul di publik | PASS | filter `getEvents`/`getEventById` + test |
| D1-2 | K4 edit `PUBLISHED` → invalid → `DRAFT` | PASS | test `resolvePublishTransition` |
| D1-2 | K5 test backend K1–K4 | PASS | 13 test |
| D1-2 | K6 UI menampilkan alasan validasi | PASS | `event_publish_validation_test.dart` |
| D1-3 | K1 `public_url` valid untuk `PUBLISHED` | PASS | `event_public_links.test.js` |
| D1-3 | K2 `DRAFT` → `public_url = null`, salin nonaktif | PASS | backend + widget test |
| D1-3 | K3 `invite_url` ≠ `public_url` | PASS | backend test |
| D1-3 | K4 test backend + widget dua panel | PASS | 6 + 2 test |
| D1-4 | K1 guest melihat event + kategori tanpa login | PASS | router + `public_event_screen_test` |
| D1-4 | K2 guest memilih 1 tiket, order tercipta | PASS | `public_registration_screen_test` (`items: {tt:1}`) |
| D1-4 | K3 `order_access_token` tersimpan & dipakai | PASS | `OrderService.createOrder` → `OrderAccessTokenStore`; `TicketService`/`PaymentService` membaca token |
| D1-4 | K4 >1 tiket tidak mungkin dari UI & ditolak server | PASS | UI radio 1 kategori; `orderController` menolak `totalQuantity !== 1` |
| D1-4 | K5 `DRAFT`/`SUSPENDED` tidak dapat didaftari | PASS | `canRegister` (UI) + RPC `is_public AND status IN ('APPROVED','PUBLISHED')` |
| D1-4 | K6 widget test 4 state | PASS | loading/error/unavailable/ready/empty/sold-out |
| D1-5 | K1 field dinamis tampil & required divalidasi | PASS | `public_registration_screen_test`, `attendee_dynamic_fields.test.js` |
| D1-5 | K2 jawaban tersimpan & terbaca kembali | PASS (kode + unit test) / **NOT RUN** (verifikasi DB nyata bersama D3) | `persistAttendeeCustomFields` dalam transaksi; DP-04 |
| D1-5 | K3 tiket gratis dapat dipindai tanpa buka halaman tiket | PASS (backfill saat order) / **NOT RUN** (scan perangkat) | `ensureOrderTokenHashes` saat order `PAID` |
| D1-5 | K4 setiap status pembayaran informatif | PASS | `payment_screen`, `payment_status_screen`, `order_payment_screen_test` |
| D1-5 | K5 test kontrak field valid/invalid | PASS | `attendee_dynamic_fields.test.js` |

## 7. Risiko, permintaan ke owner lain, dan handoff

- **D2 (invitation/membership):** halaman penerimaan undangan nyata (`features/staff/screens/accept_invitation_screen.dart`) belum ada. D1 menyediakan route `/invite/:token`, gerbang login + redirect, dan placeholder `InvitationEntryScreen`. Mohon ganti placeholder dengan screen D2 (cocokkan email → `POST /api/invitations/:token/accept` → `/staff/:eventId`). Backend kini mengirim `invite_url` pada pembuatan undangan; mohon tampilkan field itu di UI team management.
- **D2 (ticket):** `TicketListScreen` dipanggil D1 dengan `orderId` (navigasi pasca-checkout). Mohon pertahankan parameter tersebut.
- **D3 (attendee/export):** jawaban field dinamis tersedia pada `attendees.custom_fields`; mohon tampilkan di detail peserta dan sertakan pada export. `payment_status` kini juga bisa `cancelled`.
- **Risiko integrasi:** `submit-review` berubah perilaku (auto-publish); perilaku `PENDING_REVIEW` hanya tersisa pada `MOCK_MODE`. `public_url` kini `null` untuk event belum tayang (sebelumnya UI memakai tautan demo) — monitoring D3 sebaiknya menangani `null`.
- **Belum diverifikasi:** alur API + PostgreSQL nyata (order → `custom_fields` → tiket → scan) belum dijalankan pada sesi ini; perlu smoke test pada environment uji bersama (G2-4, G2-5).
- **Tidak diklaim:** builder field kustom pada form Organizer (form masih mengirim daftar kunci legacy; API & form publik sudah mendukung field bertipe), pengiriman email nyata, dan aksesibilitas penuh.


