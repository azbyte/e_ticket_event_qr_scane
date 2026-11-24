> ⚠️ **VERSI AKTIF (2026-11-25).** Checklist pengisian Tahap 3 ada di [`TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`](TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md). Dokumen ini dipertahankan sebagai riwayat.


# FINAL ACCEPTANCE CHECKLIST — E-Ticket Event

- **Versi:** 1.0 (2026-11-23)
- **Pemakaian:** diisi pada akhir Tahap 3 (T3-D3-5). Setiap baris wajib menyertakan bukti. **Jangan menandai PASS tanpa eksekusi.**
- **Definisi lengkap:** [`ROADMAP_AUDIT_FINAL.md`](ROADMAP_AUDIT_FINAL.md) §10.
- **Status yang diizinkan:** `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`.

## Cara mengisi

| Kolom | Isi |
|---|---|
| Bukti | Perintah/uji/screenshot/query |
| Tanggal | Tanggal eksekusi |
| Pelaksana | Developer/penguji |

## A. Alur per role

| ID | Butir | Uji | Hasil | Bukti |
|---|---|---|---|---|
| A-01 | Organizer membuat event & mengisi kategori tiket | Manual + API | | |
| A-02 | Event valid otomatis `PUBLISHED` tanpa Admin | API `POST /events/:id/publish` | | |
| A-03 | Event invalid tetap `DRAFT` + alasan | API + UI | | |
| A-04 | `public_url` tersedia & dapat dibuka guest | Manual | | |
| A-05 | `invite_url` tersedia & berbeda dari `public_url` | Manual | | |
| A-06 | Guest daftar tanpa akun (1 tiket, 1 peserta) | Manual | | |
| A-07 | Order & pembayaran simulasi berstatus benar | Manual + API | | |
| A-08 | E-ticket QR dapat dipindai | Device/kamera | | |
| A-09 | Staff menerima undangan & masuk workspace | Manual | | |
| A-10 | Scanner memvalidasi & menolak tiket tidak sah | Manual + API | | |
| A-11 | Check-in tercatat sekali & riwayat tampil | Manual + DB read-only | | |
| A-12 | Organizer melihat peserta (paid-first) & detail | Manual | | |
| A-13 | Export CSV identik dengan layar | Manual | | |
| A-14 | Organizer melihat order/payment & revenue | Manual | | |
| A-15 | Admin melihat akun & menonaktifkan dengan alasan | Manual + DB audit | | |
| A-16 | Admin melihat audit log hasil aksi tadi | Manual + query | | |
| A-17 | Admin mengubah settings & history tercatat | Manual + query | | |
| A-18 | Admin melihat revenue/transaksi, paket, langganan | Manual | | |
| A-19 | Admin menangguhkan event beralasan; event hilang dari publik | Manual + API | | |
| A-20 | Admin menangani laporan/keluhan | Manual | | |
| A-21 | Notifikasi Organizer/Admin berasal dari API | Manual + API | | |

## B. Integrasi & data

| ID | Butir | Hasil | Bukti |
|---|---|---|---|
| B-01 | Tidak ada mock aktif pada layar in-scope (`MOCK_MODE=false`) | | |
| B-02 | Semua data bertahan setelah reload | | |
| B-03 | Tidak ada endpoint tanpa pemakai / halaman tanpa endpoint | | |
| B-04 | `order_number` stabil sebelum/sesudah bayar | | |
| B-05 | `ticket_hash` ada untuk semua tiket | | |
| B-06 | `audit_logs` & `platform_setting_history` terisi | | |
| B-07 | `attendees.custom_fields` menyimpan jawaban form dinamis | | |

## C. Keamanan & otorisasi

| ID | Butir | Hasil | Bukti |
|---|---|---|---|
| C-01 | Cross-owner event 403/404 | | |
| C-02 | Staff hanya event membership & permission dicek | | |
| C-03 | Invitation expired/revoked/email salah ditolak | | |
| C-04 | Guest token tidak membuka order lain | | |
| C-05 | Token QR tidak bocor di log/URL | | |
| C-06 | Rate limit & body limit aktif | | |
| C-07 | CSV escaping aman | | |
| C-08 | Tidak ada secret ter-commit | | |

## D. Kualitas otomatis

| ID | Perintah | Hasil | Log |
|---|---|---|---|
| D-01 | `cd backend; npm test` | | |
| D-02 | `cd backend; npm run check` | | |
| D-03 | `cd backend; npm run format:check` | | |
| D-04 | `cd backend; npm run test:sync-config` | | |
| D-05 | `cd apps; flutter analyze` | | |
| D-06 | `cd apps; flutter test` | | |
| D-07 | `flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | | |

## E. UX & platform

| ID | Butir | Hasil | Bukti |
|---|---|---|---|
| E-01 | Loading/empty/error/unauthorized/retry/success tersedia | | |
| E-02 | Web responsif 360/768/1280/1920 tanpa overflow | | |
| E-03 | Android build & alur inti | | |
| E-04 | Pesan error berbahasa Indonesia & dapat ditindaklanjuti | | |
| E-05 | Tidak ada klaim palsu tanpa bukti | | |

## F. Operasional & rilis

| ID | Butir | Hasil | Bukti |
|---|---|---|---|
| F-01 | Dokumentasi instalasi & environment | | |
| F-02 | Runbook operasional tersedia & diuji | | |
| F-03 | Konfigurasi production diperiksa | | |
| F-04 | Smoke test production-like lulus | | |
| F-05 | Tidak ada migration tertunda | | |
| F-06 | Known limitations tercatat | | |

## G. Pernyataan status akhir

| Status | Syarat | Layak? |
|---|---|---|
| MVP SELESAI | A-01…A-21 + D-01/D-05/D-06 lulus, B-01 lulus | ☐ |
| SIAP DIUJI PENGGUNA | MVP + C-01…C-08, E-01, E-02, tidak ada P0 | ☐ |
| SIAP DEPLOYMENT | Semua di atas + E-03, F-01…F-06, tidak ada `NOT RUN` kritis | ☐ |

**Catatan:** bila ada `NOT RUN`, tuliskan alasan konkret (tidak ada device, tidak ada kredensial SMTP, tidak ada akses deployment). Status **tidak boleh** dinaikkan karena asumsi.
