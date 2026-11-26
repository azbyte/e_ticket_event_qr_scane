# LAPORAN AUDIT DAN PERBAIKAN — QR PENDAFTARAN, DESAIN TIKET, PEMBERSIHAN DEMO

- **Tanggal:** 2026-11-26
- **Status:** SELESAI untuk seluruh item dalam ruang lingkup; 2 usulan layout
  menunggu persetujuan pemilik (lihat §8.1).
- **Bukti:** `flutter analyze` bersih, `flutter test` 298/298, `npm test`
  206/206, uji alur nyata `npm run test:registration-flow` 32/32 terhadap
  backend + PostgreSQL sesungguhnya, `flutter build web --release` berhasil.

---

## 1. Penyebab utama setiap permasalahan

### 1.1 Tautan/QR pendaftaran membuka halaman login

Empat penyebab yang saling menumpuk:

| # | Akar masalah | Bukti |
|---|---|---|
| P1 | `MaterialApp` memakai `initialRoute: '/'` sehingga route awal **selalu** `/`; path dari browser (`/e/{eventId}`) diabaikan. | `apps/lib/app.dart` |
| P2 | Flutter Web default memakai *hash strategy*; `/e/{id}` dibaca sebagai path dokumen, bukan route aplikasi. | `apps/lib/main.dart` |
| P3 | `AppRouter` tidak menormalkan URL absolut/hash; `http://host/e/x` dan `/#/e/x` jatuh ke `/` (→ login). | `apps/lib/app_router.dart` |
| P4 | `/registration/:eventId` diarahkan ke `RegistrationScreen` (layar **berakun**), bukan layar guest. | `apps/lib/app_router.dart` |

### 1.2 QR Code tidak benar-benar dibuat

`OrganizerQrPlaceholder` + `_QrPatternPainter` hanya menggambar pola deterministik
dari hash id event. Itu **bukan** QR dan tidak dapat dipindai; labelnya pun
“representasi demo”. Tautan yang ditampilkan adalah `public_url` server
(`APP_PUBLIC_URL`) yang menunjuk host backend, sehingga tidak membuka aplikasi.

### 1.3 Formulir pendaftaran tidak mengikuti konfigurasi Organizer

`serializeEvent` mengirim `attendee_fields` apa adanya. Kolom itu kadang
tersimpan sebagai **teks JSON** (jalur update) dan kadang JSONB (jalur insert).
Saat berbentuk string, klien tidak dapat membacanya sehingga form publik jatuh
ke form default. Ditemukan lewat uji nyata: event dibuat dengan 5 field, respons
API mengembalikan `null`.

### 1.4 Desain tiket belum ada sama sekali

Tidak ada kolom database, endpoint, layanan rendering, komponen upload, maupun
template. Tiket hanya berupa QR di aplikasi; tidak ada PDF dan tidak ada
lampiran email.

### 1.5 Sisa unsur demo pada jalur produksi

- Halaman dukungan Organizer mengirim pengaduan dengan `organizerId = 'org-001'`
  dan email `nadia@demo.eticket.local` **hardcoded**, bukan akun yang login.
- Label “(demo)” pada snackbar tim, paket langganan, VA, scanner, label poster,
  “Penjualan kotor (demo)”, “Membuat laporan demo…”.

### 1.6 Bug tambahan yang ditemukan saat pengujian

`resolveAccess` (unduh tiket) mewajibkan query `order_id`, padahal UUID order
sudah diketahui dari baris tiket. Tautan unduh PDF yang wajar
(`/api/tickets/{id}/pdf` + header token order) selalu `404`.

---

## 2. Perbaikan yang telah dilakukan

### 2.1 Tautan & QR pendaftaran (P1–P4)

- `main.dart`: aktifkan `usePathUrlStrategy()` (web) sehingga URL aplikasi
  berbentuk `/e/{eventId}` tanpa `#`.
- `app.dart`: hapus `initialRoute: '/'`; tambahkan `onGenerateInitialRoutes`
  yang meneruskan route awal platform ke `AppRouter`.
- `app_router.dart`:
  - `_normalizeRouteName()` menormalkan tiga bentuk tautan: path strategy,
    hash strategy lama (`/#/e/x`), dan URL absolut (`http://host/e/x?y=1`).
  - `/registration/:id` sekarang memakai `PublicRegistrationScreen` (guest).
  - `_isPublicPath()` menegaskan hanya `/`, `/login`, `/register`,
    `/access-denied`, `/e/**`, `/invite/**`, `/registration/**` yang publik.
    Dashboard Organizer/Admin, data peserta, order, dan scanner tetap butuh login.
- `app_config.dart`: `publicRegistrationUrl()` menghasilkan
  `{origin aplikasi}/e/{eventId}` (origin browser di web,
  `--dart-define=APP_PUBLIC_URL` pada Android/rilis, `public_url` server sebagai
  fallback). Tautan **dan** QR dijamin menunjuk host yang benar.
- `RegistrationQrView` (baru): QR asli (`qr_flutter`) berisi URL pendaftaran.
  Bila event belum tayang, tampil status jujur — bukan QR palsu.
- `organizer_event_detail_screen.dart`: memakai `RegistrationQrView` +
  `publicRegistrationUrl`; tombol salin dan teks tautan memakai URL yang **sama**
  dengan QR.

### 2.2 Formulir pendaftaran dinamis

- `eventResponse.js`: `parseAttendeeFields()` — `attendee_fields` selalu dikirim
  sebagai **array** (JSONB maupun teks JSON), sehingga layar publik membaca
  konfigurasi asli event: nama, email, telepon, teks, dropdown (select),
  wajib/tidak wajib, dan urutan sesuai pengaturan Organizer.
- Validasi dua lapis: klien (`PublicRegistrationScreen`) dan server
  (`validateAttendeeFields` + validasi order). Dibuktikan: data tidak valid
  ditolak backend dengan `400`.
- Peserta tidak perlu akun: order guest memakai `order_access_token`
  (`X-Order-Access-Token`).

### 2.3 Desain tiket (PRD §5) — implementasi penuh

**Database** (`backend/prisma/migrations/20261126000000_ticket_design`):

```sql
ALTER TABLE "events" ADD COLUMN "ticket_design" JSONB;
ALTER TABLE "ticket_types" ADD COLUMN "ticket_design" JSONB;
```

Aditif dan nullable; `NULL` berarti desain default sistem. Sudah dijalankan
`prisma migrate deploy` → “Database schema is up to date!”, `prisma validate`
valid, tanpa drift.

**Penyimpanan & validasi** (`ticketDesignService.js`):

- Hanya PNG/JPEG, 1 KB–2 MB, **signature magic-number diperiksa** (tipe file dari
  klien tidak dipercaya).
- File disimpan di `backend/storage/ticket-designs/{eventId}/{uuid}.png`, dilayani
  lewat `GET /media/**` (nama file UUID, anti-traversal).
- Referensi file + posisi QR disimpan sebagai JSONB pada kolom `ticket_design`.

**Template**: `GET /api/ticket-design-template?format=pdf|png`
(`backend/assets/ticket-templates/ticket-template.png`, 1200×480, penanda
“AREA QR”). PDF dirender dinamis dengan ukuran & posisi QR yang sama seperti
tiket final.

**Rendering tiket**: `buildTicketPdf()` — prioritas desain
**kategori tiket → desain event → default sistem**; QR unik
(`rawTokenFor(ticket)`) ditempatkan sesuai koordinat desain; teks memuat nama
event, peserta, kategori, tanggal, lokasi, kode tiket, dan nomor registrasi.

**Penggunaan nyata** (bukan sekadar simpan file):

- `GET /api/tickets/:id/pdf` → e-ticket PDF final.
- `emailService.buildPdfAttachment()` → PDF **dilampirkan pada email tiket**,
  sehingga desain yang dipilih benar-benar sampai ke peserta. Bila rendering
  gagal, email tetap terkirim tanpa lampiran dan kegagalan dicatat (status
  pengiriman tidak diklaim lebih baik dari kenyataan).

**UI Organizer**: tab **Tiket** → kartu “Desain tiket” → layar
`TicketDesignScreen` dengan `TicketDesignPanel`: pilih cakupan (seluruh event /
per kategori), unggah PNG/JPEG, pratinjau, atur posisi X & ukuran QR, unduh
template PDF/PNG, hapus desain.

### 2.4 Penghapusan unsur demo

| Lokasi | Sebelum | Sesudah |
|---|---|---|
| `organizer_support_screen.dart` | `organizerId = 'org-001'`, email `nadia@demo…` | id & email dari akun Organizer yang login |
| Snackbar dukungan | “Laporan demo … dibuat secara lokal” | “Laporan … berhasil dikirim” |
| `team_management_screen.dart` | “diperbarui (demo)” / “dicabut (demo)” | tanpa “(demo)” |
| `subscription_screen.dart` | “Paket demo …” | “Paket …” |
| `organizer_scanner_screen.dart` | “Pemindai Tiket QR (demo)” | “Pemindai Tiket QR” |
| `organizer_event_detail_screen.dart` | “Penjualan kotor (demo)”, “Grafik penjualan (demo)”, “QR registrasi (representasi demo)” | label sebenarnya + QR asli |
| `event_form_screen.dart` | “URL poster (opsional, fixture demo)” | “URL poster (opsional)” |
| `assisted_registration_screen.dart` | “VA Demo”, “Nomor Virtual Account Demo” | “Virtual Account” (simulasi backend tetap) |
| `organizer_summary_widgets.dart` | `OrganizerQrPlaceholder` + `_QrPatternPainter` (QR palsu) | **dihapus** (dead code) |

Data fixture (`OrganizerEventFixtures`, `MockOrganizerEventRepository`,
`mock_attendee_repository`) **hanya** aktif ketika `MOCK_MODE=true`
(`organizer_event_repository_factory.dart`); build default memakai API. Tidak ada
fallback senyap ke data palsu.

**Simulasi pembayaran dipertahankan** sesuai PRD: `POST /api/payments/simulate`
tetap dipakai; order, pembayaran, dan statusnya tetap diproses backend dan
tersimpan di `event_orders`, `order_payments`, `platform_transactions`.

### 2.5 Bug tambahan

- `ticketController.resolveAccess`: `order_id` diambil dari query **atau** dari
  baris tiket, sehingga `GET /api/tickets/{id}/pdf` dapat dipakai langsung
  (tetap `404` tanpa akses sah).
- `.gitignore`: menambahkan `backend/storage/`, `backend/backups/` (berisi data
  pribadi), dan log server agar tidak masuk repo.

---

## 3. File yang dimodifikasi / ditambahkan

### Frontend (Flutter)

| File | Perubahan |
|---|---|
| `apps/lib/main.dart` | `usePathUrlStrategy()` |
| `apps/lib/app.dart` | hapus `initialRoute`, tambah `onGenerateInitialRoutes` |
| `apps/lib/app_router.dart` | normalisasi deep link, `/registration/:id` guest, perluasan `_isPublicPath` |
| `apps/lib/core/config/app_config.dart` | `publicRegistrationUrl`, `publicAppOrigin`, `apiOrigin`, `mediaUrl` |
| `apps/lib/features/organizer/events/widgets/registration_qr_view.dart` | **baru** — QR asli |
| `apps/lib/features/organizer/events/widgets/ticket_design_panel.dart` | **baru** — upload/posisi QR/template |
| `apps/lib/features/organizer/events/screens/ticket_design_screen.dart` | **baru** |
| `apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart` | QR asli, URL konsisten, kartu desain tiket |
| `apps/lib/models/event/ticket_design_model.dart` | **baru** |
| `apps/lib/services/organizer_events/ticket_design_service.dart` | **baru** |
| `apps/lib/features/organizer/events/widgets/organizer_summary_widgets.dart` | hapus QR palsu |
| `apps/lib/features/organizer/support/organizer_support_screen.dart` | identitas akun nyata |
| `apps/lib/features/organizer/membership/team_management_screen.dart` | hapus label demo |
| `apps/lib/features/organizer/plans/subscription_screen.dart` | hapus label demo |
| `apps/lib/features/organizer/operations/assisted_registration_screen.dart` | hapus label demo |
| `apps/lib/features/organizer/operations/organizer_scanner_screen.dart` | hapus label demo |
| `apps/lib/features/organizer/screens/event_form_screen.dart` | hapus label demo |
| `apps/pubspec.yaml` | `flutter_web_plugins`, `image_picker`, `url_launcher` |

### Backend (Node.js)

| File | Perubahan |
|---|---|
| `backend/prisma/schema.prisma` | `ticketDesign` pada `Event` & `TicketType` |
| `backend/prisma/migrations/20261126000000_ticket_design/migration.sql` | **baru** |
| `backend/src/services/ticketDesignService.js` | **baru** — validasi, simpan, template, render PDF |
| `backend/src/controllers/ticketDesignController.js` | **baru** |
| `backend/src/routes/events.js` | route desain tiket + template publik |
| `backend/src/controllers/ticketController.js` | `GET /tickets/:id/pdf`, `resolveAccess` |
| `backend/src/routes/orders.js` | route PDF tiket |
| `backend/src/services/emailService.js` | lampiran PDF e-ticket |
| `backend/src/utils/eventResponse.js` | normalisasi `attendee_fields` |
| `backend/src/app.js` | static `/media` |
| `backend/assets/ticket-templates/ticket-template.png` | **baru** — template 1200×480 |
| `backend/scripts/generate-ticket-template.ps1` | **baru** — regenerasi template |
| `backend/scripts/e2e-registration-flow.js`, `e2e-registration-scenarios.js` | **baru** — uji alur nyata |
| `backend/scripts/verify-ticket-pdf.js` | **baru** |
| `backend/scripts/cleanup-e2e-accounts.js` | pembersihan data uji berurutan sesuai FK |
| `backend/package.json` | dependensi `pdfkit`; script `test:registration-flow`, `verify:ticket-pdf` |

### Test

| File | Isi |
|---|---|
| `backend/test/ticket_design.test.js` | **baru** — 14 test |
| `backend/test/security_and_services.test.js` | diperbarui (lampiran PDF) |
| `apps/test/deep_link_registration_test.dart` | **baru** — 5 test |
| `apps/test/features/organizer/events/registration_qr_view_test.dart` | **baru** — 4 test |
| `apps/test/app_router_test.dart` | `/registration/:id` → layar guest |

**Dokumentasi:** `backend/README.md` (tabel endpoint + script uji), `.gitignore`,
laporan ini.

---

## 4. Endpoint API yang ditambahkan / diperbaiki

| Method | Endpoint | Akses | Keterangan |
|---|---|---|---|
| GET | `/api/events/:id/ticket-design` | Owner/Admin | Desain event + per kategori |
| PUT | `/api/events/:id/ticket-design` | Owner/Admin | Unggah (`scope=event\|ticket_type`) |
| DELETE | `/api/events/:id/ticket-design?scope=` | Owner/Admin | Hapus → default |
| GET | `/api/ticket-design-template?format=pdf\|png` | **Publik** | Template tanpa data Organizer |
| GET | `/api/tickets/:id/pdf` | Pemilik/order token | E-ticket PDF final |
| GET | `/media/ticket-designs/**` | Publik | File gambar desain (nama UUID) |
| GET | `/api/events/:id` *(diperbaiki)* | Publik | `attendee_fields` selalu array |

**Endpoint yang tetap tertutup** (diverifikasi `401`): `/api/events/mine`,
`/api/events/:id/orders`, `/api/events/:id/attendees`,
`/api/events/:id/ticket-design`, `GET /api/tickets/:id/pdf`.

---

## 5. Perubahan database

- 2 kolom JSONB baru (aditif, nullable) — lihat §2.3.
- Tidak ada perubahan tabel/relasi/constraint lain dan tidak ada data dummy yang
  di-seed.
- Data uji `*.e2e.*@example.test` sudah dibersihkan; sisa akun di database hanya
  `admin@eticket.local` dan organizer nyata.

---

## 6. Hasil pengujian setiap skenario

Semua skenario dijalankan terhadap backend + PostgreSQL nyata, bukan mock.

| Skenario | Hasil | Bukti |
|---|---|---|
| **1. Pembuatan event** — login Organizer (akun DB), buat event, kategori, form dinamis, desain tiket, simpan | LULUS | registrasi `201`, login `200`, event `201`, kategori `201`, publikasi `200 published:true`, 5 field tersimpan berurutan |
| **2. Link & QR** — `public_url` `.../e/{id}`, QR berisi URL yang sama, buka tanpa login | LULUS | `public_url = http://localhost:3100/e/{id}`; `GET /api/events/{id}` tanpa token `200`; widget test QR + 5 test deep link |
| **3. Pendaftaran peserta** — isi form, field wajib & validasi, simpan | LULUS | order `201`; data tidak valid → `400`; tersimpan di `attendees` (`custom_fields` memuat jawaban dropdown) |
| **4. Penerbitan tiket** — gratis & berbayar, desain dipakai, QR unik, email | LULUS | gratis → `PAID` langsung + 1 tiket; berbayar → `pending_payment`, 0 tiket, setelah simulasi → 1 tiket; PDF `31 KB` (desain tertanam) vs `16 KB` default; token QR 43 karakter |
| **5. Fitur lain** — login/registrasi, hak akses, scanner, dashboard, regresi | LULUS | `flutter test` 298 pass; `npm test` 206 pass; staff scanner & anti check-in ganda 20/20 |

**Perintah verifikasi akhir**

| Perintah | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **298/298 passed** |
| `npm test` (backend) | **206/206 pass** |
| `npm run test:registration-flow` | **32/32 pemeriksaan lulus** |
| `npm run check` | Syntax OK: 56 file |
| `prisma migrate status` / `validate` | up to date / valid (tanpa drift) |
| `flutter build web --release` | Build berhasil; `pushState` ada di bundel (path strategy aktif) |

---

## 7. Fitur yang sebelumnya belum tersedia → sekarang tersedia

1. QR pendaftaran yang dapat dipindai.
2. Tautan pendaftaran publik yang benar-benar membuka formulir (bukan login),
   termasuk dari URL absolut dan hash lama.
3. Halaman `/registration/:id` sebagai alur guest.
4. Form publik yang mengikuti konfigurasi field per event (termasuk dropdown,
   wajib, urutan).
5. Upload desain tiket per event dan per kategori.
6. Template tiket PDF & PNG dengan penanda posisi QR.
7. Pengaturan posisi/ukuran QR pada desain.
8. E-ticket PDF final memakai desain Organizer.
9. Lampiran PDF e-ticket pada email peserta.
10. Identitas akun nyata pada pengaduan Organizer.

---

## 8. Fitur/pekerjaan yang belum selesai dan butuh keputusan Anda

### 8.1 Rekomendasi layout yang membutuhkan PERSETUJUAN (belum saya ubah)

Saya **tidak** mengubah susunan/layout halaman yang sudah ada. Usulan berikut
saya tahan sampai Anda menyetujui:

| # | Halaman | Kondisi layout saat ini | Masalah | Rekomendasi | Alasan | Dampak |
|---|---|---|---|---|---|---|
| L1 | Detail Event → tab **Ringkasan** | Statistik → panel “Tautan Pendaftaran Peserta” (QR 112 px + teks) → panel “Tautan Undangan Panitia” → catatan validasi | QR 112 px berdampingan teks panjang; sulit dipindai dari layar saat presentasi | Perbesar QR (±200 px) + tombol “Perbesar QR” (dialog), tombol salin & buka | Demonstrasi butuh QR besar agar dapat dipindai audiens | Tidak mengubah navigasi; hanya ukuran komponen pada panel yang sama |
| L2 | Detail Event → tab **Tiket** | Daftar kategori → kartu “Desain tiket” → layar terpisah | Desain tiket berada satu tingkat lebih dalam | Jadikan bagian desain inline di dalam kartu tiap kategori (tanpa layar baru) | Lebih dekat ke tempat kategori dibuat | Menambah tinggi tab Tiket; butuh persetujuan karena mengubah susunan bagian |

Implementasi saat ini (kartu + layar terpisah) dipilih justru agar layout tab
Tiket **tidak berubah** dan data desain tidak dimuat setiap kali detail event
dibuka.

### 8.2 Item yang belum selesai (di luar kendali lingkungan ini)

| # | Item | Alasan | Status |
|---|---|---|---|
| N1 | Uji kamera/scan QR pada perangkat Android/Web nyata | Perlu perangkat & izin kamera | NOT RUN (bukan klaim berhasil) |
| N2 | Pengiriman email sungguhan | `SMTP_HOST` belum dikonfigurasi; kode mencatat `NOT_CONFIGURED` (tidak mengklaim `SENT`) | NOT RUN |
| N3 | Penyimpanan desain ke object storage (S3/Supabase Storage) | Saat ini disk lokal server (`backend/storage/`); produksi multi-instance perlu storage bersama | KEPUTUSAN DIPERLUKAN |
| N4 | Fixture demo di balik `MOCK_MODE=true` | Masih ada, tetapi tidak pernah aktif pada build default | SESUAI RANCANGAN — hapus total? butuh keputusan |

---

## 9. Catatan asumsi

1. **Origin tautan pendaftaran.** Tautan/QR memakai origin aplikasi yang sedang
   berjalan (web) atau `--dart-define=APP_PUBLIC_URL` (rilis), dengan
   `public_url` server sebagai fallback. Untuk rilis, set `APP_PUBLIC_URL` sama
   dengan `backend/.env` agar identik di semua permukaan.
2. **Desain tiket & kategori.** Desain kategori menimpa desain event; bila
   keduanya kosong dipakai desain default sistem — mengikuti ketentuan “dapat
   digunakan untuk seluruh kategori atau diatur berbeda per kategori”.
3. **Lampiran email.** PRD melarang token QR mentah pada badan email. PDF yang
   dilampirkan memuat QR (bukan token di badan email) dan hanya dikirim ke email
   pemilik tiket, sehingga tidak melanggar pembatasan tersebut.
