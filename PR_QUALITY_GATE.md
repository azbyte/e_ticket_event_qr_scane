# PR Quality Gate — Panduan Developer

Dokumen ini menjelaskan cara menggunakan mekanisme PR Quality Gate melalui AI di VS Code agar developer dapat memeriksa kesiapan kode sebelum membuat Pull Request.

## Fungsi PR Quality Gate

PR Quality Gate menjalankan seluruh pemeriksaan kualitas kode yang sama dengan yang dijalankan GitHub Actions ketika Pull Request dibuat. Tujuannya adalah mendeteksi dan memperbaiki masalah secara lokal sebelum PR dikirim, sehingga standar lokal dan CI/CD identik.

## Lokasi Skill

Skill tersedia di:
```
.agents/skills/pr-quality-gate/SKILL.md
```

Skill terdaftar dalam katalog di `SKILL.md` dan di-routing melalui `AGENTS.md`.

## Cara Memanggil Melalui AI di VS Code

Buka panel AI / chat di VS Code dan ketik salah satu perintah berikut:

- "Jalankan PR Quality Gate pada branch ini"
- "Periksa kesiapan PR sebelum saya membuat pull request"
- "Pr quality gate check"

AI akan membaca skill `pr-quality-gate`, menjalankan seluruh pemeriksaan, dan menghasilkan laporan akhir.

## Cara Menjalankan Secara Manual

Jika ingin menjalankan pemeriksaan tanpa AI, gunakan perintah berikut di terminal:

### Backend
```bash
cd backend
npm ci
npm test
node --test ../.github/scripts/validate-sync-config.test.js
npm run check
npm run format:check
npm run validate:skills
```

### Flutter
```bash
cd apps
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Semua perintah di atas adalah perintah yang sama dengan yang digunakan di `.github/workflows/quality.yml`.

## Daftar Pemeriksaan yang Dilakukan

### Backend
| Pemeriksaan | Perintah |
|---|---|
| Dependency install | `npm ci` |
| Backend tests | `npm test` |
| Sync config validator tests | `node --test ../.github/scripts/validate-sync-config.test.js` |
| Syntax check | `npm run check` |
| Format check | `npm run format:check` |
| Validate skills | `npm run validate:skills` |

### Flutter
| Pemeriksaan | Perintah |
|---|---|
| Dependency install | `flutter pub get` |
| Static analysis | `flutter analyze --no-fatal-infos` |
| Unit/widget tests | `flutter test` |

### Pre-PR Analysis (Sebelum Pemeriksaan)
- Cek branch aktif
- Cek perubahan yang belum di-commit
- Cek daftar file yang berubah
- Cek keterlambatan branch terhadap `main`
- Identifikasi potensi konflik integrasi
- Cek perubahan yang tidak berkaitan dengan tugas

## Cara Membaca Laporan Hasil

Laporan akhir memiliki kategori status per pemeriksaan:

- **PASS:** Pemeriksaan berhasil tanpa masalah.
- **FAIL:** Pemeriksaan gagal, perlu diperbaiki sebelum PR.
- **WARNING:** Terdapat potensi masalah yang perlu diperhatikan.
- **SKIPPED:** Pemeriksaan tidak dapat dijalankan atau tidak relevan (disertai alasan).

Kesimpulan akhir:

- **READY FOR PR:** Semua pemeriksaan wajib berhasil.
- **NOT READY FOR PR:** Masih terdapat pemeriksaan wajib yang gagal.
- **BLOCKED:** Pemeriksaan tidak dapat diselesaikan karena masalah lingkungan, dependency, atau konfigurasi.

## Cara Menangani Pemeriksaan yang Gagal

1. Baca pesan error dari laporan.
2. Identifikasi file dan baris yang menyebabkan kegagalan.
3. Lakukan perbaikan minimal sesuai standar proyek.
4. Jalankan ulang pemeriksaan yang gagal.
5. Ulangi PR Quality Gate hingga semua pemeriksaan wajib PASS.

**Jangan:** menyembunyikan error, mengabaikan test gagal, mengubah konfigurasi hanya agar check lolos, atau mengubah kode hanya untuk membuat check berhasil.

## Pemeriksaan yang Hanya Tersedia di CI/CD

Beberapa pemeriksaan hanya dapat dijalankan di GitHub Actions karena memerlukan environment spesifik (runner Ubuntu, cache dependency, Flutter 3.47.9, Node.js 22). Pemeriksaan ini akan ditandai sebagai **SKIPPED** saat dijalankan lokal. Jangan anggapnya PASS.

## Cara Memperbarui Quality Gate

Jika standar pemeriksaan PR di GitHub Actions (`.github/workflows/quality.yml`) berubah:

1. Perbarui daftar perintah di `.agents/skills/pr-quality-gate/SKILL.md` bagian Quality Checks.
2. Pastikan parameter dan flag sama persis dengan CI/CD.
3. Jalankan `npm run validate:skills` dari root repository untuk memastikan skill masih valid.
4. Perbarui dokumen ini jika diperlukan.

## Prinsip Penting

- Pemeriksaan lokal dan pemeriksaan PR menggunakan standar yang sama.
- Jangan membuat aturan kualitas baru yang bertentangan dengan CI/CD.
- Jangan menghilangkan pemeriksaan yang sudah ada.
- Pemeriksaan lokal tidak boleh mengubah atau menghapus pekerjaan developer.
- Tidak ada pembuatan PR otomatis, push otomatis, atau merge otomatis.