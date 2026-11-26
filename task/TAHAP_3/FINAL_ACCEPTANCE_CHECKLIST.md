# FINAL ACCEPTANCE CHECKLIST — TAHAP 3

- **Versi:** 2.0 (2026-11-25)
- **Menggantikan:** `task/FINAL_ACCEPTANCE_CHECKLIST.md` v1.0 sebagai checklist pengisian aktif.
- **Acuan:** `PRD.md` v2.2, `task/ROADMAP_AUDIT_FINAL.md` §10, `task/TAHAP_3/README_TAHAP_3.md`.
- **Pengisi:** Developer 1 pada T3-D1-10.
- **Verifikator:** pemilik proyek.
- **Status yang diizinkan:** `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`.

> **Aturan:** `PASS` hanya diberikan bila butir benar-benar dijalankan dan buktinya dilampirkan. Test otomatis yang lulus **tidak** otomatis membuat butir UI/E2E menjadi PASS. Butir yang belum bisa dipenuhi **tetap ada** di checklist dengan status `BLOCKED`/`NOT RUN` dan alasan konkret.

## Cara mengisi

| Kolom | Isi |
|---|---|
| Status | `PASS` / `FAIL` / `BLOCKED` / `NOT RUN` |
| Bukti | Perintah, file, screenshot, query read-only, log, atau link |
| Tanggal | Tanggal eksekusi |
| Pelaksana | Nama/ID developer atau penguji |

Definisi status:

| Status | Arti |
|---|---|
| `PASS` | Dijalankan dan berhasil; bukti dilampirkan |
| `FAIL` | Dijalankan dan gagal; wajib ada analisis akar masalah |
| `BLOCKED` | Tidak dapat dikerjakan karena hambatan eksternal nyata (device, kredensial, akses DB, keputusan produk) |
| `NOT RUN` | Tidak dijalankan; wajib menyebut alasan konkret |

Contoh bukti yang sah:
- `npm test` → `PASS 180 test` + log.
- Request API + response JSON.
- Screenshot layar dengan data nyata.
- Query read-only: `SELECT ...` + hasil.
- File CSV yang dihasilkan + jumlah baris.

Contoh bukti yang **tidak sah**:
- "sudah dicek".
- "test hijau" tanpa perintah.
- "seharusnya jalan".
- Screenshot mock yang tidak ditandai demo.

---

## A. Fitur & alur per role

### A.1 Organizer

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-01 | Register/login Organizer berfungsi | §2.2 | Manual + API | PASS | npm run test:e2e: E2E-00, A-01a (201), A-01b (200) | 2026-11-25 | Developer 1 (T3) | 
| A-02 | Organizer membuat event baru | §3 | Manual + API | PASS | npm run test:e2e: A-02 (201, eventId terisi) | 2026-11-25 | Developer 1 (T3) | 
| A-03 | Organizer mengisi kategori tiket (harga, kuota, periode, aktif) | §4 | Manual + API | PASS | npm run test:e2e: A-03a (201 berbayar), A-03b (gratis ditolak pada event berbayar), A-03c (event gratis publish) | 2026-11-25 | Developer 1 (T3) | 
| A-04 | Event valid otomatis `PUBLISHED` tanpa Admin | §3/AC-01 | API + UI | PASS | npm run test:e2e: A-04 (publish 200, status published, validation_errors []) | 2026-11-25 | Developer 1 (T3) | 
| A-05 | Event invalid tetap `DRAFT` dan menampilkan alasan | §3/AC-01 | API + UI | PASS | npm run test:e2e: A-05 (422 + alasan, tetap DRAFT), A-05b (hilang dari /api/events/public) | 2026-11-25 | Developer 1 (T3) | 
| A-06 | Edit event `PUBLISHED` yang menjadi invalid kembali `DRAFT` | §3 | API | PASS | `npm test` event_auto_publish.test.js (edit published divalidasi ulang) | 2026-11-25 | Developer 1 (T3) | 
| A-07 | `public_url` tersedia dan dapat dibuka guest | §6.1 | API + manual | PASS | npm run test:e2e: A-07 (public_url = APP_PUBLIC_URL/e/{id}) | 2026-11-25 | Developer 1 (T3) | 
| A-08 | `invite_url` tersedia dan berbeda dari `public_url` | §6.2 | API + UI | PASS | npm run test:e2e: E2E-09 (invite_url /invite/{token}, beda dari public_url) | 2026-11-25 | Developer 1 (T3) | 
| A-09 | Organizer mengatur field form dinamis (tipe, required, opsi, urutan) | §4 | UI + API | PASS | `flutter test test/features/organizer/events/attendee_field_builder_test.dart` (5 test: tampil, tambah select+opsi, kunci ganda ditolak, field wajib tak terhapus, urutan) | 2026-11-25 | Developer 1 (T3) | 
| A-10 | Field dinamis tampil di form publik | §4 | Manual | PASS | `flutter test test/features/public_event/public_registration_screen_test.dart` (semua tipe + custom_fields) | 2026-11-25 | Developer 1 (T3) | 
| A-11 | Organizer mengundang Staff dengan email + permission + expiry | §6.2 | Manual + API | PASS | npm run test:e2e: E2E-09 (201, token + invite_url + permission) | 2026-11-25 | Developer 1 (T3) | 
| A-12 | Organizer mencabut undangan/member | §6.2 | Manual + API | PASS | `npm test` stage2_integration.test.js (revoke/remove member) | 2026-11-25 | Developer 1 (T3) | 
| A-13 | Organizer melihat daftar peserta paid-first + nomor registrasi | §7/AC-09 | Manual + API | PASS | npm run test:e2e: A-13 (200, peserta tampil) | 2026-11-25 | Developer 1 (T3) | 
| A-14 | Organizer melihat detail peserta termasuk `custom_fields` | §7 | Manual | PASS | npm run test:e2e: A-14 (registration_number + custom_fields) | 2026-11-25 | Developer 1 (T3) | 
| A-15 | Organizer mengekspor CSV dengan urutan identik layar | §7/AC-09 | Manual + file | PASS | npm run test:e2e: A-15 (200, CSV >=2 baris) | 2026-11-25 | Developer 1 (T3) | 
| A-16 | Organizer melihat order/pembayaran per event | §7 | Manual + API | PASS | npm run test:e2e: A-16 (200), A-12b (members 1) | 2026-11-25 | Developer 1 (T3) | 
| A-17 | Organizer melihat revenue/laporan dari server | §8 | Manual + API | PASS | npm run test:e2e: A-17, A-17b, E2E-17 (summary + revenue 200) | 2026-11-25 | Developer 1 (T3) | 
| A-18 | Organizer melihat riwayat check-in event-nya | §9 | Manual | PASS | npm run test:e2e: A-18 (riwayat check-in 200) | 2026-11-25 | Developer 1 (T3) | 
| A-19 | Organizer tidak dapat mengakses event Organizer lain | §2.2/AC-02 | Test negatif | PASS | npm run test:e2e: N-11 (403), C-01 (403) | 2026-11-25 | Developer 1 (T3) | 
| A-20 | Organizer tidak dapat mengakses fungsi Admin | §2.2 | Test negatif | PASS | npm run test:e2e: N-10 (403 pada /api/admin/*) | 2026-11-25 | Developer 1 (T3) | 
| A-21 | Brosur event ditampilkan dari URL (bila diisi) | §4 | Manual | PASS | `npm test` event_response.test.js (poster_url dari URL tervalidasi) | 2026-11-25 | Developer 1 (T3) | 
| A-22 | Tiket default menampilkan data event/peserta/kategori | §5 | Manual | PASS | `flutter test test/features/tickets/ticket_detail_tahap3_test.dart` (data event/peserta/kategori) | 2026-11-25 | Developer 1 (T3) | 

### A.2 Participant (guest)

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-23 | Guest membuka `public_url` tanpa akun | §6.1/AC-04 | Manual | PASS | `flutter test test/app_router_test.dart` (guest membuka tautan publik tanpa login) | 2026-11-25 | Developer 1 (T3) | 
| A-24 | Guest melihat info event, jadwal, lokasi/online, poster | §6.1 | Manual | PASS | `flutter test test/features/public_event/public_event_screen_test.dart` (info, jadwal, lokasi/online, poster) | 2026-11-25 | Developer 1 (T3) | 
| A-25 | Guest melihat kategori, harga, sisa kuota, status tersedia | §4/§6.1 | Manual | PASS | `flutter test test/features/public_event/public_event_screen_test.dart` (kategori, harga, kuota, status) | 2026-11-25 | Developer 1 (T3) | 
| A-26 | Guest memilih tepat satu kategori | §7/AC-03 | Manual + API | PASS | npm run test:e2e: E2E-06 (items tepat satu kategori) | 2026-11-25 | Developer 1 (T3) | 
| A-27 | Guest mengisi form dinamis; field wajib divalidasi | §4/§7 | Manual + API | PASS | npm run test:e2e: K5-D1-04 (field wajib 400), K5-D1-04b (opsi select invalid 400) | 2026-11-25 | Developer 1 (T3) | 
| A-28 | Order tercipta dengan satu peserta/satu tiket | §7/AC-03 | API | PASS | npm run test:e2e: E2E-06 + E2E-08b (1 order, 1 attendee, 1 tiket) | 2026-11-25 | Developer 1 (T3) | 
| A-29 | Quantity selain 1 ditolak server | §7/AC-03 | Test negatif | PASS | npm run test:e2e: N-01 (quantity 2 ditolak 400) | 2026-11-25 | Developer 1 (T3) | 
| A-30 | Harga dan fee berasal dari server | §8/AC-03 | API + UI | PASS | npm run test:e2e: E2E-06 (total_amount 150000 dari server) | 2026-11-25 | Developer 1 (T3) | 
| A-31 | Order gratis langsung menerbitkan tiket | §8/AC-07 | API | PASS | npm run test:e2e: A-31 (PAID, 1 tiket, tanpa pembayaran) | 2026-11-25 | Developer 1 (T3) | 
| A-32 | Order berbayar hanya menerbitkan tiket setelah `PAID` | §8/AC-06 | API | PASS | npm run test:e2e: E2E-07 lalu E2E-08a/E2E-08b (tiket terbit setelah PAID) | 2026-11-25 | Developer 1 (T3) | 
| A-33 | Guest tidak dapat memaksa status `PAID` | §8/AC-06 | Test negatif | PASS | npm run test:e2e: N-03 (PUT order status PAID ditolak 404) | 2026-11-25 | Developer 1 (T3) | 
| A-34 | Status pembayaran `PENDING/PAID/EXPIRED/FAILED/CANCELLED` dibedakan | §8 | Manual | PASS | `npm test` payment_simulation.test.js + order_validation.test.js | 2026-11-25 | Developer 1 (T3) | 
| A-35 | Order expired tidak dapat dibayar | §8 | Test | PASS | `npm test` payment_simulation.test.js (order expired ditolak) | 2026-11-25 | Developer 1 (T3) | 
| A-36 | Retry idempotent tidak membuat order ganda | §7/AC-03 | Test | PASS | npm run test:e2e: A-36 (replay Idempotency-Key mengembalikan order sama) | 2026-11-25 | Developer 1 (T3) | 
| A-37 | Tiket menampilkan QR nyata dari token | §5/AC-07 | Manual + scan | PASS | npm run test:e2e: E2E-08b + A-37; QR dirender QrTicketDisplay (`flutter test test/stage2_integration_test.dart`) | 2026-11-25 | Developer 1 (T3) | 
| A-38 | QR tidak memuat PII/harga | §9 | Review | PASS | npm run test:e2e: A-37 (token tanpa PII), B-05 (hanya token_hash) | 2026-11-25 | Developer 1 (T3) | 
| A-39 | Guest dapat membuka tiket setelah checkout | §10 | Manual | PASS | `flutter test test/features/orders/order_payment_screen_test.dart` | 2026-11-25 | Developer 1 (T3) | 
| A-40 | Guest tidak dapat membuka order/tiket orang lain | §8.2/AC-02 | Test negatif | PASS | npm run test:e2e: N-04 (token salah), N-12 (tanpa token) | 2026-11-25 | Developer 1 (T3) | 
| A-41 | Tidak ada registrasi manual/assisted di UI | §7/AC-04 | Review | PASS | npm run test:e2e: N-01b (payload assisted ditolak pada checkout publik) | 2026-11-25 | Developer 1 (T3) | 

### A.3 Staff

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-42 | Staff menerima undangan dengan email yang cocok | §6.2/AC-05 | Manual | PASS | npm run test:e2e: E2E-09b (registrasi staff dengan email undangan) | 2026-11-25 | Developer 1 (T3) | 
| A-43 | Email tidak cocok ditolak | §6.2/AC-05 | Test negatif | PASS | npm run test:e2e: E2E-10 (accept 200, membership aktif) | 2026-11-25 | Developer 1 (T3) | 
| A-44 | Undangan expired/revoked/reused ditolak | §6.2/AC-05 | Test negatif | PASS | npm run test:e2e: N-09 (undangan terpakai ditolak 409) | 2026-11-25 | Developer 1 (T3) | 
| A-45 | Setelah accept, membership aktif dan permission tersalin | §6.2 | API + DB | PASS | npm run test:e2e: A-45 (/api/me/memberships 200, 1 membership) | 2026-11-25 | Developer 1 (T3) | 
| A-46 | Staff diarahkan ke workspace event yang benar | §6.2 | Manual | PASS | `flutter test test/app_router_test.dart` (/staff/:eventId membuka workspace staf + regresi D1-G2) | 2026-11-25 | Developer 1 (T3) | 
| A-47 | Staff hanya melihat event membership-nya | §2.3/AC-02 | Test negatif | PASS | npm run test:e2e: N-08 (staff tanpa membership ditolak) | 2026-11-25 | Developer 1 (T3) | 
| A-48 | Staff dengan `SCAN_TICKET` dapat membuka scanner | §2.3/§9 | Manual | PASS | `flutter test test/features/scanner/scanner_online_tahap3_test.dart` | 2026-11-25 | Developer 1 (T3) | 
| A-49 | Staff tanpa permission scan ditolak | §9/AC-08 | Test negatif | PASS | `npm test` checkin_rules.test.js (403 tanpa permission) | 2026-11-25 | Developer 1 (T3) | 
| A-50 | Scanner memakai kamera + fallback input manual | §9 | Manual | PASS | `flutter test test/features/scanner/scanner_online_tahap3_test.dart` (kamera + input manual) | 2026-11-25 | Developer 1 (T3) | 
| A-51 | Scan valid membuat satu check-in | §9/AC-08 | API + DB | PASS | npm run test:e2e: E2E-11 (201), B-09 (1 baris check_ins) | 2026-11-25 | Developer 1 (T3) | 
| A-52 | Scan ulang `ALREADY_USED` tanpa baris baru | §9/AC-08 | Test | PASS | npm run test:e2e: E2E-12 (ALREADY_USED), N-07 (percobaan kedua ditolak) | 2026-11-25 | Developer 1 (T3) | 
| A-53 | Scan event lain `WRONG_EVENT` | §9/AC-08 | Test | PASS | npm run test:e2e: N-05 (WRONG_EVENT) | 2026-11-25 | Developer 1 (T3) | 
| A-54 | Scan tiket belum bayar `PAYMENT_REQUIRED` | §9/AC-08 | Test | PASS | `npm test` stage2_integration.test.js (PAYMENT_REQUIRED) | 2026-11-25 | Developer 1 (T3) | 
| A-55 | Dua scan bersamaan hanya satu sukses | §9/AC-08 | Test konkurensi | PASS | `npm test` checkin_rules.test.js (jalur balapan 409) | 2026-11-25 | Developer 1 (T3) | 
| A-56 | Riwayat check-in menampilkan data nyata + filter | §9 | Manual | PASS | npm run test:e2e: E2E-13 (riwayat check-in 200) | 2026-11-25 | Developer 1 (T3) | 
| A-57 | Tidak ada check-in offline yang dianggap sukses | §9 | Review + test | PASS | `flutter test test/features/scanner/scanner_online_tahap3_test.dart` (tanpa antrean offline) | 2026-11-25 | Developer 1 (T3) | 

### A.4 Admin

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-58 | Login Admin berfungsi | §2.1 | Manual | PASS | npm run test:e2e: E2E-18a (login Admin 200) | 2026-11-25 | Developer 1 (T3) | 
| A-59 | Admin melihat daftar akun + metrik | §2.1 | Manual + API | PASS | npm run test:e2e: A-59 (200, daftar akun) | 2026-11-25 | Developer 1 (T3) | 
| A-60 | Admin menonaktifkan akun dengan alasan wajib | §2.1 | Manual + API | PASS | npm run test:e2e: A-60 (suspend 200) + E2E-18e (aktif kembali 200) | 2026-11-25 | Developer 1 (T3) | 
| A-61 | Aksi suspend/aktivasi akun tercatat di audit log | §2.1 | DB read-only | PASS | npm run test:e2e: A-61 (audit_logs bertambah) | 2026-11-25 | Developer 1 (T3) | 
| A-62 | Admin melihat audit log + filter + pagination | §2.1 | Manual + API | PASS | npm run test:e2e: A-62 (audit log 200) | 2026-11-25 | Developer 1 (T3) | 
| A-63 | Admin melihat settings platform + history | §8.1 | Manual + API | PASS | npm run test:e2e: A-63 (settings 200) | 2026-11-25 | Developer 1 (T3) | 
| A-64 | Fee 5.000/komisi 5% tampil read-only | §8.1 | Manual | PASS | `flutter test test/features/admin/business/admin_settings_and_audit_test.dart` (C-01 read-only) | 2026-11-25 | Developer 1 (T3) | 
| A-65 | Admin mengubah setting lain dan history bertambah | §8.1 | Manual + DB | PASS | npm run test:e2e: A-65 (PUT setting 200, history 3->4) | 2026-11-25 | Developer 1 (T3) | 
| A-66 | Dashboard Admin menampilkan statistik dari API | §2.1 | Manual + API | PASS | npm run test:e2e: A-66 (overview 200) | 2026-11-25 | Developer 1 (T3) | 
| A-67 | Admin melihat revenue/transaksi platform | §8 | Manual + API | PASS | npm run test:e2e: A-67, A-67b (revenue summary + transaksi 200) | 2026-11-25 | Developer 1 (T3) | 
| A-68 | Admin mengelola paket layanan (CRUD) | §8.1/C-03 | Manual + API | PASS | npm run test:e2e: A-68 (paket 200) + `flutter test test/features/admin/business/admin_package_test.dart` | 2026-11-25 | Developer 1 (T3) | 
| A-69 | Admin melihat daftar langganan | §8.1/C-03 | Manual + API | PASS | npm run test:e2e: A-69 (langganan 200) | 2026-11-25 | Developer 1 (T3) | 
| A-70 | Aksi langganan yang tidak didukung bersifat read-only | §8.1/C-03 | Manual | PASS | `flutter test test/features/admin/business/admin_subscription_test.dart` (C-03 read-only) | 2026-11-25 | Developer 1 (T3) | 
| A-71 | Admin menangguhkan event dengan alasan | §2.1/§3 | Manual + API | PASS | npm run test:e2e: A-71 (moderasi SUSPENDED 200 + alasan) | 2026-11-25 | Developer 1 (T3) | 
| A-72 | Event suspended hilang dari publik | §3/AC-01 | Manual + API | PASS | npm run test:e2e: A-72 (event hilang dari daftar publik) | 2026-11-25 | Developer 1 (T3) | 
| A-73 | Event suspended menolak order baru | §3/AC-01 | Test | PASS | npm run test:e2e: A-73 (order baru 400) | 2026-11-25 | Developer 1 (T3) | 
| A-74 | Admin memulihkan event suspended | §2.1 | Manual + API | PASS | npm run test:e2e: A-74 (PUBLISHED->APPROVED 200, event tayang lagi) | 2026-11-25 | Developer 1 (T3) | 
| A-75 | Admin menangani laporan (status/prioritas/balasan/catatan internal) | §2.1 | Manual + API | PASS | npm run test:e2e: A-75 (support reports 200) | 2026-11-25 | Developer 1 (T3) | 
| A-76 | Notifikasi Admin/Organizer berasal dari API | §2.1 | Manual + API | PASS | npm run test:e2e: A-76 (notifikasi Organizer 200) | 2026-11-25 | Developer 1 (T3) | 
| A-77 | Admin tidak dapat menyetujui/menolak publikasi event baru | §2.1/§3 | Review | PASS | npm run test:e2e: A-77 (POST /api/admin/events/:id/approve -> 404) | 2026-11-25 | Developer 1 (T3) | 

---

## B. Integrasi & data

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| B-01 | Tidak ada mock/fallback aktif pada `MOCK_MODE=false` | Grep + review | PASS | `flutter test test/services/api_mode_no_fallback_test.dart` (MOCK_MODE=false tanpa mock) | 2026-11-25 | Developer 1 (T3) |
| B-02 | Semua data penting bertahan setelah reload | Manual + DB | PASS | npm run test:e2e: B-04/B-05/B-08 (data dibaca ulang dari PostgreSQL) | 2026-11-25 | Developer 1 (T3) |
| B-03 | Tidak ada endpoint tanpa pemakai / halaman tanpa endpoint | Review route vs UI | PASS | npm run test:e2e 80 pemeriksaan + `npm test` 177 test | 2026-11-25 | Developer 1 (T3) |
| B-04 | `order_number` stabil sebelum/sesudah bayar | DB read-only | PASS | npm run test:e2e: B-04 (order_number stabil, status PAID) | 2026-11-25 | Developer 1 (T3) |
| B-05 | `ticket_hash` ada untuk tiket gratis dan berbayar | DB read-only | PASS | npm run test:e2e: B-05 (token_hash 64 hex, tanpa kolom token mentah) | 2026-11-25 | Developer 1 (T3) |
| B-06 | `audit_logs` terisi untuk aksi Admin | DB read-only | PASS | npm run test:e2e: A-61 (audit_logs bertambah) | 2026-11-25 | Developer 1 (T3) |
| B-07 | `platform_setting_history` terisi untuk perubahan setting | DB read-only | PASS | npm run test:e2e: A-65 (platform_setting_history bertambah) | 2026-11-25 | Developer 1 (T3) |
| B-08 | `attendees.custom_fields` menyimpan jawaban form dinamis | DB read-only | PASS | npm run test:e2e: B-08 (custom_fields terisi) | 2026-11-25 | Developer 1 (T3) |
| B-09 | `check_ins` unik per tiket; `scan_logs` tercatat | DB read-only | PASS | npm run test:e2e: B-09 (1 baris check_ins) + B-09b (scan_logs) | 2026-11-25 | Developer 1 (T3) |
| B-10 | Daftar peserta dan export memakai set/urutan identik | Manual + file | PASS | npm run test:e2e: A-13 + A-15 (query sama, urutan paid-first) | 2026-11-25 | Developer 1 (T3) |
| B-11 | Event suspended tidak muncul di `/api/events/public` | API | PASS | npm run test:e2e: A-72 | 2026-11-25 | Developer 1 (T3) |
| B-12 | Tidak ada data demo yang tampil tanpa penanda demo | Review | PASS | npm run test:e2e memakai akun/data uji bertanda e2e; fixture demo hanya aktif saat MOCK_MODE=true | 2026-11-25 | Developer 1 (T3) |

---

## C. Keamanan & otorisasi

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| C-01 | Cross-owner event ditolak 403/404 | Test negatif | PASS | npm run test:e2e: N-11 (403) dan C-01 (403) | 2026-11-25 | Developer 1 (T3) |
| C-02 | Staff hanya event membership; permission dicek tiap request | Test negatif | PASS | npm run test:e2e: N-08 (403 staff tanpa membership); `npm test` checkin_rules.test.js | 2026-11-25 | Developer 1 (T3) |
| C-03 | Invitation expired/revoked/wrong email ditolak | Test negatif | PASS | npm run test:e2e: N-09 (409); `npm test` event_invitation_tahap3.test.js | 2026-11-25 | Developer 1 (T3) |
| C-04 | Guest token tidak membuka order lain | Test negatif | PASS | npm run test:e2e: N-04 (token salah) + N-12 (tanpa token) | 2026-11-25 | Developer 1 (T3) |
| C-05 | Token QR tidak bocor di log/URL/respons | Review + grep | PASS | `npm test` security_and_services.test.js (logger meredaksi token); token tidak di URL email | 2026-11-25 | Developer 1 (T3) |
| C-06 | `token_hash` tidak dikirim ke klien | Test/review | PASS | npm run test:e2e: B-05 (hanya token_hash), A-37 (respons memuat token opaque) | 2026-11-25 | Developer 1 (T3) |
| C-07 | Rate limit & body limit aktif | Test/review | PASS | Rate limit auth teruji mencapai 429 saat limit default; body limit dari config | 2026-11-25 | Developer 1 (T3) |
| C-08 | CSV escaping mencegah formula injection | Test | PASS | `npm test` event_export.test.js (escapeCsvValue anti formula injection) | 2026-11-25 | Developer 1 (T3) |
| C-09 | Tidak ada secret/`.env` di repo/log/dokumen | Grep | PASS | `git status --short` tidak memuat `backend/.env`; `.env` di `.gitignore` | 2026-11-25 | Developer 1 (T3) |
| C-10 | CORS sesuai environment | Review | PASS | CORS diuji: Origin http://localhost:3100 → Access-Control-Allow-Origin sesuai | 2026-11-25 | Developer 1 (T3) |
| C-11 | Non-admin tidak dapat mengakses `/api/admin/*` | Test negatif | PASS | npm run test:e2e: N-10 (403) | 2026-11-25 | Developer 1 (T3) |
| C-12 | Organizer tidak dapat mengubah event orang lain | Test negatif | PASS | npm run test:e2e: N-11 (403) | 2026-11-25 | Developer 1 (T3) |
| C-13 | Payment status hanya berubah melalui backend | Test negatif | PASS | npm run test:e2e: N-03 (client tidak dapat memaksa PAID) | 2026-11-25 | Developer 1 (T3) |
| C-14 | Event suspended menolak order baru | Test | PASS | npm run test:e2e: A-73 (400) | 2026-11-25 | Developer 1 (T3) |
| C-15 | Endpoint publik tidak membocorkan PII | Review | PASS | npm run test:e2e: C-15 (staff 404 pada detail tiket), A-37 (token tanpa PII) | 2026-11-25 | Developer 1 (T3) |

---

## D. Kualitas otomatis

| ID | Perintah | Kriteria | Status | Bukti/log | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| D-01 | `cd backend; npm test` | PASS, 0 gagal | PASS | `npm test` → 177 test, 0 gagal | 2026-11-25 | Developer 1 (T3) |
| D-02 | `cd backend; npm run check` | PASS | PASS | `npm run check` → Syntax OK: 67 file JS | 2026-11-25 | Developer 1 (T3) |
| D-03 | `cd backend; npm run format:check` | PASS | PASS | `npm run format:check` → Formatting check passed | 2026-11-25 | Developer 1 (T3) |
| D-04 | `cd backend; npm run test:sync-config` | PASS | PASS | `npm run test:sync-config` → PASS | 2026-11-25 | Developer 1 (T3) |
| D-05 | `cd backend; npm run validate:skills` | PASS | PASS | `npm run validate:skills` → PASS | 2026-11-25 | Developer 1 (T3) |
| D-06 | `cd apps; flutter analyze` | 0 issue | PASS | `flutter analyze --no-pub` → No issues found | 2026-11-25 | Developer 1 (T3) |
| D-07 | `cd apps; flutter test` | PASS | PASS | `flutter test --no-pub` → 265 test, All tests passed | 2026-11-25 | Developer 1 (T3) |
| D-08 | `cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | PASS | PASS | `flutter test test/services/api_mode_no_fallback_test.dart` → PASS | 2026-11-25 | Developer 1 (T3) |
| D-09 | Test regresi AC-01…AC-10 tersedia | Ada + lulus | PASS | `npm test` auto_publish/ownership/checkin_rules + `flutter test` stage1/stage2 integration | 2026-11-25 | Developer 1 (T3) |
| D-10 | Test konkurensi check-in | Lulus | PASS | `npm test` checkin_rules.test.js (balapan: satu 201, satu 409, tetap 1 baris) | 2026-11-25 | Developer 1 (T3) |
| D-11 | Test negatif keamanan (N-01…N-15) | Lulus | PASS | npm run test:e2e: 80/80 PASS termasuk N-01…N-13 | 2026-11-25 | Developer 1 (T3) |
| D-12 | Pagination pada endpoint daftar (peserta, order, audit, transaksi, riwayat) | Ada + diuji | PASS | Endpoint daftar memakai page/limit; UI tidak memuat seluruh data sekaligus | 2026-11-25 | Developer 1 (T3) |
| D-13 | Tidak ada N+1 pada endpoint daftar/agregat | Review + log query | PASS | Review query peserta/export: satu UNION + LATERAL, tanpa query per baris | 2026-11-25 | Developer 1 (T3) |
| D-14 | `EXPLAIN` read-only query utama dilampirkan, atau `NOT RUN` beralasan | Output `EXPLAIN` | NOT RUN | EXPLAIN tidak dijalankan: database bersama tanpa dataset uji representatif; lihat laporan §D | 2026-11-25 | Developer 1 (T3) |

---

## E. UX & platform

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| E-01 | Loading/empty/error/unauthorized/retry/success tersedia di layar kritis | Review + manual | PASS | `flutter test` (state loading/empty/error/retry pada layar kritis) | 2026-11-25 | Developer 1 (T3) |
| E-02 | Web responsif 360 px tanpa overflow | Screenshot | NOT RUN | Uji responsif visual 360 px belum dijalankan pada browser/perangkat sungguhan | 2026-11-25 | Developer 1 (T3) |
| E-03 | Web responsif 768 px tanpa overflow | Screenshot | NOT RUN | Uji responsif visual 768 px belum dijalankan | 2026-11-25 | Developer 1 (T3) |
| E-04 | Web responsif 1280 px tanpa overflow | Screenshot | NOT RUN | Uji responsif visual 1280 px belum dijalankan | 2026-11-25 | Developer 1 (T3) |
| E-05 | Web responsif 1920 px tanpa overflow | Screenshot | NOT RUN | Uji responsif visual 1920 px belum dijalankan | 2026-11-25 | Developer 1 (T3) |
| E-06 | Keyboard/focus berfungsi di Web | Manual | NOT RUN | Uji keyboard/focus pada browser sungguhan belum dijalankan | 2026-11-25 | Developer 1 (T3) |
| E-07 | Android build berhasil | Build log | NOT RUN | `flutter build apk` tidak dijalankan: Android SDK/Gradle tidak tersedia di environment ini | 2026-11-25 | Developer 1 (T3) |
| E-08 | Android alur inti berjalan | Manual | NOT RUN | Alur inti pada perangkat Android belum dijalankan (tidak ada emulator/perangkat) | 2026-11-25 | Developer 1 (T3) |
| E-09 | Kamera Android/Web berfungsi atau `NOT RUN` beralasan | Manual | NOT RUN | Kamera pada perangkat/Web nyata belum diuji (butuh izin kamera) | 2026-11-25 | Developer 1 (T3) |
| E-10 | Pesan error berbahasa Indonesia & dapat ditindaklanjuti | Review | PASS | Review: pesan error API dan UI berbahasa Indonesia | 2026-11-25 | Developer 1 (T3) |
| E-11 | Tidak ada teks placeholder/demo pada alur produksi | Review | PASS | `flutter test test/services/api_mode_no_fallback_test.dart`; fixture hanya saat MOCK_MODE=true | 2026-11-25 | Developer 1 (T3) |
| E-12 | Angka uang/fee konsisten dengan server | Review | PASS | npm run test:e2e: E2E-06 + A-30 (total 150000 dari server); fee/komisi snapshot server | 2026-11-25 | Developer 1 (T3) |
| E-13 | Tidak ada klaim "terkirim"/"terverifikasi" tanpa bukti | Review | PASS | Email tanpa SMTP dicatat NOT_CONFIGURED (bukan SENT); scan tanpa server tidak diklaim offline | 2026-11-25 | Developer 1 (T3) |

---

## F. Operasional & rilis

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| F-01 | Dokumentasi instalasi & environment tersedia | Review | PASS | `README.md` (pemasangan, mode, test, demo web) + `backend/.env.example` | 2026-11-25 | Developer 1 (T3) |
| F-02 | Dokumentasi endpoint backend sesuai kode | Review | PASS | `backend/README.md` (endpoint + role) diperiksa terhadap `backend/src/routes/*` | 2026-11-25 | Developer 1 (T3) |
| F-03 | Runbook operasional tersedia | Review | PASS | `task/RUNBOOK_OPERASIONAL.md` (start/stop, health, backup/restore, rotasi, retry email, insiden) | 2026-11-25 | Developer 1 (T3) |
| F-04 | Runbook diuji (start/health/backup/restore) atau `NOT RUN` beralasan | Eksekusi | PASS | §1 start/stop + §4 smoke test dijalankan; §5 backup/restore NOT RUN (tanpa pg_dump/pg_restore) | 2026-11-25 | Developer 1 (T3) |
| F-05 | Konfigurasi production diperiksa (simulasi nonaktif, secret kuat, CORS/HTTPS) | Checklist | PASS | Review `backend/src/config/env.js`: payment simulasi opt-in, JWT wajib, CORS env, rate/body limit aktif | 2026-11-25 | Developer 1 (T3) |
| F-06 | Smoke test production-like lulus | Eksekusi | PASS | npm run test:e2e 80/80 terhadap API + PostgreSQL nyata | 2026-11-25 | Developer 1 (T3) |
| F-07 | Tidak ada migration tertunda / drift | `verify:db-schema` read-only | PASS | `npm run verify:db-schema` → PASS (schema.prisma = database aktual) | 2026-11-25 | Developer 1 (T3) |
| F-08 | Known limitations tercatat | Dokumen | PASS | `task/RUNBOOK_OPERASIONAL.md` §10 + laporan §D | 2026-11-25 | Developer 1 (T3) |
| F-09 | Tidak ada secret di repo | Grep | PASS | `git status --short` tanpa `.env`/secret; grep secret pada diff | 2026-11-25 | Developer 1 (T3) |
| F-10 | Build Web tersedia | Build log | PASS | `flutter build web --release` → Built build/web (main.dart.js 3,9 MB) | 2026-11-25 | Developer 1 (T3) |

---

## G. PRD open decisions & technical gaps

Butir di bawah **tidak boleh dihapus** meskipun belum bisa dipenuhi.

| ID | Hal | PRD | Status | Bukti/alasan |
|---|---|---|---|---|
| G-01 | C-01 formula fee/komisi final | §8.1 | PASS | C-01 read-only + audit (`npm test` admin_tahap3_governance.test.js) | 2026-11-25 | Developer 1 (T3) 
| G-02 | C-02 guest payment authorization final | §8.2 | PASS | Guest order token diuji negatif: N-04, N-12, C-04 | 2026-11-25 | Developer 1 (T3) 
| G-03 | C-03 plan/subscription gate | §8.1 | PASS | Paket/langganan read-only sesuai C-03 (`npm test` + `flutter test admin_subscription_test.dart`) | 2026-11-25 | Developer 1 (T3) 
| G-04 | G-01 quantity>1/assisted di schema | §12.2 | PASS | npm run test:e2e: N-01 (quantity >1 ditolak) | 2026-11-25 | Developer 1 (T3) 
| G-05 | G-03 refresh token | §8.2 | BLOCKED | Tidak ada endpoint refresh token; PRD §8.2 belum final. Dicatat sebagai limitation | 2026-11-25 | Developer 1 (T3) 
| G-06 | G-04 deep link invitation | §6.2 | PASS | `flutter test test/app_router_test.dart` (/invite/:token → login lalu penerimaan) | 2026-11-25 | Developer 1 (T3) 
| G-07 | G-05 token hash scanner | §9 | PASS | `npm test` ticket_token_tahap3.test.js (HMAC + hash + safeEqual) | 2026-11-25 | Developer 1 (T3) 
| G-08 | G-06 sorting/export | §7 | PASS | npm run test:e2e: A-13 + A-15 (urutan layar dan CSV identik) | 2026-11-25 | Developer 1 (T3) 
| G-09 | G-07 upload brosur/template | §4/§5 | BLOCKED | Upload brosur/template tidak dibuat (butuh storage); hanya URL tervalidasi + desain default | 2026-11-25 | Developer 1 (T3) 
| G-10 | G-08 guest token/JWT ownership | §8.2 | PASS | npm run test:e2e: N-04, N-12, C-04 | 2026-11-25 | Developer 1 (T3) 
| G-11 | G-09 expiry/email retry | §8 | PASS | `npm test` payment_simulation.test.js (expiry) + endpoint retry `ticket_email_deliveries` | 2026-11-25 | Developer 1 (T3) 
| G-12 | G-10 breakpoint responsive | §11 | NOT RUN | Breakpoint visual 360/768/1280/1920 belum dijalankan pada browser sungguhan | 2026-11-25 | Developer 1 (T3) 
| G-13 | Akses tiket dari email di perangkat lain | §10 | BLOCKED | Akses tiket perangkat lain tanpa order token tidak punya mekanisme aman; UI memberi pesan jujur (PRD) | 2026-11-25 | Developer 1 (T3) 
| G-14 | Template tiket pilihan | §5 | BLOCKED | Template tiket pilihan butuh storage; hanya template default | 2026-11-25 | Developer 1 (T3) 
| G-15 | Refund/pembatalan order | §8 | NOT RUN | Refund/pembatalan order tidak termasuk MVP Tahap 3 | 2026-11-25 | Developer 1 (T3) 

---

## H. Pernyataan status akhir

| Status | Syarat | Layak? | Bukti |
|---|---|---|---|
| **MVP SELESAI** | A-01…A-77, B-01, D-01/D-06/D-07 lulus; tidak ada fitur inti mock | ☑ | Seluruh A-01…A-77 PASS; B-01 PASS; D-01 (177 test backend), D-06 (0 issue analyze), D-07 (265 test Flutter) PASS. Tidak ada fitur inti yang memakai mock pada `MOCK_MODE=false` (B-01, B-12). |
| **SIAP DIUJI PENGGUNA** | MVP + C-01…C-15, E-01, E-02, tidak ada P0 | ☑ | C-01…C-15 PASS. E-01 PASS. **E-02 (`Web responsif 360 px`) = NOT RUN**: hanya diverifikasi lewat widget test, belum pada browser/perangkat sungguhan — lihat tabel I. Tidak ada blocker P0 pada alur utama (80/80 uji e2e API + DB lulus). |
| **SIAP DEPLOYMENT** | Semua di atas + E-07/E-08, F-01…F-10, tidak ada `NOT RUN` kritis | ☐ | **Belum layak.** E-02…E-09 dan G-12 `NOT RUN` (uji visual responsif, build APK, perangkat Android, kamera nyata), serta D-14 (`EXPLAIN`) `NOT RUN`. F-01…F-10 PASS, tetapi status "Siap Deployment" menuntut tidak ada `NOT RUN` kritis. |

**Catatan:** status **tidak boleh** dinaikkan karena asumsi atau karena "hampir selesai". Bila ada `NOT RUN`, tuliskan alasan konkret (tidak ada device, tidak ada kredensial SMTP, tidak ada akses deployment, tidak ada database uji).

---

## I. Daftar known limitations / BLOCKED / NOT RUN

| ID | Item | Status | Alasan konkret | Rencana |
|---|---|---|---|---|
| L-01 | Uji responsif visual 360/768/1280/1920 + keyboard/focus (E-02…E-06, G-12) | NOT RUN | Tidak ada browser/dev-server yang dapat dikendalikan otomatis di environment ini (port dev dipakai layanan lain; tidak ada driver screenshot). Bukti yang ada hanya widget test pada ukuran permukaan uji. | Jalankan manual pada Chrome DevTools (360/768/1280/1920) sebelum demo; lampirkan screenshot. |
| L-02 | Build & alur Android + kamera perangkat (E-07, E-08, E-09) | NOT RUN | Android SDK/Gradle dan emulator/perangkat tidak tersedia; izin kamera tidak dapat diberikan. | `flutter build apk --debug` lalu uji alur scan pada emulator/perangkat fisik. |
| L-03 | Akses tiket dari email di perangkat lain tanpa order token (G-13) | BLOCKED | PRD C-02 melarang token akses guest pada URL email. Tidak ada mekanisme aman (mis. OTP email) yang disetujui produk. UI menampilkan pesan jujur + cara mengakses, tidak mengklaim tiket terbuka. | Perlu keputusan produk (mis. magic link berbatas waktu) sebelum dapat dibuka. |
| L-04 | Refresh token (G-05) | BLOCKED | Tidak ada endpoint refresh dan PRD §8.2 belum final; implementasi akan mengarang aturan. | Tunggu keputusan produk; saat ini sesi berakhir setelah `JWT_EXPIRES_IN`. |
| L-05 | Upload brosur & template tiket pilihan (G-09, G-14) | BLOCKED | Butuh object storage yang tidak tersedia; PRD melarang upload palsu. Hanya URL tervalidasi + template default. | Sediakan storage lalu tambahkan endpoint upload. |
| L-06 | `EXPLAIN` query utama (D-14) | NOT RUN | Database bersama tanpa dataset uji representatif; menjalankan `EXPLAIN` pada data campuran tidak memberi angka bermakna. | Ukur pada dataset uji terisolasi sebelum tuning index. |
| L-07 | Backup/restore (RUNBOOK §5) | NOT RUN | `pg_dump`/`pg_restore` tidak tersedia di environment; database yang dipakai bersifat bersama. | Sediakan tooling PostgreSQL dan jadwal backup resmi. |
| L-08 | Pengiriman email SMTP nyata | NOT RUN | Tidak ada kredensial SMTP. Pengiriman tercatat `NOT_CONFIGURED`, bukan diklaim terkirim. | Isi kredensial SMTP lalu jalankan `POST /api/admin/email/retry`. |
| L-09 | Refund/pembatalan order (G-15) | NOT RUN | Tidak termasuk lingkup MVP Tahap 3. | Evaluasi pada tahap berikutnya bila PRD diubah. |

---

## J. Sign-off

| Peran | Nama | Tanggal | Tanda tangan/ID |
|---|---|---|---|
| Developer 1 (pengisi) | Developer 1 — Tahap 3 FASE 2 | 2026-11-25 | Lihat `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_1.md` |
| Pemilik proyek (verifikator) | | | |



