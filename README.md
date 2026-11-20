# E-Ticket Event & QR Scanner

## Panduan developer dan AI

- Titik masuk AI dan pembagian tugas aktif:
  [`task/PEMBAGIAN_TUGAS_FINAL.md`](task/PEMBAGIAN_TUGAS_FINAL.md). Instruksi singkat
  yang didukung: “Saya Developer 1/2/3, kerjakan Tahap 1/2/3.” Workflow memeriksa
  status Git dan gate tahap sebelum memilih task; archive T03 bersifat historis.
- Satu-satunya PRD aktif: [`PRD.md`](PRD.md). Keputusan produk yang ditandai
  OPEN DECISION tetap memblokir hanya acceptance/implementasi yang bergantung
  padanya; lihat status setiap task dan gate.
- Database authority dan proses FINISHING:
  [`task/FINISHING_AUTHORITY.md`](task/FINISHING_AUTHORITY.md).
- Matriks PRD, status technical gate, dan proposal database (tidak memberi izin
  perubahan DB): [`task/PRD_TRACEABILITY_MATRIX.md`](task/PRD_TRACEABILITY_MATRIX.md),
  [`task/TECHNICAL_GATE_CLOSURE.md`](task/TECHNICAL_GATE_CLOSURE.md),
  [`task/DB_CHANGE_PROPOSAL.md`](task/DB_CHANGE_PROPOSAL.md).
- Product decision register, usulan kontrak teknis dan status entry gate Fase 1C:
  [`task/FASE_1C_AUTHORIZATION_REGISTER.md`](task/FASE_1C_AUTHORIZATION_REGISTER.md).
- Authorization, status izin scope dan daftar approval Fase 1D:
  [`task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md`](task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md).
- Ownership lintas tahap dan finalisasi task system Fase 1E:
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
