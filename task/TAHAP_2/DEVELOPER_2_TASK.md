# Tahap 2 — Developer 2: scanner dan online check-in

> **Eksekusi autonomous.** Perintah pemilik proyek ("Kerjakan Developer 2 Tahap 2") sudah merupakan otorisasi implementasi; tidak perlu menunggu baseline Tahap 1 GO. Scan behavior yang telah ditetapkan dapat diuji pada source/contract yang ada, perubahan token storage/architecture diputuskan sendiri mengikuti pola keamanan yang ada (hash server-side, bearer token tidak ditulis ke log) dan dicatat sebagai keputusan teknis; bila DB terdampak, tulis proposal FINISHING dan lanjutkan bagian lain. Jangan mengubah schema/migration.

## Tujuan
Membuktikan QR scanner online memvalidasi tiket eligible sekali, pada event yang tepat dan hanya untuk actor berizin.

## Kondisi awal
Baca PRD §§2, 9–10, 12–16; Tahap 2 ownership/contract; docs/DATABASE; source ticket/check-in controllers and scanners; tests. Treat sync endpoint as outside MVP; do not extend offline behavior.

## Pekerjaan
Trace camera/scan input → validation endpoint → result/history. Pastikan server checks authenticated Staff/Organizer permissions, event membership/event scope, ticket issued and eligible/paid, duplicate scan, atomic writes and safe error. Implement UI permission/camera/error/loading/success states only in owned paths. Validate QR payload handling without logging bearer token. Add tests for valid, duplicate, wrong event, unpaid/invalid, no permission and concurrency-safe backend where test harness supports it. If token hashing/storage or a route/shared API change is needed, implement the minimum safe version consistent with the PRD and existing patterns, document the decision and its impact in the report, and continue; only schema/migration needs are escalated to FINISHING as a proposal.

## Files / dependencies
Only D2 paths in `FILE_OWNERSHIP.md`; `ticketTokenService.js` is exclusively D2. Do not edit D1 invitation or D3 admin/list, routes/schema/router/global API/dependencies.

## Acceptance/tests
- Valid eligible paid ticket scans once and shows confirmation.
- repeat, wrong-event, unpaid, revoked/unpermitted/unauthorized fail; no success offline.
- No token leakage in logs/UI beyond required scan payload.
- Permission/camera/API denial has retryable accessible state.
- Run focused tests and report NOT RUN live camera/DB if not available.

Do not trust client-supplied event/payment status. Fill report from actual tests; hand back wider defects.
