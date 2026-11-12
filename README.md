# E-Ticket Event & QR Scanner

## Panduan developer dan AI

- Instruksi utama: [`AGENTS.md`](AGENTS.md); katalog skill: [`SKILL.md`](SKILL.md).
- Arsitektur dan workflow lokal: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Kontribusi dan pemeriksaan sebelum PR: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Hasil audit tools dan penerapan: [`LAPORAN_ANALISIS_DAN_PENERAPAN_TOOLS.txt`](LAPORAN_ANALISIS_DAN_PENERAPAN_TOOLS.txt).
- GitHub Actions memeriksa backend tests/syntax, test validator sinkronisasi
  branch, dan Flutter analyze/widget tests pada push dan pull request.

Versi tool yang dipakai CI: Node.js 22 dan Flutter 3.47.9 stable. Gunakan versi
tersebut untuk hasil lokal yang konsisten.

Backend checks:

```bash
cd backend
npm test
node --test ../.github/scripts/validate-sync-config.test.js
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
flutter test
```

`flutter analyze` lokal saat ini mengeluarkan temuan info yang sudah ada di
kode; CI menggunakan `--no-fatal-infos`, tetapi tetap gagal untuk error/warning.
`npm run lint` tetap tersedia sebagai alias kompatibilitas untuk `npm run check`
dan tidak dijalankan terpisah oleh CI. `npm run format:check` memeriksa trailing
whitespace dan validitas JSON—belum setara dengan formatter penuh.

## Akun demo (mode dummy)

Aplikasi berjalan dalam mode demo/dummy secara default dan tidak memerlukan backend.
Gunakan salah satu akun berikut pada halaman masuk (email atau username dapat digunakan):

| Peran | Email | Username | Kata sandi |
| --- | --- | --- | --- |
| Admin | `admin@event.com` | `admin` | `Admin123!` |
| Penyelenggara | `organizer@event.com` | `organizer` | `Organizer123!` |

Mode demo dapat dinonaktifkan untuk integrasi backend dengan menjalankan Flutter
menggunakan `--dart-define=MOCK_MODE=false`.
