# Kontribusi

1. Buat branch untuk satu unit perubahan dan jelaskan tujuan serta cakupan.
2. Aktifkan hook pre-push satu kali pada setiap clone:
   `git config core.hooksPath .githooks`. Pastikan dependency backend dan Flutter
   sudah tersedia (`npm ci` di `backend/` dan `flutter pub get` di `apps/`).
   Hook menjalankan pemeriksaan kualitas penuh sebelum push; jangan gunakan
   `git push --no-verify` untuk melewati pemeriksaan.
3. Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, PRD dan skill yang dirutekan lewat
   `SKILL.md` untuk jenis pekerjaan.
4. Jangan sertakan `.env`, secret, data pribadi, build output atau perubahan
   dependency yang tidak diperlukan. Jangan mengubah API/database/fitur bisnis
   dalam PR tooling.
5. Jalankan `npm --prefix backend run validate:skills` dari root setelah
   mengubah instruksi/skill; jalankan pemeriksaan frontend/backend yang relevan
   menurut `README.md` dan laporkan perintah serta hasilnya. Untuk bug, sertakan
   langkah reproduksi dan regression test jika memungkinkan.
6. Sebelum membuat PR, jalankan PR Quality Gate melalui AI di VS Code
   (skill `pr-quality-gate`) atau jalankan pemeriksaan secara manual menurut
   `PR_QUALITY_GATE.md`. Pastikan semua pemeriksaan wajib berhasil.
7. Tinjau diff, dokumentasi dan status Git sebelum membuat PR. PR menjelaskan
   risiko, pengujian, integrasi yang tidak diuji dan screenshot UI bila relevan.

## Syarat merge dan konflik

Maintainer repository perlu membuat branch protection/ruleset untuk setiap
branch tujuan PR (minimal `main`) dan menandai status check `PR Quality Gate`
sebagai required. Aktifkan juga kewajiban branch terbaru sebelum merge agar PR
tidak digabungkan di atas base yang sudah berubah. Workflow CI tetap berjalan
untuk semua branch, tetapi hanya aturan GitHub tersebut yang dapat memblokir
merge; hook lokal dapat dilewati dan bukan pengganti CI.

Jika sinkronisasi branch setelah merge menemukan konflik, ringkasan job GitHub
akan mencantumkan branch dan file konflik beserta perintah `fetch`, `switch`,
`merge`, dan `push`. Selesaikan konflik secara manual: tinjau kedua perubahan,
jangan memilih sisi secara membabi buta, dan untuk konflik file biner atau
modify/delete putuskan secara eksplisit apakah file dipertahankan atau dihapus.
Setelah itu jalankan pemeriksaan kualitas sebelum push kembali.
