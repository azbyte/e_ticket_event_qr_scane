> **Revisi 2026-11-25 — model Tahap 3.** Tahap 3 dijalankan dengan **FASE 1: Developer 2 + Developer 3 paralel** (tanpa Developer 1) lalu **FASE 2: Developer 1** menyelesaikan integrasi, implementasi tersisa, audit, dan acceptance. Rincian ada di [`TAHAP_3/README_TAHAP_3.md`](TAHAP_3/README_TAHAP_3.md). Bagian dokumen ini yang menyebut Developer 4 sebagai pelaksana Tahap 3 digantikan oleh model tersebut.


# PEMBAGIAN TUGAS FINAL — Roadmap Penyelesaian E-Ticket Event

- **Versi:** 3.0 (audit & restrukturisasi 2026-11-23)
- **Menggantikan:** versi pra-audit yang diarsipkan di `archive/PEMBAGIAN_TUGAS_FINAL_PRA_AUDIT_2026-11-23.md`.
- **Dasar:** [`ROADMAP_AUDIT_FINAL.md`](ROADMAP_AUDIT_FINAL.md) — audit source code, route, UI, dan database aktual.
- **PRD acuan:** [`../PRD.md`](../PRD.md) v2.2.
- **Sifat dokumen:** rencana kerja. Implementasi hanya dimulai atas perintah pemilik proyek.

## Indeks dokumen roadmap (satu sumber per topik)

| Topik | Dokumen |
|---|---|
| Hasil audit, status fitur, konflik keputusan, definisi selesai | [`ROADMAP_AUDIT_FINAL.md`](ROADMAP_AUDIT_FINAL.md) |
| Roadmap master, pembagian developer, urutan, gate G2 | dokumen ini |
| Rincian task Tahap 2 | [`TAHAP_2/RENCANA_KERJA.md`](TAHAP_2/RENCANA_KERJA.md) |
| Kontrak API lintas developer | [`TAHAP_2/INTEGRATION_CONTRACT.md`](TAHAP_2/INTEGRATION_CONTRACT.md) |
| Kepemilikan file | [`TAHAP_2/INTEGRATION_CONTRACT.md`](TAHAP_2/INTEGRATION_CONTRACT.md) Bagian 2 + [`TAHAP_2/FILE_OWNERSHIP.md`](TAHAP_2/FILE_OWNERSHIP.md) (ringkasan) |
| Lembar kerja per developer Tahap 2 | `TAHAP_2/DEVELOPER_{1,2,3}_TASK.md` |
| Rincian task Tahap 3 + gate | [`TAHAP_3/README_TAHAP_3.md`](TAHAP_3/README_TAHAP_3.md) |
| Checklist penerimaan akhir (diisi di Tahap 3) | [`TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`](TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md) |
| Kebutuhan perubahan database (tidak diotorisasi) | [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md) |
| Otoritas DB/FINISHING | [`FINISHING_AUTHORITY.md`](FINISHING_AUTHORITY.md) |

---

## 0. Mulai dari sini (untuk developer yang baru menerima tugas)

Jika Anda baru bergabung dan mendapat pesan "Kerjakan Developer N Tahap 2", ikuti urutan ini **persis**:

| Langkah | Baca / lakukan | Perkiraan waktu |
|---|---|---|
| 1 | Baca **hanya** `TAHAP_2/DEVELOPER_<N>_TASK.md` | 5 menit |
| 2 | Baca §C/§D/§E pada `TAHAP_2/RENCANA_KERJA.md` untuk daftar task Anda | 15 menit |
| 3 | Baca §B.1–B.3 `TAHAP_2/RENCANA_KERJA.md` (protokol paralel & merge) | 5 menit |
| 4 | Baca `TAHAP_2/INTEGRATION_CONTRACT.md` Bagian 1 (kontrak) & Bagian 2 (allow-list file Anda) | 10 menit |
| 5 | Cek `git status` + `git log --oneline -5`; siapkan branch `Developer-<N>` | 5 menit |
| 6 | Jalankan baseline: `cd backend; npm test` dan `cd apps; flutter analyze; flutter test` — catat hasilnya | 5 menit |
| 7 | Mulai task pertama sesuai urutan dependency di laporan Anda | — |

**Yang tidak perlu dibaca:** `ROADMAP_AUDIT_FINAL.md` (378 baris — hanya untuk memahami *mengapa*), `task/archive/**`, `task/TAHAP_1/**`, `task/FASE_1*`, `TECHNICAL_GATE_CLOSURE.md`, `PRD_TRACEABILITY_MATRIX.md`.

**Bila ragu tentang satu hal:** cari di `INTEGRATION_CONTRACT.md` dulu. Bila tidak ada, catat sebagai asumsi di laporan dan lanjut — jangan berhenti menunggu jawaban.

> ⚠️ Pada pekerjaan audit ini **tidak ada source code, schema, migration, atau data yang diubah.** Dokumen ini adalah rencana, bukan laporan progres.

---

## 1. Ringkasan roadmap

| Tahap | Tujuan | Output | Gate keluar |
|---|---|---|---|
| **1 (selesai)** | Fondasi: auth, schema, event/kategori tiket, order 1 tiket, pembayaran simulasi, tiket, check-in atomik, invitation backend, test dasar | 32 tabel, 9 migration, backend 89 test, Flutter 188 test | Tertutup (laporan D1–D4 Tahap 1) |
| **2 (prioritas utama)** | Menyelesaikan **seluruh fungsi inti MVP** dan menghubungkan semua layar in-scope ke API nyata | 3 developer × 5 task; setiap alur end-to-end | Gate G2 (§5) |
| **3 (finalisasi)** | Uji integrasi, keamanan, UI/UX, performa, deployment readiness, dokumentasi operasional — **FASE 1: Developer 2 + 3 paralel; FASE 2: Developer 1** | Task T3-D1-01…T3-D1-10 + T3-D2-* + T3-D3-* | Gate F1 + F2 (`TAHAP_3/README_TAHAP_3.md` §5) |

## Prinsip yang tidak boleh dilanggar:
1. Satu developer menangani satu alur end-to-end (backend + Flutter + test).
2. Satu file hanya dimiliki satu developer dalam satu tahap (`TAHAP_2/FILE_OWNERSHIP.md`).
3. Tidak ada task yang mengulang pekerjaan Tahap 1 yang sudah selesai.
4. Tidak ada fitur inti MVP yang ditunda ke Tahap 3.
5. Developer 1–3 tidak mengubah schema/migration/seed; kebutuhan DB dicatat di `DB_CHANGE_PROPOSAL.md`.
6. Setiap task wajib punya kriteria keberhasilan objektif dan bukti pengujian.

---

## 1.1 Prosedur eksekusi (menggantikan "Autonomous Execution Protocol" versi lama)

Protokol lama hanya tersimpan historis di `archive/PEMBAGIAN_TUGAS_FINAL_PRA_AUDIT_2026-11-23.md`. Yang berlaku sekarang:

1. **Perintah pemilik proyek = otorisasi implementasi.** Untuk permintaan "Kerjakan Developer N Tahap M", identifikasi task pada `TAHAP_2/RENCANA_KERJA.md`, baca konteks yang diperlukan, tentukan keputusan teknis sendiri, implementasikan, uji, perbaiki, lalu laporkan. **Jangan** meminta approval teknis kedua dan **jangan** berhenti setelah membuat analisis.
2. **Baca seperlunya, bukan seluruh repo.** Cukup: task milik Anda, `INTEGRATION_CONTRACT.md`, `FILE_OWNERSHIP.md`, laporan sebelumnya, dan source yang relevan. `task/archive/` hanya untuk penelusuran sejarah.
3. **OPEN DECISION dijawab dengan asumsi paling aman** (lihat `ROADMAP_AUDIT_FINAL.md` §9), dicatat di laporan, lalu lanjut. Jangan menunggu keputusan produk untuk hal yang tidak memblokir.
4. **`BLOCKED` hanya untuk hambatan eksternal nyata** (tidak ada kredensial SMTP, tidak ada device, akses DB tidak tersedia). Bukan untuk "menunggu persetujuan".
5. **Status `PASS` wajib disertai perintah yang benar-benar dijalankan.** `NOT RUN` harus menyebut alasan konkret.
6. **Database tetap terlarang bagi D1–D3.** Batasan DB bukan alasan menghentikan pekerjaan non-DB: selesaikan bagian yang tidak butuh DB, catat kebutuhan DB di `DB_CHANGE_PROPOSAL.md`.
7. **Bila butuh file milik developer lain:** tulis spesifikasi di PR dan laporan, lalu lanjutkan bagian Anda. Jangan edit file orang lain, jangan tandai task `BLOCKED` karenanya.
8. **Pekerjaan selesai = kode + test + laporan diperbarui.** Laporan (`LAPORAN_DEVELOPER_N.md`) adalah bagian dari Definition of Done, bukan lampiran opsional.

---

## 2. Struktur tim dan domain

| Developer | Domain utama | Alur bisnis yang dimiliki |
|---|---|---|
| **Developer 1** | *Publishable Event & Public Registration* | Organizer membuat event → validasi otomatis → publish → dua tautan (publik & staff) → guest mendaftar dari tautan publik → order → pembayaran. **Ditambah** kepemilikan tunggal `app/app_router.dart`, `app/app.dart`, `app/routes/app_routes.dart`. |
| **Developer 2** | *Ticketing, Staff Workspace, Check-in* | Tiket terbit → QR nyata → invitation staff → membership staff → scanner kamera → validasi → check-in → riwayat. **Ditambah** kepemilikan tunggal `checkInController.js` & `ticketController.js`. |
| **Developer 3** | *Attendee/Export & Admin Platform* | Daftar peserta paid-first → export → order monitoring organizer → revenue organizer → seluruh konsol Admin → notifikasi Organizer. |

**Alasan pembagian:** ketiga domain hampir tidak berpotongan file, dapat berjalan paralel setelah D1-1/D1-2 selesai, dan masing-masing menghasilkan satu alur bisnis utuh yang dapat diuji mandiri.

**Developer 4 (FINISHING/integrator)** tidak lagi menjadi pelaksana Tahap 3. Tahap 3 memakai model **FASE 1 (Developer 2 + Developer 3 paralel) → FASE 2 (Developer 1)**; rincian di [`TAHAP_3/README_TAHAP_3.md`](TAHAP_3/README_TAHAP_3.md).

---

## 3. Peta fitur → pemilik (tidak ada fitur tanpa owner)

| Fitur / AC PRD | Backend | Flutter | Task Tahap 2 |
|---|---|---|---|
| Auth & register Organizer (AC-05) | ada | ada | selesai Tahap 1 |
| CRUD event, ownership, kategori tiket | ada | ada | selesai; diperbaiki D1-2 |
| Validasi event → publish otomatis (AC-01) | `eventController` | form + status | **D1-2** |
| Public link + staff link (keputusan 3) | `eventController`, `eventInvitationController` | detail event | **D1-3** |
| Landing publik + registrasi guest (AC-04) | `GET /events/public` | `app_router`, `public_event` | **D1-4** |
| Order 1 tiket, harga server, idempotency | ada | ada | selesai; diperbaiki D1-5 |
| Pembayaran simulasi + status (AC-07) | ada | ada | selesai; diperbaiki D1-5 |
| QR e-ticket (AC-06) | token ada | `qr_ticket_display` | **D2-1** |
| Invitation staff + accept link | ada | `team_management_screen` | **D2-2** |
| Membership staff + routing workspace (AC-08) | baru: `GET /me/memberships` | `staff_dashboard`, router | **D2-2** |
| Scanner kamera & validasi | `checkInController`, `ticketController` | `scanner` | **D2-3** |
| Check-in tunggal + riwayat | ada | `check_in_service` | **D2-4** |
| Daftar peserta paid-first + detail (AC-09) | `checkInController` attendee | `attendee_list_screen` | **D3-1** |
| Export CSV | baru | `organizer_operations` | **D3-2** |
| Order/pembayaran per event | baru | layar baru | **D3-2** |
| Revenue & laporan organizer | ada | `organizer_report_screen` | **D3-2** |
| Akun admin + suspend + audit | perlu alasan/audit | `account_management` | **D3-3** |
| Audit log endpoint + UI | baru | `audit_log_screen` | **D3-3** |
| Platform settings + history | baru | `admin_settings_screen` | **D3-3** |
| Revenue/transaksi Admin | ada | `transaction_revenue_screen` | **D3-4** |
| Paket layanan Admin | ada | `package_management` | **D3-4** |
| Langganan Admin | baru (list) | `subscription_management` | **D3-4** |
| Dashboard Admin statistik | baru (overview) | `admin_dashboard` | **D3-4** |
| Event monitoring + suspend (AC-02) | `eventMetricsController` | `event_moderation` | **D3-5** |
| Laporan/keluhan admin | ada | `report_management` | **D3-5** |
| Notifikasi Organizer + nav | ada | `organizer_notifications` | **D3-5** |
| Assisted registration / offline scan | ada | ada | **NO LONGER REQUIRED (MVP)** — disembunyikan, tidak dihapus |

---

## 4. Ringkasan task per developer

Rincian lengkap ada di [`TAHAP_2/RENCANA_KERJA.md`](TAHAP_2/RENCANA_KERJA.md).
**Wajib dibaca lebih dulu:** protokol kerja paralel & merge di `TAHAP_2/RENCANA_KERJA.md` §B.1–B.3.

### Hari 1 — Bootstrap (blocking, 3 PR kecil)

| ID | Pemilik | Isi | Alasan |
|---|---|---|---|
| **D2-0** | D2 | Dependency `qr_flutter` + `mobile_scanner` | Agar D1 & D3 bisa menjalankan `pub get`/`test` |
| **D1-A** | D1 | Stub `public_event/`, `services/public_event/`, route publik | Agar D2 (invite) & D1 (fitur) tidak bentrok di router |
| **D3-A** | D3 | `utils/auditLog.js` + mount path kosong di `app.js` | Agar D1/D2 dapat menambah route tanpa mengedit `app.js` |

Ketiga PR ini **harus** ter-merge sebelum task fitur dimulai.

### Developer 1 — Publishable Event & Public Registration

| ID | Judul | Depends on | Estimasi |
|---|---|---|---|
| **D1-1** | Fondasi routing publik & kepemilikan route (`app_router`, `app_routes`, `app.dart`) | — | M |
| **D1-2** | Auto-publish event (validasi → `PUBLISHED`) + state lifecycle | — | L |
| **D1-3** | Dua tautan event: `public_url` publik + staff invitation URL | D1-2 | M |
| **D1-4** | Landing publik + registrasi guest + checkout | D1-1, D1-2 | XL |
| **D1-5** | Perbaikan alur order/payment/tiket guest + dynamic attendee data | D1-4 | L |

### Developer 2 — Ticketing, Staff Workspace, Check-in

| ID | Judul | Depends on | Estimasi |
|---|---|---|---|
| **D2-1** | QR e-ticket nyata + data tiket pribadi | — | M |
| **D2-2** | Invitation staff end-to-end + membership self endpoint + routing workspace (koordinasi D1-1 untuk route) | D1-1 (route), D1-3 (URL) | XL |
| **D2-3** | Scanner kamera + validasi tiket (online, MVP) | D2-1, D2-2 | XL |
| **D2-4** | Check-in tunggal, riwayat, dan konsolidasi jalur verifikasi | D2-3 | L |
| **D2-5** | Test regresi tiket–scan + daftar endpoint tiket/check-in di README backend | D2-1..D2-4 | M |

### Developer 3 — Attendee, Export, Order Monitoring, Admin Platform

| ID | Judul | Depends on | Estimasi |
|---|---|---|---|
| **D3-1** | Attendee data nyata: paid-first, nomor registrasi, detail peserta, permission | — | L |
| **D3-2** | Export CSV, order/payment monitoring organizer, revenue & laporan organizer | D3-1 | L |
| **D3-3** | Admin akun + audit log + platform settings (backend & UI) | — | XL |
| **D3-4** | Admin dashboard nyata + revenue/transaksi + paket + langganan | D3-3 (audit util) | XL |
| **D3-5** | Admin event monitoring/suspend, laporan, notifikasi Organizer, integrasi akhir Tahap 2 | D1-3, D2-2, D3-1..D3-4 | L |

**Catatan pembagian:** Task tidak dibuat sama jumlah/bobotnya secara artifisial. D1 memikul beban UI/route publik yang berat; D2 memikul beban device/kamera; D3 memikul banyak layar Admin yang bersifat wiring. Total estimasi ketiganya sebanding (±3–4 minggu kerja per developer).

---

## 5. Urutan pengerjaan & dependency

### 5.1 Gelombang kerja

| Gelombang | D1 | D2 | D3 | Catatan |
|---|---|---|---|---|
| **W1 (paralel)** | D1-1, D1-2 | D2-1 | D3-1, D3-3 | Semua independen; dimulai bersamaan |
| **W2** | D1-3, D1-4 (butuh D1-1+2) | D2-2 (butuh route D1-1) | D3-2 (butuh D3-1), D3-4 (butuh D3-3) | Koordinasi `app_router` lewat D1 |
| **W3** | D1-5 | D2-3, D2-4 | D3-5 (parsial: admin event/report/notif) | D2-3 membutuhkan QR D2-1 |
| **W4 (integrasi)** | Perbaikan hasil integrasi | D2-5 + perbaikan | D3-5 integrasi akhir Tahap 2 | Gate G2 |

### 5.2 Dependency matrix

| Task | Butuh | Diblokir bila |
|---|---|---|
| D1-2 | — | — |
| D1-3 | D1-2 (event harus `PUBLISHED` untuk URL publik) | link publik harus tetap null |
| D1-4 | D1-1, D1-2 | guest tidak dapat menemukan event |
| D1-5 | D1-4 | halaman registrasi belum publik |
| D2-2 | D1-1 (registrasi route `/invite/:token`), D1-3 (URL undangan) | Staff tidak punya tautan |
| D2-3 | D2-1 (token tiket), D2-2 (permission staff) | tidak ada data QR untuk dipindai / tidak ada otorisasi scan |
| D2-4 | D2-3 | riwayat kosong tanpa check-in |
| D3-2 | D3-1 | export harus memakai set/urutan yang sama |
| D3-4 | D3-3 (util audit) | aksi admin tanpa audit |
| D3-5 | D1-3, D2-2, D3-1..D3-4 | integrasi lintas domain |

### 5.3 Hal yang harus selesai lebih dulu (blocker lintas tim)

1. **D1-1** — karena `app/app_router.dart` dan `app/routes/app_routes.dart` hanya boleh diubah D1. D2 mengirimkan kebutuhan route (path, guard) sebagai permintaan tertulis; D1 mengimplementasikan.
2. **D1-2** — karena semua alur publik bergantung pada event yang tervalidasi dan tayang.
3. **D3-3 util audit** — karena D3-4/D3-5 memakai helper audit yang sama.

### 5.4 Kontrak integrasi wajib (lihat `TAHAP_2/INTEGRATION_CONTRACT.md`)

- `GET /api/events/public` tidak berubah bentuk.
- `GET /api/events/:id` mengembalikan `public_url` terisi untuk event `PUBLISHED` (nullable).
- `POST /api/orders` tetap mengembalikan `{ order, order_access_token }`.
- `GET /api/tickets/:id?order_id=` tetap mengembalikan `ticket.token` hanya untuk pemilik.
- Attendee response mendapat field **tambahan** (tidak menghapus field lama): `order_number`, `payment_status`, `registration_number`.
- Route baru yang ditambahkan: `POST /api/events/:id/publish`, `GET /api/me/memberships`, `GET /api/events/:id/orders`, `GET /api/events/:id/attendees/export`, `GET /api/admin/audit-logs`, `GET/PUT /api/admin/settings`, `GET /api/admin/subscriptions`, `GET /api/admin/overview`.

---

## 6. Batas tanggung jawab

### 6.1 Dilarang untuk seluruh developer (Tahap 2)

1. Mengubah `backend/prisma/schema.prisma`, `backend/prisma/migrations/**`, `backend/supabase/**`, atau menjalankan migration/seed/reset.
2. Mengubah data database selain melalui API aplikasi pada environment uji.
3. Menghapus fitur, route, atau kolom yang sudah ada. Fitur non-MVP cukup disembunyikan.
4. Mengubah kontrak response yang sudah dipakai developer lain tanpa menulis perubahan di `INTEGRATION_CONTRACT.md` dan memberi tahu pemilik proyek.
5. Mengedit file di luar allow-list milik developer lain (lihat `TAHAP_2/FILE_OWNERSHIP.md`).
6. Mengklaim status PASS tanpa menjalankan perintah verifikasi.
7. Menambah dependency tanpa mencatatnya di laporan task.

### 6.2 Kepemilikan file bersama (satu owner per file)

| File | Owner Tahap 2 | Cara developer lain meminta perubahan |
|---|---|---|
| `apps/lib/app.dart`, `apps/lib/app_router.dart`, `apps/lib/routes/app_routes.dart` | **D1** | Kirim spesifikasi route di laporan/PR comment; D1 yang mengedit |
| `backend/src/app.js` | **D3** (pemilik rute admin/registrasi router akhir) | D1/D2 mengirim daftar route + mount path |
| `backend/src/controllers/eventController.js`, `eventMetricsController.js` (bagian publish) | **D1** | D3 memakai endpoint, tidak mengedit |
| `backend/src/controllers/checkInController.js`, `ticketController.js` | **D2** | D3 hanya membaca |
| `backend/src/controllers/eventInvitationController.js` | **D2** | D1 memakai untuk URL |
| `backend/src/controllers/adminController.js`, `planController.js`, `subscriptionController.js`, `revenueController.js`, `reportController.js`, `notificationController.js` | **D3** | — |
| `backend/src/utils/auditLog.js` (baru) | **D3** | — |
| `apps/lib/services/organizer_operations/**` | **D3** | D2 memakai `services/scanner` & `services/check_in` saja |
| `apps/lib/services/admin/**` | **D3** | — |
| `apps/lib/services/organizer_membership/**`, `services/check_in/**`, `services/scanner/**`, `services/ticket/**` | **D2** | — |
| `apps/lib/services/order/**`, `services/payment/**`, `services/event/**`, `services/public_event/**` (baru) | **D1** | — |
| `apps/pubspec.yaml` | **D2** (dependency QR & kamera) | Perubahan lain diajukan ke D2 |

### 6.3 Definition of Done per task

Sebuah task dinyatakan selesai bila:
1. Kode backend + Flutter untuk alur tersebut ada dan terhubung ke API nyata.
2. Tidak ada mock/in-memory yang aktif pada mode API untuk layar tersebut.
3. Test backend (unit/integration) untuk logika baru lulus.
4. Test Flutter (widget/unit) untuk layar baru lulus.
5. `npm test`, `npm run check`, `flutter analyze`, `flutter test` lulus pada branch developer.
6. Laporan task diperbarui: file yang disentuh, endpoint baru, bukti PASS/FAIL/NOT RUN.
7. Kriteria keberhasilan spesifik task terpenuhi seluruhnya.

---

## 7. Gate Tahap 2 (G2)

Tahap 2 dinyatakan selesai bila **semua** berikut terpenuhi dan dibuktikan:

| # | Gate | Bukti minimum |
|---|---|---|
| G2-1 | Event valid otomatis `PUBLISHED` tanpa aksi Admin | Test backend + bukti API |
| G2-2 | Event tidak valid tidak terlihat publik | Test negatif |
| G2-3 | `public_url` & staff invitation URL tersedia dan berbeda | Bukti response API + screenshot/record |
| G2-4 | Guest dapat membuka halaman publik, mendaftar, membuat order, membayar, dan memperoleh tiket tanpa login | Alur E2E manual/otomatis |
| G2-5 | QR tiket nyata dapat dipindai dan tervalidasi | Bukti scan pada device/emulator |
| G2-6 | Invitation staff sampai ke workspace staff dengan permission yang benar | Test + bukti UI |
| G2-7 | Duplicate check-in ditolak; riwayat check-in tampil | Test + bukti UI |
| G2-8 | Daftar peserta paid-first + nomor registrasi; export identik | Test + bukti CSV |
| G2-9 | Seluruh layar Admin in-scope memakai API (akun, audit, settings, revenue, paket, langganan, laporan) | Checklist per layar + bukti |
| G2-10 | Tidak ada mock/in-memory yang tersisa pada layar in-scope pada `MOCK_MODE=false` | Hasil `Select-String` + review |
| G2-11 | `npm test`, `npm run check`, `npm run format:check`, `flutter analyze`, `flutter test` PASS | Log perintah |
| G2-12 | Dokumentasi kontrak & ownership diperbarui; tidak ada file konflik yang diklaim ganda | Review `FILE_OWNERSHIP.md` |

Gate G2 **gagal** bila salah satu belum terpenuhi. Tahap 3 tidak boleh dimulai untuk item yang bergantung pada G2 yang belum lulus.

---

## 8. Target waktu

| Minggu | Aktivitas | Status target |
|---|---|---|
| 1 | **Hari 1: Bootstrap** (D2-0, D1-A, D3-A merge) → lalu W1: D1-1, D1-2, D2-1, D3-1, D3-3 | Semua task W1 selesai |
| 2 | W2: D1-3, D1-4, D2-2, D3-2, D3-4 | Semua task W2 selesai |
| 3 | W3: D1-5, D2-3, D2-4, D3-5 (parsial) | Semua task W3 selesai |
| 4 | W4: integrasi, perbaikan, gate G2 | G2 lulus |
| 5–6 | Tahap 3 — **FASE 1: D2 + D3 paralel; FASE 2: D1** | Gate F1 + F2 (`TAHAP_3/README_TAHAP_3.md` §5) |

Jika pemilik proyek mempercepat/memperlambat, urutan dependency dan gate tidak boleh diubah.

---

## 9. Riwayat perubahan dokumen

| Tanggal | Perubahan | Alasan |
|---|---|---|
| 2026-11-23 (pra-audit) | Rencana berbasis asumsi "verifikasi endpoint" | Diarsipkan |
| 2026-11-23 (audit) | Pembagian ulang berbasis domain end-to-end; 15 task; gate G2 terukur; kepemilikan file tunggal | Hasil audit `ROADMAP_AUDIT_FINAL.md` |



