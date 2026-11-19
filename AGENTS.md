# Panduan AI dan developer — E-Ticket Event & QR Scanner

Gunakan Bahasa Indonesia untuk komunikasi dan dokumentasi kecuali nama teknis.
Jika melanjutkan checkpoint T03, mulai dengan [`task/HANDOVER_AI_T03.md`](task/HANDOVER_AI_T03.md),
kemudian baca dokumen lain yang dirujuk hanya jika diperlukan. Jangan membaca
seluruh `task/archive/` atau `archive/` secara default.
Sebelum mengubah kode, baca `README.md`, `prd.md`, dan bagian arsitektur yang
terdampak di `docs/ARCHITECTURE.md`. Untuk aturan khusus gunakan skills di
`.agents/skills/` (lihat `SKILL.md` sebagai katalog). Jangan menganggap prototipe
atau dummy sebagai jaminan keamanan maupun perilaku backend.

## Fakta proyek saat ini

- Frontend: Flutter/Dart di `apps/`, Flutter Web dan Android; state dengan
  Provider, HTTP melalui `http`, secure storage melalui
  `flutter_secure_storage`. `apps/lib/` memakai struktur `core`, `features`,
  `models`, `providers`, `services`.
- Backend: JavaScript CommonJS, Node.js, Express 4 di `backend/`; controller,
  routes, middleware, services, models dan validators di `backend/src/`.
- Persistence/auth: Supabase/PostgreSQL, JWT dan role. SQL migration aktual
  berada di `backend/supabase/migrations/`. Ikuti implementasi dan migration,
  jangan mengandalkan schema lama di README backend.
- Flutter memakai API backend secara default; mode demo harus diaktifkan secara
  eksplisit dengan `MOCK_MODE=true`. Integrasi seluruh modul belum selesai dan
  backend membutuhkan environment variables.
- PRD mendeskripsikan beberapa fitur sebagai rencana/prototype; jangan mengklaim
  fitur yang belum diimplementasikan sebagai tersedia.

## Routing skills

Pilih skill berdasarkan pekerjaan, jangan jalankan semua prosedur untuk setiap
perubahan. Baca katalog root [`SKILL.md`](SKILL.md) untuk memilih skill yang
sesuai; file skill berada di `.agents/skills/<nama>/SKILL.md`. Skill berikut
berlaku untuk pekerjaan backend sesuai cakupannya:

- Fitur backend atau perubahan API: gunakan `backend-api`; tambahkan
  `requirements` jika menyentuh perilaku, role, acceptance criteria, atau
  kontrak API.
- Bug backend: gunakan `debug` untuk reproduksi dan diagnosis, serta
  `backend-api` bila alur endpoint, akses, atau persistence terdampak.
- Review perubahan backend: gunakan `review` untuk memeriksa regresi, validasi,
  authorization/ownership, dan kontrak.
- Pemeriksaan kualitas backend: gunakan `pr-quality-gate` dalam mode targeted
  sesuai dampak atau mode penuh sebelum PR.
- Perubahan instruksi, skill, konfigurasi, atau tooling backend: gunakan
  `workspace`.
- Gunakan `flutter-ui` hanya bila pekerjaan juga mengubah UI Flutter; skill ini
  tidak menggantikan pemeriksaan backend.

Skill tidak perlu dijalankan semuanya untuk setiap perubahan. Ikuti prasyarat
dan pemeriksaan yang dinyatakan oleh skill terpilih.

Requirement sumber adalah `prd.md` serta migration/source aktual; PRD UI prototype
memiliki batas cakupan tersendiri. Jika permintaan menyentuh backend, cek konteks
dan mandat terkini—jangan menganggap roadmap PRD sebagai approval otomatis.

## Batas perubahan

- Jangan mengubah flow bisnis, skema/database, API, role, atau dependensi runtime
  sebagai bagian pekerjaan tooling tanpa alasan/mandat eksplisit.
- Jangan pernah menaruh secret, `.env`, service role key, atau token ke kode,
  fixture, log, dokumentasi, maupun aplikasi Flutter.
- Validasi authorization di backend; menyembunyikan kontrol UI bukan keamanan.
- Pertahankan pola dan library yang telah digunakan. Hindari duplikasi
  service/helper serta dependency baru untuk fungsi yang sudah ada.
- Perubahan Flutter harus menjaga loading/error/empty state, navigasi, aksesibilitas,
  layout sempit/lebar dan gaya visual yang telah ada. Periksa widget test.
- Perubahan backend harus menjaga bentuk response dan middleware error yang ada;
  periksa authorization/ownership serta validasi masukan ketika relevan.
- Jangan menyalin konfigurasi SiagaBanjir yang khusus NestJS, MySQL, domain banjir,
  atau kebijakan branch/commit yang khusus repo tersebut.

## Siklus kerja

1. Periksa status/diff Git, baca modul terdampak, PRD, dokumentasi dan skill terkait.
2. Rumuskan perubahan sekecil mungkin; perubahan tooling bukan alasan menambah fitur.
3. Jalankan pemeriksaan relevan dari `apps/`: `flutter analyze`, `flutter test`;
   dari `backend/`: `npm test`, `npm run check`, `npm run format:check`, dan
   `npm run validate:skills`. Uji validator sinkronisasi dengan
   `npm run test:sync-config` dari `backend/`.
   `npm run lint` adalah alias `npm run check`, jadi tidak perlu menjalankan
   keduanya.
4. Tinjau diff dan catat PASS/FAIL/BLOCKED/NOT RUN. Bedakan analisis statis,
   unit/widget test, integrasi Supabase/API dan validasi UI/perangkat.
5. Perbarui dokumentasi bila fakta atau cara kerja berubah. Jangan mengklaim
   provider eksternal, deployment, aksesibilitas penuh, atau keamanan penuh telah diuji.

## Keamanan dan data

Gunakan `.env.example` sebagai daftar nama konfigurasi saja; jangan menampilkan
nilai `.env`. Jangan menjalankan mutasi database/provisioning akun sungguhan,
menghubungi provider berbayar, atau memakai data pribadi pada pengujian. Gunakan
fixtures sintetis dan environment uji bila tersedia.
