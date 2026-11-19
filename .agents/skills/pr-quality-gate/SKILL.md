---
name: pr-quality-gate
description: Memilih pemeriksaan targeted sesuai risiko perubahan atau menjalankan gate lengkap pra-PR yang konsisten dengan CI untuk Flutter/backend.
---

# PR Quality Gate

Pilih satu mode:
- **Targeted** untuk validasi iterasi: jalankan pemeriksaan terkecil yang membuktikan area terdampak.
- **Pre-PR** sebelum PR: seluruh pemeriksaan CI di bawah, tidak menghilangkan langkah wajib.

Skill ini tidak membuat PR, commit, push, merge, fetch, atau mengubah flow Git. Jangan menganggap hook lokal sebagai gate otoritatif; hanya required status check CI/branch protection yang dapat memblokir merge.

## Sebelum memilih checks

Periksa branch, `git status --short`, diff staged/unstaged dan file terdampak. Identifikasi perubahan di luar scope. Gunakan remote-tracking ref `origin/main` hanya jika tersedia lokal; jangan fetch. Jika tidak ada, status keterkinian/merge-base adalah NOT RUN, bukan PASS.

## Mode Targeted

Pilih checks berdasarkan dampak, bukan hanya ekstensi file:

| Dampak | Checks minimum yang relevan |
|---|---|
| Backend Express, endpoint, auth, persistence | Dari `backend/`: `npm test`, `npm run check`; tambah format check bila format/JSON berubah. |
| Perubahan workflow/config sinkronisasi | `npm run test:sync-config` dari `backend/`; checks file lain yang terdampak. |
| Skill/katalog/link | `npm --prefix backend run validate:skills`. |
| Flutter UI/state/model/service | Dari `apps/`: `flutter analyze`, `flutter test` (boleh target test lebih sempit saat iterasi, catat cakupan). |
| Backend dan klien terintegrasi | Checks kedua stack serta test yang mengunci kontrak. |
| Docs/config saja | Validator/format/link yang relevan; skip checks aplikasi dengan alasan. |

Pilih tambahan berdasarkan risiko: auth/ownership/QR/transaksi memerlukan regression/security tests; perubahan migration/constraint memerlukan schema/DB checks jika environment uji tersedia. Jangan menjalankan mutasi produksi.

## Mode Pre-PR: checks CI wajib

Jalankan pada versi/runtime CI yang ditentukan repository. Jangan mengulang alias `npm run lint` karena sama dengan `npm run check`.

Di `backend/`:
```bash
npm ci
npm test
npm run test:sync-config
npm run check
npm run format:check
npm run validate:skills
```

Di `apps/`:
```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

Jangan menjalankan ulang dependency install jika CI/local setup sudah memadai dan perubahan dependency tidak ada, kecuali workflow gate mensyaratkannya. Jika mengikuti CI persis, lakukan semua langkahnya. Jangan memodifikasi dependency untuk membuat check lolos.

## Laporan hasil

Catat branch/ref yang tersedia, mode, cakupan, file penting, dan setiap check dengan `PASS`, `FAIL`, `BLOCKED`, `NOT RUN` atau `SKIPPED` serta alasan. Ringkas kegagalan dan langkah lanjut. Kesimpulkan:
- **READY FOR PR** hanya bila semua checks wajib lulus.
- **NOT READY FOR PR** bila check wajib gagal.
- **BLOCKED** bila check wajib tak dapat dijalankan karena environment/dependency.

Jangan menyatakan integrasi Supabase/provider, keamanan keseluruhan, deployment, UI/perangkat atau E2E lulus bila tidak benar-benar diuji. Pemeriksaan lokal bukan pengganti CI/required branch protection.

Jika workflow `.github/workflows/quality.yml` berubah, selaraskan daftar/perintah Skill dengan workflow, lalu jalankan validator Skill dan `npm run test:sync-config`. Tandai checks khusus CI (runner, cache, secrets) SKIPPED lokal dengan alasan, jangan beri PASS palsu.