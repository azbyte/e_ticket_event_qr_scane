# Laporan Pembersihan Proyek — E-Ticket Event & QR Scanner

- **Tanggal:** 2026-11-28
- **Branch:** `feat/email` (HEAD `575f90a`)
- **Cakupan:** `apps/`, `backend/`, `docs/`, `scripts/`, root repository
- **Tidak disentuh:** `PRD.md`, `README.md`, `AGENTS.md`, `SKILL.md`, `CONTRIBUTING.md`,
  `PR_QUALITY_GATE.md`, `docs/**`, seluruh isi `task/**` (kecuali 2 baris rujukan path yang
  diperbarui), schema/migration, API, routes, controller, middleware, konfigurasi build,
  dependencies.

---

## A. Ringkasan

| Metrik | Sebelum | Sesudah |
|---|---|---|
| File ter-track Git | 594 | 593 |
| Artefak generated di disk | ~936 MB | ~0 MB |
| File laporan historis di root | 11 | 0 (dipindah ke `task/archive/`) |
| Isi root (file) | 21 | 10 |

Prinsip yang dipakai: **hapus hanya yang terbukti tidak dipakai**, diverifikasi dengan
analisis *reachability* (Dart) dan resolusi `require` (Node), bukan berdasarkan nama file.
Semua file yang dihapus berada di luar Git (ignored) atau merupakan kode mati yang sudah
diotorisasi penghapusannya oleh dokumen `task/`.

---

## B. Kode yang Dihapus

| File | Bukti | Dasar |
|---|---|---|
| `apps/lib/features/scanner/widgets/scanner_placeholder.dart` | (1) Nol `import`/`export`/`part` yang menunjuk file ini di seluruh `apps/lib` + `apps/test`. (2) Tidak *reachable* dari entry point `apps/lib/main.dart` (analisis transitif 150 file `apps/lib` → 148 reachable; hanya file ini dan `assisted_registration_screen.dart` yang tidak). (3) Tidak dipakai satu pun test. | `task/TAHAP_3/FILE_OWNERSHIP.md:959` — "Bila tidak lagi dipakai setelah kamera → Hapus setelah grep"; `task/TAHAP_3/TUGAS_DEVELOPER_2.md:218` — "hapus bila tidak dipakai". Kamera nyata (`camera_scanner_view.dart`) sudah dipakai. |

---

## C. File yang **Sengaja Dipertahankan** Meski Terlihat Tidak Dipakai

| File | Alasan dipertahankan |
|---|---|
| `apps/lib/features/organizer/operations/assisted_registration_screen.dart` | Terbukti kode mati (tidak reachable dari `main.dart` maupun test), **tetapi** `task/TAHAP_3/FILE_OWNERSHIP.md` §12.3 dan §12.4 menyatakannya eksplisit sebagai *file yang wajib dipertahankan* dan *tidak boleh dihapus meskipun tampak tidak dipakai* ("non-MVP, tetap ada", "disembunyikan, bukan dihapus"). |
| `backend/src/models/Event.js`, `Ticket.js`, `User.js`, `backend/src/config/supabase.js` | Nol `require` dari kode runtime (hanya saling mengimpor). **Tetapi** `backend/README.md:123–127` menyatakan keduanya sengaja dipertahankan karena berada di area konfigurasi database yang wewenangnya ada pada FINISHING, dan `AGENTS.md` melarang Developer 1–3 mengubah konfigurasi database. |
| `backend/scripts/**` (34 file) | Seluruhnya terdaftar di `backend/package.json`, di-`require` script lain (`e2e-live-helpers.js`, `e2e-registration-scenarios.js`, `integration/safety.js`), atau didokumentasikan di `backend/README.md`. Tidak ada yang yatim. |
| `backend/tools/*.py` + `requirements.txt` | Alat validasi PDF/QR terdokumentasi di `backend/README.md:188–189`. |
| `apps/ios/`, `apps/macos/`, `apps/linux/`, `apps/windows/` | `README.md:87` menyebut target **web/desktop**; scaffolding platform masih dipakai untuk build desktop. |
| `scripts/serve-web.js`, `pyrightconfig.json`, `backend/nodemon.json`, `.vscode/settings.json` | Dipakai/dirujuk `README.md`, `pyrightconfig` (Pylance), `test/server_startup.test.js`, dan `backend/README.md`. |
| `apps/lib/services/mock/**`, `organizer_event_fixtures.dart` | Mock demo `MOCK_MODE=true` — dipakai test suite dan mode demo. |

---

## D. Artefak Generated yang Dihapus

Semuanya ter-ignore Git (`.gitignore`, `apps/.gitignore`, `backend/.gitignore`), jadi **tidak
mengubah isi repository** dan dibuat ulang otomatis saat build/test berikutnya.

| Path | Ukuran | Isi |
|---|---|---|
| `apps/build/` | 827,2 MB (1029 file) | Output build Android/debug + cache `flutter test` |
| `apps/.dart_tool/` | 105,0 MB (279 file) | Cache tooling/pub |
| `apps/android/.gradle/` | 1,9 MB (25 file) | Cache Gradle |
| `backend/_verify-out/` | 2,3 MB (100 file) | Log & skrip hasil verifikasi manual (render PDF, decode QR, diagnostik) |

`backend/storage/` (3,6 MB) **tidak dihapus** — itu penyimpanan desain tiket runtime yang
mungkin masih dirujuk baris database. `backend/node_modules/` dan `backend/.venv/` juga
dipertahankan karena dibutuhkan untuk menjalankan backend dan alat validasi Python.

---

## E. Laporan Historis Root → `task/archive/`

11 dokumen laporan/audit yang sebelumnya menumpuk di root dipindahkan (bukan dihapus) ke
`task/archive/` menggunakan `git mv` sehingga riwayat Git tetap utuh:

`LAPORAN_AUDIT_PENDAFTARAN_DESAIN_TIKET.md`, `LAPORAN_MIGRASI_EMAIL_BREVO_SMTP.md`,
`LAPORAN_PERBAIKAN_DESAIN_TIKET_PESERTA.md`, `LAPORAN_PERBAIKAN_DIAGNOSTIC_VSCODE.md`,
`LAPORAN_PERBAIKAN_EMAIL_TIKET.md`, `LAPORAN_PERBAIKAN_ETIKET_PDF.md`,
`LAPORAN_PERBAIKAN_PENGIRIMAN_EMAIL_TIKET_FINAL.md`,
`LAPORAN_PERBAIKAN_PENGIRIMAN_TIKET_EMAIL.md`,
`LAPORAN_PROPORSI_TIKET_DAN_PERBAIKAN_ERROR.md`, `AUDIT_REPORT.md`,
`AUDIT_PEMBERSIHAN_REPOSITORY.md`.

Alasan pemindahan, bukan penghapusan: `AGENTS.md` mewajibkan laporan pekerjaan developer
dipertahankan, dan `task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md:166` sendiri menyatakan
dokumen audit tersebut berstatus *"ARCHIVE or KEEP as audit context"*. Pemilik proyek dapat
menghapusnya kapan pun bila memang tidak diperlukan.

Rujukan path pada `task/FASE_1C_AUTHORIZATION_REGISTER.md:156` dan
`task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md:166` diperbarui ke `task/archive/…` agar tidak
menjadi tautan putus.

---

## F. Hasil Verifikasi

| Pemeriksaan | Perintah | Hasil |
|---|---|---|
| Analisis statis Flutter | `flutter analyze --no-fatal-infos` (dari `apps/`) | **PASS** — `No issues found!` |
| Unit/widget test Flutter | `flutter test --dart-define=MOCK_MODE=true` | **PASS** — 314 test lulus, 23 skip |
| Test backend | `npm test` (dari `backend/`) | **PASS** — 303 test lulus, 0 gagal |
| Sintaks backend | `npm run check` | **PASS** — `Syntax OK: 60 JavaScript files checked.` |
| Format backend | `npm run format:check` | **PASS** |
| Validasi skills | `npm run validate:skills` | **PASS** — 7 skill |
| Integritas PRD | `git hash-object PRD.md` vs `git rev-parse HEAD:PRD.md` | **PASS** — identik `437e6d54` |
| Tautan dokumen | grep `AUDIT_REPORT`/`LAPORAN_` di README, docs, PRD, AGENTS | **PASS** — tidak ada tautan putus |
| Pemulihan environment | `flutter pub get` setelah pembersihan cache | **PASS** — `Got dependencies!` |

Catatan: `flutter test` dijalankan **setelah** `scanner_placeholder.dart` dihapus, sehingga
hasil PASS tersebut sekaligus membuktikan tidak ada regresi akibat penghapusan.

---

## G. Yang Tidak Diverifikasi / Perlu Keputusan Pemilik

1. `backend/.venv/` (386 MB) dan `backend/node_modules/` (344 MB) dibiarkan: keduanya
   dependency lokal, bukan file proyek, dan dibutuhkan untuk menjalankan backend/alat Python.
2. `backend/src/models/*.js` + `backend/src/config/supabase.js` menunggu keputusan FINISHING
   sebelum boleh dihapus (lihat bagian C).
3. Integrasi Supabase/API nyata dan validasi UI pada perangkat tidak dijalankan pada tugas
   ini; yang divalidasi adalah analisis statis dan test otomatis.

---

## H. Putaran Kedua — Alat QR Python → JavaScript

### H.1 `backend/tools/check_qr_scannability.py` dihapus, digantikan test JS

Alat Python itu mengukur QR dari PDF hasil render (300 DPI) dengan tiga ambang: modul
≥ 0,4 mm, quiet zone ≥ 2 modul, alas putih ≤ 6 modul. Ketiga ambang tersebut dapat
dihitung **analitis** dari geometri yang benar-benar dipakai saat PDF dibuat, sehingga
tidak perlu rasterisasi:

| Parameter | Sumber nilai |
|---|---|
| Ukuran kotak QR | `LANDSCAPE_CANVAS.qrSize` = 220 pt; `PORTRAIT_CANVAS.qrSize` = 250 pt |
| Batas bawah ukuran QR | `QR_MIN_POINTS` = 100 pt; `QR_PLACEMENT_LIMITS.size.min` = 0,15 |
| Jumlah modul QR | `QRCode.create(token, { errorCorrectionLevel: 'M' }).modules.size` → 33 modul untuk token 43 karakter |
| Quiet zone | `margin: 2` pada `QRCode.toBuffer` |
| Alas putih | `QR_BACKING_PAD` = 6 pt |

Hasil hitung (semuanya lolos ambang 0,4 mm):

| Kasus | Ukuran QR | Modul |
|---|---|---|
| Default landscape | 220 pt (77,61 mm) | **2,098 mm** |
| Default portrait | 250 pt (88,19 mm) | **2,384 mm** |
| Terkecil diizinkan (landscape) | 100 pt (35,28 mm) | **0,954 mm** |

Penggantinya: `backend/test/ticket_qr_scannability.test.js` (5 test, tanpa dependensi
baru, ikut `npm test` dan CI). Referensi di `backend/tools/requirements.txt` dan
`backend/README.md` diperbarui; `Pillow` dihapus dari requirements karena satu-satunya
pemakainya (`_verify-out/make_artwork.py`) sudah tidak ada.

**Batasan yang jujur:** pemeriksaan analitis tidak mendeteksi cacat piksel (mis. QR
tertarik tidak proporsional saat `doc.image()`). Bukti visual & decode akhir tetap
tersedia lewat dua alat Python yang dipertahankan.

### H.2 Dua alat Python yang **tidak** dapat digantikan JS tanpa dependensi baru

| Alat | Kebutuhan teknis | Alternatif JS |
|---|---|---|
| `render_ticket_pdf.py` | Rasterisasi PDF → PNG | Perlu `pdfjs-dist` + `@napi-rs/canvas` (binary native) |
| `decode_ticket_qr.py` | Rasterisasi PDF + dekode QR | Perlu tambahan `jsqr`/`@zxing` (paket `qrcode` hanya *encoder*) |

Menambah 3 dependensi hanya untuk menggantikan alat manual melanggar aturan `AGENTS.md`
("hindari dependency baru untuk fungsi yang sudah ada"), jadi keduanya dipertahankan.

### H.3 `(.venv)` di terminal dihilangkan

Penyebabnya `.vscode/settings.json`: `"python.terminal.activateEnvironment": true`.
Diubah menjadi `false`, sehingga prompt terminal tidak lagi berawalan `(.venv)`.
Virtual environment tetap berfungsi bila dipanggil eksplisit:

```powershell
.\.venv\Scripts\python.exe tools/decode_ticket_qr.py <file.pdf>
```

`backend/.venv` (386 MB) bersifat opsional dan ter-ignore Git; aman dihapus
(`Remove-Item backend\.venv -Recurse -Force`) lalu dibuat ulang dengan
`py -3.14 -m venv .venv` bila alat Python dibutuhkan lagi.

### H.4 Verifikasi putaran kedua

| Pemeriksaan | Hasil |
|---|---|
| `npm test` | **PASS** — 308 test (sebelumnya 303, +5 test QR) |
| `npm run check` | **PASS** — Syntax OK 60 file |
| `npm run format:check` | **PASS** |
| `npm run validate:skills` | **PASS** |
| Referensi `check_qr_scannability` di dokumen aktif | **0** — tidak ada tautan putus |

---

## I. Guard agar `task/` tidak dibaca AI (hemat token)

Sejak pekerjaan aplikasi tidak lagi bergantung pada `task/`, folder itu dijadikan
**arsip eksplisit** agar assistant tidak menghabiskan konteks membuka 66 file historis.

### I.1 Yang diubah

| File | Perubahan |
|---|---|
| `AGENTS.md` | Menghapus "Entry point workflow developer adalah `task/PEMBAGIAN_TUGAS_FINAL.md`" dan menggantinya dengan bagian **“Folder `task/` adalah arsip — jangan dibaca”**. Rujukan `task/FINISHING_AUTHORITY.md` diganti pernyataan bahwa aturan DB berlaku penuh tanpa membaca `task/`. Instruksi baca diubah menjadi `README.md`, `PRD.md`, `docs/`, `.agents/skills/`. |
| `SKILL.md` | Bagian "Eksekusi tugas developer" tidak lagi menautkan `task/PEMBAGIAN_TUGAS_FINAL.md`; protocol diringkas dan ditautkan ke `AGENTS.md` + catatan arsip. |
| `README.md` | Titik masuk AI diarahkan ke `AGENTS.md`; 9 tautan `task/*` pada bagian "Panduan developer dan AI" diganti ringkasan aturan + pernyataan arsip. |
| `task/README.md` | **Baru.** Papan penunjuk: menyatakan folder ini arsip, melarang AI membaca default, dan mendaftar sumber aktif. |
| `docs/DATABASE.md`, `docs/ARCHITECTURE.md`, `backend/README.md` | Pointer FINISHING diarahkan ke `AGENTS.md`; rujukan audit/proposal historis ditandai `(arsip)`. |

### I.2 Yang **tidak** diubah (agar tidak merusak)

- Isi 66 file di `task/**` — tidak satu pun dihapus atau dipindahkan.
- `.agents/skills/*/SKILL.md` — diverifikasi **nol** referensi `task/`, jadi skill tidak
  pernah menarik AI ke arsip.
- `.github/sync-config.yaml` — hanya mengatur hierarki branch, tidak mengunci isi
  `AGENTS.md`; `validate-sync-config` tidak menyentuh file dokumentasi.
- Logika bisnis, API, schema, dan test — tidak ada perubahan.

### I.3 Verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `npm run validate:skills` | **PASS** — 7 skill, link `AGENTS.md` valid |
| `npm run format:check` | **PASS** |
| `npm run check` | **PASS** — 60 file |
| `npm test` | **PASS** — 308 test |
| `flutter analyze` | **PASS** — `No issues found!` |
| Grep `task/` di `AGENTS.md`, `SKILL.md`, `README.md`, `.agents/skills/**` | Hanya kalimat **larangan/arsip**, tidak ada lagi instruksi membuka `task/` |

**Batas yang perlu diketahui:** `AGENTS.md` adalah instruksi, bukan sandbox. Assistant
yang mengabaikan instruksi tetap secara teknis dapat membuka `task/`; yang dijamin
adalah tidak ada lagi perintah, tautan, atau "entry point" yang mengarahkan ke sana.


