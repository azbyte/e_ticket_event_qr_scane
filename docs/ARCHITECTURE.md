# Arsitektur dan panduan pengembangan

## Kondisi aktual

Repository berisi aplikasi Flutter di `apps/` dan API Node.js di `backend/`.
Flutter menargetkan Android/Web, menggunakan Provider, HTTP, secure storage, dan
mode mock/demo yang aktif secara default (`MOCK_MODE=false` untuk API). Backend
menggunakan JavaScript CommonJS, Express 4, JWT, Supabase JS/PostgreSQL, validasi
`express-validator`, serta QR generator. Struktur backend aktual berada di
`backend/src/{config,controllers,middleware,models,routes,services,utils,validators}`.

Alur umum API adalah routes → middleware (auth/role/validation) → controllers →
services/models → Supabase. Periksa kode dan migration di
`backend/supabase/migrations/` untuk kontrak aktual. README backend berisi bagian
schema/endpoint historis yang mungkin tidak sama dengan implementasi sekarang;
jangan gunakan bagian itu sebagai sumber kebenaran tanpa verifikasi.

Flutter mengorganisasi kode di `apps/lib/` menjadi `core`, `features`, `models`,
`providers`, dan `services`. UI menggunakan tema/material yang telah ada.
Perubahan UI perlu mempertahankan mock dan integrasi API yang terpisah.

## Alur kerja

1. Baca `AGENTS.md`, PRD, README dan modul terdampak. Periksa status/diff Git.
2. Hindari perubahan bisnis, database dan dependency saat tugas hanya tooling.
3. Gunakan fixtures sintetis; tidak perlu Supabase untuk unit/widget test.
4. Frontend, dari `apps/`: `flutter pub get`, `flutter analyze`, `flutter test`.
5. Backend, dari `backend/`: `npm ci`, `npm test`,
   `npm run test:sync-config`,
   `npm run check`, `npm run format:check`, `npm run validate:skills`.
6. Tinjau diff, periksa secret dan dokumentasi, catat hasil/batasan.

Git hook `.githooks/pre-push` dapat diaktifkan per clone dengan
`git config core.hooksPath .githooks`. Hook menjalankan seluruh pemeriksaan kode
sebelum push dan memerlukan dependency lokal yang telah disiapkan. GitHub Actions
menjalankan quality workflow pada semua push dan pull request; maintainer harus
menjadikan status `PR Quality Gate` required melalui branch protection/ruleset
agar kegagalan memblokir merge. Konflik sinkronisasi branch dilaporkan dengan
daftar file dan instruksi resolusi pada ringkasan job.

`npm run lint` adalah alias kompatibilitas untuk `npm run check` dan tidak
dijalankan terpisah oleh CI. `npm run format:check` memeriksa trailing
whitespace dan JSON, bukan formatter penuh. `npm run validate:skills` memeriksa
frontmatter, nama skill unik, dan target link relatif pada katalog/skill.
ESLint/Prettier belum dipasang: instalasi dicoba tetapi registry npm tidak
tersedia pada sesi audit.

## UI quality

Gunakan design tokens/theme dan widgets proyek sebelum menambah komponen baru.
Periksa Android/web layout sempit dan lebar, teks panjang, fokus/keyboard,
semantics/label, kontras, serta loading/error/empty/success state. Belum ada
visual regression runner atau audit accessibility otomatis yang dikonfigurasi.

## Batas integrasi dan keamanan

Supabase, kamera scanner, payment, autentikasi provider, API end-to-end dan
deployment memerlukan konfigurasi/layanan yang tidak disediakan untuk test lokal.
Jangan mengekspos `SUPABASE_SERVICE_ROLE_KEY` atau `JWT_SECRET` ke Flutter.
Otorisasi harus ditegakkan di server; role UI bukan boundary keamanan.
