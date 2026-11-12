---
name: pr-quality-gate
description: Memilih dan menjalankan pemeriksaan kualitas Flutter/backend yang sesuai dengan dampak perubahan, serta menjalankan pemeriksaan lengkap sebagai gate sebelum Pull Request, dengan laporan kesiapan PR yang sinkron dengan CI/CD.
---

# Skill PR Quality Gate

Skill ini memungkinkan developer menjalankan pemeriksaan kualitas kode secara lokal melalui AI di VS Code sebelum membuat Pull Request. Semua pemeriksaan menggunakan perintah dan konfigurasi yang sama dengan workflow GitHub Actions (`.github/workflows/quality.yml`) sehingga standar lokal dan CI/CD identik.

Skill ini menggabungkan dua mode pemeriksaan yang sebelumnya dipisah:
- **Mode Targeted (verification)**: pemeriksaan kecil yang cukup buktikan risiko area yang berubah, dipilih berdasarkan dampak perubahan.
- **Mode Pre-PR Gate (pr-quality-gate)**: seluruh pemeriksaan wajib sebagai gate kelulusan PR, dengan laporan READY FOR PR / NOT READY FOR PR / BLOCKED.

Skill ini TIDAK mengubah flow Git, TIDAK membuat PR otomatis, dan TIDAK push otomatis.

Repository menyediakan hook pre-push di `.githooks/pre-push`. Setelah
mengaktifkan `git config core.hooksPath .githooks` dan menyiapkan dependency,
hook menjalankan seluruh pemeriksaan backend dan Flutter yang sama dengan CI
sebelum push. Hook lokal dapat dilewati; status `PR Quality Gate` yang diwajibkan
melalui branch protection/ruleset GitHub adalah gate merge yang otoritatif.

## 1. Tujuan

- Deteksi dan perbaiki masalah sebelum PR dibuat.
- Hindari dua sistem quality check yang berbeda (lokal vs CI/CD).
- Berikan laporan akhir yang jelas: READY FOR PR / NOT READY FOR PR / BLOCKED.
- Hindari duplikasi instruksi pemeriksaan di banyak skill.

## 2. Pre-PR Analysis

### 2.1 Cek branch aktif
```bash
git branch --show-current
```
Catat nama branch aktif. Pastikan tidak berada pada branch `main` langsung.

### 2.2 Cek perubahan yang belum di-commit
```bash
git status --porcelain
```
Identifikasi file yang ditambahkan, diubah, atau dihapus tetapi belum di-commit.

### 2.3 Cek daftar file yang berubah
```bash
git diff --name-only HEAD
git diff --cached --name-only
```
Catat semua file yang terpengaruh oleh perubahan developer.

### 2.4 Cek keterlambatan branch terhadap target branch PR (opsional)
```bash
git show-ref --verify refs/remotes/origin/main
git log --oneline origin/main..HEAD
```
Gunakan hanya remote-tracking ref yang sudah tersedia lokal; langkah ini tidak
menjalankan `fetch` atau mengubah referensi Git. Jika ref tidak tersedia,
tandai perbandingan sebagai **NOT RUN** dan jangan menyimpulkan branch up-to-date.
Jika base tersedia, bandingkan commit dan tandai keterlambatan sebagai WARNING.

### 2.5 Identifikasi potensi konflik integrasi
```bash
git merge-base HEAD origin/main
```
Gunakan hasil hanya jika remote-tracking ref tersedia lokal; jangan melakukan
fetch otomatis atau menyembunyikan kegagalan perintah.

## 3. Pemilihan Pemeriksaan Berdasarkan Risiko (Mode Targeted)

Cocokkan perubahan dengan risiko dan pilih pemeriksaan terkecil yang cukup membuktikannya. Fokus pada area yang paling berpotensi terpengaruh oleh perubahan.

- Perubahan UI Flutter → `flutter analyze` dan `flutter test` di `apps/`.
- Perubahan backend Express → `npm test` dan `npm run check` di `backend/`.
- Perubahan hanya dokumentasi/config → pemeriksaan dapat dibatasi pada file terkait, tandai pemeriksaan lain sebagai SKIPPED.

Catat perintah, hasil PASS/FAIL/BLOCKED/NOT RUN, dan batasan. Jangan menyebut semua fitur/regresi lulus bila hanya menjalankan pemeriksaan sebagian.

## 4. Pemeriksaan Kualitas (Mode Pre-PR Gate)

Sebelum membuat PR, jalankan seluruh pemeriksaan wajib berikut.

### 4.1 Backend Checks

Di direktori `backend/`:

| No | Pemeriksaan | Perintah | Sumber CI/CD |
|---|---|---|---|
| 1 | Dependency install | `npm ci` | quality.yml |
| 2 | Backend tests | `npm test` | quality.yml |
| 3 | Sync config validator tests | `npm run test:sync-config` | quality.yml |
| 4 | Syntax check | `npm run check` | quality.yml |
| 5 | Format check | `npm run format:check` | quality.yml |
| 6 | Validate skills | `npm run validate:skills` | quality.yml |

Contoh eksekusi:
```bash
cd backend
npm ci
npm test
npm run test:sync-config
npm run check
npm run format:check
npm run validate:skills
```

### 4.2 Flutter Checks

Di direktori `apps/`:

| No | Pemeriksaan | Perintah | Sumber CI/CD |
|---|---|---|---|
| 1 | Dependency install | `flutter pub get` | quality.yml |
| 2 | Static analysis | `flutter analyze --no-fatal-infos` | quality.yml |
| 3 | Unit/widget tests | `flutter test` | quality.yml |

Contoh eksekusi:
```bash
cd apps
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

## 5. Laporan Kesiapan PR

Setelah semua pemeriksaan selesai, buat laporan dengan format berikut:

```
# Laporan PR Quality Gate

## Branch
- Branch aktif: <nama-branch>
- Target branch PR: main
- Perubahan belum di-commit: <ya/tidak>
- File yang berubah: <daftar file>

## Mode Pemeriksaan
- Targeted / Pre-PR Gate

## Hasil Pemeriksaan

| Pemeriksaan | Status | Detail |
|---|---|---|
| Backend: npm test | PASS/FAIL/SKIPPED | ... |
| Backend: npm run check | PASS/FAIL/SKIPPED | ... |
| Backend: npm run format:check | PASS/FAIL/SKIPPED | ... |
| Backend: npm run validate:skills | PASS/FAIL/SKIPPED | ... |
| Backend: sync config validator tests | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter pub get | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter analyze | PASS/FAIL/SKIPPED | ... |
| Flutter: flutter test | PASS/FAIL/SKIPPED | ... |

## Kesimpulan

**READY FOR PR** / **NOT READY FOR PR** / **BLOCKED**

<alasan singkat>

### Kategori Status

- **PASS**: Pemeriksaan berhasil tanpa masalah.
- **FAIL**: Pemeriksaan gagal, perlu diperbaiki sebelum PR.
- **WARNING**: Terdapat potensi masalah yang perlu diperhatikan (misal: branch tertinggal jauh dari main).
- **SKIPPED**: Pemeriksaan tidak dapat dijalankan atau tidak relevan, disertai alasannya.

### Kesimpulan Akhir

- **READY FOR PR**: Semua pemeriksaan wajib berhasil (tidak ada FAIL pada pemeriksaan wajib).
- **NOT READY FOR PR**: Masih terdapat pemeriksaan wajib yang gagal.
## 6. Pemeriksaan Hanya Tersedia di CI/CD

Beberapa pemeriksaan hanya dapat dijalankan di GitHub Actions karena memerlukan environment spesifik:
- Cache dependency (`cache: npm`, `cache: true` untuk Flutter).
- Runner Ubuntu dengan Flutter 3.47.9 dan Node.js 22.
- Concurrency cancellation untuk PR yang diperbarui.

Jika pemeriksaan ini tidak tersedia lokal, tandai sebagai **SKIPPED** dengan alasan "Hanya tersedia di GitHub Actions environment". Jangan beri status PASS palsu.

## 7. Konflik Sinkronisasi Branch

Jika workflow sinkronisasi gagal saat merge source ke direct child, ringkasan
job mencantumkan branch dan file konflik serta perintah untuk mengambil source,
berpindah ke child, dan mengulang merge secara lokal. Jangan memilih versi
otomatis. Tinjau kedua sisi; untuk file biner atau modify/delete tentukan
eksplisit apakah file dipertahankan atau dihapus. Setelah resolusi, jalankan
quality checks sebelum push.

## 8. Cara Memanggil Skill Ini

Di VS Code, gunakan perintah AI / chat dan sebutkan:
- "Jalankan PR Quality Gate pada branch ini"
- "Periksa kesiapan PR sebelum saya membuat pull request"
- "Pr quality gate check"
- "Jalankan pemeriksaan kualitas berdasarkan dampak perubahan" (mode targeted)

AI akan menjalankan langkah yang relevan di skill ini dan memberikan laporan akhir.

## 9. Cara Memperbarui Skill Ini

Jika standar pemeriksaan PR di GitHub Actions (`.github/workflows/quality.yml`) berubah:
1. Perbarui daftar perintah di bagian 4 (Pemeriksaan Kualitas) agar sesuai.
2. Pastikan parameter dan flag sama persis dengan CI/CD.
3. Perbarui tabel pemeriksaan jika diperlukan.
4. Jalankan `npm run validate:skills` dan `node --test
   ../.github/scripts/validate-sync-config.test.js` untuk memastikan kedua
   mekanisme validasi tetap berfungsi.