# Tahap 2 — Developer 2: scanner dan online check-in

> Mulai dari baseline Tahap 1 GO. Scan behavior yang telah ditetapkan dapat diuji pada source/contract yang ada, tetapi perubahan token storage/architecture memerlukan security decision dan, bila DB terdampak, proposal FINISHING. Jangan mengubah schema/migration.

## Tujuan
Membuktikan QR scanner online memvalidasi tiket eligible sekali, pada event yang tepat dan hanya untuk actor berizin.

## Kondisi awal
Baca PRD §§2, 9–10, 12–16; Tahap 2 ownership/contract; docs/DATABASE; source ticket/check-in controllers and scanners; tests. Treat sync endpoint as outside MVP; do not extend offline behavior.

## Pekerjaan
Trace camera/scan input → validation endpoint → result/history. Pastikan server checks authenticated Staff/Organizer permissions, event membership/event scope, ticket issued and eligible/paid, duplicate scan, atomic writes and safe error. Implement UI permission/camera/error/loading/success states only in owned paths. Validate QR payload handling without logging bearer token. Add tests for valid, duplicate, wrong event, unpaid/invalid, no permission and concurrency-safe backend where test harness supports it. If token hashing/storage or route/shared API needed, stop and request a security-approved contract.

## Files / dependencies
Only D2 paths in `FILE_OWNERSHIP.md`; `ticketTokenService.js` is exclusively D2. Do not edit D1 invitation or D3 admin/list, routes/schema/router/global API/dependencies.

## Acceptance/tests
- Valid eligible paid ticket scans once and shows confirmation.
- repeat, wrong-event, unpaid, revoked/unpermitted/unauthorized fail; no success offline.
- No token leakage in logs/UI beyond required scan payload.
- Permission/camera/API denial has retryable accessible state.
- Run focused tests and report NOT RUN live camera/DB if not available.

Do not trust client-supplied event/payment status. Fill report from actual tests; hand back wider defects.
