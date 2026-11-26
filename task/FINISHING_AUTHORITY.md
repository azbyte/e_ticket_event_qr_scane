# Otoritas database dan tahap FINISHING

> **Catatan workflow autonomous:** dokumen ini mengatur **wewenang database** —
> batas nyata yang tetap berlaku, bukan approval gate teknis untuk pekerjaan
> sehari-hari. Developer 1–3 menyelesaikan seluruh scope task yang tidak
> memerlukan perubahan DB tanpa menunggu izin apa pun (lihat *Autonomous Execution
> Protocol* pada [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md)); kebutuhan
> DB dicatat sebagai proposal di [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md)
> dan butir yang benar-benar bergantung DB ditandai NOT RUN dengan alasan spesifik.
> Ketentuan Developer 1 Tahap 1 yang sudah disetujui tetap berlaku apa adanya.


## Aturan mutlak

Selama Tahap 1–3 dan integrasi masing-masing, Developer 1, 2, dan 3 **dilarang**
mengubah `backend/prisma/schema.prisma`, migration Prisma atau SQL, migration
Supabase, struktur/relasi/constraint tabel, konfigurasi database, seed, maupun
menjalankan perintah yang mengubah database. Menemukan kebutuhan DB bukan
otorisasi untuk mengedit.

Developer yang menemukan kebutuhan tersebut harus menghentikan bagian terkait
dan menyerahkan proposal berisi:

- kebutuhan/acceptance PRD dan alasan teknis;
- model/tabel/relasi/constraint terdampak;
- kompatibilitas data dan migration sebelumnya;
- dependency API/client/task lain;
- risiko, prosedur validasi, pengujian, dan rencana rollback bila relevan;
- bukti bahwa solusi tanpa perubahan database tidak mencukupi.

Proposal dicatat pada laporan developer dan diserahkan kepada maintainer untuk
dipertimbangkan pada FINISHING. Jangan membuat perubahan palsu/local-only atau
dummy yang diklaim sebagai integrasi persisten.

## Kapan FINISHING berwenang

FINISHING adalah satu-satunya tahap yang dapat mengizinkan perubahan database.
Otoritas tidak melekat otomatis pada Developer 4, integrator, atau jabatan lain.
Sebelum pekerjaan FINISHING dimulai, pemilik proyek/maintainer wajib mencatat:

1. nama/identitas penanggung jawab FINISHING;
2. gate FINISHING dibuka dan baseline tahap 3 GO yang menjadi dasar;
3. daftar proposal database yang disetujui serta alasan/PRD requirement;
4. scope dan file yang boleh diubah; pihak reviewer/persetujuan;
5. environment test terisolasi dan prosedur validasi yang diizinkan.

Tanpa seluruh catatan tersebut, perubahan database tetap **BLOCKED**. Peran
Developer 4 atau nama task “finishing” saja tidak cukup untuk memberikan kuasa.

## Prosedur perubahan DB yang disetujui

Hanya penanggung jawab FINISHING yang ditetapkan boleh mengimplementasikan
perubahan yang disetujui. Setiap perubahan harus:

- sesuai PRD/keputusan tertulis dan konsisten dengan `backend/prisma/schema.prisma`
  sebagai sumber schema yang ditetapkan;
- meninjau riwayat dan objek legacy `backend/prisma/legacy-migrations/` tanpa
  menjalankan/menghapusnya secara otomatis;
- memiliki migration yang reviewable dan tidak merusak data/migration sebelumnya;
- memeriksa relasi, constraint, indeks, otorisasi, kompatibilitas runtime dan
  dampak API/client;
- diuji hanya pada database disposable/non-production yang disetujui; tidak ada
  reset/push/mutasi database pengguna atau remote tanpa otorisasi terpisah;
- mencatat prosedur deployment/validasi, risiko/rollback, hasil test, reviewer,
  file dan alasan pada laporan FINISHING.

Seed/demo provisioning hanya dapat dilakukan oleh operator yang berwenang pada
database test terisolasi sesuai prosedur yang disetujui; jangan menyimpan
credential di repository atau laporan.

## Batas integrator

Developer 4/integrator memeriksa report, ownership, kontrak, test, build dan
integrasi. Tanpa penetapan tertulis di atas, ia tidak mengubah database. FINISHING
tidak menghapus tanggung jawab developer: task yang tak membutuhkan DB harus
diselesaikan oleh owner tahapnya. Pekerjaan domain yang belum selesai dikembalikan
kepada owner dengan blocker/evidence, bukan disamarkan sebagai finishing.