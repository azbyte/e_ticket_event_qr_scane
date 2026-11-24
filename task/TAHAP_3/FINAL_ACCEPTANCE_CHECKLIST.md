# FINAL ACCEPTANCE CHECKLIST — TAHAP 3

- **Versi:** 2.0 (2026-11-25)
- **Menggantikan:** `task/FINAL_ACCEPTANCE_CHECKLIST.md` v1.0 sebagai checklist pengisian aktif.
- **Acuan:** `PRD.md` v2.2, `task/ROADMAP_AUDIT_FINAL.md` §10, `task/TAHAP_3/README_TAHAP_3.md`.
- **Pengisi:** Developer 1 pada T3-D1-10.
- **Verifikator:** pemilik proyek.
- **Status yang diizinkan:** `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`.

> **Aturan:** `PASS` hanya diberikan bila butir benar-benar dijalankan dan buktinya dilampirkan. Test otomatis yang lulus **tidak** otomatis membuat butir UI/E2E menjadi PASS. Butir yang belum bisa dipenuhi **tetap ada** di checklist dengan status `BLOCKED`/`NOT RUN` dan alasan konkret.

## Cara mengisi

| Kolom | Isi |
|---|---|
| Status | `PASS` / `FAIL` / `BLOCKED` / `NOT RUN` |
| Bukti | Perintah, file, screenshot, query read-only, log, atau link |
| Tanggal | Tanggal eksekusi |
| Pelaksana | Nama/ID developer atau penguji |

Definisi status:

| Status | Arti |
|---|---|
| `PASS` | Dijalankan dan berhasil; bukti dilampirkan |
| `FAIL` | Dijalankan dan gagal; wajib ada analisis akar masalah |
| `BLOCKED` | Tidak dapat dikerjakan karena hambatan eksternal nyata (device, kredensial, akses DB, keputusan produk) |
| `NOT RUN` | Tidak dijalankan; wajib menyebut alasan konkret |

Contoh bukti yang sah:
- `npm test` → `PASS 180 test` + log.
- Request API + response JSON.
- Screenshot layar dengan data nyata.
- Query read-only: `SELECT ...` + hasil.
- File CSV yang dihasilkan + jumlah baris.

Contoh bukti yang **tidak sah**:
- "sudah dicek".
- "test hijau" tanpa perintah.
- "seharusnya jalan".
- Screenshot mock yang tidak ditandai demo.

---

## A. Fitur & alur per role

### A.1 Organizer

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-01 | Register/login Organizer berfungsi | §2.2 | Manual + API | | | | |
| A-02 | Organizer membuat event baru | §3 | Manual + API | | | | |
| A-03 | Organizer mengisi kategori tiket (harga, kuota, periode, aktif) | §4 | Manual + API | | | | |
| A-04 | Event valid otomatis `PUBLISHED` tanpa Admin | §3/AC-01 | API + UI | | | | |
| A-05 | Event invalid tetap `DRAFT` dan menampilkan alasan | §3/AC-01 | API + UI | | | | |
| A-06 | Edit event `PUBLISHED` yang menjadi invalid kembali `DRAFT` | §3 | API | | | | |
| A-07 | `public_url` tersedia dan dapat dibuka guest | §6.1 | API + manual | | | | |
| A-08 | `invite_url` tersedia dan berbeda dari `public_url` | §6.2 | API + UI | | | | |
| A-09 | Organizer mengatur field form dinamis (tipe, required, opsi, urutan) | §4 | UI + API | | | | |
| A-10 | Field dinamis tampil di form publik | §4 | Manual | | | | |
| A-11 | Organizer mengundang Staff dengan email + permission + expiry | §6.2 | Manual + API | | | | |
| A-12 | Organizer mencabut undangan/member | §6.2 | Manual + API | | | | |
| A-13 | Organizer melihat daftar peserta paid-first + nomor registrasi | §7/AC-09 | Manual + API | | | | |
| A-14 | Organizer melihat detail peserta termasuk `custom_fields` | §7 | Manual | | | | |
| A-15 | Organizer mengekspor CSV dengan urutan identik layar | §7/AC-09 | Manual + file | | | | |
| A-16 | Organizer melihat order/pembayaran per event | §7 | Manual + API | | | | |
| A-17 | Organizer melihat revenue/laporan dari server | §8 | Manual + API | | | | |
| A-18 | Organizer melihat riwayat check-in event-nya | §9 | Manual | | | | |
| A-19 | Organizer tidak dapat mengakses event Organizer lain | §2.2/AC-02 | Test negatif | | | | |
| A-20 | Organizer tidak dapat mengakses fungsi Admin | §2.2 | Test negatif | | | | |
| A-21 | Brosur event ditampilkan dari URL (bila diisi) | §4 | Manual | | | | |
| A-22 | Tiket default menampilkan data event/peserta/kategori | §5 | Manual | | | | |

### A.2 Participant (guest)

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-23 | Guest membuka `public_url` tanpa akun | §6.1/AC-04 | Manual | | | | |
| A-24 | Guest melihat info event, jadwal, lokasi/online, poster | §6.1 | Manual | | | | |
| A-25 | Guest melihat kategori, harga, sisa kuota, status tersedia | §4/§6.1 | Manual | | | | |
| A-26 | Guest memilih tepat satu kategori | §7/AC-03 | Manual + API | | | | |
| A-27 | Guest mengisi form dinamis; field wajib divalidasi | §4/§7 | Manual + API | | | | |
| A-28 | Order tercipta dengan satu peserta/satu tiket | §7/AC-03 | API | | | | |
| A-29 | Quantity selain 1 ditolak server | §7/AC-03 | Test negatif | | | | |
| A-30 | Harga dan fee berasal dari server | §8/AC-03 | API + UI | | | | |
| A-31 | Order gratis langsung menerbitkan tiket | §8/AC-07 | API | | | | |
| A-32 | Order berbayar hanya menerbitkan tiket setelah `PAID` | §8/AC-06 | API | | | | |
| A-33 | Guest tidak dapat memaksa status `PAID` | §8/AC-06 | Test negatif | | | | |
| A-34 | Status pembayaran `PENDING/PAID/EXPIRED/FAILED/CANCELLED` dibedakan | §8 | Manual | | | | |
| A-35 | Order expired tidak dapat dibayar | §8 | Test | | | | |
| A-36 | Retry idempotent tidak membuat order ganda | §7/AC-03 | Test | | | | |
| A-37 | Tiket menampilkan QR nyata dari token | §5/AC-07 | Manual + scan | | | | |
| A-38 | QR tidak memuat PII/harga | §9 | Review | | | | |
| A-39 | Guest dapat membuka tiket setelah checkout | §10 | Manual | | | | |
| A-40 | Guest tidak dapat membuka order/tiket orang lain | §8.2/AC-02 | Test negatif | | | | |
| A-41 | Tidak ada registrasi manual/assisted di UI | §7/AC-04 | Review | | | | |

### A.3 Staff

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-42 | Staff menerima undangan dengan email yang cocok | §6.2/AC-05 | Manual | | | | |
| A-43 | Email tidak cocok ditolak | §6.2/AC-05 | Test negatif | | | | |
| A-44 | Undangan expired/revoked/reused ditolak | §6.2/AC-05 | Test negatif | | | | |
| A-45 | Setelah accept, membership aktif dan permission tersalin | §6.2 | API + DB | | | | |
| A-46 | Staff diarahkan ke workspace event yang benar | §6.2 | Manual | | | | |
| A-47 | Staff hanya melihat event membership-nya | §2.3/AC-02 | Test negatif | | | | |
| A-48 | Staff dengan `SCAN_TICKET` dapat membuka scanner | §2.3/§9 | Manual | | | | |
| A-49 | Staff tanpa permission scan ditolak | §9/AC-08 | Test negatif | | | | |
| A-50 | Scanner memakai kamera + fallback input manual | §9 | Manual | | | | |
| A-51 | Scan valid membuat satu check-in | §9/AC-08 | API + DB | | | | |
| A-52 | Scan ulang `ALREADY_USED` tanpa baris baru | §9/AC-08 | Test | | | | |
| A-53 | Scan event lain `WRONG_EVENT` | §9/AC-08 | Test | | | | |
| A-54 | Scan tiket belum bayar `PAYMENT_REQUIRED` | §9/AC-08 | Test | | | | |
| A-55 | Dua scan bersamaan hanya satu sukses | §9/AC-08 | Test konkurensi | | | | |
| A-56 | Riwayat check-in menampilkan data nyata + filter | §9 | Manual | | | | |
| A-57 | Tidak ada check-in offline yang dianggap sukses | §9 | Review + test | | | | |

### A.4 Admin

| ID | Butir | PRD | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|---|
| A-58 | Login Admin berfungsi | §2.1 | Manual | | | | |
| A-59 | Admin melihat daftar akun + metrik | §2.1 | Manual + API | | | | |
| A-60 | Admin menonaktifkan akun dengan alasan wajib | §2.1 | Manual + API | | | | |
| A-61 | Aksi suspend/aktivasi akun tercatat di audit log | §2.1 | DB read-only | | | | |
| A-62 | Admin melihat audit log + filter + pagination | §2.1 | Manual + API | | | | |
| A-63 | Admin melihat settings platform + history | §8.1 | Manual + API | | | | |
| A-64 | Fee 5.000/komisi 5% tampil read-only | §8.1 | Manual | | | | |
| A-65 | Admin mengubah setting lain dan history bertambah | §8.1 | Manual + DB | | | | |
| A-66 | Dashboard Admin menampilkan statistik dari API | §2.1 | Manual + API | | | | |
| A-67 | Admin melihat revenue/transaksi platform | §8 | Manual + API | | | | |
| A-68 | Admin mengelola paket layanan (CRUD) | §8.1/C-03 | Manual + API | | | | |
| A-69 | Admin melihat daftar langganan | §8.1/C-03 | Manual + API | | | | |
| A-70 | Aksi langganan yang tidak didukung bersifat read-only | §8.1/C-03 | Manual | | | | |
| A-71 | Admin menangguhkan event dengan alasan | §2.1/§3 | Manual + API | | | | |
| A-72 | Event suspended hilang dari publik | §3/AC-01 | Manual + API | | | | |
| A-73 | Event suspended menolak order baru | §3/AC-01 | Test | | | | |
| A-74 | Admin memulihkan event suspended | §2.1 | Manual + API | | | | |
| A-75 | Admin menangani laporan (status/prioritas/balasan/catatan internal) | §2.1 | Manual + API | | | | |
| A-76 | Notifikasi Admin/Organizer berasal dari API | §2.1 | Manual + API | | | | |
| A-77 | Admin tidak dapat menyetujui/menolak publikasi event baru | §2.1/§3 | Review | | | | |

---

## B. Integrasi & data

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| B-01 | Tidak ada mock/fallback aktif pada `MOCK_MODE=false` | Grep + review | | | | |
| B-02 | Semua data penting bertahan setelah reload | Manual + DB | | | | |
| B-03 | Tidak ada endpoint tanpa pemakai / halaman tanpa endpoint | Review route vs UI | | | | |
| B-04 | `order_number` stabil sebelum/sesudah bayar | DB read-only | | | | |
| B-05 | `ticket_hash` ada untuk tiket gratis dan berbayar | DB read-only | | | | |
| B-06 | `audit_logs` terisi untuk aksi Admin | DB read-only | | | | |
| B-07 | `platform_setting_history` terisi untuk perubahan setting | DB read-only | | | | |
| B-08 | `attendees.custom_fields` menyimpan jawaban form dinamis | DB read-only | | | | |
| B-09 | `check_ins` unik per tiket; `scan_logs` tercatat | DB read-only | | | | |
| B-10 | Daftar peserta dan export memakai set/urutan identik | Manual + file | | | | |
| B-11 | Event suspended tidak muncul di `/api/events/public` | API | | | | |
| B-12 | Tidak ada data demo yang tampil tanpa penanda demo | Review | | | | |

---

## C. Keamanan & otorisasi

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| C-01 | Cross-owner event ditolak 403/404 | Test negatif | | | | |
| C-02 | Staff hanya event membership; permission dicek tiap request | Test negatif | | | | |
| C-03 | Invitation expired/revoked/wrong email ditolak | Test negatif | | | | |
| C-04 | Guest token tidak membuka order lain | Test negatif | | | | |
| C-05 | Token QR tidak bocor di log/URL/respons | Review + grep | | | | |
| C-06 | `token_hash` tidak dikirim ke klien | Test/review | | | | |
| C-07 | Rate limit & body limit aktif | Test/review | | | | |
| C-08 | CSV escaping mencegah formula injection | Test | | | | |
| C-09 | Tidak ada secret/`.env` di repo/log/dokumen | Grep | | | | |
| C-10 | CORS sesuai environment | Review | | | | |
| C-11 | Non-admin tidak dapat mengakses `/api/admin/*` | Test negatif | | | | |
| C-12 | Organizer tidak dapat mengubah event orang lain | Test negatif | | | | |
| C-13 | Payment status hanya berubah melalui backend | Test negatif | | | | |
| C-14 | Event suspended menolak order baru | Test | | | | |
| C-15 | Endpoint publik tidak membocorkan PII | Review | | | | |

---

## D. Kualitas otomatis

| ID | Perintah | Kriteria | Status | Bukti/log | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| D-01 | `cd backend; npm test` | PASS, 0 gagal | | | | |
| D-02 | `cd backend; npm run check` | PASS | | | | |
| D-03 | `cd backend; npm run format:check` | PASS | | | | |
| D-04 | `cd backend; npm run test:sync-config` | PASS | | | | |
| D-05 | `cd backend; npm run validate:skills` | PASS | | | | |
| D-06 | `cd apps; flutter analyze` | 0 issue | | | | |
| D-07 | `cd apps; flutter test` | PASS | | | | |
| D-08 | `cd apps; flutter test --dart-define=MOCK_MODE=false test/services/api_mode_no_fallback_test.dart` | PASS | | | | |
| D-09 | Test regresi AC-01…AC-10 tersedia | Ada + lulus | | | | |
| D-10 | Test konkurensi check-in | Lulus | | | | |
| D-11 | Test negatif keamanan (N-01…N-15) | Lulus | | | | |
| D-12 | Pagination pada endpoint daftar (peserta, order, audit, transaksi, riwayat) | Ada + diuji | | | | |
| D-13 | Tidak ada N+1 pada endpoint daftar/agregat | Review + log query | | | | |
| D-14 | `EXPLAIN` read-only query utama dilampirkan, atau `NOT RUN` beralasan | Output `EXPLAIN` | | | | |

---

## E. UX & platform

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| E-01 | Loading/empty/error/unauthorized/retry/success tersedia di layar kritis | Review + manual | | | | |
| E-02 | Web responsif 360 px tanpa overflow | Screenshot | | | | |
| E-03 | Web responsif 768 px tanpa overflow | Screenshot | | | | |
| E-04 | Web responsif 1280 px tanpa overflow | Screenshot | | | | |
| E-05 | Web responsif 1920 px tanpa overflow | Screenshot | | | | |
| E-06 | Keyboard/focus berfungsi di Web | Manual | | | | |
| E-07 | Android build berhasil | Build log | | | | |
| E-08 | Android alur inti berjalan | Manual | | | | |
| E-09 | Kamera Android/Web berfungsi atau `NOT RUN` beralasan | Manual | | | | |
| E-10 | Pesan error berbahasa Indonesia & dapat ditindaklanjuti | Review | | | | |
| E-11 | Tidak ada teks placeholder/demo pada alur produksi | Review | | | | |
| E-12 | Angka uang/fee konsisten dengan server | Review | | | | |
| E-13 | Tidak ada klaim "terkirim"/"terverifikasi" tanpa bukti | Review | | | | |

---

## F. Operasional & rilis

| ID | Butir | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
|---|---|---|---|---|---|---|
| F-01 | Dokumentasi instalasi & environment tersedia | Review | | | | |
| F-02 | Dokumentasi endpoint backend sesuai kode | Review | | | | |
| F-03 | Runbook operasional tersedia | Review | | | | |
| F-04 | Runbook diuji (start/health/backup/restore) atau `NOT RUN` beralasan | Eksekusi | | | | |
| F-05 | Konfigurasi production diperiksa (simulasi nonaktif, secret kuat, CORS/HTTPS) | Checklist | | | | |
| F-06 | Smoke test production-like lulus | Eksekusi | | | | |
| F-07 | Tidak ada migration tertunda / drift | `verify:db-schema` read-only | | | | |
| F-08 | Known limitations tercatat | Dokumen | | | | |
| F-09 | Tidak ada secret di repo | Grep | | | | |
| F-10 | Build Web tersedia | Build log | | | | |

---

## G. PRD open decisions & technical gaps

Butir di bawah **tidak boleh dihapus** meskipun belum bisa dipenuhi.

| ID | Hal | PRD | Status | Bukti/alasan |
|---|---|---|---|---|
| G-01 | C-01 formula fee/komisi final | §8.1 | | Fee 5.000/5% ditampilkan read-only; formula/payout belum final |
| G-02 | C-02 guest payment authorization final | §8.2 | | Guest order token dipakai sebagai interpretasi; catat asumsi |
| G-03 | C-03 plan/subscription gate | §8.1 | | Katalog/CRUD ada; paywall/entitlement tidak dibuat |
| G-04 | G-01 quantity>1/assisted di schema | §12.2 | | Backend menolak; schema legacy tetap |
| G-05 | G-03 refresh token | §8.2 | | Tidak ada endpoint refresh; catat |
| G-06 | G-04 deep link invitation | §6.2 | | Diuji atau `NOT RUN` |
| G-07 | G-05 token hash scanner | §9 | | Verifikasi implementasi |
| G-08 | G-06 sorting/export | §7 | | Dibuktikan |
| G-09 | G-07 upload brosur/template | §4/§5 | | Hanya URL/default; upload/template `BLOCKED` |
| G-10 | G-08 guest token/JWT ownership | §8.2 | | Diuji negatif |
| G-11 | G-09 expiry/email retry | §8 | | Diuji atau `NOT RUN` |
| G-12 | G-10 breakpoint responsive | §11 | | 360/768/1280/1920 diuji |
| G-13 | Akses tiket dari email di perangkat lain | §10 | | Bila tidak ada mekanisme aman: `BLOCKED` + penjelasan |
| G-14 | Template tiket pilihan | §5 | | Default saja; `BLOCKED` bila butuh storage |
| G-15 | Refund/pembatalan order | §8 | | Tidak termasuk MVP; catat |

---

## H. Pernyataan status akhir

| Status | Syarat | Layak? | Bukti |
|---|---|---|---|
| **MVP SELESAI** | A-01…A-77, B-01, D-01/D-06/D-07 lulus; tidak ada fitur inti mock | ☐ | |
| **SIAP DIUJI PENGGUNA** | MVP + C-01…C-15, E-01, E-02, tidak ada P0 | ☐ | |
| **SIAP DEPLOYMENT** | Semua di atas + E-07/E-08, F-01…F-10, tidak ada `NOT RUN` kritis | ☐ | |

**Catatan:** status **tidak boleh** dinaikkan karena asumsi atau karena "hampir selesai". Bila ada `NOT RUN`, tuliskan alasan konkret (tidak ada device, tidak ada kredensial SMTP, tidak ada akses deployment, tidak ada database uji).

---

## I. Daftar known limitations / BLOCKED / NOT RUN

| ID | Item | Status | Alasan konkret | Rencana |
|---|---|---|---|---|
| L-01 | | | | |
| L-02 | | | | |

---

## J. Sign-off

| Peran | Nama | Tanggal | Tanda tangan/ID |
|---|---|---|---|
| Developer 1 (pengisi) | | | |
| Pemilik proyek (verifikator) | | | |



