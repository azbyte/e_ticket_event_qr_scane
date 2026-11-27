# Laporan — Proporsi E-Tiket & Perbaikan Error VS Code

Lingkup pekerjaan ini adalah **penyelarasan proporsi tipografi vs QR Code** pada
e-tiket PDF, **penyelesaian diagnostic `paymentController.js`**, dan
**penyelesaian unresolved import Python** di `backend/tools/`.

> Laporan sebelumnya (`LAPORAN_PERBAIKAN_ETIKET_PDF.md`) mencatat komposisi
> referensi (informasi minimal kiri atas + QR di bawahnya). Angka tipografi dan
> QR pada laporan lama **digantikan** oleh laporan ini; prinsip desainnya tidak
> berubah.

## 1. Penyebab tulisan terlalu kecil dan QR terlalu besar

1. **Tipografi**: `TICKET_TYPE` di `backend/src/services/ticketDesignService.js`
   masih memakai skala 24 / 13,5 / 12 / 10,5 pt. Pada kanvas 842 × 594 pt
   (≈29,7 × 21 cm), 10,5 pt hanya ±3,7 mm sehingga instruksi nyaris tidak
   terbaca saat PDF dibuka fit-to-screen di laptop maupun ponsel.
2. **QR**: `LANDSCAPE_CANVAS.qrSize = 280` pt (47,1% tinggi kanvas) dan
   `PORTRAIT_CANVAS.qrSize = 300` pt. Perbandingan tinggi blok teks (≈107 pt)
   dengan QR (280 pt) adalah **1 : 2,6**, sehingga QR mendominasi dan teks
   terlihat kecil.
3. **Area teks ikut menahan pembesaran**: `DEFAULT_INFO_BY_ORIENTATION.height`
   hanya 0,18 (landscape) / 0,16 (portrait) = 106,9 / 112,6 pt. Nilai ini
   dipakai `drawTicketInfoLines` sebagai `maxHeight`; bila tipografi diperbesar
   tanpa menaikkan `height`, `scale` akan mengecilkan font kembali sehingga
   perubahan tidak terlihat pada PDF. Ini sebabnya pembesaran **harus**
   menyentuh `TICKET_TYPE`, `textWidth`, dan `height` sekaligus.

## 2. Ukuran font sebelum dan sesudah

| Baris | Sebelum | Sesudah | Perubahan |
|---|---|---|---|
| `E-TIKET [NAMA EVENT]` | 24 pt (auto-fit 24→16) | **31 pt** (auto-fit 31→22) | +29,2% |
| `ID TIKET: …` | 13,5 pt bold | **17,5 pt** bold | +29,6% |
| `Peserta: …` | 12 pt | **15,5 pt** | +29,2% |
| Instruksi penukaran | 10,5 pt | **13,5 pt** | +28,6% |
| Judul pada area teks sempit (<240 pt) | 19 pt | **25 pt** | +31,6% |

Tinggi blok teks alami (`INFO_BLOCK_REFERENCE_HEIGHT`) naik dari ±107 pt menjadi
**137,8 pt**; area teks default disesuaikan (`height` 0,18 → **0,232** landscape,
0,16 → **0,196** portrait; `textWidth` 356 → **392** pt, 330 → **344** pt) agar
skala tipografi tetap 1 (tidak dikecilkan otomatis).

## 3. Ukuran QR Code sebelum dan sesudah

| Item | Sebelum | Sesudah |
|---|---|---|
| QR landscape | 280 pt (47,1% tinggi kanvas) | **240 pt** (40,4%) |
| QR portrait | 300 pt (42,6%) | **260 pt** (36,9%) |
| Posisi Y QR landscape | 176 pt | **200 pt** (di bawah blok teks yang lebih tinggi) |
| Rasio tinggi teks : sisi QR | 107 : 280 = **1 : 2,6** | 138 : 240 = **1 : 1,7** |
| `QR_MIN_POINTS` (batas bawah desain kustom) | 200 pt | tetap 200 pt |
| Alas putih | QR + 6 pt (`QR_BACKING_PAD`) | tetap QR + 6 pt |

240 pt = 8,5 cm sisi QR — masih di atas ambang pemindaian kamera ponsel
(modul 2,20 mm, quiet zone 5,35 modul) dan berada dalam rentang target
220–260 pt.


## 4. File yang berubah

| File | Perubahan |
|---|---|
| `backend/src/services/ticketDesignService.js` | `TICKET_TYPE` (31/17,5/15,5/13,5), `titleSizes` area sempit, `textWidth`/`qrY`/`qrSize` landscape, `textWidth`/`qrSize` portrait, `DEFAULT_INFO_BY_ORIENTATION.height`, komentar |
| `backend/src/controllers/paymentController.js` | Helper `runBestEffort`; tiga blok `try/catch` berulang diganti pemanggilan helper (logika & urutan sama) |
| `backend/test/ticket_design.test.js` | Ambang QR medium & tipografi baru + cek jarak teks↔QR |
| `backend/test/ticket_email_delivery.test.js` | Isolasi `EMAIL_PROVIDER` agar uji transport tidak dikunci `.env` |
| `backend/test/email_ticket_delivery_rules.test.js` | `withEnv` melepas `EMAIL_PROVIDER` bila kasus uji tidak menyetelnya |
| `backend/test/ticket_identity.test.js` | Uji keunikan ID publik tidak lagi flaky (batas duplikat acak ≤ 2) |
| `backend/scripts/verify-ticket-pdf.js` | Verifikasi tipografi (4 baris + hierarki) dan QR medium |
| `backend/scripts/generate-ticket-template.ps1` | Penanda QR template mengikuti 240/260 pt |
| `backend/tools/check_qr_scannability.py` | `QR_BOX` mengikuti tata letak baru |
| `backend/tools/decode_ticket_qr.py` | Opsi `--expect=<token>` untuk membuktikan isi QR = token tiket |
| `backend/tools/requirements.txt` (**baru**) | `PyMuPDF`, `opencv-python-headless`, `numpy` |
| `pyrightconfig.json` (**baru**) | `venvPath`/`venv` → `backend/.venv`, `include` `backend/tools` |
| `.vscode/settings.json` (**baru**, lokal/ignored) | `python.defaultInterpreterPath` → `backend/.venv` |
| `apps/lib/models/event/ticket_design_model.dart` | Default QR/info disamakan dengan backend |
| `apps/test/ticket_design_layout_test.dart` | Ambang QR medium + lebar/tinggi area teks baru |
| `backend/README.md`, `docs/ARCHITECTURE.md`, `.gitignore` | Ukuran baru, cara pasang venv, `.venv/` diabaikan |

## 5. Penyebab lima error pada `paymentController.js`

Diagnostic yang dilaporkan:

| Baris | Pesan |
|---|---|
| 92 | `'try' expected` |
| 107 | `';' expected`, `Argument expression expected` |
| 129 | `Declaration or statement expected` (2×) |

Pola pesan ini (bukan "unexpected token" pada satu titik, melainkan
`'try' expected` lalu `argument expression` pada template literal lalu
`declaration or statement expected` di akhir fungsi) adalah tanda parser
kehilangan sinkronisasi **lebih awal** dari baris yang dilaporkan — bukan lima
kesalahan terpisah.

Hasil audit berkas:

- `node --check` dan parse V8 (`vm.Script`): **OK**, baik untuk versi `HEAD`
  maupun working tree → tidak ada kurung/try yang benar-benar hilang di berkas
  yang tersimpan.
- Pemeriksaan byte (`backend/_verify-out/diag-payment.js`): tanpa BOM, tanpa CR
  tunggal, tanpa karakter tak terlihat (NBSP/zero-width), kurung kurawal
  seimbang.

Kesimpulan: diagnostic berasal dari **buffer VS Code yang tidak konsisten saat
blok `try { await ensureOrderPublicTicketCodes(orderId) } catch { … }`
(7 baris, satu-satunya blok `try` baru di sekitar baris 85–93) sedang ditulis**.
Selama blok itu belum lengkap (mis. `try {` sudah ada tetapi `} catch (error) {`
belum), `try` berikutnya menjadi ilegal → `'try' expected` di baris 92; template
literal `body:` pada baris 107 lalu dibaca sebagai lanjutan ekspresi →
`';' expected` + `Argument expression expected`; dan kurung penutup fungsi
terhitung berlebih → `Declaration or statement expected` di baris 129.
Setelah berkas tersimpan utuh, rantai itu hilang.

## 6. Perbaikan yang dilakukan

1. **Struktur dibuat tidak mungkin mengulang pola tersebut**: tiga blok
   `try/catch` identik (token hash, ID publik, antrean email) diganti satu
   helper `runBestEffort(label, task, context)` yang mencatat
   `logger.error(label, { ...context, error })` dan mengembalikan `null` bila
   gagal. Label log (`ticket_token_backfill_failed`,
   `ticket_public_code_backfill_failed`, `ticket_email_dispatch_failed`) dan
   urutan eksekusi **tidak berubah**; `emailResults` tetap array (`?? []`).
2. Tidak ada fungsi/logika yang dihapus: `getPayment` dan `simulatePayment`
   utuh, termasuk validasi status (`PAID`/`CANCELLED`/expired), RPC
   `simulate_event_payment`, notifikasi `PAYMENT_PAID`/`PAYMENT_FAILED`, dan
   `serializePayment`/`emailQueue.summarize` pada respons.
3. Route tetap memakai controller yang sama:
   `backend/src/routes/orders.js` → `GET /:orderId` (`getPayment`),
   `POST /simulate` (`simulatePayment`); modul route berhasil di-`require`.


## 7. Penyebab import Python tidak terdeteksi

1. `backend/tools/*.py` memakai `pymupdf` (paket **PyMuPDF**) dan `cv2` (paket
   **opencv-python**), yang **bukan** dependensi runtime backend (`package.json`
   hanya Node). Tidak ada `requirements.txt` dan tidak ada virtual environment
   proyek, sehingga tidak ada tempat dependency ini "seharusnya" berada.
2. Library memang **sudah terpasang**, tetapi pada interpreter **global**
   Python 3.14 (`C:\Users\…\pythoncore-3.14-64`), sedangkan Pylance memakai
   `python` dari PATH = **Python 3.11.6**
   (`C:\Users\…\Programs\Python\Python311\python.exe`) yang tidak memiliki
   `pymupdf`. Itulah sebabnya import dianggap unresolved walau script dapat
   dijalankan dengan `py`.
3. Karena tidak ada `pyrightconfig.json`/`python.defaultInterpreterPath`,
   Pylance menebak interpreter per-workspace, bukan environment proyek.

## 8. Dependency dan konfigurasi yang diperbaiki

- `backend/tools/requirements.txt` (baru): `PyMuPDF>=1.24,<3`,
  `opencv-python-headless>=4.10,<6`, `numpy>=1.26` — beserta catatan bahwa nama
  paket ≠ nama modul (`PyMuPDF`→`pymupdf`, `opencv-python-headless`→`cv2`).
  Nama import **tidak** diubah karena API yang dipakai (`pymupdf.Matrix`,
  `pymupdf.Pixmap`, `cv2.QRCodeDetector`) memang milik PyMuPDF 1.24+/OpenCV 4+.
- Virtual environment proyek: `backend/.venv` (Python 3.14.5) +
  `pip install -r tools/requirements.txt` → `pymupdf 2.2` (modul 1.28.6),
  `opencv-python-headless 5.1.0.95`, `numpy 2.5.5`.
- `pyrightconfig.json` (root): `venvPath: "backend"`, `venv: ".venv"`,
  `include: ["backend/tools"]`, `pythonVersion: "3.14"` — Pylance memakai
  environment yang sama dengan tempat dependency dipasang. Diagnostic
  **tidak** dimatikan (`reportMissingImports: "error"` tetap aktif).
- `.vscode/settings.json` (lokal, diabaikan Git): `python.defaultInterpreterPath`
  → `${workspaceFolder}/backend/.venv/Scripts/python.exe`.
- `.gitignore`: `.venv/`, `venv/` agar environment lokal tidak masuk repo.

## 9. Hasil pengujian

| Pengujian | Perintah | Hasil |
|---|---|---|
| Sintaks `paymentController.js` | `node --check src/controllers/paymentController.js` | **PASS** (exit 0) |
| Sintaks seluruh backend | `npm run check` | **PASS** — 60 berkas JS |
| Format | `npm run format:check` | **PASS** |
| Unit/integration backend | `npm test` | **PASS** — 284/284 |
| Pembayaran (unit + Tahap 1) | `node --test test/payment_simulation.test.js test/stage1_integration.test.js` | **PASS** — 22/22 (simulasi sukses, sudah dibayar, kedaluwarsa, gagal) |
| Verifikasi PDF | `npm run verify:ticket-pdf` | **PASS** — 55 pemeriksaan OK, 0 GAGAL |
| Sinkronisasi konfigurasi | `npm run test:sync-config` | **PASS** — 14/14 |
| Skills | `npm run validate:skills` | **PASS** — 7 skill |
| Flutter analyze | `flutter analyze` | **PASS** — no issues |
| Flutter test | `flutter test` | **PASS** — 331/331 |
| Import Python (setara Pylance) | `python -m pyright` (Pyright 1.1.414) | **PASS** — 0 error, 0 warning |
| QR: modul & quiet zone | `tools/check_qr_scannability.py` (4 PDF) | **PASS** — modul 2,20–2,46 mm, quiet zone 5,17–5,35 modul, alas putih ≤1,4 modul |
| QR: dapat dipindai | `tools/decode_ticket_qr.py --expect=<token>` (6 PDF) | **PASS** — semua terdekode & isinya sama dengan token tiket |
| Render PDF → PNG | `tools/render_ticket_pdf.py` (9 PDF) | **PASS** — semua 842×594 / 440×704 pt |
| Endpoint pembayaran nyata | `npm run verify:ticket-email-e2e` | **BLOCKED** — memerlukan database + SMTP aktif (tidak dijalankan di sesi ini) |
| Uji perangkat/kamera fisik | — | **BLOCKED** — tidak ada perangkat pada sesi ini |

Dua pengujian berstatus BLOCKED **tidak** menjadi penghalang: jalur pembayaran
tetap tercakup unit + integration test tanpa database, dan keterbacaan QR
dibuktikan lewat dekode OpenCV atas hasil render PDF asli.

## 10. Lokasi PDF hasil pengujian dan hasil render

Folder: `backend/_verify-out/` (diabaikan Git).

| PDF | Render PNG |
|---|---|
| `ticket-landscape-default.pdf` | `render/ticket-landscape-default.png` |
| `ticket-portrait-default.pdf` | `render/ticket-portrait-default.png` |
| `ticket-landscape-custom.pdf` | `render/ticket-landscape-custom.png` |
| `ticket-portrait-custom.pdf` | `render/ticket-portrait-custom.png` |
| `ticket-landscape-legacy-ratio.pdf` | `render/ticket-landscape-legacy-ratio.png` |
| `ticket-long-title.pdf` | `render/ticket-long-title.png` |
| `ticket-email-attachment.pdf` | `render/ticket-email-attachment.png` |
| `template-landscape.pdf` / `template-portrait.pdf` | `render/template-*.png` |

Log: `verify.log`/`final-verify.log` (verifikasi PDF), `final-scan.log` (QR),
`final-decode.log` (dekode QR), `final-tests.log` (unit test), `pyright.log`.

Cara mengulang:

```powershell
cd backend
npm run verify:ticket-pdf
.\.venv\Scripts\python.exe tools/render_ticket_pdf.py _verify-out
.\.venv\Scripts\python.exe tools/check_qr_scannability.py _verify-out/ticket-landscape-default.pdf _verify-out/ticket-portrait-default.pdf
.\.venv\Scripts\python.exe tools/decode_ticket_qr.py --expect=<token> _verify-out/ticket-landscape-default.pdf
```

## 11. Catatan hasil pemeriksaan visual

- Dimensi tetap **842 × 594 pt** (landscape) dan **440 × 704 pt** (portrait).
- Blok teks berakhir 166,2 pt (landscape) / 151,5 pt (portrait); QR mulai
  200 pt / 236 pt → tidak ada tulisan bertumpuk, jarak teks↔QR 34 pt.
- Kotak putih hanya selebar QR + 6 pt; artwork, ornamen, dan ilustrasi tetap
  terlihat (tidak tertutup).
- **Satu ornamen dipindahkan**: grid titik dekoratif panel kiri sebelumnya
  berada di kanan atas (y 36–75 pt) dan kini tertutup judul yang lebih besar,
  sehingga dipindah ke bawah area QR (y 498–537 pt, ruang kosong di panel pink).
  Bentuk, warna, dan jumlah titik tidak berubah; garis perforasi, lingkaran
  dekoratif, dan ornamen panel kanan tetap pada posisi semula.
- Judul panjang (`Seminar Nasional Transformasi Digital Indonesia 2026`)
  terpotong elipsis setelah auto-fit 31→22 pt — perilaku lama dipertahankan
  agar tinggi blok teks tidak melewati area QR.
- Nama file lampiran tetap `E-TIKET Nama Peserta.pdf`.
