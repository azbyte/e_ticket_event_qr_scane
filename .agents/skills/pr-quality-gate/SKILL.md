---
name: pr-quality-gate
description: Menjalankan pemeriksaan kualitas kode lokal sebelum Pull Request menggunakan standar yang sama dengan CI/CD GitHub Actions, kemudian menghasilkan laporan kesiapan PR.
---

# Skill PR Quality Gate

Skill ini memungkinkan developer menjalankan seluruh pemeriksaan kualitas kode secara lokal melalui AI di VS Code sebelum membuat Pull Request. Semua pemeriksaan menggunakan perintah dan konfigurasi yang sama dengan workflow GitHub Actions (`.github/workflows/quality.yml`) sehingga standar lokal dan CI/CD identik.

## Tujuan

- Deteksi dan perbaiki masalah sebelum PR dibuat.
- Hindari dua sistem quality check yang berbeda (lokal vs CI/CD).
- Berikan laporan akhir yang jelas: READY FOR PR / NOT READY FOR PR / BLOCKED.
- Tidak mengubah flow Git, tidak membuat PR otomatis, tidak push otomatis.

## 1. Pre-PR Analysis

### 1.1 Cek branch aktif
```bash
git branch --show-current
```
Catat nama branch aktif. Pastikan tidak berada pada branch `main` langsung.

### 1.2 Cek perubahan yang belum di-commit
```bash
git status --porcelain
```
Identifikasi file yang ditambahkan, diubah, atau dihapus tetapi belum di-commit.

### 1.3 Cek daftar file yang berubah
```bash
git diff --name-only HEAD
git diff --cached --name-only
```
Catat semua file yang terpengaruh oleh perubahan developer.

### 1.4 Cek keterlambatan branch terhadap target branch PR
```bash
git log --oneline main..HEAD 2>/dev/null || git log --oneline origin/main..HEAD 2>/dev/null
```
Identifikasi commit pada branch aktif yang belum ada di `main`.

### 1.5 Identifikasi potensi konflik integrasi
```bash
git fetch origin 2>/dev/null || true
git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || true
```
Jika branch aktif jauh tertinggal dari `main`, tandai sebagai WARNING.

### 1.6 Cek perubahan yang tidak berkaitan dengan tugas
Bandingkan daftar file yang berubah dengan cakupan tugas. Tanyakan kepada developer jika terdapat file yang tidak terkait.

## 2. Quality Checks

Jalankan seluruh pemeriksaan berikut menggunakan perintah yang sama dengan GitHub Actions.

### 2.1 Backend Checks

Di direktori `backend/`:

| No | Pemeriksaan | Perintah | Sumber CI/CD |
|---|---|---|---|
| 1 | Dependency install | `npm ci` | quality.yml |
| 2 | Backend tests | `npm test` | quality.yml |
| 3 | Syntax check | `npm run check` | quality.yml |
| 4 | Lint | `npm run lint` | quality.yml |
| 5 | Format check | `npm run format:check` | quality.yml |
| 6 | Validate skills | `npm run validate:skills` | quality.yml |

Contoh eksekutan:
```bash
cd backend
npm ci
npm test
npm run check
npm run lint
npm run format:check
npm run validate:skills
```

### 2.2 Flutter Checks

Di direktori `apps/`:

| No | Pemeriksaan | Perintah | Sumber CI/CD |
|---|---|---|---|
| 1 | Dependency install | `flutter pub get` | quality.yml |
| 2 | Static analysis | `flutter analyze --no-fatal-infos` | quality.yml |
| 3 | Unit/widget tests | `flutter test` | quality.yml |

Contoh eksekutan:
```bash
cd apps
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

### 2.3 Konfigurasi yang Sama dengan CI/CD

Semua perintah di atas diambil langsung dari `.github/workflows/quality.yml` dan `README.md`. Jangan membuat perintah baru atau mengubah parameter. Jika standar CI/CD berubah, perbarui skill ini agar sinkron.

## 3. Error Analysis

Jika pemeriksaan gagal:

1. **Identifikasi penyebab:** Baca output error lengkap dari perintah yang gagal.
2. **Tampilkan nama pemeriksaan:** Sebutkan secara eksplisit pemeriksaan mana yang gagal.
3. **Tampilkan pesan error:** Salin pesan error relevan tanpa disunting.
4. **Identifikasi file dan lokasi:** Jika error menyebutkan file dan baris, catatnya.
5. **Berikan rekomendasi perbaikan:** Sarankan perubahan minimal sesuai standar proyek.
6. **Jalankan kembali:** Setelah perbaikan, jalankan ulang pemeriksaan yang gagal.

**Larangannya:**
- Jangan menyembunyikan error.
- Jangan mengabaikan test yang gagal.
- Jangan menurunkan standar kualitas.
- Jangan mengubah konfigurasi hanya agar pemeriksaan terlihat berhasil.
- Jangan mengubah kode aplikasi hanya untuk membuat Quality Checks berhasil.

## 4. Final PR Readiness Report

Setelah semua pemeriksaan selesai, buat laporan dengan format berikut:

```
# Laporan PR Quality Gate

## Branch
- Branch aktif: <nama-branch>
- Target branch PR: main
- Perubahan belum di-commit: <ya/tidak>
- File yang berubah: <daftar file>

## Hasil Pemeriksaan

| Pemeriksaan | Status | Detail |
|---|---|---|
| Backend: npm test | PASS/FAIL/SKIPPED | ... |
| Backend: npm run check | PASS/FAIL/SKIPPED | ... |
| Backend: npm run lint | PASS/FAIL/SKIPPED | ... |
| Backend: npm run format:check | PASS/FAIL/SKIPPED | ... |
| Backend: npm run validate:skills | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter pub get | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter analyze | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter test | PASS/FAIL/SKIPPED | ... |

## Kesimpulan

**READY FOR PR** / **NOT READY FOR PR** / **BLOCKED**

<alasan singkat>
```

### Kategori Status
- **PASS:** Pemeriksaan berhasil tanpa masalah.
- **FAIL:** Pemeriksaan gagal, perlu diperbaiki sebelum PR.
- **WARNING:** Terdapat potensi masalah yang perlu diperhatikan (misal: branch tertinggal jauh dari main).
- **SKIPPED:** Pemeriksaan tidak dapat dijalankan atau tidak relevan, disertai alasannya.

### Kesimplan Akhir
- **READY FOR PR:** Semua pemeriksaan wajib berhasil (tidak ada FAIL pada pemeriksaan wajib).
- **NOT READY FOR PR:** Masih terdapat pemeriksaan wajib yang gagal.
- **BLOCKED:** Pemeriksaan tidak dapat diselesaikan karena masalah lingkungan, dependency, konfigurasi, atau keterbatasan lainnya.

## 5. Pemeriksaan Hanya Tersedia di CI/CD

Beberapa pemeriksaan hanya dapat dijalankan di GitHub Actions karena memerlukan environment spesifik:
- Cache dependency (`cache: npm`, `cache: true` untuk Flutter)
- Runner Ubuntu dengan Flutter 3.47.9 dan Node.js 22
- Concurrency cancellation untuk PR yang diperbarui

Jika pemeriksaan ini tidak tersedia lokal, tandai sebagai **SKIPPED** dengan alasan "Hanya tersedia di GitHub Actions environment". Jangan beri status PASS palsu.

## 6. Cara Memanggil Skill Ini

Di VS Code, gunakan perintah AI / chat dan sebutkan:
- "Jalankan PR Quality Gate pada branch ini"
- "Periksa kesiapan PR sebelum saya membuat pull request"
- "Pr quality gate check"

AI akan menjalankan semua langkah di skill ini dan memberikan laporan akhir.

## 7. Cara Memperbarui Skill Ini

Jika standar pemeriksaan PR di GitHub Actions (`.github/workflows/quality.yml`) berubah:
1. Perbarui daftar perintah di bagian 2 (Quality Checks) agar sesuai.
2. Pastikan parameter dan flag sama persis dengan CI/CD.
3. Perbarui tabel pemeriksaan jika diperlukan.
4. Jalankan `npm run validate:skills` untuk memastikan skill masih valid.