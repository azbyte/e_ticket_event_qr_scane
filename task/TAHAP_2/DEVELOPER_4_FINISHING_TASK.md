# Integrator Tahap 2 (pasca-merge, bukan FINISHING database)

## Kapan aktif (non-blocking)
Perintah pemilik proyek untuk peran integrator sudah merupakan otorisasi: mulai dari kondisi repository aktual, tanpa menunggu seluruh PR merged, baseline Tahap 1 tervalidasi, atau PRD decisions ditandatangani. Bila PR/laporan belum ada, audit working tree yang tersedia dan catat sebagai NOT RUN. Bila menemukan domain failure, perbaiki bila masih dalam scope integrator; selain itu hand-back ke pemilik dengan bukti.

## Baca / urutan
Baca Tahap 2 ownership/contract, D1–3 tasks & reports, merged PR diffs/CI, PRD AC-02/06/08/09, source touched files. Pertama audit file paths; kedua kontrak invitation→membership→scanner→attendee; ketiga jalankan test target dan quality checks; keempat smoke UI integration; terakhir isi laporan GO/NO-GO.

## Scope kecil
Boleh hanya laporan D4 dan integration test files di `FILE_OWNERSHIP.md`. Periksa deep-link manual hanya bila test device/environment tersedia; periksa online scanner happy/reject paths memakai synthetic fixture. Tak perlu melakukan audit repo atau membuat feature baru. Tiny integration fix hanya pada D4-owned test; source domain issue dikembalikan.

## Dilarang
Membangun ulang invitation/scanner/admin, schema/migration/SQL/seed/config DB, route/router/global config, token architecture tanpa security decision, offline scanning. Tidak seed atau mengakses/memutasi database pengguna/remote. Integrator tidak otomatis menjadi penanggung jawab FINISHING atau memiliki otoritas database; lihat `../FINISHING_AUTHORITY.md`.

## Kelulusan
Ownership/contract pass; tests required pass dengan skips dijelaskan; denied flows tidak lolos; no app mock fallback; remaining runtime/device evidence transparan. Baseline GO hanya bila kriteria Tahap 2 semua pass.

## Laporan
Gunakan format Tahap 1 report D4: PR commits, ownership, contract, checks, device/DB limits, defects handback, residual risk, GO/NO-GO.
