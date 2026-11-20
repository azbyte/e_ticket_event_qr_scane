# Kepemilikan file — Tahap 1

**Mode:** allow-list preferensial (non-blocking); lihat [`../TECHNICAL_GATE_CLOSURE.md`](../TECHNICAL_GATE_CLOSURE.md) dan kontrak Tahap 1. C-01–C-03 dan catatan teknis G-01/G-02 tidak memblokir pekerjaan: acceptance terkait dikerjakan dengan interpretasi paling aman dan konsisten PRD, lalu dicatat sebagai asumsi pada laporan Tabel merupakan globs ownership preferensial: kerjakan path milik sendiri lebih dulu, dan perubahan di luar kolom boleh diperbolehkan bila benar-benar diperlukan dengan perubahan minimum yang didokumentasikan pada laporan. Sebelum mulai, diff per PR tetap dihitung ulang terhadap daftar ini untuk mendeteksi tumpang tindih.

| Pemilik | Path yang boleh diubah |
|---|---|
| Developer 1 | `backend/src/middleware/authMiddleware.js`; `backend/src/controllers/authController.js`; `backend/src/services/authService.js`; `backend/src/validators/authValidator.js`; `apps/lib/features/auth/**`; `apps/lib/providers/auth_provider.dart`; tests auth spesifik di `apps/test/features/auth/**`, `backend/test/auth_*.test.js` (buat hanya bila needed) |
| Developer 2 | `backend/src/controllers/eventController.js`; `backend/src/controllers/eventMetricsController.js`; `backend/src/controllers/ticketTypeController.js`; `backend/src/utils/eventResponse.js`; `backend/src/utils/eventSummary.js`; `apps/lib/features/organizer/events/**`; `apps/lib/features/events/**`; tests event/ticket-type spesifik di `apps/test/features/organizer/events/**`, `backend/test/event_*.test.js`, `backend/test/ticket_type_*.test.js` |
| Developer 3 | `backend/src/controllers/orderController.js`; `backend/src/controllers/paymentController.js`; `backend/src/services/ticketTokenService.js`; `backend/src/utils/orderResponse.js`; `apps/lib/features/registration/**`; `apps/lib/features/orders/**`; `apps/lib/features/payments/**`; `apps/lib/features/tickets/**`; tests order/payment spesifik di `apps/test/features/registration/**`, `apps/test/features/orders/**`, `backend/test/order_*.test.js`, `backend/test/payment_*.test.js` |
| Developer 4 (post-merge) | `task/TAHAP_1/LAPORAN_DEVELOPER_4.md`; integration-only tests `backend/test/stage1_integration.test.js`, `apps/test/stage1_integration_test.dart`; no other source unless a predeclared tiny integration defect is approved by owner |

## Dilarang untuk D1–D3
`apps/lib/main.dart`, `app.dart`, `app_router.dart`, `routes/**`, shared `core/**`, app Provider root registration, unrelated providers/services/models; `backend/server.js`, `backend/src/app.js`, `backend/src/routes/**`, `backend/src/config/**`, global middleware, shared error/response/validators, `backend/prisma/**`, `backend/supabase/**`, package/pubspec/lock, CI, global tests, `README.md`, PRD, all task docs besides assigned report. D1–D3 dilarang mengubah atau menjalankan perubahan database apa pun. Kebutuhan DB hanya dilaporkan untuk FINISHING sesuai `../FINISHING_AUTHORITY.md`; persetujuan owner biasa tidak memberi izin edit.

### Collision controls / required caveats
- Named test ownership intersects by prefix; confirm no existing shared test file is edited by two PRs. New tests must remain within respective directory and a single author.
- Event and order both depend on Event/Order API contracts but own distinct file paths. They consume existing serializers/model interfaces only; no shared event/order model changes.
- If required behavior cannot be implemented without locked shared route, provider, schema or config, record exact interface/file, block affected criterion, and return request to maintainer; do not change it. Developer 4 is not automatic schema owner.
- This assignment has no overlapping allow-globs; imports/behavior can still conflict and are reviewed against contract.

## Amendment A-1 — Tahap 1, disetujui maintainer 2026-11-20

Keputusan maintainer (disampaikan sebagai instruksi langsung pada sesi kerja
"Developer 1 — Tahap 1", 2026-11-20) menyetujui blocker **B-1 s.d. B-4** yang
dicatat pada `LAPORAN_DEVELOPER_1.md` Lampiran B. Amendment ini adalah instrumen
tertulis yang dimaksud `../FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md` untuk
menyelesaikan selisih dokumen; tanpa baris ini D1 tetap tidak boleh menyentuh path
terkait.

1. **Baseline & technical contract (B-1): GO.** Baseline Tahap 1 = branch
   `update/featur`, commit `5413de1`. `INTEGRATION_CONTRACT.md` Tahap 1 disetujui
   untuk scope auth D1. Evidence baseline lokal: `backend npm run check` PASS
   (61 file), `npm run format:check` PASS, `npm test` 27/27 PASS,
   `apps flutter analyze` PASS, `apps flutter test` 150/150 PASS.
2. **Lokasi test auth (B-2): DISAHKAN.** D1 boleh membuat, sebagai author tunggal,
   `apps/test/features/auth/**` dan `backend/test/auth_*.test.js`. Test global/existing
   dan direktori test developer lain tetap terlarang.
3. **`backend/src/middleware/authMiddleware.js` (B-3): milik D1, non-breaking saja.**
   Selisih dengan `INTEGRATION_CONTRACT.md` diselesaikan sebagai berikut: D1 boleh
   mengubah file ini **hanya** untuk perubahan non-breaking (tanpa mengubah method,
   path, envelope response, status code, maupun semantik otorisasi). Perubahan breaking
   tetap memerlukan amendment baru.
4. **Owner tunggal OR-1 s.d. OR-4 (B-4): Developer 1**, terbatas pada file dan tujuan
   berikut, hanya untuk menutup GAP-1…GAP-4 Tahap 1:
   - OR-1 `apps/lib/services/auth/auth_service.dart` — mapping request/response auth.
   - OR-2 `apps/lib/core/network/api_client.dart` dan `apps/lib/app.dart` — sinyal
     invalidasi sesi saat 401; tanpa mengubah routing/peran layar di luar kebutuhan
     GAP-2/GAP-4.
   - OR-3 `apps/lib/core/services/session_service.dart` — pemisahan penghapusan
     credential auth dari `order_access_token_*`.
   - OR-4 `backend/src/utils/constants.js`, `apps/lib/models/user/user_role.dart`,
     `apps/lib/models/user/user_model.dart` — penyelarasan kosakata role dengan
     PRD §2; **additif/non-breaking**, tanpa mengubah nilai role yang sudah
     tersimpan di database.
5. **Batas yang tetap berlaku:** tidak ada perubahan schema/migration/SQL/seed atau
   koneksi database (wewenang FINISHING per `../FINISHING_AUTHORITY.md`); tidak ada
   dependency baru; Tahap 2/3 tidak terbuka; `backend/src/routes/**`,
   `backend/src/app.js`, `backend/src/config/**`, Prisma/Supabase, pubspec/lock dan
   CI tetap terlarang bagi D1. Amendment ini tidak mengubah kepemilikan D2/D3.

