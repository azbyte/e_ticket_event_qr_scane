# TUGAS DEVELOPER 1 — TAHAP 3 (FASE 2)

- **Peran:** Developer 1 — Integrator & penyelesai akhir aplikasi.
- **Fase:** FASE 2. **Mulai hanya setelah Developer 2 dan Developer 3 menyerahkan hasil lengkap dan gate F1 lulus.**
- **Branch:** `Developer-1-T3`.
- **Selesai:** seluruh task T3-D1-01…T3-D1-10 + `FINAL_ACCEPTANCE_CHECKLIST.md` terisi + laporan + status akhir.
- **Otorisasi:** perintah pemilik proyek kepada Developer 1 adalah otorisasi implementasi.

> Dokumen ini adalah instruksi paling lengkap. Developer 1 bukan hanya integrator: ada pekerjaan implementasi nyata pada backend dan `apps/lib` yang tidak dikerjakan D2/D3.

---

## 1. Prinsip dan batas peran

1. **Jangan mulai sebelum FASE 1 selesai.** Tidak ada "bootstrap", "stub", atau "perbaikan kecil" sebelum D2/D3 menyerahkan hasil dan F1-G1…F1-G7 lulus.
2. **Integrasi + implementasi.** D1 menggabungkan hasil, menangani konflik, dan menyelesaikan pekerjaan yang belum tercakup: routing, event lifecycle, form dinamis, guest journey, backend lintas modul, audit/pembersihan, dokumentasi, acceptance.
3. **Final owner.** Setelah FASE 1, D1 boleh mengedit file D2/D3 untuk memperbaiki integrasi, dengan catatan file/alasan/dampak.
4. **Tidak menambah fitur di luar PRD.** Perbaikan harus mengarah pada pemenuhan AC/PRD, bukan fitur baru.
5. **Tidak mengubah schema/migration/seed.** Kebutuhan DB → `task/DB_CHANGE_PROPOSAL.md`, tidak dieksekusi.
6. **Tidak ada Tahap 4.** Item yang tidak bisa dipenuhi dicatat `BLOCKED`/`NOT RUN` dengan alasan.
7. **Bukti, bukan klaim.** Setiap status wajib punya perintah/bukti.

---

## 2. Kondisi awal setelah FASE 1

### 2.1 Yang harus sudah tersedia

- Branch `Developer-2-T3` dan `Developer-3-T3` sudah selesai dan rebase.
- Laporan `LAPORAN_TAHAP_3_DEVELOPER_2.md` dan `..._3.md` lengkap.
- D2: tiket/QR, invitation/membership, scanner, check-in, riwayat, test.
- D3: peserta/export, order/revenue Organizer, Admin akun/audit/settings/dashboard/revenue/paket/langganan/moderasi/laporan/notifikasi, test.
- Tidak ada file yang diubah kedua developer (F1-G2).
- `npm test`, `flutter analyze`, `flutter test` PASS pada masing-masing branch.

### 2.2 Baseline yang harus diverifikasi ulang

```powershell
git --no-pager log --oneline -10
git status --short
cd backend; npm test
cd apps; flutter analyze --no-pub
cd apps; flutter test --no-pub
```

Catat hasil. Bila gagal, perbaiki sebelum melanjutkan.

### 2.3 Gap yang menjadi pekerjaan D1 (bukan D2/D3)

| # | Gap | Bukti | Task |
|---|---|---|---|
| D1-G1 | Router tidak meneruskan `eventId` ke `AttendeeListScreen` | `app_router.dart:183-201` | T3-D1-02 |
| D1-G2 | `/staff/scanner` & `/staff/check-ins` diarahkan ke dashboard | `app_router.dart:106-109` | T3-D1-02 |
| D1-G3 | Belum ada route order Organizer | `app_router.dart` | T3-D1-02 |
| D1-G4 | `OrganizerQrPlaceholder` masih pseudo-QR | `organizer_event_detail_screen.dart:694` | T3-D1-03 |
| D1-G5 | Form Organizer belum punya builder field dinamis | `event_form_screen.dart` | T3-D1-04 |
| D1-G6 | Guest journey belum E2E pada API/DB nyata | laporan D1 Tahap 2 `NOT RUN` | T3-D1-03/T3-D1-09 |
| D1-G7 | Akses tiket dari tautan email tanpa order token | `emailService.js`, router | T3-D1-03 |
| D1-G8 | `ticket_hash` tiket gratis perlu verifikasi end-to-end | `ticketTokenService.js`, `orderController.js` | T3-D1-05 |
| D1-G9 | Notifikasi/audit lintas modul belum lengkap | `notificationService.js`, `auditLog.js` | T3-D1-05 |
| D1-G10 | File legacy `models/*.js` + `config/supabase.js` | grep referensi | T3-D1-07 |
| D1-G11 | Dokumentasi usang | `docs/**`, `README.md` | T3-D1-08 |
| D1-G12 | Bukti Web/Android/email/DB belum ada | laporan Tahap 2 | T3-D1-09 |

---

## 3. Pekerjaan setelah D2/D3 menyerahkan hasil

### T3-D1-01 — Intake FASE 1 & baseline integrasi

**Pekerjaan:**
1. Baca laporan D2/D3 dan diff masing-masing.
2. Verifikasi gate F1:
   - file di luar allow-list,
   - overlap D2/D3,
   - file beku tidak tersentuh,
   - test PASS.
3. Merge `Developer-2-T3` dan `Developer-3-T3` ke `Developer-1-T3` (urutan bebas; selesaikan konflik).
4. Jalankan ulang seluruh test setelah merge.
5. Buat **daftar gap integrasi** (IG-01, …) berisi:
   - route/parameter yang belum tersambung,
   - response yang tidak cocok,
   - permission yang salah,
   - state UI yang belum ada,
   - test yang gagal,
   - permintaan D2/D3 yang belum dikerjakan.
6. Tulis daftar tersebut di laporan §3.

**Kriteria:**
- Branch gabungan bersih; test PASS.
- Daftar gap integrasi lengkap dan bernomor.
- Tidak ada konflik yang diselesaikan dengan menghapus kode salah satu pihak.

---

### T3-D1-02 — Routing, guard, navigasi, dan shell

**Tujuan:** seluruh layar dapat diakses sesuai role, dengan parameter yang benar, tanpa default palsu.

**File:**
- `apps/lib/app_router.dart`
- `apps/lib/app.dart`
- `apps/lib/routes/app_routes.dart`
- `apps/lib/features/organizer/shell/organizer_shell.dart`
- `apps/lib/features/admin/tabs/admin_tab_controller.dart`
- `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`
- `apps/test/app_router_test.dart`
- test baru `apps/test/features/navigation/**` bila perlu

**Pekerjaan:**
1. Perbaiki defect:
   - `/organizer/events/:id/attendees` → `AttendeeListScreen(eventId: id)` (bukan `const AttendeeListScreen()`).
   - `/staff/scanner` → `ScannerScreen(eventId: ...)`; `/staff/check-ins` → `CheckInHistoryScreen(eventId: ...)`.
   - `/organizer/team` tidak memakai `evt-1001`; ambil dari konteks/argumen.
   - `/organizer/events/:id/scanner` memakai konteks membership nyata (bukan `usr-org-001`).
   - `/e/:eventId/ticket/:ticketId` meneruskan `orderId` bila ada.
   - Hapus fallback `evt-1001` pada router.
2. Tambahkan route:
   - `/organizer/events/:id/orders` → `OrganizerOrderListScreen(eventId: id)`.
   - route yang diminta D2/D3 pada laporan masing-masing.
3. Guard:
   - publik: `/`, `/login`, `/register`, `/e/**`, `/invite/**`, `/registration/**`, `/access-denied`.
   - login + redirect: `/invite/:token`.
   - organizer: `/organizer/**` (owner check di layar/API).
   - admin: `/admin/**`.
   - staff: `/staff/**` berdasarkan membership, bukan role global.
4. Navigasi:
   - detail event → peserta, order, staff, scanner.
   - shell Organizer → event, peserta, order, laporan, plans, support, notifikasi.
   - shell Admin → dashboard, akun, event, laporan, paket, langganan, transaksi, settings, audit.
   - staff dashboard → scanner/riwayat sesuai permission.
5. Hapus `OrganizerMembershipContext.owner` hardcoded dari router.
6. Test router: setiap role, guest, parameter, guard, redirect.

**Kriteria:**
- K1 Guest dapat membuka `/e/:eventId` tanpa login.
- K2 `/admin/**` menolak non-admin; `/organizer/**` menolak non-organizer.
- K3 `/staff/scanner` membuka scanner dengan event benar.
- K4 `/organizer/events/:id/attendees` membuka daftar peserta event tersebut.
- K5 `/organizer/events/:id/orders` tersedia.
- K6 Tidak ada `evt-1001`/`usr-org-001` pada router.
- K7 Test router PASS.

---

### T3-D1-03 — Public event & guest journey end-to-end

**Tujuan:** alur guest dari tautan publik sampai tiket/QR berjalan pada API nyata.

**File:**
- `apps/lib/features/public_event/**`
- `apps/lib/features/registration/screens/registration_screen.dart`
- `apps/lib/features/events/screens/event_detail_screen.dart`
- `apps/lib/features/payments/**`
- `apps/lib/features/tickets/screens/ticket_list_screen.dart` (koordinasi D2)
- `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`
- `apps/lib/features/organizer/events/widgets/organizer_summary_widgets.dart`
- `apps/lib/services/public_event/**`, `services/order/**`, `services/payment/**`
- `backend/src/controllers/eventController.js`, `orderController.js`, `paymentController.js`, `services/emailService.js`
- test baru `apps/test/features/public_event/**`, `backend/test/guest_journey_tahap3.test.js`

**Pekerjaan:**
1. **QR tautan publik:**
   - ganti `OrganizerQrPlaceholder` dengan QR nyata dari `public_url` (`qr_flutter`),
   - tampilkan hanya bila event tayang; bila draft → placeholder status, bukan QR palsu,
   - tombol salin tautan.
2. **Landing publik:**
   - data event, jadwal, lokasi/online, poster (URL), kategori (harga, sisa kuota, periode),
   - state loading/error/unavailable/sold-out,
   - tombol daftar hanya bila ada kategori dapat dipesan.
3. **Registrasi guest:**
   - satu kategori (radio), satu peserta,
   - field dinamis dari `attendee_fields` (semua tipe),
   - validasi required/tipe/opsi di UI dan server,
   - ringkasan harga dari server,
   - idempotency key,
   - `order_access_token` disimpan aman.
4. **Order/payment:**
   - order gratis → tiket langsung; berbayar → payment,
   - status `PENDING/PAID/EXPIRED/FAILED/CANCELLED` dengan aksi tepat,
   - order expired tidak dapat dibayar,
   - retry idempotent tidak membuat order ganda.
5. **Tiket:**
   - guest membuka tiket dengan order token,
   - QR nyata dari token,
   - tautan email mengarah ke `/e/:eventId/ticket/:ticketId`,
   - bila order token tidak tersedia (browser/perangkat lain), tampilkan pesan jujur dan cara mengakses; **jangan** mengklaim tiket terbuka. Catat sebagai known limitation bila tidak ada mekanisme aman.
6. **Event suspended/draft:** tidak dapat didaftari (UI + server).
7. Test:
   - guest tanpa login,
   - field wajib,
   - order 1 tiket,
   - harga server,
   - gratis vs berbayar,
   - expired,
   - tiket/QR.

**Kriteria:**
- K1 Guest membuka `/e/:eventId` tanpa akun.
- K2 Order tercipta dengan tepat 1 tiket/1 peserta/1 kategori.
- K3 Harga dan fee dari server; tidak dapat dimanipulasi.
- K4 Gratis langsung tiket; berbayar setelah `PAID`.
- K5 QR nyata dapat dipindai (dibuktikan bersama D2).
- K6 Order expired ditolak.
- K7 Tidak ada mock fallback.
- K8 Test backend + widget PASS.

---

### T3-D1-04 — Event lifecycle, form dinamis, dan publish

**Tujuan:** event valid tayang otomatis; Organizer dapat mengatur field pendaftaran bertipe; event invalid tetap privat dengan alasan.

**File:**
- `backend/src/controllers/eventController.js`
- `backend/src/routes/eventRoutes.js`
- `backend/src/utils/eventValidation.js`
- `backend/src/utils/eventResponse.js`
- `apps/lib/features/organizer/screens/event_form_screen.dart`
- `apps/lib/features/organizer/screens/event_management_screen.dart`
- `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart`
- `apps/lib/services/organizer_events/**`
- `apps/lib/models/event/**`
- test `backend/test/event_auto_publish.test.js`, `apps/test/features/organizer/events/**`

**Pekerjaan:**
1. Auto-publish:
   - validasi server terpusat,
   - `POST /api/events/:id/publish` → `PUBLISHED` bila valid; `422` + alasan bila tidak,
   - edit event `PUBLISHED` memicu validasi ulang; invalid → `DRAFT`,
   - `public_url` diisi saat publish dan saat serialize,
   - event invalid tidak muncul di `/api/events/public`.
2. Event suspended:
   - tidak muncul publik,
   - menolak order baru,
   - data lama tetap ada.
3. Form dinamis:
   - builder field: tambah/edit/hapus/urutkan,
   - tipe `text|textarea|number|date|select|checkbox`,
   - `required`, `options` untuk select,
   - validasi key unik dan tidak kosong,
   - simpan ke `events.attendee_fields`,
   - kompatibel dengan format lama array string.
4. Form publik membaca `attendee_fields` dan merender semua tipe.
5. Brosur: hanya URL tervalidasi; **jangan** membuat upload palsu.
6. Template tiket: desain default; jangan membuat selector palsu bila storage belum ada.
7. UI menampilkan alasan validasi yang dapat diperbaiki.
8. Test: publish valid/invalid, edit published, field builder, rendering publik.

**Kriteria:**
- K1 Event valid → `PUBLISHED` tanpa Admin.
- K2 Event invalid → `DRAFT` + alasan.
- K3 Edit published → invalid → `DRAFT` dan hilang publik.
- K4 Field dinamis tersimpan dan tampil di form publik.
- K5 Field wajib/tipe salah ditolak server.
- K6 Tidak ada upload/template palsu.
- K7 Test backend + widget PASS.

---

### T3-D1-05 — Backend integrasi lintas modul

**Tujuan:** backend konsisten, aman, dan semua modul terhubung.

**File:**
- `backend/src/app.js`
- `backend/src/config/**`
- `backend/src/middleware/**`
- `backend/src/controllers/eventController.js`, `orderController.js`, `paymentController.js`
- `backend/src/routes/eventRoutes.js`, `orderRoutes.js`, `paymentRoutes.js`
- `backend/src/services/emailService.js`, `notificationService.js`
- `backend/src/utils/eventValidation.js`, `eventResponse.js`, `orderResponse.js`
- test `backend/test/**` (perluasan)

**Pekerjaan:**
1. Route/mount:
   - pastikan semua route ter-mount dan tidak ada duplikasi,
   - 404 konsisten,
   - urutan route statis sebelum dinamis.
2. Permission/ownership:
   - cross-owner event → 403/404,
   - staff hanya event membership,
   - admin-only route menolak role lain,
   - guest order token hanya untuk order tersebut.
3. Order/payment:
   - quantity 1, satu attendee, satu item,
   - harga server; order lama tidak berubah,
   - idempotency tidak membuat order ganda,
   - status payment hanya backend,
   - expiry: order/payment expired tidak dapat dibayar; hold dilepas sesuai kontrak,
   - gratis langsung tiket; berbayar setelah `PAID`.
4. `ticket_hash`:
   - pastikan semua tiket (gratis/berbayar) memiliki hash,
   - backfill saat order gratis dibuat,
   - verifikasi dengan test.
5. Notifikasi:
   - buat notifikasi pada event penting: order `PAID`, tiket terbit, invitation accepted, event suspended (bila kontrak tersedia),
   - jangan mengklaim email terkirim tanpa status provider.
6. Audit:
   - pastikan aksi admin (suspend akun, suspend event, settings, paket) menulis `audit_logs`,
   - `platform_setting_history` untuk perubahan setting.
7. Event suspended:
   - tidak muncul publik,
   - order baru ditolak.
8. Konfigurasi:
   - `SIMULATED_PAYMENTS` hanya non-production,
   - `JWT_SECRET` wajib kuat,
   - `APP_PUBLIC_URL` benar,
   - CORS sesuai environment,
   - rate limit & body limit aktif.
9. Error envelope konsisten; pesan tidak membocorkan internal.
10. Test negatif keamanan (lihat §10).

**Kriteria:**
- K1 Seluruh endpoint ter-mount dan teruji.
- K2 Cross-owner/unauthorized ditolak.
- K3 Order/payment invariant terpenuhi.
- K4 `ticket_hash` ada untuk semua tiket.
- K5 Audit/settings history bertambah.
- K6 Event suspended tidak dapat didaftari.
- K7 Konfigurasi production diperiksa.
- K8 Test backend PASS.

---

### T3-D1-06 — Perbaikan bug lintas modul

**Tujuan:** menutup seluruh temuan D2/D3 dan temuan integrasi.

**Pekerjaan:**
1. Ambil seluruh `FAIL`/`BLOCKED`/permintaan integrasi dari laporan D2/D3.
2. Untuk setiap item:
   - reproduksi,
   - tentukan akar masalah,
   - perbaiki,
   - tambah test regresi,
   - catat file/alasan/dampak.
3. Fokus area yang rawan:
   - parameter route tidak diteruskan,
   - response API tidak cocok dengan model,
   - permission salah (`SCAN_TICKET` vs `VIEW_PARTICIPANTS`),
   - path API salah,
   - state UI tidak menangani error/empty,
   - data mock masih aktif,
   - angka fee/komisi salah,
   - event suspended masih bisa didaftari.
4. Jangan menutupi bug dengan fallback mock.
5. Tulis tabel bug di laporan §5.

**Kriteria:**
- Tidak ada `FAIL` terbuka dari D2/D3 tanpa alasan.
- Setiap perbaikan punya test/bukti.
- Tidak ada regresi pada test lama.

---

### T3-D1-07 — Audit & pembersihan file `backend` dan `apps/lib`

**Tujuan:** memastikan seluruh file yang ada digunakan atau memang diperlukan; tidak ada file mati/duplikat.

**Pekerjaan:**
1. **Inventaris:** buat daftar seluruh file `backend/src`, `backend/test`, `backend/scripts`, `apps/lib`, `apps/test`.
2. **Verifikasi referensi** untuk setiap kandidat:
   ```powershell
   Get-ChildItem -Recurse -Include *.dart,*.js -File |
     Select-String -Pattern "<nama-file-tanpa-ekstensi>"
   ```
   Cek juga `package.json`, `pubspec.yaml`, route, dokumentasi, dan test.
3. **Kandidat hapus (wajib diverifikasi):**
   - `backend/src/models/Event.js`, `Ticket.js`, `User.js` — tidak diimpor kode runtime; hanya `config/supabase.js`.
   - `backend/src/config/supabase.js` — legacy; hapus setelah models.
   - dependency `@supabase/supabase-js` — hapus bila tidak dipakai; perbarui lock; catat.
   - `apps/lib/features/scanner/widgets/scanner_placeholder.dart` — bila tidak dipakai setelah kamera.
   - `OrganizerQrPlaceholder` — hapus setelah QR nyata menggantikannya.
   - method mati di `OrganizerOperationsRepository` (scanner/offline/assisted) — setelah D2 pindah ke `ScannerService`.
   - data mock di `admin_revenue_service.dart`, `admin_package_service.dart`, `organizer_plans_service.dart` — setelah D3 rewrite.
   - antrean offline di `CheckInService` — setelah D2 hapus.
4. **Konsolidasi duplikat:**
   - `notificationService.js` vs `notificationController.js` — pastikan satu sumber pembuatan notifikasi.
   - `eventSummary.js` vs query di controller — pilih satu, hapus yang tidak dipakai.
   - `orderResponse.js` vs serialisasi manual — konsolidasikan.
   - `mock_attendee_repository.dart` vs data mock di repository operasional — satu sumber.
5. **Test di luar direktori test:**
   - cari `*_test.dart`/`*.test.js` di luar `apps/test`/`backend/test`,
   - jangan hapus file plugin di `apps/*/flutter/ephemeral/**`,
   - hapus hanya file test proyek yang tidak dipakai tooling.
6. **Pertahankan:**
   - `backend/prisma/**`, `backend/supabase/**`, `backend/scripts/**`,
   - seluruh test di `apps/test`/`backend/test`,
   - `docs/**`, `README.md`, `backend/README.md`, `PRD.md`, `task/**`,
   - konfigurasi build Flutter, `.github/**`, `.githooks/**`,
   - mock demo `MOCK_MODE=true`, `assisted_registration_screen.dart` (disembunyikan).
7. Setelah setiap penghapusan: jalankan `npm test`, `flutter analyze`, `flutter test`.
8. Tulis tabel di laporan: file, alasan, bukti referensi, hasil test.

**Kriteria:**
- K1 Tidak ada file mati tanpa referensi.
- K2 Tidak ada duplikasi service/helper yang jelas.
- K3 Test tetap PASS setelah pembersihan.
- K4 File wajib (config/migration/docs/test) tetap ada.
- K5 Bukti grep + daftar file dihapus dilampirkan.

---

### T3-D1-08 — Dokumentasi dan runbook

**Tujuan:** dokumentasi sesuai kondisi aktual dan dapat diikuti orang lain.

**File:**
- `README.md`
- `backend/README.md`
- `docs/ARCHITECTURE.md`
- `docs/DATABASE.md`
- `task/RUNBOOK_OPERASIONAL.md` (baru)
- `task/PRD_TRACEABILITY_MATRIX.md`
- `task/FINAL_ACCEPTANCE_CHECKLIST.md` (root — banner)
- `task/PEMBAGIAN_TUGAS_FINAL.md` (baris Tahap 3)
- `backend/.env.example` (nama variabel saja)

**Pekerjaan:**
1. `README.md`: prasyarat, versi tool, instalasi, menjalankan backend/Flutter, mode `MOCK_MODE`, perintah test, akun admin provisioning, troubleshooting.
2. `backend/README.md`: seluruh endpoint aktual (auth, event, ticket type, order, payment, ticket, check-in, invitation, membership, attendee, export, order per event, admin, plan, subscription, revenue, report, notification, organizer), role/permission, contoh request/response ringkas.
3. `docs/ARCHITECTURE.md`: struktur, alur per role, lifecycle event, dua tautan, QR/check-in, admin governance, keputusan C-01/C-02/C-03.
4. `docs/DATABASE.md`: perbarui bagian yang usang (scanner memakai `token_hash`, audit/settings sudah dipakai, status migration).
5. `task/RUNBOOK_OPERASIONAL.md`: start/stop, health check, backup/restore, rotasi JWT/token, retry email, penanganan insiden, smoke test.
6. `task/PRD_TRACEABILITY_MATRIX.md`: regenerasi status per AC dengan bukti.
7. `task/PEMBAGIAN_TUGAS_FINAL.md`: perbarui baris Tahap 3 agar menunjuk `TAHAP_3/README_TAHAP_3.md` (model FASE 1/FASE 2), bukan Developer 4.
8. `task/FINAL_ACCEPTANCE_CHECKLIST.md` (root): banner bahwa versi aktif adalah `TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`.
9. Verifikasi setiap perintah yang ditulis di dokumentasi (jalankan bila aman).
10. Jangan menulis secret/kredensial.

**Kriteria:**
- K1 Dokumentasi sesuai kode aktual.
- K2 Perintah di dokumentasi dapat dijalankan.
- K3 Runbook lengkap.
- K4 Tidak ada instruksi destruktif tanpa peringatan.
- K5 Tidak ada secret.

---

### T3-D1-09 — Verifikasi menyeluruh & uji manual

**Tujuan:** membuktikan aplikasi berjalan, bukan hanya test hijau.

**Pekerjaan:**
1. Jalankan seluruh perintah §10.1.
2. Uji manual per role (minimal satu skenario penuh):
   - Organizer: register/login → buat event → kategori → publish → salin tautan.
   - Guest: buka tautan → daftar → order → bayar → tiket/QR.
   - Staff: undang → login email cocok → terima → scanner → check-in → riwayat.
   - Organizer: peserta paid-first → detail → export CSV → order → revenue.
   - Admin: akun/suspend → audit → settings → overview → paket → langganan → moderasi → laporan → notifikasi.
3. Uji negatif keamanan §10.3.
4. Web responsif 360/768/1280/1920; keyboard/focus.
5. Android build + alur inti + kamera (atau `NOT RUN` beralasan).
6. Email: kirim nyata bila kredensial tersedia; bila tidak, `NOT RUN` dengan alasan.
7. Database: query read-only untuk membuktikan data tersimpan (order, attendee, ticket hash, check_ins, audit, settings history).
8. Catat status per platform.

**Kriteria:**
- K1 Seluruh alur role berjalan pada API nyata.
- K2 Tidak ada error kritis.
- K3 Data tersimpan dan terbaca ulang.
- K4 Status platform jujur.
- K5 Bukti dilampirkan.

---

### T3-D1-10 — Final acceptance & laporan

**Pekerjaan:**
1. Isi `TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md` setiap baris dengan status + bukti + tanggal + pelaksana.
2. Tentukan status akhir:
   - **MVP SELESAI** — syarat terpenuhi.
   - **SIAP DIUJI PENGGUNA** — syarat tambahan.
   - **SIAP DEPLOYMENT** — semua gate termasuk Web/Android/email/operasional.
3. Tulis `LAPORAN_TAHAP_3_DEVELOPER_1.md` sesuai §12.
4. Pastikan tidak ada `FAIL` terbuka tanpa penjelasan; `BLOCKED`/`NOT RUN` punya alasan konkret.
5. Serahkan hasil ke pemilik proyek.

**Kriteria:**
- K1 Checklist terisi.
- K2 Status akhir sesuai bukti.
- K3 Laporan lengkap.
- K4 Tidak ada klaim tanpa bukti.

---

## 4. File backend yang menjadi tanggung jawab Developer 1

### 4.1 Wajib diimplementasikan/diperbaiki

```
backend/src/app.js
backend/src/config/env.js
backend/src/config/db.js
backend/src/middleware/authMiddleware.js
backend/src/middleware/errorMiddleware.js
backend/src/middleware/notFoundMiddleware.js
backend/src/middleware/rateLimitMiddleware.js
backend/src/middleware/roleMiddleware.js
backend/src/middleware/validationMiddleware.js
backend/src/controllers/eventController.js
backend/src/controllers/orderController.js
backend/src/controllers/paymentController.js
backend/src/controllers/ticketTypeController.js
backend/src/controllers/authController.js
backend/src/controllers/organizerProfileController.js
backend/src/routes/eventRoutes.js
backend/src/routes/orderRoutes.js
backend/src/routes/paymentRoutes.js
backend/src/routes/ticketTypeRoutes.js
backend/src/routes/authRoutes.js
backend/src/services/emailService.js
backend/src/services/authService.js
backend/src/services/adminBootstrapService.js
backend/src/services/seedService.js
backend/src/utils/eventValidation.js
backend/src/utils/eventResponse.js
backend/src/utils/eventSummary.js
backend/src/utils/orderResponse.js
backend/src/utils/response.js
backend/src/utils/validators.js
backend/src/utils/constants.js
backend/src/utils/logger.js
backend/src/validators/authValidator.js
backend/test/event_auto_publish.test.js
backend/test/event_public_links.test.js
backend/test/event_ownership_rules.test.js
backend/test/event_response.test.js
backend/test/event_summary.test.js
backend/test/attendee_dynamic_fields.test.js
backend/test/order_*.test.js
backend/test/payment_simulation.test.js
backend/test/auth_contract.test.js
backend/test/security_and_services.test.js
backend/test/stage1_integration.test.js
backend/test/stage2_integration.test.js
backend/test/guest_journey_tahap3.test.js          (baru)
backend/test/d1_integration_tahap3.test.js         (baru)
```

### 4.2 File D2/D3 yang boleh diperbaiki D1 pada FASE 2

Hanya bila diperlukan untuk integrasi. Catat di laporan.

```
backend/src/controllers/checkInController.js
backend/src/controllers/ticketController.js
backend/src/controllers/eventInvitationController.js
backend/src/controllers/adminController.js
backend/src/controllers/auditLogController.js
backend/src/controllers/platformSettingsController.js
backend/src/controllers/adminOverviewController.js
backend/src/controllers/planController.js
backend/src/controllers/subscriptionController.js
backend/src/controllers/revenueController.js
backend/src/controllers/reportController.js
backend/src/controllers/notificationController.js
backend/src/controllers/eventMetricsController.js
backend/src/routes/checkInRoutes.js
backend/src/routes/ticketRoutes.js
backend/src/routes/invitationsRoutes.js
backend/src/routes/meRoutes.js
backend/src/routes/adminRoutes.js
backend/src/routes/planRoutes.js
backend/src/routes/subscriptionRoutes.js
backend/src/routes/revenueRoutes.js
backend/src/routes/reportRoutes.js
backend/src/routes/notificationRoutes.js
backend/src/routes/organizerRoutes.js
backend/src/services/ticketTokenService.js
backend/src/services/notificationService.js
backend/src/utils/auditLog.js
backend/src/validators/ticketValidator.js
```

### 4.3 File beku

```
backend/prisma/schema.prisma
backend/prisma/migrations/**
backend/supabase/**
```

Tidak boleh diubah atau dijalankan.

---

## 5. File frontend (`apps/lib`) yang menjadi tanggung jawab Developer 1

### 5.1 Wajib diimplementasikan/diperbaiki

> Catatan: `features/organizer/shell/organizer_shell.dart` dan `features/admin/tabs/admin_tab_controller.dart` dimiliki D3 pada FASE 1; D1 baru mengeditnya pada FASE 2 untuk integrasi navigasi.

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/main.dart
apps/lib/routes/app_routes.dart
apps/lib/core/**
apps/lib/providers/auth_provider.dart
apps/lib/providers/event_provider.dart
apps/lib/providers/order_provider.dart
apps/lib/providers/payment_provider.dart
apps/lib/services/api/**
apps/lib/services/auth/**
apps/lib/services/event/**
apps/lib/services/order/**
apps/lib/services/payment/**
apps/lib/services/public_event/**
apps/lib/services/organizer_events/**
apps/lib/models/event/**
apps/lib/models/order/**
apps/lib/models/payment/**
apps/lib/models/user/**
apps/lib/features/auth/**
apps/lib/features/events/**
apps/lib/features/home/**
apps/lib/features/orders/**
apps/lib/features/payments/**
apps/lib/features/public_event/**
apps/lib/features/registration/**
apps/lib/features/organizer/events/**
apps/lib/features/organizer/screens/event_form_screen.dart
apps/lib/features/organizer/screens/event_management_screen.dart
apps/lib/features/organizer/screens/organizer_profile_screen.dart
apps/lib/features/organizer/shell/organizer_shell.dart
apps/lib/features/admin/tabs/admin_tab_controller.dart
apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart
apps/test/app_router_test.dart
apps/test/widget_test.dart
apps/test/stage1_integration_test.dart
apps/test/stage2_integration_test.dart
apps/test/services/api_mode_no_fallback_test.dart
apps/test/helpers/test_mock_server.dart
apps/test/features/auth/**
apps/test/features/orders/**
apps/test/features/registration/**
apps/test/features/public_event/**
apps/test/features/organizer/events/**
```

### 5.2 File D2/D3 yang boleh diperbaiki D1 pada FASE 2

```
apps/lib/features/tickets/**
apps/lib/features/scanner/**
apps/lib/features/check_in/**
apps/lib/features/staff/**
apps/lib/features/organizer/membership/**
apps/lib/features/organizer/screens/staff_management_screen.dart
apps/lib/features/organizer/operations/**
apps/lib/features/organizer/plans/**
apps/lib/features/organizer/support/**
apps/lib/features/organizer/screens/attendee_list_screen.dart
apps/lib/features/organizer/screens/organizer_order_list_screen.dart
apps/lib/features/organizer/screens/organizer_dashboard_screen.dart
apps/lib/features/admin/**
apps/lib/features/reports/**
apps/lib/features/notifications/**
apps/lib/services/ticket/**
apps/lib/services/scanner/**
apps/lib/services/check_in/**
apps/lib/services/organizer_membership/**
apps/lib/services/admin/**
apps/lib/services/organizer_operations/**
apps/lib/services/organizer_plans/**
apps/lib/services/organizer_support/**
apps/lib/services/organizer_notifications/**
apps/lib/services/organizer_shell/**
apps/lib/services/report/**
apps/lib/services/notification/**
apps/lib/providers/check_in_provider.dart
apps/lib/providers/report_provider.dart
apps/lib/providers/notification_provider.dart
apps/lib/models/ticket/**
apps/lib/models/check_in/**
apps/lib/models/admin/**
apps/lib/models/report/**
```

### 5.3 File integrasi bersama

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/routes/app_routes.dart
apps/lib/core/**
apps/lib/services/api/api_service.dart
apps/pubspec.yaml
apps/pubspec.lock
apps/analysis_options.yaml
backend/src/app.js
README.md
backend/README.md
docs/**
task/**
```

---

## 6. File integrasi bersama dan cara menanganinya

| File | Fungsi | Aturan |
|---|---|---|
| `apps/lib/app_router.dart` | Semua route & guard | Satu sumber route; tidak boleh ada default palsu |
| `apps/lib/routes/app_routes.dart` | Konstanta path | Tambah path helper untuk route baru |
| `apps/lib/app.dart` | AuthGate/bootstrap | Jangan memaksa login pada route publik |
| `apps/lib/services/api/api_service.dart` | HTTP client | Jangan mengubah kontrak error tanpa alasan |
| `apps/pubspec.yaml` | Dependency | Dependency baru harus dicatat & diuji |
| `backend/src/app.js` | Mount route | Urutan route statis sebelum dinamis |
| `backend/src/middleware/**` | Auth/role/error/limit | Perubahan harus diuji seluruh role |
| `README.md`, `docs/**`, `backend/README.md` | Dokumentasi | D1 satu-satunya editor |
| `task/**` | Perencanaan & laporan | Jangan ubah laporan historis Tahap 1/2 |

Aturan:
1. Setiap perubahan `app_router.dart` harus disertai test.
2. Setiap perubahan `app.js` harus disertai test route/mount.
3. Setiap perubahan `api_service.dart` harus dicek dampaknya ke semua service.
4. Setiap dependency baru harus diuji `flutter pub get`, `analyze`, `test`, build.

---

## 7. Protokol perbaikan bug lintas modul

1. **Catat** bug: ID, gejala, langkah reproduksi, file, bukti.
2. **Reproduksi** dengan test atau langkah manual.
3. **Tentukan akar masalah** (bukan gejala).
4. **Perbaiki** di lapisan yang tepat:
   - backend jika data/otorisasi salah,
   - service jika parsing/kontrak salah,
   - UI jika state/layout salah.
5. **Tambah test regresi.**
6. **Jalankan seluruh suite** (bukan hanya test terkait).
7. **Catat** di laporan §5: file, alasan, dampak.
8. **Jangan** menutupi dengan mock/fallback.
9. **Jangan** menghapus test yang gagal; perbaiki kode atau test jika test memang salah (dengan alasan).
10. Bila bug berasal dari keputusan produk yang belum final (C-01/C-02/C-03), catat `BLOCKED` dengan dokumen keputusan; jangan mengarang aturan.

---

## 8. Audit dan pembersihan file (ringkasan eksekusi)

Detail ada di T3-D1-07. Ringkasan urutan:

1. Inventaris `backend/src`, `backend/test`, `backend/scripts`, `apps/lib`, `apps/test`.
2. Untuk setiap kandidat: grep referensi → cek route/import/test/docs → putuskan.
3. Hapus/konsolidasikan.
4. Jalankan seluruh test.
5. Catat bukti.

Kandidat utama:
- `backend/src/models/{Event,Ticket,User}.js` + `backend/src/config/supabase.js` + dependency `@supabase/supabase-js`.
- `apps/lib/features/scanner/widgets/scanner_placeholder.dart`.
- `OrganizerQrPlaceholder`.
- Mock data di service Admin/Plans.
- Method scanner/offline/assisted mati di `OrganizerOperationsRepository`.
- Antrean offline `CheckInService`.

Jangan hapus:
- migration, schema, seed/tooling, docs, test di direktori test, mock demo `MOCK_MODE`, assisted registration screen.

---

## 9. Dokumentasi dan runbook (ringkasan eksekusi)

Detail ada di T3-D1-08. Wajib diperbarui:

1. `README.md` — instalasi, mode, test, provisioning.
2. `backend/README.md` — seluruh endpoint + role.
3. `docs/ARCHITECTURE.md` — alur per role, lifecycle, QR/check-in, admin.
4. `docs/DATABASE.md` — token hash, audit/settings, status migration.
5. `task/RUNBOOK_OPERASIONAL.md` — operasional & insiden.
6. `task/PRD_TRACEABILITY_MATRIX.md` — status AC + bukti.
7. `task/PEMBAGIAN_TUGAS_FINAL.md` — baris Tahap 3 → dokumen ini.
8. `task/FINAL_ACCEPTANCE_CHECKLIST.md` (root) — banner versi aktif.
9. `backend/.env.example` — nama variabel, tanpa nilai secret.

---

## 10. Pengujian menyeluruh

### 10.1 Perintah wajib

| Pemeriksaan | Perintah | Kriteria |
|---|---|---|
| Backend test | `cd backend; npm test` | PASS, 0 gagal |
| Backend sintaks | `cd backend; npm run check` | PASS |
| Backend format | `cd backend; npm run format:check` | PASS |
| Sinkronisasi config | `cd backend; npm run test:sync-config` | PASS |
| Skill/doc | `cd backend; npm run validate:skills` | PASS |
| Flutter analyze | `cd apps; flutter analyze` | 0 issue |
| Flutter test | `cd apps; flutter test` | PASS |
| Mode API | `cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | PASS |
| Build Web | `cd apps; flutter build web` | Berhasil |
| Build Android | `cd apps; flutter build apk --debug` | Berhasil atau `NOT RUN` |

### 10.2 Matriks E2E manual

| ID | Alur | Peran | Bukti |
|---|---|---|---|
| E2E-01 | Register/login Organizer | Organizer | Screenshot/log |
| E2E-02 | Buat event + kategori | Organizer | Screenshot/API |
| E2E-03 | Publish valid | Organizer | API response `PUBLISHED` |
| E2E-04 | Publish invalid | Organizer | `422` + alasan |
| E2E-05 | Buka `public_url` | Guest | Screenshot |
| E2E-06 | Registrasi 1 tiket | Guest | Order response |
| E2E-07 | Bayar simulasi | Guest | Status `PAID` |
| E2E-08 | Tiket + QR | Guest | Screenshot QR |
| E2E-09 | Undang staff | Organizer | `invite_url` |
| E2E-10 | Terima undangan | Staff | Membership aktif |
| E2E-11 | Scan + check-in | Staff | `check_ins` |
| E2E-12 | Scan ulang | Staff | `ALREADY_USED` |
| E2E-13 | Riwayat check-in | Staff | Screenshot |
| E2E-14 | Peserta paid-first | Organizer | Screenshot |
| E2E-15 | Export CSV | Organizer | File/preview |
| E2E-16 | Order per event | Organizer | Screenshot |
| E2E-17 | Revenue Organizer | Organizer | Screenshot |
| E2E-18 | Suspend akun + audit | Admin | Screenshot/DB |
| E2E-19 | Settings + history | Admin | Screenshot/DB |
| E2E-20 | Overview/revenue/paket/langganan | Admin | Screenshot |
| E2E-21 | Suspend event | Admin | Event hilang publik |
| E2E-22 | Laporan/notifikasi | Admin/Organizer | Screenshot |

### 10.3 Uji negatif keamanan

| ID | Skenario | Harapan |
|---|---|---|
| N-01 | Order quantity 2 | Ditolak 400/422 |
| N-02 | Harga dimanipulasi | Diabaikan; harga server |
| N-03 | Client memaksa `PAID` | Ditolak |
| N-04 | Guest membaca order lain | 401/403/404 |
| N-05 | Scan tiket event lain | `WRONG_EVENT`, tanpa check-in |
| N-06 | Scan tiket belum dibayar | `PAYMENT_REQUIRED` |
| N-07 | Scan ulang | `ALREADY_USED`, tanpa baris baru |
| N-08 | Staff tanpa permission scan | 403 |
| N-09 | Invitation expired/revoked/email lain | 403/410 |
| N-10 | Non-admin `/api/admin/*` | 403 |
| N-11 | Organizer edit event orang lain | 403/404 |
| N-12 | Tiket tanpa order token | 401/403 |
| N-13 | Event suspended menerima order | Ditolak |
| N-14 | CSV formula injection | Di-escape |
| N-15 | Rate limit login/order | 429 |

### 10.4 Platform

| Platform | Wajib | Status |
|---|---|---|
| Web Chrome 1280 | Ya | PASS/NOT RUN |
| Web responsif 360/768/1920 | Ya | PASS/NOT RUN |
| Android build + alur inti | Ya | PASS/NOT RUN |
| Kamera Android/Web | Ya | PASS/NOT RUN |
| Email SMTP nyata | Bila kredensial | PASS/NOT RUN |
| Database PostgreSQL | Bila akses | PASS/NOT RUN |

### 10.5 Pemeriksaan performa

Cakupan: daftar peserta, export CSV, order per event, audit log, dashboard/overview Admin, riwayat check-in, dan scan.

| Pemeriksaan | Kriteria | Bukti |
|---|---|---|
| Pagination | Endpoint daftar memakai `page`/`limit`; UI tidak memuat seluruh data sekaligus | Request + response |
| Agregasi di SQL | Overview/revenue/summary memakai agregasi query, bukan loop di Node/Flutter | Review kode |
| N+1 | Endpoint daftar tidak memicu query per baris | Review + log query |
| Query utama | `EXPLAIN` read-only pada data uji; tidak ada sequential scan besar yang tidak disengaja | Output `EXPLAIN` |
| Scan/check-in | Respons wajar pada data uji; tetap satu transaksi atomik | Bukti uji |
| Sebelum/sesudah | Catat angka sebelum dan sesudah perbaikan | Tabel |

Larangan: mengubah index/schema (cukup proposal), menambah dependency, atau mengklaim angka tanpa pengukuran. Bila data uji/DB tidak tersedia → `NOT RUN` dengan alasan konkret.

---

## 11. Validasi seluruh kebutuhan PRD

Developer 1 wajib memetakan setiap AC ke bukti. Jangan menandai PASS hanya karena test otomatis.

| AC | Kebutuhan | Task | Bukti minimum |
|---|---|---|---|
| AC-01 | Event invalid tidak publik; valid auto-publish; suspend menolak order | T3-D1-04, T3-D1-05 | Test + API + UI |
| AC-02 | Cross-owner/unauthorized ditolak backend | T3-D1-05, T3-D1-09 | Test negatif |
| AC-03 | Order 1 kategori/1 attendee/1 tiket; harga server; idempotent | T3-D1-03, T3-D1-05 | Test + order response |
| AC-04 | Registrasi publik tanpa akun; tanpa assisted | T3-D1-02, T3-D1-03 | Uji guest + UI |
| AC-05 | Invitation scoped; invalid/expired/revoked/wrong email ditolak; scanner langsung | T3-D2-03/04 (D2) + T3-D1-02 | Test + uji staff |
| AC-06 | Payment hanya backend; status dibedakan; non-PAID tidak terbit tiket | T3-D1-03, T3-D1-05 | Test + status UI |
| AC-07 | PAID → satu tiket/QR; gratis langsung terbit | T3-D2-02 + T3-D1-03 | Test + QR |
| AC-08 | Validasi server; satu scan sukses; duplicate/wrong/unpaid/unauthorized ditolak | T3-D2-04/05/06 + T3-D1-09 | Test + device |
| AC-09 | Paid-first lalu nomor registrasi; layar = export | T3-D3-02/03 + T3-D1-09 | Bukti CSV |
| AC-10 | State lengkap; tanpa mock fallback; responsif | T3-D2-07, T3-D3-09, T3-D1-02/09 | Widget + manual |

Kebutuhan PRD lain yang wajib diverifikasi:

| PRD | Kebutuhan | Bukti |
|---|---|---|
| §3 | Auto-publish + suspend-only | API/test |
| §4 | Kategori & form dinamis; brosur opsional | UI/test |
| §5 | Tiket default + QR unik | Screenshot/QR |
| §6.1 | Public link event Published | API + UI |
| §6.2 | Invitation staff + redirect scanner | Uji E2E |
| §7 | Satu order satu tiket; nomor registrasi; paid-first | Test/DB |
| §8 | Simulasi VA; status; fee 5.000/5%; guest token | Test/UI |
| §9 | Scanner online; token opaque; check-in atomik | Test/device |
| §11 | UI konsisten; loading/empty/error/retry; responsif | Screenshot |
| §12 | Backend sumber kebenaran; permission server | Review/test |
| §15 | C-01/C-02/C-03 tidak dikarang | Catatan asumsi |

Item yang tidak dapat dipenuhi (mis. upload brosur, template tiket, akses tiket lintas perangkat) wajib tetap ada di checklist dengan status `BLOCKED`/`NOT RUN` dan alasan — jangan dihapus.

---

## 12. Format laporan hasil pekerjaan

Buat `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_1.md` dengan struktur berikut. Nomor heading **di dalam blok** adalah struktur file laporan, bukan lanjutan nomor dokumen ini.

```markdown
# Laporan Tahap 3 — Developer 1 (FASE 2)

- Status: DONE / PARTIAL / BLOCKED
- Branch: Developer-1-T3
- Baseline commit:
- Commit akhir:
- PR: <link/ID>

## 1. Ringkasan
## 2. Intake FASE 1
| Gate | Hasil | Bukti |
| F1-G1 ... |

## 3. Daftar gap integrasi
| ID | Gap | File | Status | Bukti |

## 4. Hasil per task
### T3-D1-01 ...
- Pekerjaan:
- File diubah:
- Bukti:
- Status: PASS/FAIL/BLOCKED/NOT RUN

## 5. Perbaikan bug lintas modul
| ID | Bug | Akar masalah | Perbaikan | Test |

## 6. Perubahan pada file D2/D3
| File | Alasan | Perubahan | Dampak |

## 7. Audit & pembersihan
| File | Aksi | Alasan | Bukti referensi | Test |

## 8. Dokumentasi diperbarui
## 9. Bukti pengujian
| Perintah | Hasil | Jumlah test |

## 10. Status platform
| Platform | Status | Bukti/alasan |
| API | | |
| DB | | |
| Web | | |
| Android | | |
| Email | | |

## 11. Validasi PRD
| AC | Status | Bukti |

## 12. Known limitations / BLOCKED / NOT RUN
## 13. Status akhir proyek
- MVP SELESAI / SIAP DIUJI PENGGUNA / SIAP DEPLOYMENT
- Alasan:

## 14. Pernyataan kepatuhan
- [ ] Tidak mengubah schema/migration/seed
- [ ] Tidak ada secret
- [ ] Tidak ada klaim tanpa bukti
- [ ] Tidak ada Tahap 4
```

---

## 13. Larangan

1. Memulai sebelum FASE 1 selesai.
2. Menambah fitur di luar PRD.
3. Mengubah schema/migration/seed/supabase.
4. Menjalankan migration/reset/seed pada database bersama.
5. Menyimpan secret/token di kode, test, log, dokumen, atau laporan.
6. Menutupi bug dengan mock/fallback.
7. Menghapus test di direktori test.
8. Menghapus fitur non-MVP; cukup sembunyikan.
9. Mengklaim PASS tanpa perintah/bukti.
10. Memindahkan pekerjaan ke "Tahap 4".
11. Menyatakan production-ready tanpa bukti Web/Android/email/operasional.
12. Mengubah laporan historis Tahap 1/2.

---

## 14. Definisi selesai (DoD)

Aplikasi dinyatakan selesai di Tahap 3 bila:

1. Seluruh task T3-D1-01…T3-D1-10 selesai.
2. Seluruh temuan D2/D3 ditutup atau `BLOCKED` dengan alasan.
3. Tidak ada mock/fallback pada `MOCK_MODE=false` di layar in-scope.
4. Seluruh alur role berjalan pada API/DB nyata.
5. `FINAL_ACCEPTANCE_CHECKLIST.md` terisi setiap baris.
6. Seluruh perintah §10.1 PASS.
7. Web responsif terbukti; Android build/alur terbukti atau `NOT RUN` beralasan.
8. Dokumentasi dan runbook sesuai kondisi aktual.
9. Struktur file bersih; file mati/duplikat dihapus dengan bukti.
10. Status akhir diumumkan sesuai bukti.
11. Laporan D1 lengkap.
12. Tidak ada pekerjaan tersisa yang memerlukan tahap baru.

---

## 15. Risiko dan mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| D2/D3 meninggalkan mock tersembunyi | Demo terlihat jalan, data hilang | Grep + review per layar + test `MOCK_MODE=false` |
| Route tidak meneruskan parameter | Layar kosong/salah event | Test router per role |
| Kontrak response berubah | Parsing gagal | Kontrak V2 + test kontrak |
| `ticket_hash` tidak ada | Scan gagal | Backfill + test |
| Check-in ganda | Data ganda | Transaksi + unique + test konkurensi |
| Event suspended masih bisa didaftari | Pelanggaran PRD | Test negatif + filter publik |
| Fee 2.500/komisi lokal | Angka salah | Satu sumber server; review grep |
| Email tidak terkirim | Klaim palsu | Status provider; `NOT RUN` bila tidak ada SMTP |
| Web kamera butuh HTTPS | Scan web gagal | Uji origin aman + fallback manual |
| Android tidak tersedia | Tidak bisa klaim siap deployment | `NOT RUN` + alasan |
| Pembersihan file menghapus yang dipakai | Build gagal | Grep + test setelah setiap hapus |
| Perubahan D1 pada file D2/D3 menimbulkan regresi | Domain rusak | Catat + jalankan test domain |











