# E-Ticket Event & QR Scanner

## Panduan developer dan AI

- Titik masuk AI dan pembagian tugas aktif:
  [`task/PEMBAGIAN_TUGAS_FINAL.md`](task/PEMBAGIAN_TUGAS_FINAL.md). Instruksi singkat
  yang didukung: “Kerjakan Developer 1/2/3 Tahap 1/2/3”, “Lanjutkan tugas
  Developer N”, “Perbaiki bug tahap sebelumnya”. Perintah pemilik proyek adalah
  otorisasi implementasi: AI mengerjakan task secara autonomous sampai selesai
  (context → analisis → keputusan teknis → implementasi → test → self-repair →
  audit → laporan) tanpa approval tambahan. Archive T03 bersifat historis.
  Developer 1 Tahap 1 dikecualikan dan berstatus FROZEN.
- Satu-satunya PRD aktif: [`PRD.md`](PRD.md). Keputusan produk yang ditandai
  OPEN DECISION tidak menghentikan pekerjaan: AI memilih interpretasi paling aman
  dan konsisten PRD, mengimplementasikannya, lalu mencatatnya sebagai asumsi pada
  laporan developer untuk koreksi pemilik.
- Database authority dan proses FINISHING:
  [`task/FINISHING_AUTHORITY.md`](task/FINISHING_AUTHORITY.md).
- Referensi teknis dan historis berikut **NON-BLOCKING**: isinya tidak lagi menjadi
  syarat mulai bekerja, dan status gate/approval di dalamnya digantikan oleh
  [`task/PEMBAGIAN_TUGAS_FINAL.md`](task/PEMBAGIAN_TUGAS_FINAL.md). Matriks PRD,
  status technical gate, dan proposal database (tetap menjadi jalur eskalasi
  perubahan DB, bukan izin): [`task/PRD_TRACEABILITY_MATRIX.md`](task/PRD_TRACEABILITY_MATRIX.md),
  [`task/TECHNICAL_GATE_CLOSURE.md`](task/TECHNICAL_GATE_CLOSURE.md),
  [`task/DB_CHANGE_PROPOSAL.md`](task/DB_CHANGE_PROPOSAL.md).
- Product decision register dan usulan kontrak teknis Fase 1C (referensi, bukan
  gate): [`task/FASE_1C_AUTHORIZATION_REGISTER.md`](task/FASE_1C_AUTHORIZATION_REGISTER.md).
- Catatan authorization/unblocking Fase 1D (referensi historis, bukan gate):
  [`task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md`](task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md).
- Ownership lintas tahap dan finalisasi task system Fase 1E (referensi, bukan gate):
  [`task/FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md`](task/FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md),
  [`task/FASE_1E_TASK_SYSTEM_FINALIZATION.md`](task/FASE_1E_TASK_SYSTEM_FINALIZATION.md).
- Instruksi utama: [`AGENTS.md`](AGENTS.md); katalog skill: [`SKILL.md`](SKILL.md).
- Arsitektur dan workflow lokal: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Kontribusi dan pemeriksaan sebelum PR: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Status kerja dan dependency: [`task/PEMBAGIAN_TUGAS_FINAL.md`](task/PEMBAGIAN_TUGAS_FINAL.md);
  riwayat pengerjaan: [`task/archive/LAPORAN_PENYELESAIAN.md`](task/archive/LAPORAN_PENYELESAIAN.md).
- Laporan terdahulu dan dokumen prototype lama berada di `task/archive/`;
  bukan referensi aktif kecuali penelusuran sejarah memang diperlukan.
- GitHub Actions menjalankan pemeriksaan backend dan Flutter pada setiap push
  dan pull request, lalu menerbitkan status `PR Quality Gate` sebagai satu
  pemeriksaan yang dapat diwajibkan sebelum merge.
- Hook pre-push tersedia di `.githooks/pre-push`. Aktifkan satu kali per clone
  dengan `git config core.hooksPath .githooks`; siapkan dependency lokal sesuai
  petunjuk di [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Agar merge benar-benar diblokir ketika pemeriksaan gagal, maintainer perlu
  mewajibkan status `PR Quality Gate` pada branch protection/ruleset GitHub.

Versi tool yang dipakai CI: Node.js 22 dan Flutter 3.47.9 stable. Gunakan versi
tersebut untuk hasil lokal yang konsisten.

Backend checks:

```bash
cd backend
npm test
npm run test:sync-config
npm run check
npm run format:check
```

Validate skills and their relative Markdown links from repository root:

```bash
npm --prefix backend run validate:skills
```

Flutter checks:

```bash
cd apps
flutter pub get
flutter analyze
flutter test --dart-define=MOCK_MODE=true
flutter test test/services/api_mode_no_fallback_test.dart --dart-define=MOCK_MODE=false
```

`flutter analyze` lokal saat ini mengeluarkan temuan info yang sudah ada di
kode; CI menggunakan `--no-fatal-infos`, tetapi tetap gagal untuk error/warning.
`npm run lint` tetap tersedia sebagai alias kompatibilitas untuk `npm run check`
dan tidak dijalankan terpisah oleh CI. `npm run format:check` memeriksa trailing
whitespace dan validitas JSON—belum setara dengan formatter penuh.

## Mode aplikasi

Aplikasi memakai API backend secara default. Tanpa `--dart-define`, alamat
backend mengikuti target yang dijalankan: web/desktop memakai
`http://127.0.0.1:5000/api`, emulator Android memakai
`http://10.0.2.2:5000/api`. Untuk perangkat fisik atau host lain, atur
`API_BASE_URL` eksplisit saat build:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

Mode demo hanya aktif jika diminta eksplisit dengan
`--dart-define=MOCK_MODE=true`. Persona demo pada mode itu tidak memakai akun
database dan bukan jalur login Admin. Akun Admin sebenarnya dibuat di tabel
`profiles` dengan `npm run admin:provision` setelah `ADMIN_EMAIL`/`ADMIN_PASSWORD`
diisi pada `backend/.env` (lihat `backend/README.md`).

Login Admin pada mode API memakai nilai `ADMIN_EMAIL` (atau `ADMIN_USERNAME`)
dan `ADMIN_PASSWORD` dari `backend/.env`. Alamat `admin@event.com` hanya persona
demo dan **tidak** ada di database. Sebelum mencoba masuk, pastikan backend
berjalan; layar login menyediakan tombol **Cek koneksi server** yang memanggil
`GET /health` dan menampilkan status `database: connected` bila aplikasi benar
menerima data dari PostgreSQL.

### Status integrasi (Tahap 3, terverifikasi)

Pada mode API (default), seluruh alur PRD sudah memakai API + PostgreSQL:
auth/role, event & kategori tiket, auto-publish, form peserta dinamis, order
guest, pembayaran simulasi, tiket QR + check-in, undangan/membership staf,
peserta & export CSV, order per event, revenue Organizer, serta konsol Admin
(akun, audit, settings, overview, paket, langganan, transaksi, moderasi,
laporan). Bukti dapat direproduksi dengan `cd backend; npm run test:e2e`
(lihat bagian berikut).

Order memakai biaya layanan Rp5.000 dan snapshot komisi platform 5%; hasil
simulasi pembayaran hanya dapat diaktifkan eksplisit di backend non-produksi
melalui `SIMULATED_PAYMENTS_ENABLED=true`.

### Uji end-to-end terhadap API + database nyata

```bash
cd backend
npm start                # terminal 1
npm run test:e2e         # terminal 2 — 80 pemeriksaan alur PRD
```

`npm run test:e2e` menulis data uji ke database yang ditunjuk `DATABASE_URL`
(tidak menghapus data) dan memeriksa auth, event, order, pembayaran, tiket,
scan/check-in, peserta, export CSV, hingga konsol Admin, termasuk skenario
negatif keamanan. Jalankan hanya pada database pengembangan/uji.

### Demo web

```bash
# dari root repository
cd apps
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
cd ..
node scripts/serve-web.js 3100 apps/build/web
```

Buka `http://127.0.0.1:3100`. Isi `APP_PUBLIC_URL` dan `ALLOWED_ORIGINS` pada
`backend/.env` dengan origin tersebut agar tautan publik event dan CORS benar
(mis. `APP_PUBLIC_URL=http://localhost:3100`).

Alternatif tanpa build lokal: `cd apps; flutter run -d chrome --web-port=3100`
lalu sesuaikan `APP_PUBLIC_URL`/`ALLOWED_ORIGINS` ke port tersebut.
