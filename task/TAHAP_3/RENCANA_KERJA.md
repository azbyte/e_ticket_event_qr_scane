# TAHAP 3 — RENCANA KERJA (FINALISASI & KESIAPAN RILIS)

- **Versi:** 3.1 (revisi 2026-11-23 — pelaksana diselaraskan dengan skema tim: **Developer 4** mengerjakan tahap akhir)
- **Menggantikan:** versi pra-audit di `../archive/TAHAP_3_RENCANA_KERJA_PRA_AUDIT_2026-11-23.md` dan versi 3.0 (yang membagi finalisasi ke D1/D2/D3).
- **Prasyarat:** **Gate G2 Tahap 2 lulus** (`../TAHAP_2/RENCANA_KERJA.md` §H). Tahap 3 **bukan** tempat menampung fitur inti MVP.
- **Acuan:** [`../../PRD.md`](../../PRD.md), [`../PEMBAGIAN_TUGAS_FINAL.md`](../PEMBAGIAN_TUGAS_FINAL.md), [`../ROADMAP_AUDIT_FINAL.md`](../ROADMAP_AUDIT_FINAL.md), [`../FINAL_ACCEPTANCE_CHECKLIST.md`](../FINAL_ACCEPTANCE_CHECKLIST.md).

> Dokumen ini adalah rencana. Tidak ada source code yang diubah saat penyusunan.

---

## A. Prinsip Tahap 3

1. Tahap 3 hanya berisi pekerjaan **penyempurnaan, pengujian, dan kesiapan rilis**.
2. Fitur wajib PRD yang belum selesai pada Tahap 2 **tidak boleh** dipindahkan ke sini; item tersebut dikembalikan ke task Tahap 2 pemiliknya.
3. Setiap klaim harus berbasis bukti. Status hanya: `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`.
4. Tidak ada klaim "siap production" bila SMTP, device/Android, Web, atau deployment belum diuji.
5. Tidak ada perubahan kontrak API/kebijakan data pada Tahap 3 kecuali untuk memperbaiki bug yang terbukti.

---

## B. Model pelaksanaan

**Tahap 2** dikerjakan **D1, D2, D3 secara paralel**.
**Tahap 3** dikerjakan oleh **Developer 4 sebagai pelaksana tunggal** finalisasi.

| Pelaksana | Peran Tahap 3 |
|---|---|
| **Developer 4** | Pelaksana tunggal seluruh task T3-01 … T3-13: audit kesiapan, UI/UX, responsivitas, integrasi, keamanan, konsistensi data, email, QR/check-in, performa, konfigurasi production, dokumentasi, runbook, acceptance. |
| Developer 1/2/3 | Dipanggil kembali **hanya** sebagai *subject-matter owner* bila D4 menemukan bug domain. D4 melaporkan (file, bukti, langkah reproduksi); owner yang memperbaiki sesuai allow-list Tahap 2 miliknya. |

### B.1 Aturan untuk Developer 4

1. D4 **tidak** mengubah logika bisnis domain D1/D2/D3.
2. Yang dikerjakan D4: perbaikan UI/UX, label/teks, konfigurasi, dokumentasi, harness pengujian, dan bug kecil di area netral (mis. `core/theme`, `core/validators`, `docs/`, `task/`, file konfigurasi).
3. Bug domain (logika order, publish, scanner, attendee, admin) → **dilaporkan**, bukan diperbaiki D4.
4. Bila D4 menemukan fitur wajib MVP belum selesai: gate G2 diturunkan menjadi `FAIL`; pekerjaan dikembalikan ke owner; Tahap 3 **berhenti** sampai G2 hijau kembali.
5. Setiap perbaikan owner atas temuan D4 harus melalui PR terpisah yang dirujuk dari laporan D4.
6. D4 tidak boleh memutuskan keputusan produk terbuka (C-01, C-02, C-03). Bila terhalang, tandai `BLOCKED` + tunjuk dokumen keputusan.

### B.2 Pemetaan 15 butir mandat → task Tahap 3

| # | Butir wajib Tahap 3 | Task |
|---|---|---|
| 1 | Penyelesaian kekurangan non-core yang relevan | T3-02, T3-11 |
| 2 | Penyempurnaan UI/UX | T3-02 |
| 3 | Responsive design mobile & desktop | T3-03 |
| 4 | Validasi seluruh alur pengguna | T3-04, T3-05 |
| 5 | Integrasi & regression testing | T3-05 |
| 6 | Pengujian keamanan & hak akses | T3-06 |
| 7 | Pengujian database & konsistensi transaksi | T3-07 |
| 8 | Pengujian email & notifikasi nyata | T3-08 |
| 9 | Pengujian QR Code & check-in | T3-09 |
| 10 | Penanganan error & edge case | T3-04 |
| 11 | Optimasi performa | T3-10 |
| 12 | Pemeriksaan konfigurasi production | T3-11 |
| 13 | Dokumentasi instalasi & deployment | T3-11 |
| 14 | Runbook operasional | T3-12 |
| 15 | Smoke testing & final acceptance | T3-12, T3-13 |

---

## C. Task Developer 4

### T3-01 — Audit kesiapan & daftar temuan

- **Cakupan:** verifikasi Gate G2 benar-benar lulus sebelum Tahap 3 dimulai.
- **Pekerjaan:**
  1. Jalankan seluruh perintah §D; bandingkan dengan bukti laporan D1/D2/D3.
  2. Periksa setiap butir G2 (`../TAHAP_2/RENCANA_KERJA.md` §H): `PASS`/`FAIL`.
  3. Catat setiap fitur wajib MVP yang belum selesai → kembalikan ke owner.
  4. Susun daftar temuan bernomor (F-01, …) dengan file & bukti.
- **Kriteria:** laporan audit memuat status G2 + daftar temuan; tidak ada klaim tanpa perintah yang dijalankan.
- **Larangan:** memperbaiki logika domain D1/D2/D3.

### T3-02 — Penyempurnaan UI/UX lintas alur

- **Cakupan:** konsistensi tema, tipografi, spacing, bahasa, dan state (loading/empty/error/unauthorized/retry) pada layar publik, Organizer, Staff, dan Admin.
- **Pekerjaan:** audit visual per layar; perbaiki label/teks menyesatkan; hilangkan sisa teks placeholder/demo; pastikan pesan error dapat ditindaklanjuti; pastikan angka fee/komisi yang tampil = nilai server.
- **Kriteria:** daftar layar in-scope dengan status per item + screenshot.
- **Tidak termasuk:** perubahan logika/endpoint; redesign besar.

### T3-03 — Responsive design Web & mobile

- **Cakupan:** seluruh layar in-scope pada breakpoint 360 / 768 / 1280 / 1920.
- **Pekerjaan:** perbaiki overflow, grid, tabel→kartu, dialog, scroll; uji keyboard/focus di Web.
- **Kriteria:** tidak ada `RenderFlex overflow`; bukti per breakpoint.

### T3-04 — Validasi alur & penanganan error/edge case

- **Cakupan:** alur penuh per role + minimal 10 skenario edge case (event hilang saat dibuka, kuota habis di tengah checkout, order kedaluwarsa, double-pay, jaringan putus, respons API tidak lengkap, dll).
- **Pekerjaan:** jalankan; catat hasil; laporkan bug domain ke owner; perbaiki hanya yang bersifat presentasi/konfigurasi.
- **Kriteria:** setiap skenario `PASS`/`FAIL`/`BLOCKED`; tidak ada layar kosong atau data palsu.

### T3-05 — Integrasi & regression testing lintas role

- **Cakupan:** Organizer → Guest → pembayaran → tiket → invitation Staff → scan → check-in → attendee/export → Admin audit/revenue/suspend.
- **Pekerjaan:** harness uji integrasi + panduan uji manual; jalankan seluruh test otomatis.
- **Kriteria:** seluruh alur §F lulus atau `BLOCKED` dengan alasan domain jelas.

### T3-06 — Pengujian keamanan & hak akses

- **Cakupan:** 15 skenario negatif §F.2 + pemeriksaan kebocoran token/secret.
- **Kriteria:** setiap skenario memberi status HTTP benar; tidak ada token di log/URL.

### T3-07 — Pengujian database & konsistensi transaksi

- **Cakupan:** kuota (`sold`/`held`), `check_ins` unik, `scan_logs`, `order_payments`, `ticket_hash`, `audit_logs`, `platform_setting_history`.
- **Pekerjaan:** skenario konkurensi + verifikasi integritas (query read-only).
- **Kriteria:** tanpa anomali; bukti query disertakan.
- **Larangan:** mengubah SQL/RPC/schema; bila perlu → proposal ke FINISHING.

### T3-08 — Pengujian email & notifikasi nyata

- **Cakupan:** email tiket, notifikasi in-app Organizer/Admin.
- **Kriteria:** `PASS` pada sandbox, atau `NOT RUN` dengan alasan kredensial konkret.

### T3-09 — Pengujian QR Code & check-in pada Android dan Web

- **Cakupan:** kamera, permission, fallback manual, hasil scan, riwayat.
- **Kriteria:** `PASS`/`FAIL`/`NOT RUN` per platform dengan alasan; tidak diklaim PASS tanpa eksekusi.

### T3-10 — Optimasi performa

- **Cakupan:** daftar peserta, export, dashboard Admin, audit log, scan, riwayat.
- **Pekerjaan:** pagination wajib, agregasi di SQL, hilangkan N+1, ukur sebelum/sesudah.
- **Kriteria:** target terukur tercapai pada data uji; bukti `EXPLAIN` read-only.
- **Larangan:** perubahan index/schema (proposal saja).

### T3-11 — Kekurangan non-core & konfigurasi production

- **Cakupan:** `.env.example`, `SIMULATED_PAYMENTS`, SMTP, CORS/HTTPS, secret JWT/tiket, `APP_PUBLIC_URL`, status migration, seed admin; dokumentasi usang (`docs/DATABASE.md`, `README.md`, `docs/ARCHITECTURE.md`, `task/PRD_TRACEABILITY_MATRIX.md`).
- **Kriteria:** dokumen sesuai repository aktual; tidak ada instruksi destruktif; seluruh perintah pada dokumen diverifikasi.
- **Larangan:** menyimpan secret/kredensial.

### T3-12 — Runbook operasional & smoke test

- **Cakupan:** `task/RUNBOOK_OPERASIONAL.md` — start/health/backup/restore/rotasi token/retry email/penanganan insiden + smoke test production-like.
- **Kriteria:** runbook dapat diikuti orang lain; smoke test lulus atau `NOT RUN` dengan alasan.

### T3-13 — Final acceptance & laporan Developer 4

- **Cakupan:** isi [`../FINAL_ACCEPTANCE_CHECKLIST.md`](../FINAL_ACCEPTANCE_CHECKLIST.md) dengan bukti; tulis `LAPORAN_DEVELOPER_4.md`.
- **Kriteria:** setiap baris punya status + bukti; pernyataan status akhir (MVP / Siap Uji / Siap Deployment) sesuai §F.
- **Larangan:** menaikkan status karena asumsi atau karena "hampir selesai".

---

## D. Perintah verifikasi wajib

| Perintah | Lokasi | Kriteria |
|---|---|---|
| `npm test` | `backend/` | PASS, 0 gagal |
| `npm run check` | `backend/` | PASS |
| `npm run format:check` | `backend/` | PASS |
| `npm run test:sync-config` | `backend/` | PASS |
| `flutter analyze` | `apps/` | 0 issue |
| `flutter test` | `apps/` | PASS |
| `flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | `apps/` | PASS |
| Pencarian mock pada layar in-scope | `apps/lib` | Tidak ada mock aktif |
| `flutter build web` / `flutter build apk --debug` | `apps/` | Berhasil (atau NOT RUN dengan alasan) |

---

## E. Matriks pengujian wajib

### E.1 Alur utama (happy path)
1. Organizer register → buat event → kategori tiket → publish otomatis.
2. Salin `public_url` → buka sebagai guest → daftar → order → bayar (simulasi) → tiket + QR.
3. Salin `invite_url` → login sebagai staff → terima undangan → workspace event.
4. Scan QR → check-in → riwayat menampilkan check-in.
5. Organizer: daftar peserta (paid-first) → detail → export CSV.
6. Admin: audit log memuat aksi → settings → revenue → suspend event beralasan.

### E.2 Alur negatif / keamanan
| ID | Skenario | Harapan |
|---|---|---|
| N-01 | Order quantity 2 | Ditolak 400/422 |
| N-02 | Harga dimanipulasi klien | Diabaikan; harga server |
| N-03 | Client memaksa status PAID | Ditolak |
| N-04 | Guest membaca order lain | 401/403/404 |
| N-05 | Scan tiket event lain | `WRONG_EVENT`, tanpa check-in |
| N-06 | Scan tiket belum dibayar | `PAYMENT_REQUIRED`, tanpa check-in |
| N-07 | Scan ulang tiket sama | `ALREADY_USED`, tanpa baris baru |
| N-08 | Staff tanpa permission scan | 403 |
| N-09 | Invitation expired/revoked/email lain | 403/410 |
| N-10 | Non-admin akses `/api/admin/*` | 403 |
| N-11 | Organizer mengedit event milik orang lain | 403/404 |
| N-12 | Tiket diakses tanpa order token | 401/403 |
| N-13 | Event suspended menerima order | Ditolak |
| N-14 | CSV dengan `=cmd` | Di-escape |
| N-15 | Rate limit login/order | 429 setelah batas |

### E.3 Data & konsistensi
- Kuota tidak melebihi `quota` setelah banyak order bersamaan.
- `sold` + `held` konsisten setelah order expired.
- `check_ins` unik per tiket.
- `ticket_hash` ada untuk semua tiket (termasuk gratis).
- `audit_logs` bertambah untuk setiap aksi admin.
- `platform_setting_history` bertambah untuk setiap perubahan setting.

### E.4 Platform
- Web: Chrome desktop (1280, 1920) & responsif (360).
- Android: build + alur utama + kamera.
- Status per platform wajib dicatat; `NOT RUN` bila tidak tersedia.

---

## F. Gate penyelesaian proyek (G3)

| # | Gate | Bukti |
|---|---|---|
| G3-1 | Seluruh butir `ROADMAP_AUDIT_FINAL.md` §10.2 bagian A–D tercentang | Checklist terisi |
| G3-2 | Matriks §E dijalankan; tidak ada `FAIL` terbuka; `NOT RUN` beralasan | Laporan pengujian |
| G3-3 | Seluruh perintah §D PASS | Log perintah |
| G3-4 | Tidak ada mock/in-memory pada layar in-scope di mode API | Hasil pencarian + review |
| G3-5 | Web responsif terbukti (360/768/1280/1920) | Screenshot/uji |
| G3-6 | Android build & alur inti terbukti (atau `NOT RUN` eksplisit) | Bukti build/manual |
| G3-7 | Email/notifikasi diuji dengan transport nyata atau `NOT RUN` terdokumentasi | Bukti/log |
| G3-8 | Dokumentasi instalasi, deployment, runbook, acceptance tersedia & terverifikasi | Dokumen + eksekusi |
| G3-9 | Tidak ada blocker P0/P1 terbuka | Daftar isu |
| G3-10 | Konfigurasi production diperiksa (simulasi pembayaran nonaktif, secret kuat, CORS/HTTPS) | Checklist config |
| G3-11 | Human acceptance: minimal 1 skenario penuh per role | Catatan penguji |

**Status akhir yang boleh diumumkan:**
- **MVP SELESAI** — G3-1, G3-3, G3-4 lulus.
- **SIAP DIUJI PENGGUNA** — MVP + G3-2, G3-5, G3-9.
- **SIAP DEPLOYMENT** — semua G3 lulus tanpa `NOT RUN` kritis.

---

## G. Larangan pada Tahap 3

1. Menambah fitur baru di luar PRD.
2. Menunda perbaikan fitur wajib dengan alasan "sudah lewat Tahap 2".
3. Mengganti pengujian nyata dengan klaim mock.
4. Menyimpan kredensial/SMTP/secret di repository.
5. Menjalankan migration/reset/seed pada database bersama tanpa otorisasi FINISHING.
6. Menyatakan production-ready tanpa G3 terpenuhi.
7. Developer 4 mengubah logika domain D1/D2/D3 tanpa persetujuan owner.


