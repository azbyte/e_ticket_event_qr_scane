# Integrasi Tahap 3 — tugas pasca-merge

> Ini tugas integrator pasca-merge. Bukan tahap FINISHING berotoritas database.

## Bahan dan cara memulai (non-blocking)

Mulai dari kondisi repository aktual saat perintah diberikan; tidak perlu menunggu
seluruh PR Tahap 3 merged atau baseline Tahap 2 GO. Baca kontrak/ownership, task
dan laporan D1–D3, diff/CI, PRD §§10–16, serta checklist yang dibuat D3. Bila
laporan atau evidence belum ada, kerjakan audit atas apa yang tersedia dan catat
bagian yang tidak dapat dibuktikan sebagai NOT RUN dengan alasan spesifik. Gate
dinyatakan tidak lulus hanya untuk hambatan eksternal nyata; kekurangan
dokumentasi bukan alasan berhenti.

## Urutan dan scope

1. Periksa path ownership, kontrak API/data/import, navigasi dan link runbook.
2. Jalankan quality checks backend/Flutter yang relevan dan builds bila toolchain
   tersedia; catat setiap hasil dan skip.
3. API/DB smoke hanya pada environment test terisolasi dan eksplisit. Tanpanya
   tandai BLOCKED/NOT RUN; jangan jalankan terhadap `.env`, DB pengguna/remote,
   akun sungguhan atau provider berbayar.
4. Periksa alur event → order/payment → ticket → check-in, authorization positif/
   negatif, export/report dan Android/Web sesuai environment; simpan evidence
   tanpa secret/PII.
5. Isi `LAPORAN_DEVELOPER_4.md` dan usulkan GO/NO-GO dengan baseline/evidence.
   Bug domain dikembalikan kepada owner D1–D3; tidak mengerjakan ulang fitur.

## Ownership dan larangan

Hanya `LAPORAN_DEVELOPER_4.md`, `backend/test/stage3_integration.test.js`, dan
`apps/test/stage3_integration_test.dart` sesuai `FILE_OWNERSHIP.md`. Tidak boleh
mengubah file domain, schema/migration/SQL/seed/config DB, global route/config,
dependency atau melakukan external mutation. Bila perbaikan kecil di file domain
benar-benar dibutuhkan agar integrasi dapat diuji, lakukan perubahan minimum,
jaga kontrak, dan dokumentasikan file/alasan/dampak pada laporan — tanpa menunggu
amendment ownership tertulis.

Integrator/Developer 4 **bukan** penanggung jawab FINISHING secara otomatis dan
tidak punya otoritas database dari task ini. Jika ingin ditunjuk untuk FINISHING,
penetapan eksplisit dan gate wajib dicatat menurut `../FINISHING_AUTHORITY.md`.

## Kriteria / laporan

Catat checks PASS/FAIL/BLOCKED/NOT RUN, test/API/DB/device limits, residual risk,
defect hand-back, acceptance evidence dan alasan GO/NO-GO. Environment yang tidak
tersedia berarti belum terbukti; jangan menyatakan demo-ready.