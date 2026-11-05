# E-Ticket Event & QR Scanner

## Panduan developer dan AI

- Instruksi utama: [`AGENTS.md`](AGENTS.md); katalog skill: [`SKILL.md`](SKILL.md).
- Arsitektur dan workflow lokal: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Kontribusi dan pemeriksaan sebelum PR: [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Hasil audit tools dan penerapan: [`LAPORAN_ANALISIS_DAN_PENERAPAN_TOOLS.txt`](LAPORAN_ANALISIS_DAN_PENERAPAN_TOOLS.txt).
- GitHub Actions memeriksa backend tests/syntax dan Flutter analyze/widget tests
  pada push dan pull request.

Backend checks:

```bash
cd backend
npm test
npm run check
npm run lint
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
Backend `lint`/`format:check` memakai pemeriksaan lokal tanpa dependency tambahan;
lint saat ini memeriksa syntax, sedangkan format check memeriksa trailing
whitespace dan validitas JSON—belum setara dengan ESLint/Prettier.

## Akun demo (mode dummy)

Aplikasi berjalan dalam mode demo/dummy secara default dan tidak memerlukan backend.
Gunakan salah satu akun berikut pada halaman masuk (email atau username dapat digunakan):

| Peran | Email | Username | Kata sandi |
| --- | --- | --- | --- |
| Admin | `admin@event.com` | `admin` | `Admin123!` |
| Penyelenggara | `organizer@event.com` | `organizer` | `Organizer123!` |

Mode demo dapat dinonaktifkan untuk integrasi backend dengan menjalankan Flutter
menggunakan `--dart-define=MOCK_MODE=false`.
