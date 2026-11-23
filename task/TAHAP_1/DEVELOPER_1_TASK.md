# Tahap 1 — Developer 1: autentikasi dan akses dasar

> Task auth tidak bergantung pada formula biaya, guest payment authority atau paket C-01–C-03. Tetap wajib lolos gate teknis Tahap 1 dan memakai baseline/kontrak yang disetujui. Tugas tidak mengizinkan perubahan requirements/DB/API global.

## Tujuan
Menutup gap autentikasi/session dasar dan memastikan API serta Flutter konsisten menggunakan login/logout/profile yang tersedia, tanpa menambah participant account atau refresh flow yang belum disetujui.

## Kondisi awal
Baca `../../PRD.md` §§2, 12–16; `../../README.md`; `../../docs/ARCHITECTURE.md`; `INTEGRATION_CONTRACT.md`; `FILE_OWNERSHIP.md`; routes/controllers/providers saat ini. Verifikasi baseline serta kontrak teknis Tahap 1 disetujui; jangan membaca secret `.env`.

## Pekerjaan
1. Trace login/logout/me/updateMe Flutter ↔ Express; buktikan request/header/JSON mapping.
2. Pastikan error/loading/session-expired ditampilkan eksplisit dan API gagal tidak beralih ke mock.
3. Audit serta perbaiki test positif/negatif role/auth di lingkup yang ditetapkan, tanpa mengubah authorization contract.
4. Pastikan flow registration Flutter hanya menghasilkan role yang diizinkan PRD (Organizer; admin/staff provision sesuai server invitation), bukan Participant account. Jika server route memaksa perubahan global/DB, laporkan blocker, jangan ubah file locked.
5. Pastikan logout membersihkan session lokal yang dimiliki auth service sesuai implementasi aktual; jangan mengarang server revocation.

## File dan dependensi
Boleh: hanya Developer 1 paths di `FILE_OWNERSHIP.md`. Dilarang: semua locked paths dan file developer lain pada tabel tersebut. Dependency: baseline dan technical contract Tahap 1. C-01–C-03 tidak diperlukan untuk perilaku auth dan bukan blocker bagi scope ini; task tetap menunggu baseline/technical gate yang relevan dan tidak dapat membuka Tahap 2 sendiri.

## Kriteria / verifikasi
- Login valid → session/role ditetapkan benar; invalid credentials → error tanpa mock session.
- `/me` dan profile update mengirim Bearer token yang benar; unauthorized ditangani.
- Logout membersihkan credential lokal; reopen tidak menganggap user logged-in.
- Role tidak dapat di-upgrade melalui input client; server tetap otoritas role.
- Jalankan test target baru/terdampak; catat command/result/skips. Jangan klaim live auth/provider diuji.

## Hindari / laporan
Jangan edit app router/provider root, global API client, route/middleware lain, DB/schema, dependencies. Isi `LAPORAN_DEVELOPER_1.md` berdasar diff dan test aktual; temuan yang perlu file owner lain dilaporkan, bukan diedit.
