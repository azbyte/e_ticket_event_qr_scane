# Fase 1E — Ownership & Execution Ledger

**Status:** baseline rencana/allow-list; bukan persetujuan implementasi. Gate fase
dan task tetap ditentukan oleh laporan integrasi, persetujuan yang tertulis, serta
evidence. Klasifikasi berlaku per tahap; satu file boleh berpindah domain owner
antar tahap hanya sebagaimana dicantumkan dan tidak boleh dimiliki dua developer
pada tahap yang sama.

## Arti klasifikasi

- **OWNED (Dx):** hanya developer tersebut boleh mengubah file pada tahap itu,
  sesuai acceptance dan authorization.
- **READ_ONLY:** developer boleh membaca/bergantung pada kontrak, tidak mengubah.
- **INTERFACE_ONLY:** hanya boleh mengajukan perubahan/request; tidak mengubah
  implementasi atau kontrak tanpa amendment owner tunggal tertulis.
- **DEFERRED:** tidak masuk tahap/allow-list aktif atau menunggu gate/FINISHING;
  tidak diubah oleh D1–D3.

`FILE_OWNERSHIP.md` per tahap adalah allow-list operasional. Ledger ini menjelaskan
konflik lintas tahap/shared paths; bila ada selisih, **hentikan perubahan** dan
minta maintainer menetapkan amendment, jangan memilih satu dokumen diam-diam.

## Tahap 1 — baseline kerja bersama

| File/path | Klasifikasi | Owner / pengguna | Catatan |
|---|---|---|---|
| Auth middleware/controller/service/validator yang tercantum di `TAHAP_1/FILE_OWNERSHIP.md` | OWNED D1 | D1 | Hanya login/register/me/logout/session sesuai PRD/task; shared route/config tetap terkunci. |
| `apps/lib/features/auth/**`, `apps/lib/providers/auth_provider.dart` | OWNED D1 | D1 | Test auth dibuat hanya di allow-list dan bukan test suite global. |
| Event controller, event metrics controller, ticket type controller, event serializers dan event screens yang tercantum di allow-list T1 | OWNED D2 | D2 | Tidak meliputi `backend/src/routes/eventRoutes.js`, global router/provider, schema atau DB. Lifecycle G-02 acceptance tetap BLOCKED. |
| Order/payment controller, order response/token service dan registration/order/payment/ticket features yang tercantum di allow-list T1 | OWNED D3 | D3 | Tidak meliputi route/global API, schema/SQL, shared providers atau DB. C-01/C-02 dan DP dependencies membatasi acceptance. |
| `backend/src/routes/**`, `backend/src/app.js`, middleware/config global, response/error global, Flutter app bootstrap/router/global Provider/API client | INTERFACE_ONLY | D1–D3 read-only; maintainer assigns owner by amendment | Dilarang diedit paralel. Perubahan route/authz/shared payload harus memiliki owner tunggal. |
| `backend/prisma/**`, `backend/supabase/**`, SQL, seed, DB config dan perintah DB mutation | DEFERRED | FINISHING owner only, setelah formal gate | D1–D3 tidak mengubah/m menjalankan mutasi. Proposal di `DB_CHANGE_PROPOSAL.md`. |
| Model/provider/service/widget/test yang tidak disebut allow-list | READ_ONLY atau INTERFACE_ONLY | Tidak ada owner D1–D3 pada T1 | Jika interface tidak cukup: request exact path/API; jangan mengubahnya. |
| Task report masing-masing `TAHAP_1/LAPORAN_DEVELOPER_{1,2,3}.md` | OWNED corresponding Dx | Dx | Hanya isi bukti aktual pekerjaan developer tersebut. |
| `TAHAP_1/LAPORAN_DEVELOPER_4.md`, `stage1_integration.test.js`, `stage1_integration_test.dart` | OWNED Integrator pasca-merge | D4/integrator | Integrasi/test/report only; tidak memberi hak DB atau source domain. |

## Tahap 2 — setelah Tahap 1 integration GO

| File/path | Klasifikasi | Owner / pengguna | Catatan |
|---|---|---|---|
| Invitation controller/organizer profile/membership & staff UI yang tercantum T2 | OWNED D1 | D1 | Router/deep-link global tidak termasuk; lihat G-04 amendment di bawah. |
| `backend/src/controllers/checkInController.js`, scanner/check-in screens, `ticketTokenService.js` sesuai allow-list | OWNED D2 | D2 | Attendee source endpoint berada di controller ini; D3 mengonsumsi frozen response saja. Token architecture DB change tetap proposal/FINISHING. |
| `backend/src/controllers/eventMetricsController.js` | OWNED D3 (eksklusif Tahap 2) | D3; D2 READ_ONLY endpoint | D3 owner karena file memuat Admin moderation sekaligus event summary/sales/overview. Tidak ada shared ownership. Perubahan contract API memerlukan amendment/review. |
| Admin/report/notification controllers & screens yang tercantum T2 selain eventMetrics | OWNED D3 | D3 | Tidak mengubah routes/global config/DB. C-03 hanya menahan entitlement-dependent acceptance. |
| `apps/lib/app_router.dart`, `apps/lib/app.dart`, `apps/lib/main.dart`, platform deep-link configuration | INTERFACE_ONLY — owner BELUM DITETAPKAN | D1/D2/D3 read-only | Fase 1C pernah mengusulkan D1 T2; **belum disetujui**. Maintainer perlu menunjuk satu owner + amend allow-list. Sampai itu, invitation redirect/cold/warm link BLOCKED. |
| `backend/src/routes/**`, `backend/src/app.js`, shared API client/providers/models/services | INTERFACE_ONLY | D1–D3 read-only; owner tunggal melalui amendment | Tidak ada perubahan unilateral atau dua pemilik. |
| Prisma/SQL/seed/DB configuration | DEFERRED | FINISHING owner only | Tidak ada hak DB melekat pada D4/integrator. |
| T2 developer reports | OWNED corresponding Dx | Dx | Evidence dan blocker domain. |
| `LAPORAN_DEVELOPER_4.md`, stage2 integration tests | OWNED Integrator | D4/integrator | Gate report and tests only. |

## Tahap 3 — setelah Tahap 2 integration GO

| File/path | Klasifikasi | Owner / pengguna | Catatan |
|---|---|---|---|
| `event_form_screen.dart`, `qr_ticket_display.dart`, tests yang tercantum T3 | OWNED D1 | D1 | Persisted form/template acceptance tetap BLOCKED sampai interface/storage contract disetujui. No local-only success. |
| Registration, event detail, order/payment/ticket screens/tests yang tercantum T3 | OWNED D2 | D2 | Memakai API/payload frozen; C-01/C-02 dan dynamic form contract hanya memblokir acceptance terkait. |
| `task/DEMO_RUNBOOK.md`, `task/DEMO_CHECKLIST.md`, `demo_smoke.cjs`, `demo_smoke_test.dart`, `demo_contract_smoke.test.js` | OWNED D3 | D3 | Semua belum tersedia pada snapshot sebelumnya; output baru D3. Harness harus read-only/non-destructive, tanpa `.env`/DB pengguna/provider luar. |
| Backend API/model/storage, app router/global client, schema/migration | INTERFACE_ONLY / DEFERRED | No D1–D3 write owner pada T3 | Ajukan amendment/FINISHING proposal; jangan mengarang endpoint atau persistensi. |
| T3 integration report/tests | OWNED Integrator | D4/integrator | Validasi pasca-merge; no DB authority. |

## Shared interface register (pending approval)

| Interface/file | Current owner | Needed consumer | Authorization/action |
|---|---|---|---|
| G-02 lifecycle routes/status + order gate | Existing API route/controller split; no approved shared owner change | D2 event UI + D3 checkout | **INTERFACE_ONLY/BLOCKED.** Maintainer/technical owner signs state/request/response, then assigns one owner per shared file or adjusts phase contract. No D2 unilateral route/status edit. |
| G-04 router invitation deep link → login → accept → scanner | **No owner in active allow-list** | D1 invitation, D2 scanner | **BLOCKED.** Maintainer must approve named single owner and exact router/platform files in an ownership amendment before implementation. D1 is only a proposal, not assigned. |
| G-06 attendee response and export | D2 owns `checkInController.js`; D3 owns UI/export | D3 | D2 endpoint owner freezes stable order number/payment/sort payload; D3 consumes only. If endpoint change needed, amendment naming a single API owner; no shared edits. |
| G-07 form schema/storage and public renderer | No approved shared API/model owner; D1 owns config UI, D2 owns registration UI | D1/D2 + backend | **BLOCKED.** Technical owner defines payload and appoints one shared API/model owner by amendment. Brochure storage/template persistence also need owners. |
| G-01 order/API/DB compatibility | D3 owns order app/API paths in allow-list; database owner deferred | D1/D2 event/category integration; D3 checkout | D3 may propose app-layer validation only within owned files. Any schema/SQL/data invariant goes to FINISHING. Do not claim schema rejects legacy state. |
| C-01/C-02 payment contract | Product decisions OPEN; D3 consumer | D2 T3 checkout UI | Affected payment calculations/guest payment authority **BLOCKED** until product owner decision + backend contract. |
| `eventMetricsController.js` T2 | **D3 exclusive** | D2 may read existing summary/sales APIs | No shared ownership; any changes go via amendment. |

## Database authority (all stages)

| Resource | Classification for D1–D3 | Authorized path |
|---|---|---|
| Prisma schema/migrations, Supabase legacy migrations, SQL, seed, database config, migration commands/mutating SQL | DEFERRED / prohibited | Proposal only in task report; named FINISHING owner may implement only after FINISHING opened, proposal approved, data impact/security/tests/reviewer/environment recorded in `FINISHING_AUTHORITY.md`. |

## Common report/evidence protocol

Each Dx report must include baseline/branch, task/PRD IDs, allowed/touched paths,
API/interface changes, acceptance ID → PASS/FAIL/BLOCKED/NOT RUN + test evidence,
command/output summary, limitations, database proposal (if any), and handoff owner.
Integrator D4 reports cross-module contract, ownership audit, CI/tests/build/E2E
status and GO/NO-GO. D4 cannot change domain source outside its integration-only
allow-list and is not DB owner without formal FINISHING appointment.