# Tahap 3 — Developer 3: runbook, checklist, smoke evidence

## Tujuan dan gate

Siapkan instruksi demo yang dapat diulang dan bukti smoke untuk fitur yang
benar-benar tersedia pada baseline. Mulai hanya setelah Tahap 2 GO terverifikasi
dan kontrak teknis/environment demo yang relevan disahkan. C-03 hanya memblokir
butir billing/entitlement yang bergantung padanya, bukan seluruh runbook. Task ini dokumentasi/harness; tidak
menggantikan implementasi MVP dan tidak membenarkan mock/dummy sebagai integrasi.

## Baca efisien

Baca `../../PRD.md` §§10, 12–16; `../../README.md`; bagian relevan
`../../docs/ARCHITECTURE.md`; `INTEGRATION_CONTRACT.md`, `FILE_OWNERSHIP.md`,
laporan gate Tahap 2, audit demo yang relevan di `../AUDIT_PROYEK/`, serta
`.env.example` hanya untuk nama variabel. Periksa scripts/tests conventions yang
akan disentuh. Jangan membuka `.env`, seluruh arsip, atau source tak terkait.

## Pekerjaan

1. Buat `task/DEMO_RUNBOOK.md`: versi/prasyarat, nama variabel environment saja,
   start/health dan Flutter API-mode commands yang terbukti sesuai repository,
   target Web/device, dependency/setup operator eksternal, akun demo hanya
   sebagai status provisioning (tanpa kredensial), dan layanan/provider yang
   belum diuji. Jangan memberi perintah reset/deploy/mutasi database.
2. Buat `task/DEMO_CHECKLIST.md`: acceptance wajib PRD dan alur yang tersedia,
   termasuk negative access/security, event → guest order/payment/ticket,
   Staff/check-in, attendee/export/Admin, UI states dan Android/Web. Tiap butir
   memiliki PASS/FAIL/BLOCKED/NOT RUN, evidence dan batas lingkungan. Live API/DB
   diperlukan untuk klaim E2E; mock-only tidak dapat menjadi GO.
3. Smoke checks hanya non-destructive/read-only pada interface yang sudah ada.
   Jangan menambah write path atau mengakses provider eksternal. Jika harness
   memerlukan akses DB atau path di luar allow-list, jangan implementasikan:
   catat blocker dan minta amendment/otorisasi terpisah.
4. Tandai seed/provisioning, migration, email dan payment sandbox sebagai
   prasyarat eksternal/operator. Jangan menulis credential atau hasil fiktif.
- Runbook/checklist/harness baru harus dibuat pada allow-list D3; saat ini belum
  tersedia, sehingga tugas dokumentasi belum selesai dan demo readiness belum
  dapat diklaim. Harness wajib menguji kemampuan baseline, bukan menutupi fitur
  MVP yang belum terimplementasi.

## File dan dependency

Hanya path Developer 3 di `FILE_OWNERSHIP.md`; semua kode production, database,
schema/migration, seed, routes/config, dependency, CI, secret dan file D1/D2
terkunci. Task dokumentasi/harness tidak menunggu implementasi branch D1/D2;
catat kemampuan yang tidak ada pada baseline sebagai blocker. Database restriction
rinci pada `../FINISHING_AUTHORITY.md`.

## Acceptance, test, laporan

- Semua link/command yang didokumentasikan mengarah pada file/command yang ada;
  environment variable hanya disebut namanya, tidak ada rahasia.
- Checklist mencakup mandatory criteria yang relevan, setiap item punya field
  status/evidence dan menghindari klaim selesai tanpa hasil aktual.
- Harness (jika dibuat) bersifat read-only, lokal/sintetis, tidak memakai
  `.env`/database pengguna atau menghubungi layanan eksternal.
- Jalankan test dokumentasi/harness yang relevan tanpa mutasi DB; tulis hasil
  sebenarnya di `LAPORAN_DEVELOPER_3.md`, termasuk file, acceptance, command,
  PASS/FAIL/BLOCKED/NOT RUN, dependency, blocker dan hal yang belum diuji.