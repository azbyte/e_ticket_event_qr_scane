# Laporan — Perbaikan Diagnostic VS Code (JS, Python, Pylance)

Empat diagnostic yang dilaporkan sudah ditangani. Ringkasan hasil:

| No. | File | Permasalahan | Perbaikan | Status |
|---|---|---|---|---|
| 1 | `backend/src/services/ticketDesignService.js` | `'}' expected. ts(1005)` Ln 1095, blok pembuka Ln 736 Col 40 | Blok ornamen nested-loop di Ln 736 diekstrak menjadi helper bernama `drawDotGrid` (struktur blok jelas, tanpa menambah `}`); berkas diverifikasi dengan 3 parser | **PASS** |
| 2 | `backend/_verify-out/make_artwork.py` | `Import "PIL" could not be resolved` (Ln 11) | `Pillow` dipasang di `backend/.venv` dan dicatat di `backend/tools/requirements.txt`; `import PIL` **tidak** diubah | **PASS** |
| 3 | `.vscode/settings.json` | `python.analysis.extraPaths` cannot be set when a `pyrightconfig.json` is being used (Ln 12) | `extraPaths` dipindah ke `pyrightconfig.json` (`"extraPaths": ["backend"]`), dihapus dari `settings.json` | **PASS** |
| 4 | `.vscode/settings.json` | `python.analysis.exclude` cannot be set ... (Ln 16) | `exclude` dipindah ke `pyrightconfig.json` (sudah ada, diperluas); dihapus dari `settings.json` | **PASS** |

## 1. Penyebab utama tiap masalah

### 1.1 `ticketDesignService.js` — ts(1005)

- Berkas di disk **valid**: `node --check` exit 0, `tsc` (parser yang sama dengan
  VS Code) `0 errors`, dan pemeriksaan kurung manual
  (`backend/_verify-out/diag-braces.js`) menemukan **178 blok berpasangan, 0
  kurung tanpa tutup, 0 karakter tak terlihat, tanpa BOM**.
- Blok yang ditunjuk editor (Ln 736 Col 40) adalah `{` dari
  `for (let row = 0; row < 4; row += 1) {` — dan blok itu memang ditutup di
  baris 740. Jadi laporan "Ln 736 belum ditutup" **tidak sesuai isi berkas**.
- Penyebab sebenarnya: diagnostic berasal dari **buffer editor yang tidak
  konsisten saat berkas sedang disunting** (blok ornamen panel kiri baru saja
  dipindah posisinya). Saat buffer setengah jadi, parser kehilangan
  sinkronisasi lebih awal lalu melaporkan `'}' expected` di akhir berkas.
  Setelah berkas tersimpan utuh, rantai diagnostic itu hilang — pola yang sama
  dengan kasus `paymentController.js` sebelumnya.
- Tindakan: alih-alih menambahkan `}` (yang justru merusak berkas), konstruksi
  yang ditunjuk editor dirapikan menjadi helper bernama `drawDotGrid`. Output
  visual **identik** — dibuktikan dengan hash PNG render sebelum/sesudah:
  `B1A321DF…` (landscape) dan `31AAD565…` (portrait) sama persis.

### 1.2 `make_artwork.py` — PIL unresolved

- Script memakai `from PIL import Image, ImageDraw, ImageFont` untuk membuat
  artwork uji (ilustrasi/logo/ornamen penyelenggara) sebelum PDF dirender.
- `Pillow` **tidak terpasang** di `backend/.venv` (interpreter proyek yang
  dipakai Pylance), sehingga import tidak dapat di-resolve. Di Python 3.14
  global Pillow ada, tetapi Pylance tidak memakai interpreter itu.
- Nama import tidak diubah: paket `Pillow` memang menyediakan modul `PIL`.

### 1.3 & 1.4 `settings.json` — konflik `extraPaths` / `exclude`

- Repository punya `pyrightconfig.json` (tidak ada `pyproject.toml`). Ketika
  berkas itu ada, Pylance menjadikannya **satu-satunya** sumber konfigurasi
  analisis dan menolak `python.analysis.extraPaths` / `python.analysis.exclude`
  di `settings.json`.
- Konfigurasi sebelumnya menduplikasi keduanya di dua tempat → dua warning.

## 2. File yang diubah

| File | Perubahan |
|---|---|
| `backend/src/services/ticketDesignService.js` | Helper `drawDotGrid(doc, {x,y,rows,cols,step})`; loop bersarang di `drawLandscapeTicket` diganti pemanggilan helper |
| `backend/tools/requirements.txt` | `Pillow>=10,<14` + catatan `Pillow`→`PIL` dan daftar `_verify-out/make_artwork.py` |
| `pyrightconfig.json` | `include` → `["backend"]` (agar `_verify-out/*.py` ikut dianalisis), `extraPaths: ["backend"]` ditambahkan, `backend/_verify-out` dihapus dari `exclude`, `diagnosticMode` **tidak** dipakai (bukan kunci Pyright — CLI menolaknya) |
| `.vscode/settings.json` | `python.analysis.extraPaths` & `python.analysis.exclude` dihapus; tersisa interpreter + `python.analysis.diagnosticMode` (khusus Pylance) |
| `backend/scripts/check-format.js` | `excludedDirs` + `.venv`, `venv`, `__pycache__` (environment Python bukan sumber proyek; sebelumnya `format:check` ikut memeriksa JS pihak ketiga di `.venv`) |
| `backend/README.md` | Cara pasang dependency alat validasi (termasuk Pillow & `make_artwork.py`) |
| `backend/_verify-out/diag-braces.js` | **baru** — diagnostik struktur JS (BOM/CR/karakter tak terlihat/pasangan kurung) |


## 3. Dependency yang dipasang / diperbarui

- **Dipasang** di `backend/.venv` (Python 3.14.5): `Pillow 13.0.0`.
- **Diperbarui**: `backend/tools/requirements.txt` (+`Pillow>=10,<14`).
- Tidak ada instalasi global baru dan tidak ada virtual environment baru —
  `backend/.venv` yang sudah ada dipakai ulang.
- `pyright` (1.1.414) dipasang sementara di venv **hanya untuk verifikasi**
  (setara Pylance), lalu di-uninstall agar tidak menambah dependency proyek.

Isi `backend/.venv` setelah pekerjaan: `pymupdf 2.2`, `opencv-python-headless
5.1.0.95`, `numpy 2.5.5`, `pillow 13.0.0`.

## 4. Perintah pengujian yang dijalankan

```powershell
# JavaScript
cd backend
node --check src/services/ticketDesignService.js
npx --yes -p typescript@5 tsc --allowJs --noEmit --target es2022 --module commonjs --skipLibCheck src/services/ticketDesignService.js
node _verify-out/diag-braces.js src/services/ticketDesignService.js
npm run check
npm run format:check
npm test

# Pembuatan tiket
node scripts/verify-ticket-pdf.js
node _verify-out/custom.js
.\.venv\Scripts\python.exe tools/render_ticket_pdf.py _verify-out
.\.venv\Scripts\python.exe tools/check_qr_scannability.py _verify-out/ticket-landscape-default.pdf _verify-out/ticket-portrait-default.pdf _verify-out/ticket-artwork.pdf
.\.venv\Scripts\python.exe tools/decode_ticket_qr.py --expect=<token> _verify-out/ticket-landscape-default.pdf _verify-out/ticket-portrait-default.pdf

# Python
.\.venv\Scripts\python.exe -c "import PIL; print(PIL.__version__)"
.\.venv\Scripts\python.exe _verify-out/make_artwork.py
backend\.venv\Scripts\python.exe -m pyright        # dijalankan dari root repo
```

## 5. Hasil pengujian

| Pengujian | Hasil |
|---|---|
| `node --check ticketDesignService.js` | **PASS** (exit 0) |
| `tsc --noEmit` pada `ticketDesignService.js` | **PASS** — 0 error (parser yang sama dengan VS Code) |
| `diag-braces.js` | **PASS** — 178 blok berpasangan, 0 kurung tanpa tutup, 0 karakter tak terlihat, tanpa BOM |
| `npm run check` | **PASS** — 60 berkas JS |
| `npm run format:check` | **PASS** (setelah `.venv` dikecualikan) |
| `npm test` | **PASS** — 284/284 |
| `verify-ticket-pdf` | **PASS** — 55 pemeriksaan OK, 0 GAGAL |
| Render PDF→PNG | **PASS** — 842×594 pt & 440×704 pt, hash identik dengan sebelum refactor |
| QR scanability | **PASS** — QR 240/260 pt, modul 2,20–2,46 mm, quiet zone ≥5 modul |
| QR decode (`--expect`) | **PASS** — isi QR = token tiket (default, portrait, dan artwork kustom) |
| `make_artwork.py` | **PASS** — `artwork-landscape.png` 1684×1188 px dihasilkan |
| `python -m pyright` (root repo) | **PASS** — 5 berkas dianalisis, **0 error, 0 warning**; tidak ada lagi "unrecognized setting" |

## 6. Masalah yang masih tersisa

- **Tidak ada error baru.** Satu regresi yang sempat muncul sudah diperbaiki:
  `npm run format:check` gagal karena ikut memeriksa berkas JS di dalam
  `backend/.venv` (dan dua dump JSON UTF-16 sementara di `_verify-out`);
  dump dihapus dan `.venv`/`venv`/`__pycache__` dikecualikan.
- **Belum dapat diverifikasi dari sini:** panel Problems VS Code yang sedang
  terbuka. Berkas di disk sudah valid menurut tiga parser berbeda; jika
  diagnostic lama masih tampil, jalankan **Developer: Reload Window** agar
  buffer editor memuat ulang berkas dari disk.
- `.vscode/settings.json` bersifat lokal (`.vscode/` di `.gitignore`), jadi
  developer lain perlu memilih interpreter `backend/.venv` sekali; konfigurasi
  yang dibagi lewat repo (`pyrightconfig.json`) sudah lengkap.
