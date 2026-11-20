# Tahap 2 — Developer 3: attendee, export, Admin/report/notification

> **Eksekusi autonomous.** Perintah pemilik proyek ("Kerjakan Developer 3 Tahap 2") sudah merupakan otorisasi implementasi; tidak perlu menunggu Tahap 1 GO atau bukti baseline. Untuk C-03 (plan/subscription/entitlement) pilih interpretasi paling aman dan konsisten PRD, implementasikan bagian yang tidak bertentangan, lalu catat sebagai asumsi. Fitur attendee/export/Admin dikerjakan memakai interface yang direkonstruksi dari kode aktual. Tanpa perubahan database/schema: kebutuhan DB ditulis sebagai proposal FINISHING.

## Tujuan
Lengkapi operasi pasca-registrasi MVP: attendee list paid-first/stable number/export dan Admin monitoring/report surfaces yang authorized and persistent where existing API supports them.

## Kondisi awal
Baca PRD §§2, 7, 10, 12–16; contracts/ownership; baseline; README feature integration limits; source Admin/report/notification and attendee endpoints. Classify existing implementation vs missing before editing.

## Pekerjaan
1. Trace organizer attendee list endpoint/UI and verify paid-first + stable original registration number in visible/exported data.
2. Implement export only in owned paths and only from an agreed payload/interface. Attendee endpoint/controller is D2-owned in this stage; do not edit it. If the payload lacks a stable original order number or paid-first ordering, solve it with the minimum change needed (adapter in D3 paths first, otherwise a minimal documented cross-owner change), record the interface, file, reason and impact in the report, and keep working; safe CSV escaping and synthetic tests apply to the available dataset.
3. Audit Admin accounts/events/transactions/report/suspend and Organizer reports/notifications. Fix only owned controller/screen code for API wiring/error states/persistence where API exists.
4. Do not fabricate backend APIs or in-memory success. Missing endpoint/global route support: implement the minimum required change following existing patterns and document it in the report. Missing DB/schema support: write a proposal in ../DB_CHANGE_PROPOSAL.md, finish every non-DB part, and continue.
5. Add tests for permission denial, sorting/order, export escaping and loading/empty/error/retry.

## Files / dependencies
Only D3 globs in FILE_OWNERSHIP. D1/D2 files (including `eventMetricsController.js` and attendee endpoint/controller), routes/schema/global router/API client are prohibited. Use existing frozen routes/contracts; no waiting for other implementations. C-03 only blocks plan entitlement-dependent acceptance.

## Acceptance/tests
- UI and export same rows, paid-first and stable registration identifiers.
- Organizer cannot see another event; Admin only through server authorization.
- Export safely escapes delimiters/quotes/newlines; no unintended fields.
- UI has correct API/loading/empty/error states and no mock fallback.
- Existing API persistence verified in a focused test; if the database/test environment is unavailable, mark that single check NOT RUN with the specific reason and cover the rest with unit/widget tests. Run tests, report skips.

No unsupported plan/price or notification promises; no delete of unused features. Complete actual-change report.
