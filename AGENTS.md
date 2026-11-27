# Panduan AI dan developer — E-Ticket Event & QR Scanner

Gunakan Bahasa Indonesia untuk komunikasi dan dokumentasi kecuali nama teknis.

## Folder `task/` adalah arsip — jangan dibaca

`task/` — termasuk `task/archive/` dan `task/AUDIT_PROYEK/` — berisi arsip historis:
status kerja lama, laporan developer, audit, dan proposal. **Jangan membaca file di
dalamnya secara default.** Arsip itu tidak diperlukan untuk pekerjaan aplikasi dan
hanya menghabiskan konteks. Baca `task/` hanya bila pemilik proyek menyebut nama file
atau tugasnya secara eksplisit.

Seluruh aturan yang masih berlaku sudah diringkas di dokumen ini — protokol eksekusi
otonom, batas wewenang database, pengecualian FROZEN, batas perubahan, siklus kerja,
dan aturan keamanan — sehingga pekerjaan aplikasi **tidak** bergantung pada `task/`.

**Perintah tugas dari pemilik proyek adalah otorisasi implementasi.** Untuk
permintaan berbentuk “Kerjakan Developer N Tahap M”, “Lanjutkan tugas Developer N”,
atau “Perbaiki bug tahap sebelumnya”, jalankan *Autonomous Execution Protocol*:
identifikasi pekerjaan, baca konteks seperlunya, ambil keputusan
teknis sendiri, implementasikan, uji, perbaiki error, audit, lalu laporkan. Jangan
meminta approval teknis/kedua, jangan menanyakan lokasi test atau pendekatan
implementasi, dan jangan berhenti setelah menghasilkan analisis/audit/GAP report.
Baca hanya source dan dokumentasi aktif yang relevan (`README.md`, `PRD.md`,
`docs/`, `.agents/skills/`); jangan membaca seluruh repository. Mode read-only hanya
berlaku bila pemilik proyek secara eksplisit meminta audit/review/investigasi tanpa
perubahan.

**Pengecualian: Developer 1 Tahap 1 berstatus FROZEN.** Task, status, approval,
laporan, dan Amendment A-1 miliknya dipertahankan apa adanya; jangan mengerjakan
ulang atau mengubahnya ketika menjalankan tugas developer/tahap lain.
Sebelum mengubah kode, baca `README.md`, `PRD.md`, dan bagian arsitektur yang
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
- Persistence/auth: PostgreSQL/Supabase, JWT dan role. Sumber schema dan riwayat
  migration aktif yang ditetapkan adalah `backend/prisma/schema.prisma` dan
  `backend/prisma/migrations/`. SQL legacy ada di
  `backend/prisma/legacy-migrations/` (di luar `migrations/` agar tidak pernah
  dijalankan Prisma); jangan menjalankannya atau menjadikannya baseline Prisma
  tanpa rekonsiliasi dan persetujuan penanggung jawab FINISHING. Backend runtime
  memakai `pg`, bukan Prisma Client.
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

Requirement produk aktif adalah `PRD.md`; implementation/source dan schema
menunjukkan kondisi teknis, bukan pengganti keputusan produk. PRD mencatat
keputusan yang perlu konfirmasi dan gap; jangan menganggap roadmap sebagai
approval otomatis. OPEN DECISION tidak menghentikan pekerjaan teknis: pilih
interpretasi paling aman dan konsisten PRD, implementasikan, lalu catat sebagai
asumsi yang perlu konfirmasi pada laporan.

## Batas perubahan

- Jangan mengubah flow bisnis, skema/database, API, role, atau dependensi runtime
  sebagai bagian pekerjaan tooling tanpa alasan/mandat eksplisit.
- Developer 1–3 dilarang mengubah schema, migration, struktur/relasi tabel,
  konfigurasi/seed database, atau SQL langsung. Kebutuhan perubahan dilaporkan
  sebagai proposal untuk FINISHING. Hanya penanggung jawab FINISHING yang telah
  ditetapkan dan setelah gate FINISHING dibuka boleh mengimplementasikan DB;
  Developer 4 tidak otomatis berwenang. Aturan ini berlaku penuh dan tidak
  memerlukan pembacaan dokumen lain di `task/`.
  Batas ini **tidak menghentikan task**: selesaikan seluruh bagian yang tidak
  memerlukan DB, catat proposalnya, dan lanjutkan.
- Jangan pernah menaruh secret, `.env`, service role key, atau token ke kode,
  fixture, log, dokumentasi, maupun aplikasi Flutter.
- Validasi authorization di backend; menyembunyikan kontrol UI bukan keamanan.
- Pertahankan pola dan library yang telah digunakan. Hindari duplikasi
  service/helper serta dependency baru untuk fungsi yang sudah ada.
- Perubahan di luar allow-list/file developer lain diperbolehkan bila benar-benar
  diperlukan untuk menyelesaikan tugas: lakukan perubahan **minimum**, jaga bentuk
  response/kontrak yang ada, jangan merusak pekerjaan developer lain, dan
  dokumentasikan file/alasan/dampak pada laporan. Jangan berhenti hanya karena
  file berada di area yang sebelumnya dikerjakan developer lain.
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
5. Bila pemeriksaan gagal, analisis akar masalahnya, perbaiki sendiri, dan jalankan
   ulang sampai selesai; jangan mengembalikan error yang masih dapat diperbaiki
   kepada pemilik proyek.
6. Perbarui dokumentasi bila fakta atau cara kerja berubah. Jangan mengklaim
   provider eksternal, deployment, aksesibilitas penuh, atau keamanan penuh telah diuji.

## Keamanan dan data

Gunakan `.env.example` sebagai daftar nama konfigurasi saja; jangan menampilkan
nilai `.env`. Jangan menjalankan mutasi database/provisioning akun sungguhan,
menghubungi provider berbayar, atau memakai data pribadi pada pengujian. Gunakan
fixtures sintetis dan environment uji bila tersedia.
