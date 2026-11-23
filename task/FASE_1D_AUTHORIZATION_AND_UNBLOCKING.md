# Fase 1D — Authorization Resolution & Scope Unblocking

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


- **PRD aktif:** [`../PRD.md`](../PRD.md) v2.2.
- **Snapshot kerja:** branch `update/featur`, HEAD `24d18e248b6550483e162f7484e1eab8e43bec17`.
- **Status:** **BLOCKED — tidak ada persetujuan produk/technical-owner/baseline baru yang tercatat sejak Fase 1C.** Dokumen ini memetakan status izin, bukan pengganti tanda tangan.
- **Batas:** tidak mengubah source, API, schema, migration, SQL, seed, konfigurasi DB, dokumen lain, atau state Git. Tidak ada persetujuan pemilik yang diasumsikan.

## 1. Otoritas dan persetujuan yang terbukti

Hierarki requirement mengikuti keputusan produk terbaru yang disetujui dan PRD aktif. PRD v2.2 mencatat aturan produk yang dikonfirmasi dan C-01–C-03/expiry/cancellation sebagai OPEN. `task/FASE_1C_AUTHORIZATION_REGISTER.md` sendiri menyatakan approval pemilik dan technical owner masih pending serta kotak approval baseline kosong. Tidak ditemukan bukti baru berupa identitas approver, tanggal, keputusan bertanda tangan, technical contract approval, atau gate release sejak snapshot Fase 1C.

Karena itu:

- **Product decisions explicitly CONFIRMED in PRD v2.2:** guest/public registration; tidak ada akun Participant atau manual/assisted; satu item/tiket/attendee per order dan repeat orders saat pendaftaran terbuka; harga order snapshot; simulasi payment berbayar; free issue setelah validasi; paid issue setelah PAID; ticket categories event sama-sama gratis atau berbayar; nominal Rp5.000 dan 5% saja.
- **Product decisions still OPEN:** C-01 formula/pihak fee dan commission; C-02 guest authorization untuk order status/payment simulation; C-03 subscription/entitlement; order expiry; cancellation; responsive acceptance threshold teknis belum disahkan.
- **No technical-owner authorization found:** proposed G-01–G-10/API contracts, ownership amendments, router owner, form storage contract, DB proposal acceptance, and baseline release.
- Rekomendasi yang dicatat di Fase 1C/1D bukan approval. Perubahan status register hanya dapat dilakukan setelah bukti persetujuan ditambahkan oleh pihak berwenang.

## 2. Product Decision Register

Pilihan di bawah ini **bahan keputusan**, bukan opsi yang sudah dipilih.

| ID | Requirement PRD | Pilihan/dampak | Scope terdampak | Rekomendasi AI (non-binding) | Approval pemilik | Status |
|---|---|---|---|---|---|---|
| C-01 fee/commission | `PRD.md` §§8.1, 13(11), AC-06. Rp5.000 dan 5% confirmed; formula tidak. | Fee dapat ditambahkan ke tagihan atau dipotong dari payout; basis komisi, free order, rounding, paket dan cancel mengubah total/net/ledger. | D3 T1 order/payment; D2 T3 payment display; Admin/revenue/export; DB hanya jika accounting snapshot/schema perlu. | Sebelum implementasi, tetapkan basis, liable party, free treatment dan rounding; pertahankan nominal confirmed. Jangan infer dari kode. | Belum ada nama/keputusan/tanggal/evidence. | **OPEN** |
| C-02 guest authorization | `PRD.md` §§2, 8.2, AC-06. Guest tanpa akun confirmed. | Guest token boleh menjadi authority terbatas untuk read/status/simulate; atau simulasi perlu mekanisme lain. Tidak boleh mengubah guest menjadi akun wajib tanpa approval. | D3 T1; D2 T3; backend order/payment/security contract. | Jika token dipilih, order-scope, entropy, hash at rest, rate-limit, replay/abuse controls dan log redaction; keputusan authority tetap milik owner. | Belum ada nama/keputusan/tanggal/evidence. | **OPEN** |
| C-03 plan/entitlement | `PRD.md` §8.1, §13, AC/Admin monitoring. | Subscription gate wajib, katalog non-blocking, atau penundaan scope (perlu approval jika mengubah MVP); harga/interval/limits/entitlement harus ditentukan jika dipakai. | Billing/plan UI/API/Admin; jangan blokir order/auth/event yang tidak depend padanya. | Jangan membuat paywall atau angka; selesaikan hanya setelah owner menetapkan scope dan entitlement. | Belum ada nama/keputusan/tanggal/evidence. | **OPEN** |
| OD-04 order expiry | `PRD.md` §§8, 13(4), G-09 | Durasi/anchor/hold release perlu dipilih; kode 24 jam bukan keputusan. | D3 T1, kuota D2, status payment/ticket. | Definisikan anchor, state transitions, races dan expiry order vs payment secara eksplisit. | Belum ada. | **OPEN** |
| OD-05 cancellation/refund | `PRD.md` §§8, 13, C-01. Actual refund bukan MVP; payment status simulasi bukan refund. | Aturan cancel unpaid/paid, release hold, fee handling dan refund uang nyata adalah hal berbeda; actual refund memerlukan scope approval tersendiri. | D3 T1; D2 scanner eligibility; Admin/report; possible FINISHING. | Pisahkan state machine; jangan implement actual refund atau menafsirkan `CANCELLED` sebagai refund. | Belum ada. | **OPEN** |
| OD-06 responsive threshold | `PRD.md` §11, G-10, AC-10 | Technical owner menetapkan browser/device/viewports, atau penerimaan tetap kualitatif narrow/wide dengan evidence aktual. | Seluruh UI/Integration T3. | Mulai dengan exploratory evidence dan catat ukuran aktual; jangan mengubah angka menjadi product requirement tanpa signoff. | Technical owner belum memberi target/evidence. | **OPEN TECHNICAL DECISION** |

Tidak meminta ulang keputusan CONFIRMED di PRD. Keputusan OPEN memblokir hanya task/acceptance yang bergantung padanya.

## 3. Technical Contract Register

Status setiap entry contract di bawah **PROPOSED / NOT AUTHORIZED** kecuali kolom evidence menunjukkan approval (saat ini tidak ada approval terlampir).

### G-01 — single-ticket / no-assisted

- **Contract target:** satu event, satu ticket type, quantity=1, satu attendee dan self-service per order; backend memvalidasi harga/availability/idempotency; order terpisah dapat diulang selama registrasi terbuka; harga order tetap.
- **Compatibility:** API request dapat ditolak pada app/API layer, tetapi SQL/schema masih mengizinkan quantity lebih dari satu dan assisted. Kolom/enum legacy tidak boleh dihapus oleh D1–D3. DP-01 belum disetujui.
- **Owner:** D3 untuk order code di allow-list; D1–D3 tidak memiliki schema/migration. FINISHING owner belum ditunjuk/otorisasi.
- **Test:** multi-item/qty 0/2/attendee mismatch/assisted reject; price tampering; idempotency; repeat separate order; historical multi-quantity read compatibility; quota concurrency.
- **Approval:** technical owner/maintainer belum tercatat. **BLOCKED** untuk full acceptance.

### G-02 — event lifecycle

- **Contract target dari PRD:** Draft → server validation; invalid tetap non-public dan beri actionable errors; valid auto-published tanpa Admin pre-approval; Admin suspend pascapublikasi dengan reason/audit; suspended tidak menerima order baru.
- **Legacy conflict:** `submit-review`, `PENDING_REVIEW`, `APPROVED`, moderation function dan checkout status filter masih ada. Existing route/status/API/database behavior tidak dapat diganti oleh D2 tanpa approval dan ownership perubahan.
- **Owner:** D2 untuk file event-domain dalam allow-list; routes/admin metrics shared dan DB memerlukan owner/amendment/FINISHING bila diperlukan. Technical approval G-02 belum ada.
- **Test:** validation/public visibility; no approval step; suspend reason/audit; event-scoped owner/Admin; order rejected after suspend termasuk concurrency; legacy state mapping.
- **Approval:** **BLOCKED** untuk lifecycle implementation/acceptance; independen event CRUD audit bisa hanya dilakukan setelah baseline/contract signoff.

### G-04 — Staff invitation/deep-link

- **Contract target:** invite event/email-scoped; accept authenticated matching email; pending/nonexpired/nonrevoked token; create membership + permissions; scanner route memakai event id dan server rechecks permission; invalid flow tidak membocorkan token.
- **Backend evidence:** invitation create/list/revoke/accept tersedia; token di-hash, email diperiksa, permission disalin. Default 7 hari adalah implementasi invitation, bukan expiry order decision.
- **Owner:** D1 T2 invitation backend/UI; D2 T2 scanner; `apps/lib/app_router.dart` dan platform deep-link config locked/tidak ada owner pada allow-list. Fase 1C mengusulkan D1 sebagai router owner, tetapi tidak ada amendment/approval signed.
- **Test:** token invalid/expired/revoked/reused, mismatched email, unauthenticated, duplicate/parallel acceptance, permission missing, cold/warm link login→accept→scanner, server denial.
- **Approval:** owner router **belum ditetapkan**; redirect acceptance **BLOCKED** sampai maintainer menyetujui satu owner dan allow-list amendment.

### G-05/G-08 — QR, payment eligibility, ownership

- **Contract target:** QR opaque tanpa PII; server validates ticket/event/payment/permission; check-in online, atomic satu kali. Guest order token hanya order-scoped dan **tidak** otomatis menjadi authority payment (C-02 OPEN).
- **Risiko/evidence gap:** source memiliki token hash/HMAC namun ini bukan keseluruhan security evidence; jalur verify vs check-in perlu test eligibility seragam; offline sync endpoint ada tetapi bukan MVP acceptance.
- **Owner:** D2 T2 scanner; D3 T1 guest/order; `ticketTokenService.js` harus mempunyai satu owner per tahap dan file berada di D2 T2 sesuai tabel. Shared security contract belum disetujui.
- **Test:** token forged/other-ticket, wrong event, unpaid/free eligibility per PRD, revoked/used, unauthorized/no permission, duplicate/concurrent, guest A vs B, JWT owner, log redaction, offline path cannot yield MVP success.
- **Approval:** security reviewer/technical owner belum dicatat. **BLOCKED** untuk security sign-off; C-02 tetap OPEN.

### G-06 — attendee/export

- **Contract target:** endpoint attendee mengeluarkan authorized event rows, payment/order state dan stable original order/registration number; paid-first, deterministic tie-break, layar dan export memakai row set/order yang identik.
- **Current:** attendee endpoint/controller D2-owned; controller mengurutkan purchase time dan tidak membuktikan order number/paid-first. Export endpoint belum dibuktikan.
- **Owner:** D2 eksklusif `checkInController.js`; D3 UI/export pada own paths; D3 tidak mengubah D2 endpoint. D3 uses frozen response and files an interface request if insufficient.
- **Test:** state mapping, original number stays same after payment transition, paid-first, deterministic ties, tenant/role filters, UI/export row equality, CSV escaping/privacy.
- **Approval:** endpoint schema/payload/privacy fields belum disetujui. Export acceptance **BLOCKED** sampai D2/maintainer menetapkan contract; ownership tidak shared.

### G-07 — dynamic form / brochure / ticket template

- **Contract target proposed:** field schema has stable id/type/label/required/options/validation; public response exposes config, submit uses field-id keyed answers; backend returns field-specific validation errors. Brochure storage and template ids need persistent API contract.
- **Current:** `attendee_fields`/`poster_url` exist; not proof of typed form schema, upload, validation, or template persistence.
- **Owner:** D1 T3 form UI; D2 T3 public renderer; shared API/model/storage owner **not assigned**. No developer may invent endpoints or claim local-only persistence.
- **Test:** config save/load, required/type/options validation server-side, stale config, unauthorized owner, renderer mapping/error; brochure file constraints/access only if approved; template id persistence/render.
- **Approval:** contract and owner not assigned; **BLOCKED** for persistence/E2E acceptance.

### G-09/G-10 — expiry/email/retry/responsive

- Expiry duration and cancel behavior remain product OPEN; 24-hour implementation is not authorization. Separate pending/paid/failed/expired/cancelled/refund transitions and tests.
- Email JSON transport means local rendering, not delivery; SMTP sandbox evidence is required to claim sent. Retry pending/failed/sent with idempotency and authorization.
- Responsive product requirement is qualitative narrow/wide; numeric browser/viewport matrix is technical OPEN. Device/viewport observations must record actual environment; do not promote recommendation to binding acceptance.
- Owners: D3 T1 order/payment; D2 T2 eligibility; relevant UI owner; integration lead for cross-platform evidence. Approval for expiry/cancel policy/target matrix absent.
- **Status:** **BLOCKED** for normative expiry/cancel and numeric viewport acceptance; testing exploratory only until target approval.

## 4. Database proposal authorization status

| Proposal | Can satisfy through application/API without DB? | Data/migration risk | Current disposition |
|---|---|---|---|
| DP-01 quantity/assisted | Possibly, if every write path is proven to pass through validated API and SQL function rejects via API caller. This has not been proven for all DB callers. | Existing multi-item/quantity/assisted rows may exist; no inventory performed. | **Conditional FINISHING backlog proposal; not approved.** Prefer app/API validation if sufficient, but all write paths and data compatibility need proof. |
| DP-02 event lifecycle | Existing status values may represent target states; source routes/functions/order filters must be aligned. Whether DB changes are needed is not established. | Existing legacy moderation states/events may exist; no inventory/mapping run. | **No DB change shown necessary yet; not approved.** Technical owner must first freeze transition/API contract and check all gates. |
| DP-03 free/paid and ticket issuance | Homogeneity may be enforced in app/API, but concurrent writes and atomic ticket issuance may require transaction-level guarantees. Not proven. | Mixed categories and free orders with snapshots may exist; no inventory. C-01 affects free fee semantics. | **Conditional FINISHING proposal; not approved.** No formula change until C-01. |

Semua proposal masih **proposal saja**; pemilik FINISHING/gate/approval/environment belum tercatat.

## 5. Ownership dan entry gate per task

“READY WITH LIMITATIONS” pun mensyaratkan baseline dan technical contract ditandatangani oleh maintainer. Saat dokumen ini pertama disusun tidak ada bukti penandatanganan baseline/technical gate, sehingga tidak ada task yang resmi READY untuk coding.

> **Update 2026-11-20:** maintainer telah memberi approval tertulis untuk **D1 T1
> saja** (baseline `update/featur`@`5413de1`, technical contract auth, lokasi test
> auth, amendment `authMiddleware.js` non-breaking, owner tunggal OR-1…OR-4).
> Instrumen mengikat: `TAHAP_1/FILE_OWNERSHIP.md` → "Amendment A-1" dan
> `FASE_1C_AUTHORIZATION_REGISTER.md` §5. Seluruh baris lain pada tabel di bawah
> **tetap BLOCKED**; approval ini bukan approval C-01/C-02/C-03, bukan approval
> database/FINISHING, dan tidak membuka Tahap 2/3.

| Task | Status saat ini | Scope/owner/allow-list dan batas utama | Dependency & test/evidence untuk membuka |
|---|---|---|---|
| **D1 T1 — Auth/session** | **GO (limited) — disetujui maintainer 2026-11-20** (sebelumnya: BLOCKED — kandidat READY WITH LIMITATIONS) | Tujuan auth/login/logout/me; hanya D1 allow-list T1 + Amendment A-1 (`TAHAP_1/FILE_OWNERSHIP.md`). Tidak C-01–C-03 dependency; tidak mengubah shared API/router/DB. | Baseline `update/featur`@`5413de1` + technical contract GO sudah dicatat; lokasi test disahkan (`apps/test/features/auth/**`, `backend/test/auth_*.test.js`); auth tests valid/invalid/unauthorized/role/logout/no-mock wajib lolos dan dicatat di laporan D1. |
| **D2 T1 — Event/category** | **BLOCKED** | D2 allow-list T1 untuk event controller/serializer/screens. Lifecycle auto-publish/suspend tidak boleh dikerjakan sampai G-02 contract/API/shared owner/disposition disetujui. Routes/DB locked. | Signed G-02 state/response/order gate contract; technical disposition DP-02; cross-owner/category validation/negative tests. |
| **D3 T1 — Order/payment/ticket** | **BLOCKED** | D3 allow-list T1 order/payment/ticket modules only. No DB/schema/migration/SQL. Fee formula, guest payment authority, DB compatibility, atomic free issuance are not authorized. | C-01/C-02 where affected; DP-01/DP-03 disposition and shared API contract; quantity/no-assisted, idempotency, price snapshot, guest ownership, free/paid issue tests; safe DB integration only FINISHING. |
| **D1 T2 — Invitation/membership** | **BLOCKED** | Backend invitation and membership UI allowed files. Router/deep-link is explicitly locked; cannot implement redirect. | Tahap 1 integration GO; maintainer appoints single router owner/amendment; invitation contract/test matrix. |
| **D2 T2 — Scanner/check-in** | **BLOCKED** | D2 scanner/check-in + token-service ownership per T2 allow-list; no DB/schema. Offline sync is not MVP success. | T1 integration GO; security contract/threat review; paid/event/permission/atomic tests; isolated backend integration evidence. |
| **D3 T2 — Attendee/export/Admin/report** | **BLOCKED** | D3 owns `eventMetricsController.js` exclusively in T2 plus its current UI/controllers. D2 owns attendee endpoint; D3 consumes only frozen payload. C-03 blocks only plan-entitlement behavior. | T1 integration GO; D2 endpoint payload amendment/order-number/paid-first contract; export/privacy tests; Admin/report auth/persistence tests. |
| **D1 T3 — Form/template** | **BLOCKED** | UI-only allow-list; no claims of persisted config/template without baseline storage contract. | T2 integration GO; assigned owner and approved form/storage/template contract; persistence reload/validation/widget tests. |
| **D2 T3 — Guest journey** | **BLOCKED** | Guest UI only. C-01/C-02 block affected amount/payment/guest authorization; dynamic form renderer requires frozen payload. | T2 integration GO; relevant product decisions and API contract; no-fallback, order/ticket states and responsive tests. |
| **D3 T3 — Runbook/smoke evidence** | **BLOCKED** | Documentation/harness allow-list only; harness read-only, no DB mutation/provider claims. Output files are not present yet. | T2 integration GO; stable demo environment/commands; runbook links and non-destructive tests. C-03 only blocks billing items that depend on it. |

### Acceptance criteria minimum untuk membuka integrasi Tahap 1

1. Product OPEN decisions affecting each row are signed, or explicitly excluded from that row’s scope by owner; no AI assumption.
2. Technical owner signs G-01/G-02 dispositions and frozen request/response/state contracts; DB-dependent part has approved FINISHING backlog disposition and is not falsely marked accepted.
3. Maintainer records shared-file owner/amendments, baseline commit and D1–D3 branch base; review confirms no path overlap and semantic API/data contract alignment.
4. Each D1–D3 report contains changed files, AC mapping, test commands/results and risks; test templates alone are not evidence.
5. Contract/API tests for auth, event public/ownership/category, and order quantity/idempotency/price/guest-negative pass on safe fixtures; any acceptance requiring DB is separately BLOCKED pending authorized safe DB integration.
6. Integrator records GO/NO-GO with CI/baseline evidence. A failed or unavailable required test is not GO.

These criteria **do not authorize implementation now**; owner/maintainer approval is outstanding.

## 6. GitHub baseline disposition

### Wajib masuk baseline publik bila disetujui

`README.md`, `AGENTS.md`, `SKILL.md`, `CONTRIBUTING.md`, `PR_QUALITY_GATE.md`, `PRD.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, active `task/PEMBAGIAN_TUGAS_FINAL.md`, `task/FINISHING_AUTHORITY.md`, all active phase task/ownership/contracts/reports, `task/TECHNICAL_GATE_CLOSURE.md`, `task/PRD_TRACEABILITY_MATRIX.md`, `task/DB_CHANGE_PROPOSAL.md`, `task/FASE_1C_AUTHORIZATION_REGISTER.md`, this Fase 1D register, app/backend manifests/source/tests/workflows and lockfiles.

### KEEP / MERGE / ARCHIVE / EXCLUDE recommendation — pending owner approval

| Local file group | Recommendation | Reason/status |
|---|---|---|
| README, AGENTS, SKILL, CONTRIBUTING, PR quality gate, architecture/database docs | **KEEP** | Active clone/developer/CI instructions. Review links and consistency before stage. |
| PRD.md | **KEEP** | Sole active product requirement source; currently untracked and must be deliberately included. |
| `task/PEMBAGIAN_TUGAS_FINAL.md`, `task/FINISHING_AUTHORITY.md`, active TAHAP_1–3 tasks/ownership/contracts/report templates | **KEEP** | Work controller, ownership, gate and authority baseline; not cleanup candidates. |
| Fase 1B/1C/1D registers, traceability and DB proposal | **KEEP for active authorization/history** | Needed to state gates/decisions/proposals honestly. Owner may later archive once superseded with evidence, not delete now. |
| `task/AUDIT_PROYEK/`, `AUDIT_REPORT.md`, `AUDIT_PEMBERSIHAN_REPOSITORY.md` | **ARCHIVE or KEEP as audit context; owner decision** | Snapshot/historical claims may be stale. They must not override PRD v2.2. Do not merge into PRD blindly. |
| T03 handover/integration reports and prior `task/T03_*` moved copies | **ARCHIVE** | Historical evidence; files presently appear deleted at old tracked paths and untracked at archive paths. Review rename pairs/history; no deletion or staging by this task. |
| `.env`, `.env.test`, keys/passwords, personal/live DB config/data | **EXCLUDE / must remain ignored** | Not read; ignored patterns verified. Do not publish. |
| `apps/pubspec.lock`, `backend/package-lock.json` | **KEEP** | Tracked dependency reproducibility files. |
| build output/cache/node_modules/.dart_tool/logs/local IDE config | **EXCLUDE / must remain ignored** | Generated/local data, not a clone baseline. |

Current baseline **not approved**: Git tree dirty; there is no explicit owner signoff of the file selection or secret scan of the selected staging set. Do not use `git add -A` without reviewing each path. This phase did not stage files.

## 7. Owner/technical-owner action list

These are approval requests, not assumed decisions:

1. **Pemilik produk:** C-01 formula/party/free fee; C-02 guest authority for status/payment simulation; C-03 plan gate/entitlements; order expiry/cancel policy; respond only to scopes planned to open.
2. **Technical owner/maintainer:** approve/revise G-01/G-02/G-04–G-10 proposed contracts and tests; explicitly decide whether DP-01/02/03 need DB backlog (not implementation); assign single owner for router/deep-link and shared form/storage API; record change in signed/dated amendment.
3. **Maintainer/project owner:** approve baseline file groups and archive pairing; identify baseline commit and phase test environment; authorize D1 T1 independently if desired, after required technical gate and report/test path are signed.
4. **FINISHING authority:** only later, after FINISHING is opened, name the DB owner, approve specific proposals, define review/test environment. No current permission to mutate DB.

## 8. Conclusion

- **Developer 1:** **GO (limited) sejak 2026-11-20.** Maintainer telah memberi approval tertulis: baseline `update/featur`@`5413de1`, technical contract auth Tahap 1, pengesahan lokasi test (`apps/test/features/auth/**`, `backend/test/auth_*.test.js`), amendment `authMiddleware.js` (non-breaking) dan owner tunggal OR-1…OR-4 untuk GAP-1…GAP-4. Scope tetap terbatas pada auth files + tests yang disetujui, tanpa membuka Tahap 2. Instrumen: `TAHAP_1/FILE_OWNERSHIP.md` → "Amendment A-1".
- **Developer 2:** belum boleh mulai lifecycle event/category. Hanya audit read-only yang diizinkan dapat dilakukan setelah baseline task sah; auto-publish/suspend masih memerlukan G-02 contract dan shared/DB disposition.
- **Developer 3:** belum boleh mulai order/payment acceptance. C-01/C-02 terbuka; G-01 dan free-ticket/category atomic behavior memiliki dependency DB/shared API yang belum disahkan.
- **Tahap 1 keseluruhan:** **BLOCKED**, kecuali scope auth D1 yang telah dibuka terpisah oleh approval maintainer 2026-11-20 (baseline `5413de1` + Amendment A-1). Scope D2 (event/category) dan D3 (order/payment) tetap BLOCKED sampai baseline/technical gate masing-masing disetujui; integrasi Tahap 1 tetap menunggu ketiga PR sesuai `TAHAP_1/INTEGRATION_CONTRACT.md`.
- **GitHub:** baseline **belum disetujui**; file selection, archive pairing, dan secret scan staging masih memerlukan owner review.

Fase 1D tetap **BLOCKED**, bukan PASS. Tidak ada persetujuan pemilik atau technical owner baru yang ditemukan/dibuat dalam pemeriksaan ini.