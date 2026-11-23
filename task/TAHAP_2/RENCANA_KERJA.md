# TAHAP 2 — RENCANA KERJA

- **Versi:** 3.0 (audit & restrukturisasi 2026-11-23)
- **Menggantikan:** versi pra-audit yang diarsipkan di `../archive/TAHAP_2_RENCANA_KERJA_PRA_AUDIT_2026-11-23.md`.
- **Acuan:** [`../PEMBAGIAN_TUGAS_FINAL.md`](../PEMBAGIAN_TUGAS_FINAL.md), [`../ROADMAP_AUDIT_FINAL.md`](../ROADMAP_AUDIT_FINAL.md), [`../../PRD.md`](../../PRD.md) v2.2.
- **Dokumen pendukung:** [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md), [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md).
- **Tujuan Tahap 2:** menyelesaikan **seluruh fungsi inti MVP** (Backend + Flutter + test) sampai setiap role dapat menjalankan fungsinya end-to-end pada aplikasi nyata.

> Dokumen ini adalah rencana. Tidak ada source code yang diubah saat penyusunan.

---

## A. Kondisi awal Tahap 2 (baseline commit saat audit)

Baseline: commit `cf38`/`3c6a9cf` (branch `Developer-3`/`Developer-2` ter-merge). Fakta baseline:

| Aspek | Kondisi |
|---|---|
| Backend test | 89 PASS |
| Flutter analyze | 0 issue |
| Flutter test | 188 PASS |
| Database | 32 tabel, 19 enum, 54 FK, 105 index, 9 migration, 0 drift |
| Alur publik guest | **tidak dapat dijalankan** (router memaksa login) |
| Auto-publish | **belum ada** (masih approval Admin) |
| QR tiket | **palsu** (painter pseudo-QR) |
| Scanner | **tanpa kamera**, ada mode offline non-MVP |
| Layar Admin/Organizer | sebagian besar masih in-memory |
| Daftar peserta | belum paid-first, tanpa nomor registrasi |

---

## B. Aturan kerja Tahap 2

1. Setiap developer bekerja pada branch sendiri: `Developer-1`, `Developer-2`, `Developer-3`.
2. Setiap task = satu PR dengan judul `[Tahap 2][<TASK-ID>] <ringkasan>`.
3. File shared hanya disentuh owner-nya (`FILE_OWNERSHIP.md`). Permintaan perubahan lintas owner ditulis di deskripsi PR dan laporan.
4. Tidak boleh mengubah schema/migration/seed. Kebutuhan DB → `../DB_CHANGE_PROPOSAL.md`.
5. Status bukti wajib memakai: `PASS`, `FAIL`, `BLOCKED`, `NOT RUN` (dengan alasan).
6. Mock hanya boleh hidup di `MOCK_MODE=true`. Pada `MOCK_MODE=false`, semua layar in-scope harus memakai API atau menampilkan error state.
7. Tidak menghapus fitur. Fitur non-MVP (assisted registration, offline scanner) **disembunyikan dari navigasi**, bukan dihapus.

### B.1 Protokol kerja paralel (wajib, karena D1–D3 berjalan bersamaan)

**Hari 1 — "Bootstrap day" (blocking, semua berhenti menunggu):**

| Langkah | Pemilik | Output | Selesai bila |
|---|---|---|---|
| B1 | D2 | PR `[Tahap 2][D2-0]` — dependency `qr_flutter` + `mobile_scanner` | `flutter pub get` + `analyze` + `test` PASS di branch D2-0 |
| B2 | D1 | PR `[Tahap 2][D1-A] Foundation` — **stub** `features/public_event/` (2 layar kosong), **stub** `services/public_event/`, route publik di `app_router.dart`, `routes/app_routes.dart` | `flutter analyze` PASS; route `/e/:eventId` merender layar stub, bukan login |
| B3 | D3 | PR `[Tahap 2][D3-A] Shared interface` — `utils/auditLog.js` + mount path kosong di `app.js` untuk route baru | `npm test` PASS; tidak ada route yang berperilaku baru |

Ketiga PR bootstrap di-merge ke `main` **sebelum** task fitur dimulai. Ini mencegah konflik pada `pubspec.yaml`, `app_router.dart`, dan `app.js` — tiga file yang paling rawan.

**Paralel penuh setelah hari 1:**

- D1 bekerja di branch `Developer-1` dari `main` terbaru.
- D2 bekerja di `Developer-2` dari `main` terbaru (sudah berisi D2-0).
- D3 bekerja di `Developer-3` dari `main` terbaru (sudah berisi D3-A).
- **Dilarang** melakukan merge/sync dari branch developer lain selama fase implementasi; rebase ke `main` saja.
- Setiap PR wajib rebase ke `main` sebelum merge (tidak boleh merge ke belakang).

### B.2 Protokol merge (mencegah "3 developer hijau tetapi integrasi merah")

1. Urutan merge mengikuti dependency, bukan urutan kecepatan:
   `D2-0 → D1-A → D3-A → D1-1/D1-2 → D2-1 → D3-1/D3-3 → D1-3 → D2-2 → D1-4 → D3-2 → D2-3/D3-4 → D1-5 → D2-4 → D3-5`.
2. Setiap PR yang merge **wajib** disertai hasil `npm test` + `flutter analyze` + `flutter test` pada **branch hasil rebase ke main terbaru** (bukan pada branch lama).
3. Penanggung jawab merge: pemilik proyek atau D4. Developer meng-*approve* PR miliknya sendiri.
4. Setiap kali 3 PR berturut-turut ter-merge, jalankan **smoke integrasi** singkat (login → buka event → order → bayar → tiket) untuk mendeteksi regresi lintas domain lebih awal.
5. Konflik merge **tidak** diselesaikan dengan menyalin kode developer lain. Bila muncul konflik di file milik developer lain, minta owner menyelesaikan.

### B.3 Titik sinkronisasi (± setiap 2 hari) — "sync gate"

Pada setiap sync gate, ketiga developer **wajib** menempelkan bukti ke laporan:

| Bukti | Perintah |
|---|---|
| Backend | `cd backend; npm test` |
| Analisis | `cd apps; flutter analyze` |
| Test UI | `cd apps; flutter test` |
| Bebas mock (layar miliknya) | `Select-String -Pattern "mock"` pada file yang diubah |
| Endpoint dipakai frontend | Daftar endpoint baru + layar yang memakainya |

Bila salah satu developer `FAIL` pada sync gate, pekerjaan developer tersebut dihentikan sampai hijau — developer lain tetap boleh lanjut sesuai aturan merge §B.2.

---

## C. Developer 1 — Publishable Event & Public Registration

**Domain:** lifecycle event (validasi → publish), dua tautan event, pengalaman publik, order & pembayaran guest.
**Kepemilikan tambahan:** `apps/lib/app.dart`, `apps/lib/app_router.dart`, `apps/lib/routes/app_routes.dart`.
**Total:** 5 task (D1-1 … D1-5).

### D1-1 — Fondasi routing publik & kepemilikan route

- **Status baseline:** NOT IMPLEMENTED (tidak ada route publik; `AppRoutes.registration` dideklarasikan tetapi tidak ada `case`).
- **Fitur:** kerangka navigasi halaman publik, route invitation, route staff workspace, deep link `/e/:eventId`.
- **File backend:** —
- **File Flutter:** `apps/lib/app_router.dart`, `apps/lib/app.dart`, `apps/lib/routes/app_routes.dart`.
- **Pekerjaan:**
  1. Daftarkan route publik: `/e/:eventId`, `/e/:eventId/register`, `/e/:eventId/order/:orderId`, `/e/:eventId/payment/:orderId`, `/e/:eventId/ticket/:ticketId`.
  2. Pastikan guard mengizinkan route publik tanpa token; halaman lain tetap memerlukan login.
  3. Tambahkan `/invite/:token`: bila belum login → login sambil menyimpan `redirect`; setelah login → halaman penerimaan undangan.
  4. Tambahkan `/staff` dan `/staff/:eventId` untuk workspace staff.
  5. Tambahkan `case AppRoutes.registration` agar `/registration/:eventId` tidak 404 (dialihkan ke alur publik).
  6. Perluas `_homeForRole`: role `staff` → `/staff`.
- **Dependency:** —
- **Kriteria keberhasilan:**
  - K1 `/e/{eventId}` sebagai guest tidak diarahkan ke login.
  - K2 `/admin/dashboard` sebagai guest tetap ditolak.
  - K3 `/invite/{token}` tanpa login → login → kembali ke penerimaan undangan.
  - K4 `/registration/{eventId}` tidak lagi 404.
  - K5 Widget test untuk setiap aturan di atas lulus.
- **Metode pengujian:** `flutter test` (widget router), `flutter analyze`.
- **Larangan:** tidak mengubah isi layar fitur; hanya navigasi/guard.

### D1-2 — Auto-publish event: validasi → `PUBLISHED`

- **Status baseline:** PARTIALLY IMPLEMENTED. Create → `DRAFT` (`eventController.js:210`); `submit-review` → `PENDING_REVIEW` (`:347`); publikasi hanya lewat `PUT /api/admin/events/:id/moderation`. **Bertentangan dengan PRD §3/AC-01.**
- **Fitur:** event valid langsung tayang; event invalid tetap privat dengan daftar alasan.
- **File backend:** `backend/src/controllers/eventController.js`, `backend/src/routes/eventRoutes.js`, `backend/src/utils/eventValidation.js` (baru), `backend/src/utils/eventResponse.js`.
- **File Flutter:** `apps/lib/features/organizer/screens/event_form_screen.dart`, `event_management_screen.dart`, `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`, `apps/lib/services/organizer_events/organizer_event_contract.dart`.
- **Pekerjaan:**
  1. Fungsi validasi server terpusat: judul, jadwal (mulai < selesai, tidak lampau), format & lokasi/link online, kategori event, minimal 1 kategori tiket aktif, konsistensi gratis/berbayar, harga ≥ 0, kuota ≥ 1, sales window valid.
  2. Endpoint baru `POST /api/events/:id/publish`; `POST /api/events/:id/submit-review` dipertahankan sebagai alias perilaku baru.
  3. Valid → `status='PUBLISHED'`, `is_public=true`, `submitted_at` diisi, `review_note` dibersihkan. Tidak valid → tetap `DRAFT`, `is_public=false`, alasan disimpan pada `review_note`.
  4. Edit event `PUBLISHED` memicu validasi ulang; bila jadi invalid → kembali `DRAFT`.
  5. Flutter: tombol "Terbitkan event" menampilkan hasil validasi; hapus ketergantungan pada "menunggu persetujuan Admin".
- **Dependency:** —
- **Kriteria keberhasilan:**
  - K1 Event lengkap → `PUBLISHED`, `is_public=true`, tanpa aksi Admin.
  - K2 Event tanpa kategori tiket → tetap `DRAFT` + daftar alasan.
  - K3 `GET /api/events/public` memuat event valid, tidak memuat event invalid.
  - K4 Edit `PUBLISHED`→invalid → kembali `DRAFT` dan hilang dari publik.
  - K5 Test backend untuk K1–K4 lulus.
  - K6 UI menampilkan alasan validasi.
- **Metode pengujian:** `backend/test/event_auto_publish.test.js` (baru), widget test form, bukti API manual.
- **Larangan:** tidak mengubah RPC `moderate_event`; tidak mengubah route admin; filter publik tetap kompatibel dengan data lama (`APPROVED` tetap dianggap tayang).

### D1-3 — Dua tautan event: `public_url` + staff invitation URL

- **Status baseline:** NOT IMPLEMENTED. `public_url` tidak pernah diisi; UI menampilkan tautan demo (`organizer_event_contract.dart:493-498`); URL undangan memakai header `Origin` (`eventInvitationController.js:72-80`).
- **File backend:** `backend/src/controllers/eventController.js`, `backend/src/utils/eventResponse.js`, `backend/src/controllers/eventInvitationController.js` (hanya pembentuk URL).
- **File Flutter:** `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`, `apps/lib/services/organizer_events/api_organizer_event_repository.dart`, `organizer_event_contract.dart`.
- **Pekerjaan:**
  1. Isi `public_url = {APP_PUBLIC_URL}/e/{eventId}` saat publish dan saat serialize untuk status `PUBLISHED`; `null` bila belum.
  2. Response pembuatan undangan menyertakan `invite_url = {APP_PUBLIC_URL}/invite/{rawToken}` (terpisah dari `registration_url`).
  3. UI: dua panel terpisah — "Tautan Pendaftaran Peserta" & "Tautan Undangan Panitia" — dengan tombol salin dan status disabled saat belum publish.
  4. Hapus pemakaian `registrationUrlIsDemo` dari alur produksi (tetap ada untuk `MOCK_MODE`).
- **Dependency:** D1-2.
- **Kriteria keberhasilan:**
  - K1 Response event `PUBLISHED` memuat `public_url` valid.
  - K2 Event `DRAFT` → `public_url = null`, tombol salin nonaktif.
  - K3 `invite_url` berbeda dari `public_url`.
  - K4 Test backend + widget test dua panel lulus.
- **Metode pengujian:** `backend/test/event_public_links.test.js`; widget test detail event.
- **Larangan:** hanya **menambah** field pada response undangan; tidak mengubah permission/format lama.

### D1-4 — Landing publik + registrasi guest + checkout

- **Status baseline:** PARTIALLY IMPLEMENTED. `RegistrationScreen` ada dan memakai API, tetapi hanya dapat dibuka setelah login; tidak ada halaman event publik; tidak ada alur guest.
- **Fitur:** PRD §6.1/§7 — guest membuka tautan publik, melihat event/kategori/form, mengisi **satu** peserta, membuat order, lanjut pembayaran.
- **File backend:** — (memakai `GET /api/events/:id`, `GET /api/events/:id/ticket-types`, `POST /api/orders` yang sudah ada).
- **File Flutter (baru):** `apps/lib/features/public_event/screens/public_event_screen.dart`, `public_registration_screen.dart`, `apps/lib/services/public_event/public_event_service.dart`.
- **File Flutter (diubah):** `apps/lib/features/registration/screens/registration_screen.dart` (mode publik), `apps/lib/features/events/screens/event_detail_screen.dart` (tombol daftar), `apps/lib/app_router.dart` (dari D1-1).
- **Pekerjaan:**
  1. Halaman publik event: judul, deskripsi, jadwal, lokasi/online, poster, kategori tiket (harga, kuota tersisa, status tersedia, periode penjualan), tombol "Daftar Sekarang".
  2. Registrasi guest: pilih tepat **satu** kategori tiket (radio), data peserta, ringkasan harga + biaya layanan dari **response server**.
  3. `POST /api/orders` dengan idempotency key; simpan `order_access_token` di secure storage (`OrderAccessTokenStore`).
  4. State: loading, error API, event tidak tersedia, kategori habis, sukses.
  5. Tidak ada fallback mock pada mode API.
- **Dependency:** D1-1, D1-2.
- **Kriteria keberhasilan:**
  - K1 Guest membuka `/e/{eventId}` tanpa login dan melihat data event + kategori.
  - K2 Guest memilih 1 tiket, mengisi data valid, dan order tercipta.
  - K3 `order_access_token` tersimpan; dipakai untuk membaca order/tiket.
  - K4 Pemilihan >1 tiket tidak mungkin dari UI dan tetap ditolak server.
  - K5 Event `DRAFT`/`SUSPENDED` tidak dapat didaftari (UI + server).
  - K6 Widget test untuk 4 state (loading/error/empty/success) lulus.
- **Metode pengujian:** widget test; uji manual web + backend lokal; cek `flutter test --dart-define=MOCK_MODE=false`.
- **Larangan:** tidak mengubah kontrak `POST /api/orders`; tidak menyentuh halaman Organizer selain tombol tautan.

### D1-5 — Perbaikan alur order/payment/tiket guest + dynamic attendee data

- **Status baseline:** PARTIALLY IMPLEMENTED. Order & payment nyata, tetapi: (a) `attendee_fields` hanya array nama dan tidak dirender/dikirim; (b) tiket gratis tidak menjamin `token_hash`; (c) status pembayaran di UI belum lengkap; (d) akses tiket pasca-checkout rapuh.
- **File backend:** `backend/src/controllers/orderController.js`, `backend/src/controllers/paymentController.js`, `backend/src/services/emailService.js` (teks/link), `backend/src/utils/validators.js`.
- **File Flutter:** `apps/lib/features/payments/screens/payment_screen.dart`, `payment_status_screen.dart`, `apps/lib/services/order/order_service.dart`, `apps/lib/services/payment/payment_service.dart`, `apps/lib/features/public_event/**`.
- **Pekerjaan:**
  1. Kontrak `attendee_fields` bertipe: `[{ key, label, type: text|textarea|number|date|select|checkbox, required, options[] }]`, kompatibel mundur dengan array string.
  2. Validasi field dinamis saat create/update event dan saat membuat order.
  3. Simpan jawaban ke `attendees.custom_fields` (JSON). Bila RPC belum mendukung, lakukan `UPDATE` dalam transaksi yang sama; bila tidak memungkinkan atomik, catat proposal RPC di `DB_CHANGE_PROPOSAL.md` (tanpa migration).
  4. Pastikan `token_hash` tersedia untuk semua tiket (gratis/berbayar) melalui jalur backfill milik D2 (`ensureTokenHash`/`ensureOrderTokenHashes`).
  5. UI pembayaran: status `PENDING`, `PAID`, `EXPIRED`, `FAILED`, `CANCELLED` dengan aksi tepat; tombol "Lihat E-Ticket" membawa `orderId` agar token akses dipakai.
- **Dependency:** D1-4.
- **Kriteria keberhasilan:**
  - K1 Field dinamis tampil dan wajib divalidasi bila `required`.
  - K2 Jawaban tersimpan di database dan terbaca kembali (diverifikasi bersama D3).
  - K3 Tiket gratis dapat dipindai tanpa membuka halaman tiket dulu.
  - K4 Setiap status pembayaran menampilkan informasi & aksi benar.
  - K5 Test backend kontrak field (valid/invalid) lulus.
- **Metode pengujian:** `backend/test/attendee_dynamic_fields.test.js`; widget test payment states; koordinasi test hash dengan D2.
- **Larangan:** tidak mengubah schema/RPC SQL; tidak mengubah kontrak `order_access_token`.

### Ringkasan D1

| Task | Backend | Flutter | Test |
|---|---|---|---|
| D1-1 | — | router/app/routes | widget router |
| D1-2 | eventController, eventRoutes | form, detail, status | `event_auto_publish.test.js` |
| D1-3 | eventController, eventInvitationController (URL) | event detail | `event_public_links.test.js` |
| D1-4 | — (pakai API ada) | public_event/** | widget 6 skenario |
| D1-5 | orderController, paymentController, emailService | payment screens, form builder | `attendee_dynamic_fields.test.js` |

---

## D. Developer 2 — Ticketing, Staff Workspace, Check-in

**Domain:** e-ticket QR nyata, invitation & membership staff, scanner kamera, validasi & check-in, riwayat.
**Kepemilikan tunggal:** `backend/src/controllers/checkInController.js`, `ticketController.js`, `eventInvitationController.js`; `apps/lib/services/check_in/**`, `services/scanner/**`, `services/ticket/**`, `services/organizer_membership/**`; `apps/pubspec.yaml`.
**Total:** 5 task (D2-1 … D2-5).

### D2-0 — Perubahan shared file di awal gelombang (sinkronisasi dependensi)

- **Alasan:** D2 membutuhkan dua dependency baru (`qr_flutter`, `mobile_scanner`) pada `apps/pubspec.yaml` yang **dimiliki D2**, sementara D1 dan D3 juga menjalankan `flutter test`/`flutter analyze` pada branch masing-masing. Tanpa perubahan ini lebih dulu, branch D1/D3 tidak dapat menjalankan perintah verifikasi yang sama.
- **Pekerjaan:**
  1. Tambahkan `qr_flutter` dan `mobile_scanner` ke `apps/pubspec.yaml` beserta entri `pubspec.lock`.
  2. Jalankan `flutter pub get` dan pastikan `flutter analyze` + `flutter test` tetap PASS **tanpa** perubahan perilaku.
  3. Commit sebagai PR terpisah `[Tahap 2][D2-0] dependency QR & kamera` **sebelum** D1-4/D1-5, D2-1, dan D3-1 dimulai.
  4. Umumkan hasilnya ke D1 & D3 (tanggal merge + commit hash).
- **Dependency:** — (dikerjakan paling awal, hari pertama W1)
- **Kriteria keberhasilan:**
  - K1 `flutter pub get` sukses pada tiga branch setelah rebase.
  - K2 `flutter analyze` tetap 0 issue, `flutter test` tetap 188 PASS.
  - K3 Tidak ada perubahan kode aplikasi pada PR ini.
- **Metode pengujian:** `flutter analyze`, `flutter test`, `flutter pub deps`.
- **Larangan:** tidak menambah dependency lain di luar dua paket tersebut tanpa persetujuan pemilik proyek.

### D2-1 — QR e-ticket nyata + data tiket pribadi

- **Status baseline:** PARTIALLY IMPLEMENTED. `QrTicketDisplay` menggambar pola pseudo-QR (`qr_ticket_display.dart:41-73`, painter `:140-213`); `pubspec.yaml` tidak memuat library QR; `qrService.js` backend sudah **dihapus** (dead code, digantikan `ticketTokenService.js`). Token tiket sebenarnya sudah tersedia dari `GET /api/tickets/my-tickets`.
- **Fitur:** AC-06 — e-ticket berisi QR yang dapat dipindai, tanpa membocorkan PII.
- **File backend:** `backend/src/controllers/ticketController.js`, `backend/src/services/ticketTokenService.js`.
- **File Flutter:** `apps/pubspec.yaml` (tambah `qr_flutter`), `qr_ticket_display.dart`, `ticket_detail_screen.dart`, `ticket_list_screen.dart`, `services/ticket/ticket_service.dart`, `models/ticket/ticket_model.dart`.
- **Pekerjaan:**
  1. Ganti painter pseudo-QR dengan renderer QR dari token tiket asli; token hanya di memori/secure storage, tidak di log.
  2. Verifikasi `GET /api/tickets/my-tickets` dan `/:id` mengembalikan `token` hanya untuk pemilik/admin.
  3. Backfill `token_hash` untuk tiket gratis saat order dibuat atau saat pertama dibaca; test regresi scan.
  4. Desain tiket default (event, peserta, kategori, jadwal, lokasi, kode tiket, QR) responsif Android & Web.
  5. State: tidak ditemukan, akses ditolak, belum aktif (unpaid), checked-in.
- **Dependency:** —
- **Kriteria keberhasilan:**
  - K1 QR ter-render dan dapat dipindai (dibuktikan pada D2-3/G2).
  - K2 Payload QR hanya token/ID tiket, tanpa email/telepon/harga.
  - K3 Tiket gratis & berbayar sama-sama dapat dipindai tanpa langkah tambahan.
  - K4 Akses tiket pihak lain ditolak (403/404).
  - K5 Widget test QR + test backend kebocoran token.
- **Metode pengujian:** widget test; `backend/test/ticket_token.test.js`; uji manual scan.
- **Larangan:** tidak menghapus `qr_code_data` legacy; tidak mengirim `token_hash` ke klien.

### D2-2 — Invitation staff end-to-end + membership self + routing workspace

- **Status baseline:** PARTIALLY IMPLEMENTED. Backend invitation/membership nyata; UI team memakai mock (`organizer_membership_service.dart:79-171`); tidak ada endpoint "membership saya"; staff tidak diarahkan ke workspace.
- **Fitur:** AC-08, PRD §6.2 — undangan per event, permission granular, expiry, revoke.
- **File backend:** `eventInvitationController.js`, `routes/invitationsRoutes.js`, `routes/eventRoutes.js` (tambah `GET /me/memberships` — koordinasi D1), `eventController.js` (bagian member — koordinasi D1).
- **File Flutter:** `services/organizer_membership/organizer_membership_service.dart` (rewrite ke API), `features/organizer/membership/team_management_screen.dart`, `features/organizer/screens/staff_management_screen.dart`, `features/staff/screens/staff_dashboard_screen.dart`, `features/staff/screens/accept_invitation_screen.dart` (baru).
- **Pekerjaan:**
  1. UI team via API: daftar member, undang (email + permission + expiry), cabut, ubah permission, keluarkan.
  2. Endpoint baru `GET /api/me/memberships` → `{ event_id, event_title, status, permissions[], expires_at }`.
  3. Endpoint publik `GET /api/invitations/:token` (data event minimal, tanpa PII) untuk halaman penerimaan.
  4. Halaman `/invite/:token`: login → cocokkan email → sukses → `/staff/:eventId`.
  5. Workspace staff: daftar event diikuti + tombol scanner/riwayat sesuai permission.
  6. `ASSIST_REGISTRATION` tidak ditawarkan pada UI undangan.
- **Dependency:** D1-1 (route), D1-3 (URL).
- **Kriteria keberhasilan:**
  - K1 Undangan tercatat di DB dengan token hash.
  - K2 Hanya email cocok yang dapat menerima.
  - K3 Expired/revoked ditolak.
  - K4 Permission tersalin ke `event_member_permissions`.
  - K5 Membership muncul di `/api/me/memberships`; staff diarahkan sesuai event.
  - K6 Test backend positive/negative + widget test team screen lulus.
- **Metode pengujian:** perluasan test invitation; widget test; bukti UI.
- **Larangan:** tidak mengubah skema permission; tidak menambah permission baru.

### D2-3 — Scanner kamera + validasi tiket (online, MVP)

- **Status baseline:** PARTIALLY IMPLEMENTED. `ScannerScreen` = input manual + tombol simulasi, tanpa kamera, **dan menawarkan mode offline** (`scanner_screen.dart:96-108, 213-226`). `OrganizerScannerScreen` berjudul "Mock".
- **Fitur:** AC-06/§9 — Staff memindai QR, sistem memvalidasi (valid, sudah dipakai, event salah, belum dibayar, tidak berhak).
- **File backend:** `backend/src/controllers/checkInController.js`, `backend/src/controllers/ticketController.js`.
- **File Flutter:** `apps/pubspec.yaml` (`mobile_scanner`), `features/scanner/screens/scanner_screen.dart`, `scan_result_screen.dart`, `features/scanner/widgets/scanner_placeholder.dart` → `camera_scanner_view.dart`, `services/scanner/scanner_service.dart`, `features/organizer/operations/organizer_scanner_screen.dart`.
- **Pekerjaan:**
  1. Integrasi kamera (Android + Web) + permission handling + fallback input manual.
  2. Pindai → `POST /api/tickets/validate` (atau `/check-ins`) dengan event dari membership.
  3. Tampilkan hasil: `VALID`, `ALREADY_USED`, `WRONG_EVENT`, `PAYMENT_REQUIRED`, `INVALID` + data peserta minimum.
  4. Hapus tombol simulasi & toggle offline dari alur MVP; hapus `eventId` hardcoded `evt-1001`.
  5. Cegah double-submit (lock) saat hasil masih diproses.
- **Dependency:** D2-1, D2-2.
- **Kriteria keberhasilan:**
  - K1 Kamera terbuka dan mengenali QR tiket.
  - K2 Hasil validasi sesuai backend untuk kelima hasil.
  - K3 Tidak ada mode offline/tombol simulasi pada alur MVP.
  - K4 Event berasal dari membership user.
  - K5 Widget test scanner lulus (mock platform channel).
- **Metode pengujian:** widget test; uji manual Android & Web dengan status PASS/NOT RUN per platform.
- **Larangan:** tidak menambah alur offline; route `/check-ins/sync` backend tidak dihapus, cukup tidak dipakai.

### D2-4 — Check-in tunggal, riwayat, dan konsolidasi verifikasi

- **Status baseline:** IMPLEMENTED BUT NOT VERIFIED + bug integrasi. Check-in atomik ada; `/tickets/verify` menandai `used` tanpa membuat `check_ins` (`ticketController.js:129-153`); Flutter memanggil path salah (`check_in_service.dart:116`).
- **Fitur:** AC-06/§9 — check-in satu kali, anti-duplikasi, riwayat.
- **File backend:** `checkInController.js`, `ticketController.js` (`services/qrService.js` sudah **dihapus** sebagai dead code; token QR memakai `services/ticketTokenService.js`).
- **File Flutter:** `services/check_in/check_in_service.dart`, `providers/check_in_provider.dart`, `features/check_in/screens/check_in_screen.dart`, `check_in_history_screen.dart`.
- **Pekerjaan:**
  1. `POST /api/tickets/verify` mendelegasikan ke `recordCheckIn` agar selalu membuat `check_ins` (idempotent untuk duplikat).
  2. Perbaiki path riwayat ke `GET /api/check-ins/events/:eventId/check-ins`.
  3. `CheckInService` memakai API pada mode API; mock hanya di `MOCK_MODE`.
  4. Riwayat menampilkan peserta, waktu, petugas, hasil scan; filter tanggal.
  5. Dua permintaan bersamaan → satu sukses, satu `ALREADY_USED` (test).
- **Dependency:** D2-3.
- **Kriteria keberhasilan:**
  - K1 Scan valid membuat tepat satu `check_ins` + satu `scan_logs`.
  - K2 Scan ulang `ALREADY_USED` tanpa baris baru.
  - K3 `verify` tidak mengubah status tanpa `check_ins`.
  - K4 Riwayat memuat data nyata dan dapat difilter.
  - K5 Test konkurensi backend lulus; widget test riwayat lulus.
- **Metode pengujian:** `npm test` + perluasan; widget test; uji manual.
- **Larangan:** tidak mengubah skema/constraint; tidak menambah endpoint lain.

### D2-5 — Test regresi tiket–scan & dokumentasi endpoint

- **Status baseline:** PARTIALLY IMPLEMENTED. Alur E2E tiket→scan belum tercakup; `backend/README.md` belum memuat seluruh endpoint tiket/check-in.
- **File backend:** `backend/test/**` (baru/perluasan), `backend/README.md`.
- **File Flutter:** `apps/test/**` (baru/perluasan).
- **Pekerjaan:**
  1. Regresi: tiket gratis & berbayar → scan → check-in → duplikat → riwayat.
  2. Negatif: tiket event lain, tiket belum dibayar, staff tanpa permission, token palsu/kedaluwarsa.
  3. Perbarui `backend/README.md` untuk endpoint tiket/check-in/invitation/membership.
  4. Pastikan tidak ada mock aktif pada `MOCK_MODE=false` untuk modul D2.
- **Dependency:** D2-1..D2-4.
- **Kriteria keberhasilan:**
  - K1 Minimal 8 skenario regresi lulus.
  - K2 README backend sesuai route aktual.
  - K3 `flutter test --dart-define=MOCK_MODE=false` lulus untuk modul D2.
- **Metode pengujian:** perintah test lengkap.
- **Larangan:** tidak mengubah perilaku produk; hanya test & dokumentasi.

### Ringkasan D2

| Task | Backend | Flutter | Test |
|---|---|---|---|
| D2-0 | — | `pubspec.yaml` (+ `pubspec.lock`) | `pub get` + analyze + test |
| D2-1 | ticketController, ticketTokenService | pubspec (qr_flutter), qr_ticket_display, ticket detail | widget + backend token |
| D2-2 | eventInvitationController, invitationsRoutes, memberships | membership service/screens, staff workspace, accept invitation | backend invitation + widget |
| D2-3 | checkInController/ticketController (validate) | pubspec (mobile_scanner), scanner screens | widget scanner |
| D2-4 | checkInController, ticketController (verify) | check_in service/screens | backend concurrency + widget |
| D2-5 | test + README | test | regresi 8 skenario |

> **Catatan urutan:** D2-0 harus di-merge **sebelum** D2-1 dan sebelum D1-4/D1-5/D3-1 mulai, agar ketiga branch dapat menjalankan `pub get` + `flutter test` dengan dependency yang sama.

---

## E. Developer 3 — Attendee, Export, Order Monitoring, Admin Platform

**Domain:** data peserta & export, monitoring order/pembayaran organizer, revenue organizer, konsol Admin (akun, audit, settings, revenue, paket, langganan, dashboard, monitoring event, laporan), notifikasi Organizer.
**Kepemilikan tunggal:** `backend/src/app.js`; `adminController.js`, `planController.js`, `subscriptionController.js`, `revenueController.js`, `reportController.js`, `notificationController.js`, `eventMetricsController.js` (bagian admin); `backend/src/utils/auditLog.js` (baru); `apps/lib/services/admin/**`, `services/organizer_operations/**`, `services/organizer_plans/**`, `services/organizer_support/**`, `services/organizer_notifications/**`; layar Admin & layar operasional Organizer.
**Total:** 5 task (D3-1 … D3-5).

### D3-1 — Attendee data nyata: paid-first, nomor registrasi, detail, permission

- **Status baseline:** PARTIALLY IMPLEMENTED. Endpoint hanya membaca `tickets` (`checkInController.js:230-265`), urut `purchased_at DESC`, tanpa `order_number`/status payment; UI memakai `OrganizerOperationsRepository` in-memory dengan event default `evt-1001`; permission memakai `SCAN_TICKET`.
- **Fitur:** AC-09, PRD §7 — daftar peserta prioritas pembayaran berhasil, urut nomor pendaftaran asli; detail peserta; akses sesuai permission.
- **File backend:** `backend/src/controllers/checkInController.js` (bagian `listEventAttendees` — **koordinasi tertulis dengan D2**), `backend/src/routes/checkInRoutes.js`.
- **File Flutter:** `organizer_operations_repository.dart` (rewrite data peserta ke API; mock hanya `MOCK_MODE`), `features/organizer/screens/attendee_list_screen.dart`, `features/organizer/operations/organizer_attendee_detail_screen.dart`.
- **Pekerjaan:**
  1. Sumber data: `order_items`/`attendees`/`event_orders`/`order_payments` agar order pending/expired juga terlihat dengan status jelas.
  2. Field respons tambahan: `order_number`, `payment_status`, `order_status`, `checked_in_at`, `custom_fields`.
  3. Urutan: `PAID` dulu, lalu `order_number` menaik; filter status/kategori/pencarian di server.
  4. Permission daftar & detail peserta memakai `VIEW_PARTICIPANTS`; tanpa permission → 403.
  5. UI: hapus `eventId` default `evt-1001`; event dipilih dari daftar event user; konteks membership nyata (bukan `OrganizerMembershipContext.owner` hardcoded).
  6. Sembunyikan tombol "Registrasi Terbantu" (non-MVP) tanpa menghapus layarnya.
- **Dependency:** —
- **Kriteria keberhasilan:**
  - K1 Response memuat `order_number` & `payment_status` untuk setiap peserta.
  - K2 Order `PENDING_PAYMENT` muncul setelah `PAID`, tidak tercampur.
  - K3 Urutan dalam kelompok sama = `order_number` menaik.
  - K4 Staff tanpa `VIEW_PARTICIPANTS` → 403.
  - K5 UI memakai data nyata; tidak ada `evt-1001` pada alur produksi.
  - K6 Test backend + widget test lulus.
- **Metode pengujian:** `backend/test/event_attendees_order.test.js`; widget test; bukti API.
- **Larangan:** tidak menghapus field lama; perubahan `checkInController` dibatasi bagian attendee dan dikoordinasikan dengan D2.

### D3-2 — Export CSV, order/payment monitoring, revenue & laporan Organizer

- **Status baseline:** PARTIALLY IMPLEMENTED. Export hanya CSV mock (`organizer_operations_repository.dart:776-813`); tidak ada endpoint order per event; `organizer_report_screen.dart:30-31` memakai repository mock dengan harga hardcoded.
- **File backend:** `orderController.js` (query per event), `routes/orderRoutes.js`, endpoint export di `checkInRoutes.js` (koordinasi D2), `revenueController.js`.
- **File Flutter:** `organizer_operations_repository.dart`, `features/organizer/operations/organizer_report_screen.dart`, `features/organizer/screens/organizer_order_list_screen.dart` (baru).
- **Pekerjaan:**
  1. `GET /api/events/:id/orders` (owner atau `VIEW_ORDERS`): order + payment + peserta, filter status/tanggal, pagination.
  2. `GET /api/events/:id/attendees/export` → CSV dengan kolom setara tampilan, urutan identik D3-1.
  3. CSV escaping (kutip, koma, newline, formula injection `= + - @`).
  4. Layar order Organizer: status, nominal, metode, waktu, aksi detail.
  5. Laporan revenue Organizer memakai `/api/events/:id/summary`, `/api/revenue/me`, `/api/organizer/overview`; hapus harga hardcoded.
- **Dependency:** D3-1.
- **Kriteria keberhasilan:**
  - K1 Order per event tampil dengan status nyata.
  - K2 CSV identik dengan layar (jumlah & urutan), aman dari formula injection.
  - K3 Export memerlukan `EXPORT_PARTICIPANTS`.
  - K4 Angka revenue/laporan berasal dari API.
  - K5 Test backend export/urutan/escaping + widget test lulus.
- **Metode pengujian:** `event_export.test.js`; widget test; bukti file CSV.
- **Larangan:** tidak mengubah kontrak `GET /api/orders`; endpoint baru terpisah.

### D3-3 — Admin: akun + audit log + platform settings

- **Status baseline:** NOT IMPLEMENTED untuk audit/settings; akun PARTIALLY IMPLEMENTED (suspend tanpa alasan/audit). `audit_logs`, `platform_settings`, `platform_setting_history` belum dipakai backend.
- **File backend:** `adminController.js`, `auditLogController.js` (baru), `platformSettingsController.js` (baru), `routes/adminRoutes.js`, `utils/auditLog.js` (baru), `app.js`.
- **File Flutter:** `services/admin/admin_audit_log_service.dart` (rewrite API), `services/admin/admin_settings_service.dart` (rewrite API), `features/admin/screens/account_management_screen.dart`, `audit_log_screen.dart`, `admin_settings_screen.dart`.
- **Pekerjaan:**
  1. Util `writeAuditLog({ actorId, actorName, actorRole, action, entityType, entityId, reason, details, metadata })`.
  2. Suspend/reaktivasi akun **wajib alasan** + menulis audit.
  3. `GET /api/admin/accounts` diperkaya metrik ringkas (jumlah event, jumlah order) dengan query agregat.
  4. `GET /api/admin/audit-logs` dengan filter aktor/aksi/entity/tanggal + pagination.
  5. `GET /api/admin/settings` dan `PUT /api/admin/settings/:key` + history setiap perubahan; fee/komisi CONFIRMED read-only sampai C-01 diputuskan.
  6. UI: hapus `_mockAccounts` (mock hanya `MOCK_MODE`); audit & settings membaca API.
- **Dependency:** —
- **Kriteria keberhasilan:**
  - K1 Menonaktifkan akun tanpa alasan → 400.
  - K2 Setelah suspend, `audit_logs` bertambah dengan aktor & alasan.
  - K3 Audit log dapat difilter & dipaginasi.
  - K4 Perubahan setting menulis `platform_setting_history`.
  - K5 Fee/komisi tidak dapat diubah selama C-01 terbuka.
  - K6 Angka 2.500 tidak lagi muncul di UI.
  - K7 Test backend 4 skenario + widget test lulus.
- **Metode pengujian:** `admin_audit_settings.test.js`; widget test; bukti baris audit.
- **Larangan:** tidak mengubah skema; tidak membuat endpoint tanpa `allowRoles('admin')`.

### D3-4 — Admin dashboard nyata, revenue/transaksi, paket, langganan

- **Status baseline:** PARTIALLY IMPLEMENTED. Backend revenue/plan ada; dashboard memakai angka hardcoded (`admin_dashboard_screen.dart:38-43, 643-676`); service revenue/paket/langganan in-memory; tidak ada endpoint daftar langganan Admin.
- **File backend:** `adminOverviewController.js` (baru) → `GET /api/admin/overview`; `subscriptionController.js` (tambah `GET /api/admin/subscriptions`); `planController.js` (verifikasi kontrak admin); `app.js`.
- **File Flutter:** `services/admin/admin_revenue_service.dart`, `admin_package_service.dart`, `admin_subscription_service.dart` (rewrite API), `features/admin/screens/admin_dashboard_screen.dart`, `transaction_revenue_screen.dart`, `package_management_screen.dart`, `subscription_management_screen.dart`.
- **Pekerjaan:**
  1. `GET /api/admin/overview?from&to` → event per status, organizer aktif, order, tiket terjual, peserta, check-in, gross/commission/fee/net dari `platform_transactions`.
  2. Dashboard: semua kartu & grafik dari API; tidak ada angka hardcoded.
  3. Revenue Admin: daftar transaksi + ringkasan + filter periode.
  4. Paket: CRUD via `/api/plans/admin*` + validasi form.
  5. Langganan: daftar via endpoint baru, detail, status; perpanjangan hanya bila kontrak tersedia (C-03) — bila tidak, read-only + status BLOCKED.
- **Dependency:** D3-3 (util audit).
- **Kriteria keberhasilan:**
  - K1 Kartu dashboard = nilai API.
  - K2 Tidak ada konstanta angka pada `admin_dashboard_screen.dart`.
  - K3 Transaksi & ringkasan dari `platform_transactions`.
  - K4 Perubahan paket menulis audit log.
  - K5 Daftar langganan dari API; aksi tak didukung ditandai.
  - K6 Test backend + widget test lulus.
- **Metode pengujian:** `admin_overview.test.js`; widget test; bukti angka API.
- **Larangan:** tidak mengubah model subscription; tidak menjanjikan perpanjangan bila belum diputuskan.

### D3-5 — Admin event monitoring/suspend, laporan, notifikasi Organizer, integrasi Tahap 2

- **Status baseline:** PARTIALLY IMPLEMENTED. Moderasi masih approval (`eventMetricsController.js:119-158`); UI moderasi default `pendingReview`; notifikasi Organizer selalu mock; laporan Admin sudah API.
- **File backend:** `eventMetricsController.js`, `routes/adminRoutes.js`, `notificationController.js`, `app.js`.
- **File Flutter:** `features/admin/screens/event_moderation_screen.dart`, `services/organizer_notifications/organizer_notifications_service.dart`, `features/organizer/shell/organizer_shell.dart`, `features/admin/screens/report_management_screen.dart`, `services/organizer_support/organizer_support_service.dart`.
- **Pekerjaan:**
  1. Event monitoring: daftar semua event + status + filter; aksi hanya **Suspend** dan **Pulihkan** dengan alasan wajib; tombol approve/reject dihapus untuk event baru (endpoint lama tetap untuk data lama).
  2. Event `SUSPENDED` tidak muncul publik dan menolak order baru (test).
  3. Notifikasi Organizer selalu API pada mode API; unread count dari API; shell tidak memakai mock.
  4. Laporan: alur Admin (status/priority/reply/internal note) diuji dengan data nyata; wrapper Organizer memakai `ReportService` API.
  5. Integrasi akhir Tahap 2: jalankan seluruh perintah verifikasi, catat PASS/FAIL/NOT RUN, siapkan bahan gate G2.
- **Dependency:** D1-3, D2-2, D3-1..D3-4.
- **Kriteria keberhasilan:**
  - K1 Suspend tanpa alasan → 400; dengan alasan → `SUSPENDED` + audit row.
  - K2 Event suspended tidak muncul di `/api/events/public`; order baru ditolak.
  - K3 Notifikasi Organizer dari API; unread konsisten.
  - K4 Alur laporan Admin & Organizer berjalan pada data nyata.
  - K5 Ringkasan verifikasi G2 tersedia dengan bukti.
- **Metode pengujian:** test backend moderation + notifikasi; widget test; laporan integrasi.
- **Larangan:** tidak menghapus RPC `moderate_event`; tidak mengubah data lama; tidak mengklaim PASS tanpa bukti.

### Ringkasan D3

| Task | Backend | Flutter | Test |
|---|---|---|---|
| D3-1 | checkInController (attendee) | attendee list/detail, operations repository | `event_attendees_order.test.js` |
| D3-2 | orderController (per event), export, revenue | order list, report, export | `event_export.test.js` |
| D3-3 | adminController, auditLogController, platformSettingsController, auditLog util | account/audit/settings screens | `admin_audit_settings.test.js` |
| D3-4 | adminOverviewController, subscription admin list | dashboard, revenue, package, subscription screens | `admin_overview.test.js` |
| D3-5 | eventMetricsController, notificationController | moderation, notifications, reports | admin moderation + notifikasi |

---

## F. Pekerjaan non-MVP yang dinonaktifkan (bukan dihapus)

| Item | Lokasi | Tindakan Tahap 2 | Status |
|---|---|---|---|
| Assisted registration | `features/organizer/operations/assisted_registration_screen.dart`, `OrganizerOperationsRepository.createAssistedRegistration` | Sembunyikan tombol/menu; jangan hapus file | NO LONGER REQUIRED (MVP) |
| Offline scanner | `scanner_screen.dart` toggle offline, `CheckInService.syncOfflineCheckIns`, `POST /api/check-ins/sync` | Hapus dari UI MVP; route backend dibiarkan | NO LONGER REQUIRED (MVP) |
| Payment gateway riil | — | Tidak dikerjakan | NO LONGER REQUIRED (MVP) |
| Upload file brosur | `poster_url` | Tetap URL; upload ditunda | BLOCKED (butuh keputusan storage) |
| Template tiket pilihan | — | Desain default saja; kolom template = proposal DB | BLOCKED (butuh keputusan produk/DB) |

---

## G. Matriks verifikasi Tahap 2 (dijalankan di akhir setiap task dan sebelum G2)

| Perintah | Lokasi | Frekuensi | Kriteria |
|---|---|---|---|
| `npm test` | `backend/` | Setiap task & sebelum G2 | PASS, 0 gagal |
| `npm run check` | `backend/` | Setiap task | PASS |
| `npm run format:check` | `backend/` | Setiap PR | PASS |
| `npm run test:sync-config` | `backend/` | Sebelum G2 | PASS |
| `flutter analyze` | `apps/` | Setiap task | 0 issue |
| `flutter test` | `apps/` | Setiap task | PASS |
| `flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | `apps/` | Sebelum G2 | PASS |
| `Select-String -Pattern "mock|in-memory"` pada layar in-scope | `apps/lib` | Sebelum G2 | Tidak ada mock pada API mode |
| Uji manual alur per role | Web/Android | Sebelum G2 | Dicatat PASS/NOT RUN |

---

## H. Gate penyelesaian Tahap 2 (G2)

Seluruh butir wajib lulus dengan bukti:

1. **G2-1 Auto-publish** — event valid `PUBLISHED` tanpa Admin (D1-2).
2. **G2-2 Event invalid privat** — tidak muncul publik, alasan tersedia (D1-2).
3. **G2-3 Dua tautan** — `public_url` dan `invite_url` berbeda dan berfungsi (D1-3).
4. **G2-4 Alur guest lengkap** — buka link → daftar → order → bayar → tiket (D1-4/D1-5).
5. **G2-5 QR nyata** — tiket menampilkan QR yang dapat dipindai (D2-1).
6. **G2-6 Staff E2E** — undang → terima → workspace → scanner sesuai permission (D2-2).
7. **G2-7 Check-in** — validasi, anti-duplikasi, riwayat (D2-3/D2-4).
8. **G2-8 Peserta & export** — paid-first + nomor registrasi; CSV identik (D3-1/D3-2).
9. **G2-9 Admin konsol** — akun+audit, settings, revenue, paket, langganan, monitoring, laporan dari API (D3-3/D3-4/D3-5).
10. **G2-10 Bebas mock** — tidak ada mock aktif pada layar in-scope di `MOCK_MODE=false`.
11. **G2-11 Kualitas otomatis** — seluruh perintah §G PASS.
12. **G2-12 Dokumentasi** — `INTEGRATION_CONTRACT.md` & `FILE_OWNERSHIP.md` sesuai realisasi; README backend diperbarui.
13. **G2-13 Tidak ada regresi** — 89 test backend lama + 188 test Flutter lama tetap lulus (atau kegagalan dijelaskan & diperbaiki).

Bila satu butir gagal: Tahap 3 tidak boleh dimulai untuk butir yang bergantung padanya; laporkan sebagai `FAIL`/`BLOCKED` dengan alasan.







