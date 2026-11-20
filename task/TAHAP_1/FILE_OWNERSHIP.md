# Kepemilikan file — Tahap 1

**Mode:** kondisional per scope; ikuti [`../TECHNICAL_GATE_CLOSURE.md`](../TECHNICAL_GATE_CLOSURE.md) dan kontrak Tahap 1. C-01–C-03 memblokir hanya acceptance yang bergantung padanya; G-01/G-02 dapat memblokir acceptance order/event yang terdampak. Tabel merupakan globs ownership eksklusif. Tidak boleh mengubah path di luar kolom boleh. Sebelum mulai, diff per PR harus dihitung ulang terhadap daftar ini.

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
