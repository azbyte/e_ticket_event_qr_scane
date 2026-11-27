# Fase 1C — Readiness Authorization Register

> **STATUS: REFERENSI TEKNIS / HISTORIS — NON-BLOCKING.** Sejak perbaikan workflow
> autonomous, dokumen ini **bukan lagi syarat izin** untuk mulai bekerja. Seluruh
> status `BLOCKED`, "menunggu approval/persetujuan tertulis", "gate", "baseline
> sign-off", dan "authorization" di dalamnya digantikan oleh *Autonomous Execution
> Protocol* pada [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md): perintah
> pemilik proyek adalah otorisasi implementasi, keputusan teknis diambil mandiri,
> OPEN DECISION dan gate teknis dikerjakan dengan interpretasi paling aman lalu
> dicatat sebagai asumsi, dan BLOCKED hanya untuk hambatan eksternal nyata. Isi
> dokumen dipertahankan sebagai referensi analisis dan kontrak. **Pengecualian:**
> catatan Developer 1 Tahap 1 (baris "GO (limited)" dan Amendment A-1) tetap berlaku
> apa adanya, tidak diubah, dan tidak dikerjakan ulang.


- **PRD:** `../PRD.md` v2.2 (source of product requirements)
- **Snapshot repository yang diperiksa:** branch `update/featur`, HEAD `24d18e248b6550483e162f7484e1eab8e43bec17`
- **Status fase:** **BLOCKED untuk otorisasi implementasi Tahap 1**; kontrak, rekomendasi dan daftar approval siap ditinjau.
- **Batas:** dokumen ini tidak mengubah atau menggantikan PRD. Rekomendasi AI bukan persetujuan pemilik proyek. Tidak ada perubahan source aplikasi/database, operasi DB, penghapusan, staging, commit, push, merge, atau branch change.

## 1. Product Decision Register

Status keputusan: **OPEN** sampai pemilik proyek mengisi keputusan/approval. Kolom “Rekomendasi AI” tidak memiliki kekuatan persetujuan.

| ID | Requirement PRD terkait | Pilihan yang dapat dipertimbangkan (bukan keputusan) | Dampak per pilihan | Scope terdampak | Rekomendasi AI | Keputusan pemilik | Status |
|---|---|---|---|---|---|---|---|
| C-01 — fee & commission | PRD §§8.1, 13 item 11, AC-06; nominal Rp5.000/5% CONFIRMED, formula tidak | A) biaya ditambahkan ke tagihan; B) biaya dipotong dari payout; C) komponen berbeda punya penanggung/dasar berbeda. Perlu putuskan dasar persentase, nominal free order, rounding, relasi paket, pembatalan. | A mengubah total pelanggan; B mengubah net payout; C perlu formula/ledger lebih rinci. Implementasi/source saat ini bukan keputusan. | D3 T1 payment/order; D2 T3 checkout amount display; admin/revenue/report dan FINISHING jika DB/ledger terpengaruh. | Pisahkan subtotal tiket, service fee, commission, total bayar dan net payout dalam keputusan; jangan hitung sebelum pemilik memilih basis/penanggung. | **Belum diisi** | **OPEN** |
| C-02 — guest order/payment authorization | PRD §§2, 8.2, AC-06; guest tanpa akun CONFIRMED | A) guest access token menjadi otorisasi order-scoped untuk read/status dan meminta simulasi; B) JWT/login diwajibkan untuk simulasi tetapi tidak untuk registrasi; C) mekanisme terpisah yang disetujui. Putuskan juga apakah token hanya dapat meminta hasil simulasi terbatas atau tindakan lain. | A mempertahankan guest flow tetapi token bearer berisiko replay/abuse; B menambah friction dan harus dipastikan tidak menjadi syarat memiliki akun Participant; C perlu kontrak/security design baru. | D3 T1 payment/access; D2 T3 guest journey; backend/API owner; security tests. | Jika token digunakan, scope ke satu order, high entropy, server-stored hash, rate limit/log redaction, tidak di URL, dan test cross-order. Ini mitigasi, bukan keputusan otorisasi. | **Belum diisi** | **OPEN** |
| C-03 — plan/subscription | PRD §8.1, §13, AC/Admin monitoring; keberadaan tabel/endpoint bukan entitlement | A) gate paket wajib dalam MVP; B) katalog/admin dapat dikelola tetapi enforcement non-blocking; C) billing/entitlement ditunda (hanya jika pemilik menyetujui perubahan scope/acceptance). Jika A/B dipilih, tetapkan harga, interval, limit, fitur, status/expiry dan hak saat unpaid. | A memengaruhi create/edit/publish event dan admin billing; B membatasi scope; C mengubah MVP acceptance sehingga perlu approval eksplisit. | D3 T2 Admin/report hanya area owned; fitur Organizer plans; backend plans/subscription/API; DB/FINISHING jika perlu. | Jangan membuat paywall/angka dummy; tunda hanya bila pemilik secara eksplisit mengesahkan perubahan scope. | **Belum diisi** | **OPEN** |
| OD-04 — expiry order/payment | PRD §8, §13 item 4, G-09 | A) durasi/anchor expiry eksplisit; B) expiry ditentukan oleh kebijakan event; C) kebijakan lain yang disahkan. Jangan menyimpulkan 24 jam dari controller sebagai produk. | Mengubah waktu pemesanan, kuota held/released, UX retry dan tiket; perlu konsistensi status Order/Payment. | D3 T1; D2 event/ticket availability; DB transaction tests. | Tetapkan anchor dan perilaku reservation release; uji expiry race dengan payment/check-out. | **Belum diisi** | **OPEN** |
| OD-05 — cancel/refund | PRD §§8, 13, 15 C-01 | A) cancel order sebelum paid dengan status/hold release; B) cancellation setelah paid tanpa refund; C) kebijakan refund uang nyata yang terpisah. Refund nyata bukan status simulasi dan bukan MVP menurut PRD saat ini. | State transitions, audit, quota, fee/commission dan laporan berbeda; real refund memerlukan scope/approval terpisah. | D3 T1; D2 T2 check-in eligibility; Admin/report; FINISHING bila persistence berubah. | Pisahkan cancel unpaid, expiry, failed simulation dan actual refund; jangan menambah refund gateway ke MVP tanpa approval. | **Belum diisi** | **OPEN** |
| OD-06 — responsive test target | PRD §11, G-10, AC-10 | A) pemilik teknis menyetujui browser/viewport/device matrix; B) hanya qualitative narrow/wide acceptance tanpa breakpoint numerik. | A menghasilkan ukuran test normatif; B mempertahankan fleksibilitas namun evidence perlu mencatat viewport aktual. | Semua Flutter D1–D3; integration/demo. | Gunakan viewport exploratory sebagai bukti teramati, bukan requirement; minta technical owner menetapkan matrix minimum sebelum sign-off visual. | **Belum diisi** | **OPEN technical choice** |

Aturan yang sudah **CONFIRMED** di PRD v2.2 dan tidak diminta ulang: Participant guest/no account; public registration; no manual/assisted; form Organizer configurable; satu tiket/satu attendee per order; repeat separate orders selama terbuka; payment berbayar simulasi; gratis langsung issue setelah validasi; paid issue setelah PAID; status payment dibedakan; event tidak mencampur ticket category gratis/berbayar; harga pada order terkunci. Refund uang nyata bukan fitur MVP saat ini.

## 2. Technical Contract Register — proposed, approval pending

Kontrak di bawah merumuskan maksud PRD untuk memperjelas task. Kontrak yang menyentuh API/shared file/database **belum diotorisasi untuk implementasi** sampai technical owner/maintainer mengisi approval. Source runtime sekarang tetap berbeda.

### G-01 — order/participant

**Proposed external API invariant:** satu request order hanya satu event, satu `ticket_type_id`, `quantity: 1`, satu attendee object dan self-service; tidak menerima assisted fields/registration. Setiap order terpisah boleh dibuat saat registrasi terbuka. Backend menentukan harga, menyimpan snapshot unit price, memvalidasi event/category/sales/quota dan idempotency. Response mempertahankan order number dan status.

**Compatibility:** controller dapat menolak input multi-item/quantity/assisted tanpa menghapus kolom legacy. Namun SQL function/schema saat ini tetap menerima state lebih luas. Runtime path dan semua function callers perlu dibuktikan; DB-level invariant belum diputuskan. D1–D3 tidak boleh mengubah DB. DP-01 berada PROPOSAL ONLY; owner FINISHING memutuskan apakah DB invariant perlu setelah impact inventory.

**Tests:** valid order 1; quantity 0/2; multi-item; mismatch/multi-attendee; assisted payload; forged price; unavailable/sold-out/time window; replay same key/data; same key/different fingerprint; repeated distinct order; old order readability.

### G-02 — event lifecycle

**Proposed product state contract:** `DRAFT` private → server validation fails: tetap non-public dan mengembalikan error per field; validation passes: auto-public (`PUBLISHED`/`is_public=true`) tanpa Admin approval; published → Admin may suspend dengan reason/audit; suspended event hidden/checkout denied. Unsuspend/reactivation policy tidak ditetapkan oleh PRD ini dan tetap perlu keputusan/technical approval. `PENDING_REVIEW`/`APPROVED`/`REVISION_REQUESTED` legacy bukan langkah target MVP bila berlawanan dengan PRD.

**Order/publication coupling:** public list/detail dan checkout harus memakai kondisi Published yang sama; suspend harus mencegah order baru secara server-authoritative, termasuk race dengan checkout. Tidak ada perubahan route/state DB yang disetujui dalam register ini. Existing `POST /events/:id/submit-review` dan Admin moderation route adalah shared contract surfaces; D2 tidak boleh mengubah route/schema sendiri. Technical owner harus memilih apakah endpoint lama dipertahankan dengan semantics baru atau dibuat contract amendment/version.

**Tests:** invalid stays private; valid auto Published; public list/detail match; no Admin approval required; suspend reason/audit; suspended cannot order; concurrent suspend/order; cross-owner/admin authorization; legacy state migration/backfill review bila diperlukan.

### G-04 — invitation/deep-link

**Proposed API/interface:** create invitation returns event scope, invited email, permissions, expiry/status and a one-time opaque link/token. Accept requires authenticated account with matching email, pending/unexpired/unrevoked token and is idempotent/atomic; response returns event id/title and effective permissions. Flutter handles `/invite/{token}` for cold and warm start; if unauthenticated, retains token securely across login, calls accept, then routes to event-scoped scanner; errors do not leak token and offer safe return/retry. Server rechecks membership/permission on every scanner operation.

**Proposed owner amendment (not approved):** D1 Tahap 2 owns invitation backend and staff-management UI within current globs; D2 owns scanner/check-in UI/backend. App-global `apps/lib/app_router.dart`/deep-link configuration has no D1–D3 owner and is locked. Recommend maintainer appoint a **single router integration owner** (suggestion: D1 Tahap 2 with explicit amendment, if maintainer approves) for router/platform link handling; until signed, this scope remains BLOCKED. Do not represent this suggestion as assignment/approval.

**Tests:** event/email/permission scope; wrong-email; missing login; invalid/expired/revoked/reused token; parallel acceptance; member revoked; no scanner permission; cold/warm link → login → accept → event scanner; no bearer token in logs.

### G-05/G-08 — QR/guest/security

**QR/check-in contract:** opaque ticket token carries no PII; token-to-ticket and order/payment eligibility checked by server; event ownership/membership/permission checked server-side; no success offline; valid online ticket can be checked in once atomically; duplicate/wrong-event/unpaid/invalid/revoked/unauthorized denied. Token display/hash presence alone is not a security proof.

**Guest order contract:** order token may only address one guest-owned order/ticket. It does not automatically authorize payment simulation; that authority remains C-02. Tests must separately assert order read, ticket read, payment read, simulate-payment operation, cross-order access and JWT owner access. Never treat C-02 as check-in authorization.

**Tests:** forged token; correct token against wrong ticket/order/event; paid/free eligibility according to approved product contract; unpaid/expired/failed; duplicate/concurrent scan; wrong/no event permission; guest A vs B; JWT role/owner; replay/rate limiting; sensitive token redaction; offline API cannot yield accepted MVP check-in.

### G-06 — attendee/export

**Proposed boundary:** D2 Tahap 2 exclusively owns backend attendee endpoint (`checkInController.js`). D3 Tahap 2 exclusively owns attendee UI/export within its allow-list. Endpoint contract should return event-scoped authorized rows including immutable `order_number` as the PRD registration identifier, payment/order state, ticket/attendee fields permitted by privacy rules and stable sort keys. D3 may apply/export **exactly the same row set and canonical ordering**; D3 must not edit D2 endpoint or `eventMetricsController.js`.

**Ordering:** PAID first, then original stable registration/order number; define deterministic tie-breaker in a signed technical contract (recommend order number then ticket id, not approved yet). Current attendee endpoint sorts purchase time descending and lacks proven order number/paid-first; export route not evidenced. Endpoint amendment and exact field/privacy contract required before this acceptance can GO.

**Tests:** PAID/PENDING/EXPIRED/CANCELLED/free classification after product status policy; payment transition leaves order number unchanged; tied sort deterministic; filter/authorization scope; export rows equal UI rows and sort; CSV quotes/delimiters/newlines; no unapproved PII.

### G-07 — dynamic form/brochure/template

**Proposed form contract:** persisted configuration includes stable field id, type, label, required flag and type-specific options/validation. Public event response supplies that versioned configuration; public submission returns answers keyed by field id; backend validates against current approved event config and responds with field-level errors. D1 owns Organizer form UI; D2 owns public renderer; shared API/model owner must be assigned by maintainer before contract change. Existing `attendee_fields` array alone does not establish this contract.

Brochure is optional in PRD but upload/storage/security/metadata/read access lack a proven contract. Ticket template/default selection and persisted identifier also lack evidence. D1 may present only existing persisted values; no local-only success or fake upload. Recommend separate assigned backend/storage owner in a future authorized stage; not currently assigned.

**Tests:** config round trip/reload; supported/unsupported field type; required/malformed/unknown fields; unauthorized organizer; stale form version; upload MIME/size/ownership/public read if approved; template id round trip and issued ticket render.

### G-09/G-10 — expiry/email/responsive

- Order/payment expiry: product duration/anchor is OPEN; controller’s 24-hour value is implementation, not product approval. Do not set acceptance deadline until decision or explicit technical policy approval. Cancel, failed simulation, expiry and actual refund are distinct.
- Email: `disabled` and JSON transport do not prove delivery. Only approved test SMTP sandbox can evidence actual delivery. Retry tests cover pending/failed/sent, idempotence, attempts, authorization and truthful status.
- Responsive: PRD mandates usable narrow/wide layouts but not pixel values or browser list. Technical owner may approve a test matrix. Suggested exploratory points (e.g. narrow phone / tablet / wide desktop) are recommendations only, not normative thresholds until signed.

## 3. Database proposal disposition

| Proposal | PRD necessity | Can app-only satisfy behavior? | Legacy data impact | Migration | Test | Disposition now |
|---|---|---|---|---|---|---|
| DP-01 quantity/assisted | Order API behavior must satisfy single item/attendee and no assisted. | **Potentially yes for public API behavior**: controller can reject invalid requests and never emit assisted flow; schema legacy columns can remain. Direct SQL callers and all write paths have not been exhaustively proven; DB constraints would be defense-in-depth, not automatically required by PRD. | Multi-item/quantity>1/assisted historical rows may exist; no inventory run. Do not delete/coerce. | **Not authorized/not yet proven strictly required.** Retain DP-01 in FINISHING backlog as conditional hardening/compatibility review. | API boundary rejection + all callers audit; if DB invariant approved later: historical inventory, migration compatibility, old/new fixtures, rollback. | **CONDITIONAL PROPOSAL; no approval to implement.** Can be removed from DB backlog only after technical owner proves all writers pass API guard and accepts no DB invariant. |
| DP-02 event lifecycle | Auto-publish/suspend behavior is explicit PRD. | **Possibly**, using existing enum values `DRAFT/PUBLISHED/SUSPENDED`, `is_public`, current admin moderation tables/functions and order checks, but shared route/function behavior must align. No new column clearly required from current evidence. | Legacy moderation states and existing events may exist; map/read-only inventory required before transition decisions. | **No migration demonstrated necessary yet.** Existing enum includes target statuses. Function/route SQL implementation still requires review and tests; do not assume no DB need until confirmed. | State transition/API tests; suspend/order race; existing state inventory on safe copy; SQL function regression and schema diff if database scope later approved. | **No DB change authorized; FINISHING review conditional if source changes need function/migration.** |
| DP-03 free/paid homogeneity/free issuance | Product behavior is explicit PRD. | **Potentially not safely via non-atomic app checks alone** under concurrent category updates/orders; SQL transaction may be needed to preserve event-wide homogeneity and atomic free issue. Runtime API may enforce if all writes serialized/locked, not proven. | Existing mixed-price events/orders/tickets and zero-total/service-fee snapshots may exist; not inventoried. | **Possible**, not proven mandatory. Needs product C-01 for fee treatment of free orders before formula/payment changes. | Mixed category create/update under concurrency; free order exactly-one ticket/no paid payment; paid failed/expiry no ticket; transaction rollback/quota; historical compatibility. | **OPEN conditional FINISHING proposal.** No implementation until event data impact, atomicity analysis and C-01 dependency are resolved. |

Rules: none of these dispositions is approval; no schema/migration/SQL/seed/config was modified or executed. FINISHING can only consider a proposal after its explicitly named owner, stage gate and test environment are approved.

## 4. Ownership amendment register

`eventMetricsController.js` has one exclusive Tahap 2 owner: **Developer 3**, because the controller includes Admin moderation as well as event metrics. D2 consumes existing summary/sales APIs read-only. Attendee endpoint `checkInController.js` is **Developer 2**; D3 consumes its approved payload and owns UI/export only. No shared ownership.

App router/deep-link: proposed amendment is D1 Tahap 2 as sole owner for `apps/lib/app_router.dart` and app/platform link configuration, while D1 retains invitation backend/membership and D2 retains scanner. **Pending maintainer approval; current allow-list does not include it, so D1 must not edit it yet.** If not approved, maintainer/integrator must name another single owner; no D1–D3 implementation can start for redirect acceptance.

Shared form-schema/API/storage and ticket-template persistence: **no owner assigned in current allow-lists**. Product areas D1 (config UI) and D2 (public render) are not ownership of the shared backend interface. Maintainer must appoint one interface/API owner by written amendment or keep those acceptance rows BLOCKED.

## 5. Development Entry Gate — owner authorization still required

| Scope | Status now | READY criteria / limitation |
|---|---|---|
| D1 T1 auth/session | **GO (limited) — approved 2026-11-20** (sebelumnya: BLOCKED → candidate READY WITH LIMITATIONS) | Product C-01–C-03 are irrelevant to auth. Baseline + technical gate ditandatangani maintainer; test ownership/path disahkan. Cannot alter shared router/API or DB and cannot open T2. |
| D2 T1 event/category | **BLOCKED** | CRUD validation can be separately scoped, but event lifecycle acceptance cannot GO until G-02 status/public/order contract, shared route owner/amendment and DB disposition are signed. Existing routes source contradicts PRD. |
| D3 T1 order/payment/ticket | **BLOCKED** | Single-item API logic is a possible app-only path, but current SQL/schema allow wider data; DP-01 conditional review needed. Payment steps blocked by C-01/C-02 and guest authorization. Free-ticket AC and same-event category homogeneity need an approved atomic contract (DP-03). |

**Keputusan maintainer 2026-11-20 (baris D1 T1).** Owner/approver: maintainer
proyek (keputusan disampaikan sebagai instruksi langsung pada sesi kerja
"Developer 1 — Tahap 1"). Scope yang disetujui: baseline branch `update/featur`
commit `5413de1`; technical contract Tahap 1 untuk scope auth; pengesahan lokasi
test `apps/test/features/auth/**` dan `backend/test/auth_*.test.js`; amendment
`authMiddleware.js` (non-breaking); owner tunggal OR-1…OR-4 untuk menutup
GAP-1…GAP-4. Evidence: hasil check lokal pada baseline tersebut
(`npm run check`, `npm run format:check`, `npm test` 27/27, `flutter analyze`,
`flutter test` 150/150) sebagaimana dicatat di
[`TAHAP_1/LAPORAN_DEVELOPER_1.md`](TAHAP_1/LAPORAN_DEVELOPER_1.md). Rincian
mengikat ada di `TAHAP_1/FILE_OWNERSHIP.md` → "Amendment A-1". Baris D2/D3 **tidak**
berubah dan tetap BLOCKED; keputusan ini bukan approval C-01/C-02/C-03, bukan
approval database/FINISHING, dan tidak membuka Tahap 2.


AI cannot turn these into GO by recommendation. Required signatures/entries:

- Product owner: decisions C-01/C-02/C-03 and expiry/cancel policy only when corresponding scope is to open.
- Technical owner/maintainer: G-02 lifecycle/API contract, DP-01/02/03 disposition, owners for shared router and form/storage API, same baseline and allow-list amendments.
- FINISHING owner: only after FINISHING opened, explicitly approve any DB proposal and safe test scope.

## 6. GitHub baseline approval checklist

Snapshot remains dirty/unpublished. No stage/add/commit/push was performed. Review and approve each group before choosing files for the public baseline.

### Wajib masuk setelah disetujui

- `README.md`, `AGENTS.md`, `SKILL.md`, `CONTRIBUTING.md`, `PR_QUALITY_GATE.md`.
- `PRD.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`.
- `task/PEMBAGIAN_TUGAS_FINAL.md`, `task/FINISHING_AUTHORITY.md`.
- Active phase tasks, ownership, contracts, reports/templates; Fase 1B technical gate, traceability matrix and DB proposal; this authorization register.
- App/backend manifests, source, tests, GitHub workflows/config, and required lockfiles (`apps/pubspec.lock`, `backend/package-lock.json`).
- `.env.example` and `.env.test.example` only as safe variable-name templates, after review.

### Optional (pemilik memilih)

- `task/archive/AUDIT_REPORT.md`, `task/archive/AUDIT_PEMBERSIHAN_REPOSITORY.md`, `task/AUDIT_PROYEK/`: snapshot audit, bukan otoritas terbaru.
- `task/archive/` reports/handover. If retained, explicitly historical. T03 source files currently appear as deleted plus untracked archive copies; review rename pairing and history before staging.

### Arsip

- Older reports, prototypes, T03 handover/integration reports, and prior task documents under `task/archive/`. Do not link them as active instructions.

### Tidak boleh dipublikasikan / harus ignore

- `.env`, `.env.test`, credentials, passwords, API/service-role keys, local-only config, user/production data, logs, build output and caches.
- Ignore rules confirmed for `.env`, `.env.test`, `apps/.dart_tool`, `apps/build`, and `backend/node_modules`. Lockfiles remain tracked.
- No secret scan over file contents was performed in this phase; `.env` was not read. Before owner stages, run secret scanning/review of selected files.

**Persetujuan pemilik:** [ ] active baseline list approved  [ ] archive policy approved  [ ] local rename/deletion set reviewed  **Decision/date:** __________

## 7. Final Fase 1C status

- **Technical contract recommendations prepared:** yes.
- **Technical contract authorization by technical owner:** pending.
- **Product decisions C-01–C-03 / expiry/cancel:** remain OPEN; only dependent scopes blocked.
- **DB proposals:** dispositions classified; conditional backlog only, no approval to implement.
- **PRD traceability:** matrix covers product sections/AC and open decisions; no requirement is marked tested/accepted without evidence.
- **GitHub baseline:** approval pending owner’s file selection/sign-off.
- **Tahap 1 overall:** **BLOCKED**. Scope D1 auth is a candidate for limited opening after baseline/technical approval; D2 lifecycle and D3 order/payment remain blocked as described.