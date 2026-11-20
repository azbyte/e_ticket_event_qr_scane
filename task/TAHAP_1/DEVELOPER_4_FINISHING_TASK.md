# Integrator Tahap 1 (pasca-merge, bukan FINISHING database)

## Kapan aktif (non-blocking)
Tiga PR D1–D3 telah di-review dan merged ke branch tahap, laporan developer terisi, file ownership pass, dan product/technical gates diperiksa. Bila PR atau laporan belum lengkap, audit working tree yang tersedia dan catat sebagai NOT RUN; bila modul tidak lulus, perbaiki bila masih dalam scope integrator, selain itu kembalikan issue kepada pemiliknya dengan bukti.

## Baca
`../../PRD.md` §16 dan keputusan final; `FILE_OWNERSHIP.md`; `INTEGRATION_CONTRACT.md`; `DEVELOPER_1_TASK.md`–`DEVELOPER_3_TASK.md`; ketiga laporan; GitHub PR descriptions/diff/CI; source aktual di touched paths.

## Pekerjaan / urutan
1. Cocokkan touched paths tiap PR dengan ownership; selisih yang tidak dicatat pada laporan menjadi temuan yang harus dijelaskan, bukan kegagalan otomatis.
2. Review API/JSON/import/serializer/state semantic bersama, terutama auth → event/category → order; periksa integration contract.
3. Jalankan backend tests/check/format, Flutter analyze/test, API-mode no-fallback test dan sync-config; tulis status setiap command.
4. Jalankan integration test DB hanya jika ada dedicated non-production test DB dan opt-in harness; tanpa itu catat NOT RUN. Jangan seed atau melakukan mutasi data sungguhan.
5. Verifikasi smoke static/click-flow available; catat fitur belum E2E.
6. Perbaikan hanya pada test files integrator yang tercantum di `FILE_OWNERSHIP.md`. Bug di modul dikembalikan kepada owner; tidak rewrite fitur.
7. Isi laporan validasi dan usulkan merged commit sebagai baseline hanya jika semua acceptance PASS dan PRD blockers resolved.

## Boleh / dilarang
Boleh: integrator-owned report/tests only. Dilarang: implementasi feature, schema/migration/SQL/seed/config DB, global routes/router, files owned D1–D3. Jangan seed atau mengakses/memutasi database pengguna/remote. Peran ini bukan penanggung jawab FINISHING dan tidak memberikan otoritas database. Lihat `../FINISHING_AUTHORITY.md`.

## Kriteria lulus
Semua PR file-scope patuh; no unresolved contract mismatch; tests relevant PASS (skip/NOT RUN explained); known blocker tidak disamarkan; demo claim dibatasi bukti; baseline merge tercatat.

## Format laporan
Ringkas PR/commit; file ownership result; contract matrix; checks PASS/FAIL/BLOCKED/NOT RUN; defects dan owner handback; perubahan D4; residual risks; keputusan baseline (GO/NO-GO).