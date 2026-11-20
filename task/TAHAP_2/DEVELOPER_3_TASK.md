# Tahap 2 — Developer 3: attendee, export, Admin/report/notification

> Mulai setelah Tahap 1 GO dan baseline dibuktikan. Jangan mengimplementasikan plan/subscription gate atau entitlement baru selagi C-03 terbuka; fitur attendee/export/Admin yang independen boleh dikerjakan memakai interface yang disetujui. No database/routes/shared app routing changes.

## Tujuan
Lengkapi operasi pasca-registrasi MVP: attendee list paid-first/stable number/export dan Admin monitoring/report surfaces yang authorized and persistent where existing API supports them.

## Kondisi awal
Baca PRD §§2, 7, 10, 12–16; contracts/ownership; baseline; README feature integration limits; source Admin/report/notification and attendee endpoints. Classify existing implementation vs missing before editing.

## Pekerjaan
1. Trace organizer attendee list endpoint/UI and verify paid-first + stable original registration number in visible/exported data.
2. Implement export only in owned paths and only from an agreed payload/interface. Attendee endpoint/controller is D2-owned in this stage; do not edit it. If payload lacks stable original order number or paid-first order, submit an interface request and mark export AC BLOCKED until D2/maintainer contract amendment; safe CSV escaping and synthetic tests apply to the available dataset.
3. Audit Admin accounts/events/transactions/report/suspend and Organizer reports/notifications. Fix only owned controller/screen code for API wiring/error states/persistence where API exists.
4. Do not fabricate backend APIs or in-memory success. Missing endpoint/global route/DB support = documented blocker request.
5. Add tests for permission denial, sorting/order, export escaping and loading/empty/error/retry.

## Files / dependencies
Only D3 globs in FILE_OWNERSHIP. D1/D2 files (including `eventMetricsController.js` and attendee endpoint/controller), routes/schema/global router/API client are prohibited. Use existing frozen routes/contracts; no waiting for other implementations. C-03 only blocks plan entitlement-dependent acceptance.

## Acceptance/tests
- UI and export same rows, paid-first and stable registration identifiers.
- Organizer cannot see another event; Admin only through server authorization.
- Export safely escapes delimiters/quotes/newlines; no unintended fields.
- UI has correct API/loading/empty/error states and no mock fallback.
- Existing API persistence verified in focused test or clearly BLOCKED if absent; run tests, report skips.

No unsupported plan/price or notification promises; no delete of unused features. Complete actual-change report.
