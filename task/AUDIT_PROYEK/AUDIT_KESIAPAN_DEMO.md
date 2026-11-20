# Audit kesiapan demonstrasi — 20 November 2026

## Kesimpulan saat ini
**Belum dinyatakan siap demo E2E.** Flutter analyze + unit/widget suite dan backend unit/static checks lulus pada workspace yang diperiksa; tidak ada bukti live database/API, deployment, provider email, credentials demo seeded, atau full demo transaction/check-in. Dokumentasi README menyebut beberapa domain masih in-memory/missing API. Tidak membuka `.env` atau melakukan operasi data.

## Bukti non-destruktif
| Pemeriksaan | Hasil | Batas |
|---|---|---|
| `npm --prefix backend test` | PASS: 27 tests, 0 failed | Unit tests, bukan API/DB integration |
| `npm --prefix backend run check` | PASS: syntax 61 JS files | Bukan lint keamanan/behavior lengkap |
| `npm --prefix backend run format:check` | PASS | Trailing whitespace/JSON, bukan formatter penuh |
| `npm --prefix backend run validate:skills` | PASS: 7 skills, 8 Markdown | Bukan validate link keseluruhan dokumentasi task yang belum dibuat saat dijalankan |
| `npm --prefix backend run prisma:validate` | PASS; schema valid | Bukan koneksi/status migration live |
| `flutter analyze --no-pub` dalam `apps/` | PASS: No issues found | Static analyze saja |
| `flutter test --no-pub --dart-define=MOCK_MODE=true` dalam `apps/` | PASS: semua yang jalan; ringkasan runner 139 passed, 11 skipped | Skipped dicatat; bukan E2E browser/perangkat |
| `npm run test:sync-config` | NOT RUN | Bukan blocker source, perlu jalankan sebelum merge |
| API mode Flutter no-fallback test | NOT RUN | Jalankan targeted test dengan `MOCK_MODE=false` sebelum merge |
| Android/Web build + live DB/API + E2E | NOT RUN | Perlu env uji aman/credentials synthetic dan runtime target |

## Alur demo yang perlu dibuktikan sebelum menyebut siap
1. Bootstrap backend dengan `.env.example` sebagai daftar nama (secret dari operator, bukan dokumen); health check menunjukkan DB connected pada DB demo/test terisolasi.
2. Migrasi/seed demo yang disetujui: periksa migration history sebelum mutasi; tidak boleh `db push`, `migrate reset`, atau memakai DB production. Seed organizer/admin accounts eksplisit; verifikasi role tanpa mempublikasikan password.
3. Flutter build Android/Web dengan `API_BASE_URL` yang dapat dijangkau (API mode default); origin/CORS, deep links, responsive viewport diuji.
4. Login/logout Admin, Organizer dan Staff; negative tests cross-role, cross-owner, event permission. Participant tetap guest tanpa account/dashboard.
5. Organizer buat valid event dan tiket → valid event auto-publish; invalid event tertahan dengan error actionable; kategori inactive/sold-out/out-of-window menolak order.
6. Public link → dynamic fields valid → satu order, satu attendee/ticket → payment simulation server-side (hanya test mode) → ticket/QR; invalid/retry/duplicate/expiry/unauthorized ditolak.
7. Undang Staff email/event/permission; accept via authenticated deep-link; scanner membuka event scope; valid paid ticket scan sukses sekali; repeat/unpaid/wrong event/no permission offline ditolak.
8. Daftar participant PAID-first/stable registration number, export; admin monitoring/support/audit; cek persistence reload dan error/empty/loading/retry UI.
9. Jalankan regresi, simpan laporan bukti serta build artifact lokal yang tidak memuat secret/PII.

## Konfigurasi dan risiko
- `API_BASE_URL` default emulator Android `http://10.0.2.2:5000/api`; web/device memerlukan alamat sesuai lingkungan.
- Backend memerlukan `DATABASE_URL`, `DIRECT_URL`, `JWT_SECRET`, port/host/CORS; payment simulation hanya bila `SIMULATED_PAYMENTS_ENABLED=true` pada non-production. Email membutuhkan SMTP config; tidak ada klaim delivery tanpa test sink.
- README menyatakan `MOCK_MODE=true` khusus demo/mock; jangan memakai sebagai bukti backend integration.
- Seed dapat memodifikasi DB; jangan jalankan sebelum memastikan DB test dedicated dan approval.
- Biaya/komisi, guest access, paket, expiry, storage serta deep link adalah blocker/technical gaps di PRD. Jangan membuat demo behavior yang menyembunyikan keputusan tersebut.
