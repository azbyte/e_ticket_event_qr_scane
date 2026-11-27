# Laporan Perbaikan E-Tiket PDF — Dimensi, QR, ID Tiket, Tata Letak, dan Nama File

Lingkup: pembuatan & pengiriman e-tiket PDF (unduhan manual dan lampiran email)
untuk event gratis maupun berbayar, orientasi landscape dan portrait.

> **Diperbarui:** ukuran tipografi dan QR pada laporan ini sudah digantikan oleh
> [`LAPORAN_PROPORSI_TIKET_DAN_PERBAIKAN_ERROR.md`](LAPORAN_PROPORSI_TIKET_DAN_PERBAIKAN_ERROR.md)
> (tipografi 31/17,5/15,5/13,5 pt dan QR medium 240/260 pt). Prinsip desain,
> dimensi kanvas, dan mekanisme QR tetap seperti dijelaskan di bawah.


> **Revisi terakhir (desain final mengikuti referensi U-NITY)**: tata letak
> diubah menjadi informasi tambahan minimal di kiri atas + QR besar tepat di
> bawahnya, tanpa panel/kartu di atas artwork. Lihat §8.

## 1. Hasil Audit

Satu-satunya jalur rendering adalah
`backend/src/services/ticketDesignService.js` (`buildTicketPdf`) dengan
`pdfkit@0.21.0` + `qrcode@1.5.3`. Jalur unduhan (`GET /api/tickets/:id/pdf` →
`ticketController.getTicketPdf`) dan lampiran email
(`emailService.buildPdfAttachment` → `buildMessage` → `deliver`) memakai fungsi
yang sama, dan event gratis/berbayar sama-sama lewat
`ensureOrderTokenHashes` → `emailQueue.enqueueOrder` → `sendTicketEmail`.
**Tidak ada implementasi ganda** yang perlu dikonsolidasikan.

Akar masalah yang ditemukan:

| # | Masalah | Penyebab |
|---|---|---|
| 1 | Tiket landscape terlihat sangat panjang/pipih | `ORIENTATION_SPEC.landscape = 720 × 288 pt` (rasio 2.5:1) **dan** `pageSizeFor()` menurunkan tinggi halaman dari rasio file desain (`height = width × imageRatio`), sehingga ukuran halaman tidak pernah tetap |
| 2 | QR kecil & relatif tidak menonjol | QR = 50% tinggi kanvas 288 pt = **144 pt**, `margin: 1`, dan tanpa latar putih pada desain kustom (hanya pada layout default) |
| 3 | Desain kustom berisiko menutupi QR / kontras rendah | QR PNG dari `qrcode` transparan; modul "terang" tembus background berwarna |
| 4 | ID tiket 36 karakter | `ticket_code` dibuat RPC database: `'TKT-' || replace(gen_random_uuid(),'-','')` |
| 5 | Nama file tidak sesuai format | `tiket-${ticket_code}.pdf` pada lampiran email **dan** unduhan manual |
| 6 | Tata letak bergaya dokumen administrasi | `drawDefaultLayout` = blok biru + 5 baris teks datar tanpa hierarki visual |
| 7 | Template desain memuat teks contoh | `generate-ticket-template.ps1` mencetak "Nama Event/Nama Peserta/..." sehingga desain yang diunggah menghasilkan teks ganda |

Dampak tambahan yang ditemukan saat implementasi: `fill(color, opacity)` PDFKit
mengubah `fillOpacity` secara **persisten**, sehingga satu ornamen transparan
membuat seluruh teks setelahnya ikut pudar. Ini diperbaiki dan diberi komentar.

## 2. File yang Diubah

| File | Alasan |
|---|---|
| `backend/src/services/ticketDesignService.js` | Kanvas tetap 842×594/440×704 pt, renderer layout baru (landscape + portrait), QR besar + kartu putih + quiet zone, `contain`-fit desain kustom, metadata PDF |
| `backend/src/services/ticketCodeService.js` (**baru**) | ID publik `ETK-XXXXXX` (Crockford Base32), idempotent, guard anti-timpa, backfill |
| `backend/src/utils/ticketFilename.js` (**baru**) | `E-TIKET Nama Peserta.pdf` + `Content-Disposition` (ASCII + UTF-8) |
| `backend/src/services/emailService.js` | Nama lampiran format wajib; ID publik dipastikan sebelum konteks dimuat |
| `backend/src/controllers/ticketController.js` | Header unduhan memakai format nama yang sama; ID publik dirapikan sebelum render |
| `backend/src/controllers/orderController.js` | ID publik ditetapkan sebelum email/PDF (order gratis PAID) |
| `backend/src/controllers/paymentController.js` | ID publik ditetapkan setelah pembayaran PAID |
| `backend/src/controllers/checkInController.js` | Lookup kode manual: `ticket_code` → fallback `qr_code_data` untuk tiket lama |
| `backend/src/utils/validators.js` | `validateTicketCode` menerima `ETK-XXXXXX` dan kode lama |
| `backend/scripts/backfill-ticket-codes.js` (**baru**) + `package.json` | `npm run tickets:backfill-codes` (idempotent, tanpa hapus data) |
| `backend/scripts/verify-ticket-pdf.js` | Verifikasi dimensi/QR/nama file/kompatibilitas |
| `backend/scripts/verify-ticket-email-e2e.js` | Verifikasi nama lampiran + ukuran halaman pada email nyata |
| `backend/scripts/generate-ticket-template.ps1` | Template = latar/ornamen + penanda QR (tanpa teks contoh), 1684×1188 & 880×1408 px |
| `backend/assets/ticket-templates/*.png` | Regenerasi template sesuai kanvas baru |
| `backend/test/ticket_identity.test.js` (**baru**) | Regresi ID publik & nama file |
| `backend/test/{ticket_design,checkin_rules,ticket_email_delivery,security_and_services}.test.js` | Menyesuaikan ekspektasi kanvas/ID/nama file + fallback tiket lama |
| `backend/tools/*.py` (**baru**, alat validasi) | Render PDF→PNG, ukur QR, dan dekode QR (OpenCV) |
| `apps/lib/models/event/ticket_design_model.dart` | Rasio & default QR/info disamakan dengan backend |
| `apps/lib/features/organizer/events/widgets/ticket_design_panel.dart` | Teks panduan rasio 1.42:1 (842×594 pt) |
| `apps/lib/models/ticket/ticket_model.dart` | Dokumentasi `ETK-XXXXXX` |
| `backend/README.md`, `docs/ARCHITECTURE.md` | Dokumentasi kanvas, QR, ID publik, nama file, skrip backfill |

## 3. Hasil Implementasi

- **Dimensi**: `landscape` = **842 × 594 pt** (A4 landscape), `portrait` =
  **440 × 704 pt**. Ukuran halaman kini **tidak bergantung** pada file desain;
  `pageSizeFor()` mengembalikan kanvas tetap.
- **Layout landscape**: background dusty pink/krem dengan ornamen; informasi
  tambahan minimal di kiri atas (`E-TIKET [NAMA EVENT]`, `ID TIKET: …`,
  `Peserta: …`, instruksi penukaran) dan **QR 280 pt** tepat di bawahnya dengan
  alas putih tipis. Rincian lengkap ada di §8.
- **Layout portrait**: header pink 216 pt berisi informasi minimal di kiri atas,
  lalu QR 300 pt di bawahnya (kanvas 440 × 704 pt).
- **QR**: 280 pt (landscape) / 300 pt (portrait), `margin: 2`, modul putih
  **opaque** (`color: {dark:'#000000', light:'#FFFFFF'}`), minimum 200 pt untuk
  desain kustom yang menyimpan ukuran kecil, alas putih hanya +6 pt.
- **ID tiket**: `ETK-` + 6 karakter Crockford Base32 (`0-9A-Z` tanpa I/L/O/U),
  disimpan di `tickets.ticket_code` (kolom unik yang sudah ada). `tickets.id`
  (UUID) tetap primary key/relasi → **tidak ada perubahan schema**. Kandidat
  bentrok diulang (unique index), dan bila gagal total kode lama dipertahankan
  sehingga tiket tidak pernah menjadi tidak valid.
- **Nama file**: `E-TIKET Nama Peserta.pdf` dari `attendees.name`, spasi biasa,
  karakter terlarang (`\ / : * ? " < > |`, kontrol) → spasi, `filename*`
  UTF-8 untuk nama non-Latin. Dipakai pada lampiran email **dan** unduhan manual.
- **Desain custom**: tetap didukung penuh (event & per kategori). Gambar
  digambar `contain` di kanvas (rasio asli utuh); desain lama 2.5:1 tetap
  tercetak utuh dengan mat ivory. Posisi QR/teks tetap dari `design.qr` /
  `design.info` (relatif persegi gambar).
- **Portrait**: tetap berjalan (440×704 pt, QR 300 pt) dan diuji.

## 4. Hasil Pengujian

| Pengujian | Hasil | Status |
|---|---|---|
| Dimensi landscape | `MediaBox 0 0 842 594` pada tiket default, desain kustom, dan desain lama 2.5:1 | PASS |
| QR Code | 280 pt / 300 pt, modul 2,62–2,79 mm, quiet zone 4,55–7,10 modul; **QR terdekode OpenCV** pada semua PDF uji (§8.5) | PASS |
| ID tiket | `ETK-XXXXXX`; 5000 sampel unik; tiket lama `TKT-<uuid>` tetap ditemukan | PASS |
| Nama file PDF | `E-TIKET Aziz.pdf`, `E-TIKET Budi Santoso.pdf`, 4 kata, spasi berlebih, karakter khusus, nama kosong | PASS |
| Email attachment | E2E: `E-TIKET Peserta Gratis E2E.pdf` & `E-TIKET Peserta Bayar E2E.pdf`, PDF 842×594 pt | PASS |
| Event gratis | E2E: tiket terbit PAID → email `SENT` → PDF+QR → verify 200 | PASS |
| Event berbayar | E2E: `pending_payment` → tiket belum terbit → simulasi bayar → tiket+email `SENT` | PASS |
| Desain custom | Kanvas 842×594/440×704 pt, rasio gambar = rasio kanvas, QR 280/300 pt | PASS |
| Tiket portrait | 440×704 pt, QR 300 pt, QR di bawah blok teks | PASS |
| Check-in | `POST /api/tickets/verify` → 200 (E2E), `verify:ticket-flow` PASS | PASS |
| Backfill ID tiket lama (DB nyata) | **BLOCKED** — tidak dijalankan pada database bersama; skrip + unit test tersedia, lookup kode lama diverifikasi read-only | BLOCKED |

Pemeriksaan statis/unit: `npm run check` PASS (60 file), `npm run format:check`
PASS, `npm run validate:skills` PASS, `flutter analyze` PASS, `flutter test`
**326 PASS**. `npm test` backend: **275 pass / 5 fail** — 5 kegagalan tersebut
**sudah ada sebelum pekerjaan ini** (kebocoran `EMAIL_PROVIDER=brevo` dari
`backend/.env` ke `test/email_ticket_delivery_rules.test.js`), dibuktikan dengan
`git stash` + `npm test` pada kode asli (259 pass / 5 fail, kegagalan identik).

## 5. Bukti Hasil

- PDF uji: `backend/_verify-out/ticket-landscape-default.pdf`,
  `ticket-portrait-default.pdf`, `ticket-landscape-custom.pdf`,
  `ticket-portrait-custom.pdf`, `ticket-landscape-legacy-ratio.pdf`,
  `template-landscape.pdf`, `template-portrait.pdf`.
- Render PNG 150 DPI: `backend/_verify-out/render/*.png`
  (`py tools/render_ticket_pdf.py backend/_verify-out`).
- Ukuran halaman: `MediaBox` dibaca langsung dari byte PDF + PyMuPDF
  (`842.00 x 594.00 pt`, `440.00 x 704.00 pt`).
- QR: `py tools/check_qr_scannability.py …` (modul & quiet zone) dan
  `py tools/decode_ticket_qr.py …` → QR terdekode sama dengan token QR tiket
  (`18ex5oOpWc_Cw0FYNMtfCjKQ7hzGRNIf5djhsN8GMFI`, 43 karakter).
- E2E email: `npm run verify:ticket-email-e2e` → semua PASS (stub penyedia email).

## 6. Permasalahan Tersisa

1. **Backfill ID tiket lama di database bersama belum dijalankan** (kebijakan:
   tidak ada mutasi data nyata tanpa persetujuan). Jalankan
   `npm run tickets:backfill-codes` dari `backend/` saat disetujui; idempotent
   dan tidak menghapus data. Selama belum dijalankan, tiket lama tetap valid
   (kode `TKT-<uuid>` dapat divalidasi lewat `qr_code_data`).
2. **5 unit test email gagal karena `.env` lokal** (`EMAIL_PROVIDER=brevo`),
   bukan karena perubahan ini. Saran: set `EMAIL_PROVIDER=''` pada lingkungan test.
3. **Email masuk inbox asli** belum diverifikasi (butuh kredensial & akses
   mailbox); bukti yang ada adalah penerimaan oleh penyedia (stub/SMTP lokal).
4. `backend/tools/*.py` memerlukan `pymupdf`/`opencv-python` **hanya untuk
   validasi manual**; keduanya bukan dependensi aplikasi.

## 7. Kesimpulan

Seluruh target teknis tercapai: PDF landscape **842 × 594 pt**, QR besar dan
terbukti dapat dipindai, tata letak baru mengikuti komposisi referensi
(informasi minimal di kiri atas + QR di bawahnya, artwork tetap dominan), ID
tiket ringkas `ETK-XXXXXX` yang unik dan tetap kompatibel dengan tiket lama,
serta nama lampiran `E-TIKET Nama Peserta.pdf` pada email dan unduhan. Desain
custom dan tiket portrait tetap berfungsi, dan alur validasi/check-in tidak
berubah. Satu item berstatus BLOCKED (backfill data tiket lama di database
bersama) karena membutuhkan persetujuan pemilik data, bukan karena kendala
teknis.

## 8. Revisi desain final (referensi U-NITY)

### 8.1 Prinsip yang diterapkan

Gambar yang diunggah penyelenggara adalah **desain utama**; sistem hanya
menambahkan informasi dinamis di atasnya. Tidak ada panel, kartu, kotak
informasi, atau latar baru. Kotak putih **hanya** dipakai sebagai alas QR Code.

### 8.2 Perubahan tata letak

| Aspek | Sebelum | Sesudah (referensi U-NITY) |
|---|---|---|
| Informasi di tiket | 8+ baris: judul, kartu ID, nama, kategori • jadwal, lokasi, nomor registrasi, "Berlaku untuk 1 orang", tanggal terbit | 4 baris: `E-TIKET [NAMA EVENT]`, `ID TIKET: …`, `Peserta: …`, instruksi penukaran |
| Posisi teks | Panel kiri + kartu ID + kartu penutup | Kiri atas, tanpa panel/latar, teks hitam `#1A1A1A` |
| QR Code | 190 pt (landscape) / 200 pt (portrait) | **280 pt** (landscape) / **300 pt** (portrait) |
| Alas putih QR | Kartu putih `QR + 24 pt` (padding 8% + radius 16) | Hanya `QR + 6 pt` (`QR_BACKING_PAD`), radius 4 |
| Label "Pindai QR"/"AREA QR" di tiket final | Ada | Dihapus dari tiket final (hanya di template PDF/PNG) |
| Tanggal / lokasi / kategori / nomor registrasi / tanggal terbit | Dicetak | Tidak dicetak |
| Badge monogram + nama penyelenggara | Ada | Dihapus (artwork penyelenggara sudah memuat identitas) |

Tata letak konkret (pt, kanvas landscape 842 × 594):

- teks mulai di `x=56, y=52`, lebar 330 pt;
- QR di `x=56, y=176`, sisi **280 pt** → berakhir di 456 pt, masih di dalam
  halaman (594 pt) dengan margin 138 pt.

Portrait (440 × 704): teks `x=36, y=40`, QR `x=36, y=236`, sisi **300 pt**.

### 8.3 Perilaku desain kustom

- Artwork digambar `contain` (rasio asli utuh, tanpa potong/regang) sebagai
  background utama.
- Teks memakai `design.info`; QR memakai `design.qr`. Keduanya tetap relatif
  terhadap persegi gambar agar desain lama konsisten.
- `avoidInfoOverlap` menggeser QR ke bawah teks hanya bila akan bertabrakan, dan
  memperkecil QR hanya bila hasil geser keluar halaman — QR tidak pernah
  tertimpa teks atau terpotong.
- Teks digambar **sebelum** QR sehingga QR selalu berada di lapisan atas dan
  tetap dapat dipindai.

### 8.4 Perubahan file pada revisi ini

| File | Perubahan |
|---|---|
| `backend/src/services/ticketDesignService.js` | Konstanta kanvas/QR baru, `drawTicketInfoLines`, `drawQrBacking` (alas QR tipis), `avoidInfoOverlap`, layout landscape & portrait minimal, `ticketDisplayData` hanya field yang dicetak, `drawCustomDesignInfo` memakai 4 baris |
| `backend/scripts/generate-ticket-template.ps1` | Penanda QR = garis putus-putus tipis tanpa alas putih & tanpa teks "AREA QR"; koordinat mengikuti layout baru |
| `backend/assets/ticket-templates/*.png` | Regenerasi (1684×1188 & 880×1408 px) |
| `backend/tools/check_qr_scannability.py` | Kotak QR baru + pengukuran ketebalan alas putih (menolak alas > 6 modul) |
| `backend/scripts/verify-ticket-pdf.js` | Verifikasi tata letak referensi: teks hanya di kiri atas, QR besar di bawah teks, tanpa informasi administratif |
| `backend/test/ticket_design.test.js` | Ekspektasi QR/teks baru + regresi "tidak ada informasi administratif" & "teks di kiri atas" |
| `apps/lib/models/event/ticket_design_model.dart` | Default QR/info disamakan dengan backend (280/300 pt, teks hitam) |
| `apps/test/ticket_design_layout_test.dart` (**baru**) | Mengunci default QR/info Flutter agar tidak menyimpang dari backend |
| `backend/README.md`, `docs/ARCHITECTURE.md` | Dokumentasi prinsip desain & isi tiket |

### 8.5 Hasil pengujian revisi

| Pengujian | Hasil | Status |
|---|---|---|
| Dimensi PDF | `842 × 594 pt` (landscape) & `440 × 704 pt` (portrait) pada tiket default, desain kustom, dan desain lama 2.5:1 | PASS |
| Informasi tambahan tidak berlebihan | Hanya 4 baris; `No. registrasi`, `Diterbitkan`, `Berlaku untuk`, `Kategori tiket` tidak ditemukan di teks PDF | PASS |
| Tulisan di kiri atas | Semua matriks teks `Tm` berada di `x ≤ 56 pt` dan `y ≥ 469 pt` (dari bawah) pada 842×594 | PASS |
| QR lebih besar | 280 pt (landscape) / 300 pt (portrait) — sebelumnya 190/200 pt | PASS |
| Kotak putih hanya mengelilingi QR | Alas putih **+6 pt** tiap sisi (0,73–0,81 modul); pemeriksa menolak alas > 6 modul | PASS |
| Background asli dominan | Artwork uji (`_verify-out/artwork-landscape.png`) tetap utuh: logo, ilustrasi, ornamen bawah, dan nama event pada desain tidak tertutup | PASS |
| QR dapat dipindai | OpenCV mendekode QR dari PDF default, portrait, kustom, artwork, dan desain lama; isi QR identik dengan token tiket (43 karakter) dan `sha256(QR) == token_hash` | PASS |
| QR tetap kontras | Modul 2,62–2,79 mm, quiet zone 4,55–7,10 modul, modul terang opaque | PASS |
| Desain kustom tidak distorsi | Rasio gambar = rasio kanvas, `contain`-fit | PASS |
| Lampiran email | Jalur `emailService.buildPdfAttachment` memakai `buildTicketPdf` yang sama; PDF lampiran diuji ulang (`_verify-out/ticket-email-attachment.pdf`) | PASS (stub penyedia) |
| Validasi tiket / check-in | Token QR pada PDF terverifikasi terhadap `token_hash` (alur `findTicketByRawToken`); tidak ada perubahan pada controller/route validasi | PASS (offline chain) |
| Statis & unit backend | `npm run check` PASS (60 file), `npm run format:check` PASS, `test/ticket_design.test.js` 29/29 PASS | PASS |
| Flutter | `flutter analyze` PASS, `flutter test` **330 PASS** (+4 test baru tata letak tiket) | PASS |
| `npm test` backend | 283 test, 278 pass / 5 fail — 5 kegagalan email sudah ada sebelumnya (kebocoran `EMAIL_PROVIDER=brevo` dari `backend/.env`) | FAIL (pre-existing) |
| E2E email nyata (`npm run verify:ticket-email-e2e`) | **NOT RUN** pada revisi ini: skrip menulis data uji ke database bersama (Supabase) dan kebijakan proyek melarang mutasi data nyata tanpa persetujuan. Jalur rendering yang dipakai sudah diverifikasi offline dengan fungsi yang sama | NOT RUN |
| Email masuk inbox asli | Butuh kredensial & akses mailbox | NOT RUN |

### 8.6 Bukti visual

- `backend/_verify-out/render/ticket-landscape-default.png` — teks kiri atas,
  QR besar, tanpa panel informasi.
- `backend/_verify-out/render/ticket-portrait-default.png` — varian portrait.
- `backend/_verify-out/render/ticket-artwork.png` — desain penyelenggara
  (logo "U-NITY", ilustrasi, ornamen) tetap dominan; teks hitam di kiri atas dan
  kotak putih hanya di sekitar QR.
- `backend/_verify-out/render/ticket-landscape-legacy-ratio.png` — kompatibilitas
  desain lama 2.5:1.
- `backend/_verify-out/render/template-landscape.png` — template tanpa teks
  contoh dan tanpa alas putih.

### 8.7 Asumsi yang perlu konfirmasi

1. Nama peserta tetap dicetak (`Peserta: …`) sebagai identifikasi pemilik tiket,
   sesuai instruksi, dengan satu baris sederhana tanpa blok baru.
2. Warna teks tetap `#1A1A1A` (hitam) untuk semua desain; `design.info.color`
   dari Organizer masih dihormati bila diisi. Kontras di atas artwork gelap
   sepenuhnya bergantung pada desain penyelenggara — belum ada auto-kontras.
3. Bila Organizer mengunggah desain yang area kirinya berisi ilustrasi padat,
   teks tetap dicetak di posisi default; belum ada editor posisi teks di UI
   (hanya posisi QR yang dapat diatur).

## 9. Revisi tipografi (keterbacaan tulisan di atas QR)

### 9.1 Perubahan

Hanya ukuran & jarak tipografi blok informasi yang berubah. Background,
ilustrasi, posisi QR (56/176 pt), ukuran QR (280 pt), alas putih QR, dimensi
842 × 594 pt, dan komposisi keseluruhan **tidak diubah**.

| Baris | Sebelum | Sesudah | Kenaikan |
|---|---|---|---|
| `E-TIKET [NAMA EVENT]` | 20 pt (auto-fit 20→12,5) | **24 pt** (auto-fit 24→16) | +20% |
| `ID TIKET: …` | 11,5 pt bold | **13,5 pt** bold | +17% |
| `Peserta: …` | 10 pt | **12 pt** | +20% |
| Instruksi penukaran | 9 pt | **10,5 pt** | +17% |

Penyesuaian pendukung agar tipografi lebih besar tetap proporsional:

- Jarak baris (line gap) disetel ulang: 1,35 / 1,9 / 1,9 / 2,4 — hasil nyata
  jarak antarbaris 19,8–24,9 pt sehingga tidak ada teks bertumpuk.
- Lebar area teks dinaikkan: landscape 330 → **356 pt** (masih 58 pt di kiri
  garis pemisah panel), portrait 300 → **330 pt** (74 pt sisa di kanan header).
- Tinggi area teks default (`DEFAULT_INFO_BY_ORIENTATION`) disesuaikan ke tinggi
  alami blok baru: landscape 0,16 → **0,18** (106,9 pt).
- Ukuran font dipusatkan pada konstanta `TICKET_TYPE` + `INFO_BLOCK_REFERENCE_HEIGHT`
  agar backend dan UI Flutter tidak menyimpang.

Hierarki terverifikasi dari PDF: **24 > 13,5 > 12 > 10,5 pt** (judul > ID >
nama > instruksi).

### 9.2 Hasil pengujian

| Pengujian | Hasil | Status |
|---|---|---|
| Ukuran font per baris | 24 / 13,5 / 12 / 10,5 pt pada tiket default, artwork kustom, dan lampiran email | PASS |
| Hierarki | Judul > ID > nama > instruksi, menurun monoton | PASS |
| Tidak ada teks bertumpuk | Jarak antarbaris 19,8–24,9 pt (≥ 1× ukuran font baris berikutnya) | PASS |
| Judul panjang | Auto-fit mengecil ke 16 pt + elipsis rapi; tetap 1 baris, tidak menabrak QR (`_verify-out/render/ticket-long-title.png`) | PASS |
| Blok teks vs QR | Teks berakhir di ±140 pt, QR mulai 176 pt → tidak beririsan | PASS |
| QR tidak berubah | 280/300 pt, modul 2,62–2,79 mm, quiet zone 4,55–4,77 modul, alas putih 0,73–0,81 modul | PASS |
| QR dapat dipindai | OpenCV mendekode default, portrait, artwork kustom, dan judul panjang (43 karakter) | PASS |
| Background/ilustrasi utuh | Logo, ilustrasi, ornamen, dan teks pada artwork tetap terlihat (tidak tertutup) | PASS |
| Dimensi PDF | 842 × 594 pt (landscape) & 440 × 704 pt (portrait) | PASS |
| Regresi unit | `test/ticket_design.test.js` **30/30 PASS** (termasuk test baru hierarki tipografi) | PASS |
| Statis backend | `npm run check` PASS (60 file), `npm run format:check` PASS | PASS |
| Flutter | `flutter analyze` PASS, `flutter test` **331 PASS** (test baru area teks default) | PASS |
| `npm test` backend | 284 test, 279 pass / 5 fail — 5 kegagalan email **pre-existing** (`EMAIL_PROVIDER=brevo` di `backend/.env`) | FAIL (pre-existing) |

### 9.3 Bukti visual

- `backend/_verify-out/render/ticket-landscape-default.png` — tulisan lebih
  besar & mudah dibaca, QR dan background tidak berubah.
- `backend/_verify-out/render/ticket-portrait-default.png` — varian portrait.
- `backend/_verify-out/render/ticket-artwork.png` — desain penyelenggara
  (logo "U-NITY", ilustrasi, ornamen) tetap dominan.
- `backend/_verify-out/render/ticket-long-title.png` — nama event panjang.
