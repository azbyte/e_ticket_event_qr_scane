# Laporan — Perbaikan Desain & Tata Letak Tiket Peserta

Permintaan: tiket peserta wajib mengikuti desain unggahan penyelenggara (default
sistem hanya bila tidak ada unggahan), QR Code dapat diatur ukuran & posisinya
dan benar-benar diterapkan pada tiket, serta tulisan diperbesar dengan hierarki
proporsional tanpa tumpang tindih/terpotong.

## 1. Temuan (akar masalah)

| # | Temuan | Dampak |
|---|---|---|
| 1 | `buildTicketPdf` memakai kandidat desain pertama (kategori) tanpa memeriksa file; bila file kategori hilang, tiket langsung memakai **desain default** walau desain event ada | Desain unggahan penyelenggara bisa tergantikan desain bawaan |
| 2 | `qrRectFromFractions` menaikkan ukuran QR ke minimum 200 pt lalu **memotongnya** ke ruang tersisa | Ukuran QR yang diatur Organizer tidak dipakai apa adanya |
| 3 | `avoidInfoOverlap` **memperkecil** QR bila tidak muat di bawah teks | Pengaturan Organizer diabaikan secara senyap |
| 4 | Blok informasi hanya 4 baris (31/17,5/15,5/13,5 pt); kategori, jadwal, dan lokasi tidak dicetak | Tulisan terasa kecil dan informasi penting hilang |
| 5 | Panel Organizer hanya punya slider **X** dan **ukuran**; perubahan tidak dapat disimpan tanpa mengunggah ulang file (dan unggah ulang menghapus pengaturan QR yang sedang diatur) | Posisi vertikal tidak dapat diatur; pengaturan tidak tersimpan |
| 6 | Slider memakai nilai tersimpan apa adanya, sedangkan backend membatasi 15%–90% | Nilai lama (mis. 90%) membuat slider menerima nilai di luar batasnya |

## 2. Perbaikan

### 2.1 Pemilihan desain (wajib mengikuti unggahan penyelenggara)

- `resolveDesignAsset([kategori, event])` mencoba kandidat berurutan dan memakai
  kandidat **pertama yang filenya benar-benar ada**. Referensi yang menunjuk file
  hilang dilewati, sehingga tiket memakai desain event — bukan desain default.
- Desain default sistem hanya dipakai bila tidak ada file desain sama sekali.
- Orientasi tetap dibaca dari kolom `ticket_design_orientation` (kategori →
  event → JSON desain → default) agar orientasi tersimpan tidak hilang.

### 2.2 Pengaturan ukuran & posisi QR Code

- Backend: `qrRectFromFractions` memakai `size × tinggi kanvas` **apa adanya**
  (batas pindai minimum `QR_MIN_POINTS` 100 pt, maksimum sisi halaman). Posisi
  digeser hanya bila QR akan keluar halaman — ukuran tidak diperkecil.
- `validateQrPlacement` menjadi satu sumber aturan (dipakai jalur unggah dan
  jalur simpan pengaturan): posisi 0–95%, ukuran 15%–60%.
- `placeTicketInfoAndQr` menjaga QR dan blok teks tidak bertumpuk: posisi QR
  Organizer dipertahankan; bila QR besar menabrak teks dan tidak dapat digeser,
  **blok teks** yang dipindah (QR tetap pada ukuran/posisi yang diatur).
- Mode simpan baru `PUT /api/events/:id/ticket-design` dengan `qr_only: true`
  (`applyQrPlacement`) menyimpan posisi/ukuran QR pada desain yang sudah ada
  **tanpa mengunggah ulang file** dan tanpa mengubah orientasi/area teks.
- Flutter: slider **X**, **Y (baru)**, dan **ukuran**; tombol **“Simpan
  pengaturan QR”** (aktif hanya bila ada perubahan) dan **“Atur ulang default”**;
  status “tersimpan / belum disimpan”; nilai tersimpan dirapikan ke batas
  (`TicketQrPlacement.clamped()`).

### 2.3 Tipografi lebih besar dan proporsional

| Baris | Sebelum | Sesudah |
|---|---|---|
| `E-TIKET [NAMA EVENT]` | 31 pt, auto-fit 31→22 | **34 pt**, auto-fit 34→26, boleh 2 baris |
| `Peserta: [NAMA]` | 15,5 pt | **23 pt** bold, auto-fit 23→17 agar satu baris utuh |
| `ID TIKET` | 17,5 pt | **16 pt** bold |
| `Kategori` | tidak dicetak | **16 pt** |
| `Jadwal` (tanggal & waktu, WIB) | tidak dicetak | **16 pt** |
| `Lokasi` | tidak dicetak | **16 pt** |
| Instruksi penukaran | 13,5 pt | **14 pt** |

- Area teks default diperbesar mengikuti tipografi baru (landscape
  `textHeight` 208 pt, portrait 200 pt; header portrait 216 → 252 pt) dan QR
  digeser ke bawahnya (landscape y 200 → 284 pt, portrait 236 → 266 pt).
- Judul memilih ukuran terbesar yang muat **satu baris**; nama event yang sangat
  panjang baru dibungkus dua baris — sehingga blok lain tidak ikut mengecil.
- Bila area teks desain kustom lebih pendek, seluruh blok dikecilkan proporsional
  (skala minimum 0,62, hierarki tetap) agar tidak menimpa QR.

### 2.4 Aset & dokumentasi

- `generate-ticket-template.ps1` + template PNG landscape/portrait diregenerasi
  mengikuti posisi & ukuran QR default baru (penanda area QR).
- `check_qr_scannability.py` memakai kotak QR default baru.
- `README.md` (backend) dan `docs/ARCHITECTURE.md` diperbarui.

## 3. File yang diubah

| File | Perubahan |
|---|---|
| `backend/src/services/ticketDesignService.js` | `resolveDesignAsset`, `qrRectFromFractions` (ukuran Organizer dipakai), `placeTicketInfoAndQr`, `validateQrPlacement`, `applyQrPlacement`, `resolveInfoLayout`, `infoBlockLines`, tipografi `TICKET_TYPE`, `textHeight` kanvas, `formatTicketSchedule` |
| `backend/src/controllers/ticketDesignController.js` | Mode `qr_only` (simpan posisi/ukuran QR tanpa unggah ulang) |
| `backend/scripts/verify-ticket-pdf.js` | Verifikasi 7 baris & tipografi baru, pengaturan QR Organizer, fallback desain |
| `backend/scripts/generate-ticket-template.ps1`, `backend/assets/ticket-templates/*.png` | Penanda QR mengikuti default baru |
| `backend/tools/check_qr_scannability.py` | Kotak QR default baru |
| `backend/test/ticket_design.test.js` | Test tipografi/QR/placement/resolusi desain (diperbarui + baru) |
| `backend/test/ticket_design_qr_settings.test.js` (**baru**) | Test controller mode `qr_only` (SQL & payload) |
| `apps/lib/models/event/ticket_design_model.dart` | Default QR/area teks baru, `clamped()`, `==`/`hashCode`, `hasCustomQr` |
| `apps/lib/services/organizer_events/ticket_design_service.dart` | `saveQrPlacement()` (`qr_only`) |
| `apps/lib/features/organizer/events/widgets/ticket_design_panel.dart` | Slider Y, simpan/atur ulang QR, status, sinkronisasi state |
| `apps/test/ticket_design_layout_test.dart`, `apps/test/features/organizer/events/ticket_design_orientation_test.dart` | Default baru + widget test pengaturan QR |
| `backend/README.md`, `docs/ARCHITECTURE.md` | Dokumentasi tata letak, tipografi, dan mode `qr_only` |

Tidak ada perubahan schema/migration dan tidak ada dependensi baru.

## 4. Pengujian

| Pengujian | Hasil |
|---|---|
| `npm test` (backend) | **PASS** — 303/303 |
| `flutter analyze` | **PASS** — 0 issue |
| `flutter test` | **PASS** — 337/337 |
| `npm run check`, `npm run format:check`, `npm run validate:skills`, `npm run test:sync-config` | **PASS** |
| `npm run verify:ticket-pdf` | **PASS** — 66 OK, 0 GAGAL |
| Render PDF → PNG (default landscape/portrait, kustom, QR 15%/60%, area teks sempit) | **PASS** — 842×594 & 440×704 pt, tidak ada tumpang tindih |
| QR scannability (`check_qr_scannability.py`) | **PASS** — modul 2,03/2,37 mm, quiet zone 9,33/5,36 modul |
| QR decode `--expect` (default landscape/portrait, QR kustom, ukuran 15%–90%) | **PASS** — isi QR = token tiket |
| Lampiran email | Memakai `buildTicketPdf` yang sama (tidak ada jalur rendering kedua); E2E SMTP **NOT RUN** (tidak ada kredensial di environment ini) |

## 5. Asumsi yang perlu konfirmasi

1. **Ukuran QR default** diturunkan (landscape 240 → 220 pt, portrait 260 →
   250 pt) agar tulisan yang lebih besar tetap seimbang; keduanya masih lolos uji
   pindai (modul ≥ 2 mm, quiet zone ≥ 5 modul).
2. **Kategori, jadwal, dan lokasi dicetak** pada tiket (permintaan §3). Bila
   penyelenggara ingin tiket hanya berisi nama event + peserta + QR, daftar baris
   dapat diubah di `infoBlockLines`.
3. **Batas ukuran QR 15%–60%**: nilai lama di atas 60% tetap dapat dicetak,
   tetapi dirapikan ke 60% saat Organizer membuka panel.
4. **Mode `qr_only` hanya untuk desain yang sudah diunggah**; desain default
   memakai posisi QR bawaan sistem (tidak disimpan per event).
5. Jadwal memakai zona waktu `Asia/Jakarta`, sama dengan email tiket.

