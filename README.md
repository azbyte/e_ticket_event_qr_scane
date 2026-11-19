# E-Ticket Event & QR Scanner

## Panduan developer dan AI

- Titik masuk terbaru untuk AI yang melanjutkan checkpoint database T03:
  [`task/HANDOVER_AI_T03.md`](task/HANDOVER_AI_T03.md). Baca handover dahulu;
  jangan membaca archive historis kecuali perlu bukti asal keputusan.
- Instruksi utama: [`AGENTS.md`](AGENTS.md); katalog skill: [`SKILL.md`](SKILL.md).
- Arsitektur dan workflow lokal: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Kontribusi dan pemeriksaan sebelum PR: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Status kerja dan dependency: [`task/PEMBAGIAN_TUGAS_FINAL.md`](task/PEMBAGIAN_TUGAS_FINAL.md);
  riwayat pengerjaan: [`task/archive/LAPORAN_PENYELESAIAN.md`](task/archive/LAPORAN_PENYELESAIAN.md).
- Laporan terdahulu dan dokumen prototype lama berada di `task/archive/` atau
  `archive/`; bukan referensi aktif kecuali handover meminta penelusuran sejarah.
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

Aplikasi memakai API backend secara default. Atur `API_BASE_URL` saat build
sesuai host backend yang dapat dijangkau perangkat. Contoh untuk emulator Android:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

Mode demo hanya aktif jika diminta eksplisit dengan
`--dart-define=MOCK_MODE=true`. Akun demo hanya berlaku pada mode tersebut.
Integrasi belum mencakup semua modul. Manajemen event/kategori tiket Organizer,
moderasi event Admin, registrasi order, pembayaran simulasi, dan pembacaan tiket
order kini memakai API. Dashboard keuangan, paket, langganan, check-in/scanner,
laporan, notifikasi, serta beberapa operasi masih memiliki jalur in-memory atau
endpoint yang belum tersedia. Jangan anggap aplikasi sudah sepenuhnya memakai
database atau siap produksi. Order memakai biaya layanan Rp5.000 dan snapshot
komisi platform 5%; hasil simulasi pembayaran hanya dapat diaktifkan eksplisit
di backend non-produksi melalui `SIMULATED_PAYMENTS_ENABLED=true`.
