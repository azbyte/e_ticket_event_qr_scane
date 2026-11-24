# TAHAP 3 — README PELAKSANAAN FINAL

- **Versi:** 1.0 (2026-11-25)
- **Status:** Dokumen perencanaan aktif. Tidak ada source code yang diubah saat penyusunan.
- **Menggantikan:** rencana Tahap 3 sebelumnya yang sudah dihapus dari folder ini karena digantikan dokumen final: `RENCANA_KERJA.md` v3.1 (model Developer 4), `DEVELOPER_1/2/3_TASK.md` + `DEVELOPER_4_FINISHING_TASK.md` (20-11-2026), versi lama `FILE_OWNERSHIP.md` dan `INTEGRATION_CONTRACT.md` (20-11-2026), serta template `LAPORAN_DEVELOPER_1..4.md`. Baris Tahap 3 pada `task/PEMBAGIAN_TUGAS_FINAL.md` §2/§8 juga diselaraskan.
- **Isi folder ini:** hanya tujuh dokumen final (lihat §3). Laporan hasil kerja dibuat developer saat pelaksanaan dengan nama `LAPORAN_TAHAP_3_DEVELOPER_<N>.md`.
- **Acuan kebutuhan:** [`../../PRD.md`](../../PRD.md) v2.2.
- **Acuan kondisi teknis:** [`../ROADMAP_AUDIT_FINAL.md`](../ROADMAP_AUDIT_FINAL.md), laporan Tahap 2 D1/D2/D3, dan audit source code 2026-11-25.
- **Sifat:** rencana + instruksi kerja. Perintah pemilik proyek kepada developer adalah otorisasi implementasi.

> **Tidak ada Tahap 4.** Seluruh pekerjaan yang masih diperlukan berdasarkan PRD diselesaikan di Tahap 3. Bila ada item yang tidak dapat diselesaikan karena keputusan produk atau lingkungan eksternal, item tersebut dicatat `BLOCKED`/`NOT RUN` dengan alasan konkret di `FINAL_ACCEPTANCE_CHECKLIST.md` — bukan dipindahkan ke tahap baru.

---

## 0. Keputusan pelaksanaan yang mengikat

1. **FASE 1** — Developer 2 dan Developer 3 bekerja **bersamaan dan mandiri**. Tidak ada pekerjaan implementasi Developer 1 pada fase ini.
2. **FASE 2** — Developer 1 mulai **hanya setelah** Developer 2 dan Developer 3 menyerahkan hasil lengkap (kode + test + laporan) dan gate F1 lulus.
3. Developer 2 dan Developer 3 **tidak boleh mengubah file yang sama**. File bersama menjadi tanggung jawab Developer 1.
4. Kontrak integrasi, matriks kepemilikan file, spesifikasi endpoint, dan DTO **sudah ditetapkan pada dokumen ini dan `INTEGRATION_CONTRACT.md`**. Developer 2/3 tidak menunggu keputusan Developer 1 untuk mulai bekerja.
5. Developer 1 bukan hanya integrator. Developer 1 wajib melakukan **implementasi nyata** pada backend dan `apps/lib`: routing, event lifecycle, form dinamis, guest journey, perbaikan lintas modul, audit/pembersihan, dokumentasi, dan acceptance.
6. Tidak ada fitur wajib PRD yang boleh dihapus dari checklist karena belum bisa dipenuhi. Status wajib jujur: `PASS`, `FAIL`, `BLOCKED`, atau `NOT RUN`.

---

## 1. Baseline terverifikasi (2026-11-25)

Baseline commit: `78e19f0` (`update/featur`, HEAD saat dokumen ini disusun).

| Pemeriksaan | Perintah | Hasil baseline |
|---|---|---|
| Backend test | `cd backend; npm test` | **PASS** — 163 test, 0 gagal |
| Backend sintaks | `cd backend; npm run check` | **PASS** — 67 file JavaScript |
| Backend format | `cd backend; npm run format:check` | **PASS** |
| Flutter analyze | `cd apps; flutter analyze --no-pub` | **PASS** — 0 issue |
| Flutter test | `cd apps; flutter test --no-pub` | **PASS** — 238 test |

Baseline ini **bukan** bukti aplikasi selesai. Test hijau tidak membuktikan integrasi API nyata, perangkat, Web, email, atau database. Lihat §1.1.

### 1.1 Kondisi nyata yang menjadi titik awal Tahap 3

Sudah tersedia dan tidak perlu dibangun ulang:

- Auth JWT + role, event & kategori tiket, order satu tiket, pembayaran simulasi, tiket, check-in atomik, invitation, audit/settings/overview admin, export peserta, order per event, notifikasi, laporan dukungan, paket/langganan/revenue.
- QR tiket memakai `qr_flutter` (`apps/lib/features/tickets/widgets/qr_ticket_display.dart`).
- Scanner memakai `mobile_scanner` dan tidak lagi menawarkan mode offline pada alur MVP.
- `GET /api/me/memberships`, `GET /api/invitations/:token`, `POST /api/events/:id/publish`, `GET /api/events/:id/orders`, `GET /api/events/:id/attendees/export`, `GET /api/admin/audit-logs`, `GET/PUT /api/admin/settings`, `GET /api/admin/overview`, `GET /api/admin/subscriptions` sudah ter-mount.
- Halaman penerimaan undangan `apps/lib/features/staff/screens/accept_invitation_screen.dart` sudah ada.

Masih belum selesai / masih bermasalah (menjadi pekerjaan Tahap 3):

| # | Temuan | Bukti awal | Penanggung jawab |
|---|---|---|---|
| G-01 | `AdminRevenueService` dan `AdminPackageService` masih 100% in-memory | `apps/lib/services/admin/admin_revenue_service.dart`, `admin_package_service.dart` tidak memakai `ApiClient` | D3 |
| G-02 | `OrganizerPlansService` masih in-memory | `apps/lib/services/organizer_plans/organizer_plans_service.dart` | D3 |
| G-03 | Export peserta masih dibuat lokal dari repository, bukan dari endpoint export | `attendee_list_screen.dart` → `_repo.exportAttendeesCsv(...)` | D3 |
| G-04 | `fetchEventReportFromApi` menelan error dan diam-diam kembali ke data mock | `organizer_operations_repository.dart` blok `catch (_) { return getEventReport(eventId); }` | D3 |
| G-05 | Admin audit/settings service diam-diam memakai cache/mock saat API gagal | `admin_audit_log_service.dart:141-142`, `admin_settings_service.dart:81-82` | D3 |
| G-06 | Dashboard Admin masih memakai `fallbackRevenue` dan angka konstanta | `admin_dashboard_screen.dart:63-87` | D3 |
| G-07 | Moderasi event masih default `pendingReview` dan menampilkan aksi approve/reject | `event_moderation_screen.dart:38, 335, 403` | D3 |
| G-08 | Notifikasi Organizer mengembalikan mock saat API gagal | `organizer_notifications_service.dart:101` | D3 |
| G-09 | Organizer dashboard memakai `org-001` hardcoded | `organizer_dashboard_screen.dart:46` | D3 |
| G-10 | `OrganizerOperationsRepository` masih menginisialisasi data mock dan menyimpan mock scanner/offline/assisted | `organizer_operations_repository.dart:218, 236-348, 787` | D3 |
| G-11 | `OrganizerScannerScreen` masih memakai repository operasional, bukan `ScannerService` | `organizer_scanner_screen.dart:33-34` | D2 |
| G-12 | `CheckInService` masih menyimpan antrean offline dan `sync` Post-MVP | `check_in_service.dart:40-41, 197-230` | D2 |
| G-13 | Layar check-in & scanner memiliki default `evt-1001` | `check_in_screen.dart:13`, `check_in_history_screen.dart:13`, `app_router.dart:81` | D2 + D1 |
| G-14 | Staff dashboard memakai nama/judul/event default | `staff_dashboard_screen.dart:19-22` | D2 |
| G-15 | Team/staff management memiliki default `evt-1001` | `team_management_screen.dart:18`, `staff_management_screen.dart:14` | D2 |
| G-16 | Router tidak meneruskan `eventId` ke `AttendeeListScreen`; `/staff/scanner` dan `/staff/check-ins` diarahkan ke dashboard; belum ada route order Organizer | `app_router.dart:106-109, 183-201` | D1 |
| G-17 | `OrganizerQrPlaceholder` masih berupa pola pseudo-QR pada detail event | `organizer_event_detail_screen.dart:694`, `organizer_summary_widgets.dart:203` | D1 |
| G-18 | Form Organizer belum menyediakan builder field dinamis bertipe | laporan D1 Tahap 2 §7 menyatakan belum dikerjakan | D1 |
| G-19 | `backend/src/models/{Event,Ticket,User}.js` + `src/config/supabase.js` tidak direferensikan kode runtime (perlu verifikasi final) | grep referensi 2026-11-25 | D1 |
| G-20 | `apps/test/stage2_integration_test.dart`, `api_mode_no_fallback_test.dart`, `helpers/test_mock_server.dart` bersifat lintas domain | — | D1 |
| G-21 | `docs/DATABASE.md`, `docs/ARCHITECTURE.md`, `README.md`, `backend/README.md`, `task/PRD_TRACEABILITY_MATRIX.md` belum mencerminkan kondisi Tahap 2/3 | — | D1 |
| G-22 | Bukti E2E API/DB/Android/Web/email belum ada | laporan Tahap 2 banyak `NOT RUN` | D1 |

> Daftar di atas adalah **titik awal**, bukan daftar lengkap. Setiap developer wajib menambah temuan baru pada laporannya dengan bukti file/baris.

---

## 2. Model pelaksanaan

### 2.1 FASE 1 — Developer 2 + Developer 3 paralel

| Aspek | Aturan |
|---|---|
| Mulai | Bersamaan, dari baseline yang sama (`78e19f0` atau commit integrasi yang disepakati pemilik proyek) |
| Branch | `Developer-2-T3` dan `Developer-3-T3` |
| File | Hanya file pada `FILE_OWNERSHIP.md` Bagian 2 (D2) / Bagian 3 (D3) |
| File bersama | **Dilarang diedit.** Kebutuhan dicatat di laporan bagian "Permintaan Integrasi untuk Developer 1" |
| Router/aplikasi | D2/D3 tidak mengedit `app.dart`, `app_router.dart`, `routes/app_routes.dart`, `pubspec.yaml`, `backend/src/app.js` |
| Dokumentasi | D2/D3 tidak mengedit `README.md`, `docs/**`, `backend/README.md`; cukup menulis isi yang perlu didokumentasikan pada laporan |
| Selesai | Kode + test + laporan + bukti perintah; seluruh kriteria task terpenuhi |
| Gate | F1-G1 … F1-G7 (§5.1) |

D2 dan D3 **boleh** menjalankan seluruh test suite. Bila test milik developer lain gagal karena perubahan mereka, mereka **tidak boleh** mengedit test tersebut; kegagalan dilaporkan dengan bukti dan diselesaikan D1 pada FASE 2 (atau oleh owner file bila disepakati tertulis).

### 2.2 FASE 2 — Developer 1

| Aspek | Aturan |
|---|---|
| Mulai | Hanya setelah D2 dan D3 menyerahkan hasil dan F1-G1…F1-G7 lulus |
| Branch | `Developer-1-T3` (integrasi), boleh merge `Developer-2-T3` dan `Developer-3-T3` |
| File | Seluruh file bersama + seluruh file backend/frontend yang belum tercakup + perbaikan bug lintas modul |
| Wewenang | Final owner integrasi. Perubahan pada file D2/D3 diperbolehkan untuk memperbaiki integrasi, wajib dicatat (file, alasan, dampak) di laporan |
| Selesai | Seluruh task T3-D1-01…T3-D1-10 + checklist acceptance terisi + status akhir diumumkan |
| Gate | F2-G1 … F2-G10 (§5.2) |

### 2.3 Larangan urutan

- Developer 1 **tidak boleh** memulai implementasi (termasuk "bootstrap", "stub", atau "perbaikan kecil") sebelum FASE 1 selesai.
- Developer 2/3 **tidak boleh** menunggu Developer 1 untuk memulai. Kontrak sudah tersedia.
- Tidak boleh ada pekerjaan yang dipindahkan ke "Tahap 4".

---

## 3. Dokumen dan urutan baca

| Dokumen | Isi | Wajib dibaca oleh |
|---|---|---|
| `README_TAHAP_3.md` (ini) | Aturan main, fase, gate, ringkasan task, traceability | D1, D2, D3, pemilik proyek |
| `TUGAS_DEVELOPER_2.md` | Instruksi lengkap D2 | D2, D1 (saat intake) |
| `TUGAS_DEVELOPER_3.md` | Instruksi lengkap D3 | D3, D1 (saat intake) |
| `TUGAS_DEVELOPER_1.md` | Instruksi lengkap D1 | D1, pemilik proyek |
| `FILE_OWNERSHIP.md` | Kepemilikan file per fase + bukti tidak ada overlap | D1, D2, D3 |
| `INTEGRATION_CONTRACT.md` | Endpoint, DTO, permission, route, error, mock policy | D1, D2, D3 |
| `FINAL_ACCEPTANCE_CHECKLIST.md` | Checklist PRD + status + bukti | D1 (pengisi), pemilik proyek (verifikator) |

### 3.1 Urutan baca per developer

**Developer 2:**
1. `README_TAHAP_3.md` §0–§5.
2. `TUGAS_DEVELOPER_2.md` (seluruhnya).
3. `FILE_OWNERSHIP.md` Bagian 1, 2, 6, 7.
4. `INTEGRATION_CONTRACT.md` Bagian 1, 3, 4, 6, 7.
5. Source yang tercantum pada tugas.

**Developer 3:**
1. `README_TAHAP_3.md` §0–§5.
2. `TUGAS_DEVELOPER_3.md` (seluruhnya).
3. `FILE_OWNERSHIP.md` Bagian 1, 3, 6, 7.
4. `INTEGRATION_CONTRACT.md` Bagian 1, 3, 5, 6, 7.
5. Source yang tercantum pada tugas.

**Developer 1:**
1. `README_TAHAP_3.md` (seluruhnya).
2. `TUGAS_DEVELOPER_1.md` (seluruhnya).
3. `FILE_OWNERSHIP.md` (seluruhnya).
4. `INTEGRATION_CONTRACT.md` (seluruhnya).
5. Laporan D2 dan D3 + diff branch masing-masing.
6. `PRD.md`, `ROADMAP_AUDIT_FINAL.md` §10, `FINAL_ACCEPTANCE_CHECKLIST.md`.

---

## 4. Peta pekerjaan

### 4.1 Developer 2 — Ticketing, Staff Workspace, Scanner & Check-in

| ID | Judul | Output utama |
|---|---|---|
| T3-D2-01 | Audit awal & bukti baseline D2 | Daftar gap terverifikasi + baseline test |
| T3-D2-02 | Tiket, QR, dan akses tiket | QR nyata dari token, state tiket, akses pemilik, tanpa PII |
| T3-D2-03 | Invitation, membership, workspace staff | UI team via API, `invite_url`, accept flow, staff workspace nyata |
| T3-D2-04 | Scanner kamera & validasi online | Kamera + fallback manual, event dari membership, 6 status hasil |
| T3-D2-05 | Check-in tunggal & riwayat | Satu jalur check-in, anti-duplikasi, riwayat nyata + filter |
| T3-D2-06 | Backend tiket/check-in: konsolidasi & keamanan | `verify` → `check_ins`, hash gratis, permission, tanpa kebocoran token |
| T3-D2-07 | Regresi, bukti bebas mock, laporan | Test baru + hasil perintah + laporan |

### 4.2 Developer 3 — Peserta, Export, Back-office Organizer, Konsol Admin

| ID | Judul | Output utama |
|---|---|---|
| T3-D3-01 | Audit awal & bukti baseline D3 | Daftar gap terverifikasi + baseline test |
| T3-D3-02 | Daftar & detail peserta | API nyata, paid-first, nomor registrasi, permission, tanpa `evt-1001` |
| T3-D3-03 | Export CSV | CSV dari endpoint, urutan identik, escaping, bukti file |
| T3-D3-04 | Order & revenue Organizer | Order/payment per event + laporan dari API, tanpa fallback mock |
| T3-D3-05 | Admin akun, audit, settings | API nyata, alasan wajib, audit/history, fee 5.000 read-only |
| T3-D3-06 | Admin dashboard, revenue, paket, langganan | Semua dari API, tanpa angka konstanta, C-03 read-only |
| T3-D3-07 | Admin moderasi, laporan, notifikasi, plans/support | Suspend-only beralasan, laporan nyata, notifikasi API |
| T3-D3-08 | Konsolidasi repository operasional | Mock hanya `MOCK_MODE`, hapus jalur mati scanner/offline/assisted |
| T3-D3-09 | Regresi, bukti bebas mock, laporan | Test baru + hasil perintah + laporan |

### 4.3 Developer 1 — Integrasi, penyelesaian, audit, acceptance

| ID | Judul | Output utama |
|---|---|---|
| T3-D1-01 | Intake FASE 1 & baseline integrasi | Branch gabungan, gate awal, daftar gap |
| T3-D1-02 | Routing, guard, navigasi, shell | Router benar untuk semua role, tanpa default palsu |
| T3-D1-03 | Public event & guest journey E2E | Link publik, registrasi, order, bayar, tiket, QR, email |
| T3-D1-04 | Event lifecycle, form dinamis, publish | Auto-publish, builder field bertipe, validasi server |
| T3-D1-05 | Backend integrasi lintas modul | Route/mount, permission, expiry, hash, audit, env |
| T3-D1-06 | Perbaikan bug lintas modul | Seluruh temuan D2/D3 + temuan integrasi |
| T3-D1-07 | Audit & pembersihan file | File mati/duplikat dihapus setelah verifikasi referensi |
| T3-D1-08 | Dokumentasi & runbook | README, ARCHITECTURE, DATABASE, backend README, runbook |
| T3-D1-09 | Verifikasi menyeluruh & uji manual | Test, build, Web, Android, DB read-only, security |
| T3-D1-10 | Final acceptance & laporan | Checklist terisi + status akhir + laporan D1 |

---

## 5. Gate

### 5.1 Gate FASE 1 (F1)

| ID | Gate | Bukti minimum |
|---|---|---|
| F1-G1 | D2 dan D3 hanya mengubah file pada allow-list-nya | `git diff --name-only` per branch vs `FILE_OWNERSHIP.md` |
| F1-G2 | Tidak ada file yang diubah kedua developer | Irisan daftar file D2 dan D3 = kosong |
| F1-G3 | `npm test`, `npm run check`, `npm run format:check` PASS pada masing-masing branch | Log perintah |
| F1-G4 | `flutter analyze` 0 issue dan `flutter test` PASS pada masing-masing branch | Log perintah |
| F1-G5 | Tidak ada mock/fallback aktif pada `MOCK_MODE=false` untuk modul yang menjadi tanggung jawabnya | Hasil `Select-String` + review |
| F1-G6 | Seluruh kriteria task D2/D3 terpenuhi atau `BLOCKED` dengan alasan eksternal konkret | Laporan D2/D3 |
| F1-G7 | Laporan D2/D3 lengkap (format §11 masing-masing dokumen) | File laporan |

Bila salah satu gate gagal, FASE 2 **tidak dimulai**. Developer yang gagal memperbaiki sendiri; developer lain tidak perlu menunggu.

### 5.2 Gate FASE 2 (F2)

| ID | Gate | Bukti minimum |
|---|---|---|
| F2-G1 | Seluruh perintah verifikasi §6 PASS | Log perintah |
| F2-G2 | Tidak ada mock/fallback pada `MOCK_MODE=false` di seluruh layar in-scope | `Select-String` + review per layar |
| F2-G3 | Seluruh alur role berjalan pada API nyata | Bukti manual/otomatis per alur |
| F2-G4 | Data penting tersimpan dan terbaca ulang dari PostgreSQL | Query read-only + bukti UI |
| F2-G5 | Tidak ada error kritis/P0 terbuka | Daftar isu |
| F2-G6 | Struktur file bersih; tidak ada file mati tanpa referensi | Daftar file dihapus + bukti grep |
| F2-G7 | Dokumentasi dan runbook sesuai kondisi aktual | Dokumen + perintah yang diverifikasi |
| F2-G8 | Web responsif 360/768/1280/1920 terbukti atau `NOT RUN` beralasan | Screenshot/uji |
| F2-G9 | Android build & alur inti terbukti atau `NOT RUN` beralasan | Bukti build/device |
| F2-G10 | `FINAL_ACCEPTANCE_CHECKLIST.md` terisi setiap baris dengan status + bukti | Checklist |

---

## 6. Perintah verifikasi wajib

| Perintah | Lokasi | Kriteria |
|---|---|---|
| `npm test` | `backend/` | PASS, 0 gagal |
| `npm run check` | `backend/` | PASS |
| `npm run format:check` | `backend/` | PASS |
| `npm run test:sync-config` | `backend/` | PASS |
| `npm run validate:skills` | `backend/` | PASS |
| `flutter analyze` | `apps/` | 0 issue |
| `flutter test` | `apps/` | PASS |
| `flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | `apps/` | PASS |
| `flutter build web` | `apps/` | Berhasil (D1) |
| `flutter build apk --debug` | `apps/` | Berhasil atau `NOT RUN` beralasan (D1) |

Setiap laporan wajib menuliskan **perintah yang benar-benar dijalankan**, bukan perkiraan. Status `PASS` tanpa perintah adalah pelanggaran.

---

## 7. Dependensi yang sudah diselesaikan di perencanaan

Dependensi berikut **tidak boleh** menjadi alasan D2/D3 berhenti atau menunggu D1.

| # | Dependensi lama | Penyelesaian di dokumen |
|---|---|---|
| 1 | D2 butuh route `/invite/:token`, `/staff`, `/staff/:eventId` | Route sudah ada di `routes/app_routes.dart` dan `app_router.dart`; perbaikan parameter route menjadi tugas D1 (T3-D1-02). D2 membangun screen + navigasi internal. |
| 2 | D2 butuh `GET /api/me/memberships` | Sudah ada dan ter-mount (`meRoutes.js`). D2 hanya memakai. |
| 3 | D3 butuh `GET /api/events/:id/orders`, `/attendees/export`, `/admin/*` | Sudah ada dan ter-mount (`app.js:71-72`, `adminRoutes.js`). D3 hanya memakai. |
| 4 | D2/D3 butuh perubahan `backend/src/app.js` | Tidak perlu. Seluruh endpoint yang dibutuhkan sudah ter-mount. Bila ternyata perlu, dicatat untuk D1. |
| 5 | D2 butuh dependency QR/kamera | `qr_flutter` dan `mobile_scanner` sudah ada di `pubspec.yaml`. D2/D3 tidak mengedit `pubspec.yaml`. |
| 6 | D2/D3 butuh dokumentasi endpoint | D2/D3 menulis di laporan; D1 memperbarui `backend/README.md` (T3-D1-08). |
| 7 | `checkInController.js` dipakai D2 dan D3 | **Satu owner: D2.** D3 hanya membaca endpoint. Perubahan backend peserta/export/order dilaporkan ke D2; bila tidak selesai di FASE 1, D1 menyelesaikannya di FASE 2. |
| 8 | `organizer_operations_repository.dart` dipakai scanner (D2) dan peserta/export/report (D3) | **Satu owner: D3.** D2 memindahkan `OrganizerScannerScreen` ke `ScannerService` tanpa mengedit repository. D3 menghapus jalur mati scanner/offline/assisted setelah D2 selesai. |
| 9 | Test lintas domain | `stage2_integration_test.dart`, `api_mode_no_fallback_test.dart`, `helpers/test_mock_server.dart` → **D1**. D2/D3 menambah file test baru sendiri. |
| 10 | `backend/README.md`, `docs/**`, `README.md` | **D1** pada FASE 2. D2/D3 tidak mengedit. |
| 11 | `app_router.dart` bug parameter | Didaftar sebagai defect awal (G-16) dan diperbaiki D1 pada T3-D1-02. D2/D3 mendokumentasikan kebutuhan route. |
| 12 | `OrganizerQrPlaceholder` dan builder field dinamis | D1 (T3-D1-03/T3-D1-04). Bukan tanggung jawab D2/D3. |

---

## 8. Aturan keras

1. **Satu file satu owner per fase.** Lihat `FILE_OWNERSHIP.md`.
2. **Dilarang mengubah** `backend/prisma/**`, `backend/supabase/**`, `PRD.md`, `task/TAHAP_1/**`, `task/TAHAP_2/**` (laporan/dokumen), `task/archive/**`, `.github/**`, `.githooks/**`.
3. **Dilarang** menjalankan migration, seed, reset, atau mutasi database bersama. Query read-only diperbolehkan untuk verifikasi bila environment tersedia.
4. **Dilarang** menaruh secret, token, `.env`, atau kredensial di kode, test, log, dokumen, atau laporan.
5. **Dilarang** mengklaim PASS tanpa perintah/bukti.
6. **Dilarang** menghapus fitur yang sudah ada. Fitur non-MVP (assisted registration, offline scanner, payment gateway) disembunyikan, bukan dijadikan alur sukses.
7. **Dilarang** menambah dependency tanpa persetujuan dan pencatatan. `pubspec.yaml`/`package.json` adalah milik D1 pada Tahap 3.
8. **Dilarang** membuat endpoint/DTO baru tanpa memperbarui `INTEGRATION_CONTRACT.md` pada PR yang sama dan melaporkannya.
9. **Dilarang** memakai mock sebagai fallback ketika API gagal pada `MOCK_MODE=false`.
10. **Dilarang** mengubah perilaku kontrak yang sudah dipakai developer lain tanpa mencatat versi/field tambahan.

---

## 9. Status dan bukti

Gunakan hanya empat status:

| Status | Arti |
|---|---|
| `PASS` | Dijalankan dan berhasil, dengan perintah/bukti |
| `FAIL` | Dijalankan dan gagal; wajib ada analisis akar masalah |
| `BLOCKED` | Tidak dapat dikerjakan karena hambatan eksternal nyata (tidak ada kredensial, device, akses DB, keputusan produk) |
| `NOT RUN` | Tidak dijalankan; wajib menyebut alasan konkret |

`BLOCKED` **bukan** untuk "menunggu approval", "menunggu developer lain", atau "belum sempat". Pekerjaan yang dapat diselesaikan tanpa environment tetap wajib diselesaikan.

---

## 10. Serah terima

### 10.1 D2/D3 → D1

Setiap developer menyerahkan:

1. Branch `Developer-2-T3` / `Developer-3-T3` yang sudah rebase ke baseline.
2. PR dengan judul `[Tahap 3][FASE 1][D2] <ringkasan>` / `... [D3] ...`.
3. Laporan `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_2.md` / `..._3.md` sesuai format.
4. Daftar file yang diubah (harus cocok allow-list).
5. Daftar endpoint yang dipakai/diubah.
6. Daftar "Permintaan Integrasi untuk Developer 1" (route, navigasi, dokumentasi, bug backend di luar ownership).
7. Bukti test dan status platform.
8. Pernyataan tidak menyentuh schema/migration/seed dan tidak mengedit file developer lain.

### 10.2 D1 → pemilik proyek

1. Branch `Developer-1-T3` + PR integrasi.
2. Laporan `task/TAHAP_3/LAPORAN_TAHAP_3_DEVELOPER_1.md`.
3. `FINAL_ACCEPTANCE_CHECKLIST.md` terisi.
4. Daftar file dihapus/dikonsolidasikan + bukti verifikasi referensi.
5. Daftar perbaikan bug lintas modul.
6. Status akhir: **MVP SELESAI**, **SIAP DIUJI PENGGUNA**, atau **SIAP DEPLOYMENT** — hanya bila syaratnya terpenuhi.
7. Daftar `BLOCKED`/`NOT RUN` yang masih tersisa beserta alasan.

---

## 11. Traceability PRD → task Tahap 3

| AC PRD | Kebutuhan | Task utama |
|---|---|---|
| AC-01 | Event invalid tidak publik; valid auto-publish; suspend menolak order | T3-D1-04, T3-D1-05, T3-D3-07 |
| AC-02 | Cross-owner/unauthorized ditolak backend | T3-D2-06, T3-D3-05, T3-D1-05, T3-D1-09 |
| AC-03 | Order 1 kategori/1 attendee/1 tiket; harga server; idempotent | T3-D1-03, T3-D1-05 |
| AC-04 | Registrasi publik tanpa akun; tanpa assisted | T3-D1-02, T3-D1-03, T3-D3-02 |
| AC-05 | Invitation scoped; invalid/expired/revoked/wrong email ditolak; scanner langsung | T3-D2-03, T3-D2-04 |
| AC-06 | Payment hanya backend; status dibedakan; non-PAID tidak terbit tiket | T3-D1-03, T3-D1-05 |
| AC-07 | PAID → satu tiket/QR; gratis langsung terbit | T3-D2-02, T3-D1-03, T3-D1-05 |
| AC-08 | Validasi server; satu scan sukses; duplicate/wrong/unpaid/unauthorized ditolak | T3-D2-04, T3-D2-05, T3-D2-06 |
| AC-09 | Paid-first lalu nomor registrasi; layar = export | T3-D3-02, T3-D3-03 |
| AC-10 | Loading/empty/error/unauthorized/retry/success; tanpa mock fallback; responsif | T3-D2-07, T3-D3-09, T3-D1-02, T3-D1-09 |
| PRD §5 | Tiket default dengan QR unik | T3-D2-02, T3-D1-03 |
| PRD §6.1 | Public link event Published | T3-D1-03, T3-D1-04 |
| PRD §6.2 | Invitation staff + redirect scanner | T3-D2-03, T3-D2-04 |
| PRD §7 | Form dinamis, nomor registrasi stabil, daftar peserta | T3-D1-04, T3-D3-02 |
| PRD §8 | Simulasi VA, status, fee 5.000/5% | T3-D1-03, T3-D1-05, T3-D3-05 |
| PRD §9 | Scanner online, token opaque, check-in atomik | T3-D2-04, T3-D2-05, T3-D2-06 |
| PRD §11 | UI konsisten, state lengkap, responsif | T3-D2-07, T3-D3-09, T3-D1-09 |
| PRD §12 | Backend/API sumber kebenaran; permission server | T3-D1-05, T3-D2-06, T3-D3-05 |
| PRD §15 | C-01/C-02/C-03 tidak dikarang | T3-D3-05, T3-D3-06, T3-D3-07, T3-D1-05 |

Checklist rinci ada di `FINAL_ACCEPTANCE_CHECKLIST.md`.

---

## 12. Larangan khusus Tahap 3

1. Menambah fitur baru di luar PRD.
2. Memindahkan fitur wajib ke "Tahap 4" atau "Post-MVP" tanpa dasar PRD.
3. Mengganti pengujian nyata dengan klaim mock.
4. Menyimpan kredensial/SMTP/secret di repository.
5. Menjalankan migration/reset/seed pada database bersama.
6. Menyatakan production-ready tanpa bukti.
7. Developer 2/3 mengedit file bersama atau file developer lain.
8. Developer 1 memulai implementasi sebelum FASE 1 selesai.

---

## 13. Riwayat dokumen

| Tanggal | Perubahan | Alasan |
|---|---|---|
| 2026-11-23 | Rencana Tahap 3 v3.1 (model Developer 4) | Rencana sebelumnya; sudah dihapus dari folder ini |
| 2026-11-25 | README ini + 6 dokumen pendukung; model FASE 1 (D2+D3) → FASE 2 (D1); tanpa Tahap 4 | Perintah pemilik proyek: dokumen tugas individual, D2/D3 paralel tanpa konflik, D1 menyelesaikan integrasi |
