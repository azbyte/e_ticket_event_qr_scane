# Tahap 2 — Developer 1: staff invitation dan membership

> **Eksekusi autonomous.** Perintah pemilik proyek ("Kerjakan Developer 1 Tahap 2") sudah merupakan otorisasi implementasi; tidak perlu menunggu Tahap 1 GO atau baseline yang diverifikasi maintainer. Kerjakan audit, API invitation, dan deep-link/redirect dalam satu alur. Bila acceptance memerlukan perubahan app router/global navigation di luar allow-list, lakukan perubahan **minimum** yang diperlukan, jaga perilaku navigasi lainnya, dan dokumentasikan file/alasan/dampak pada laporan — jangan menandai acceptance BLOCKED hanya karena owner router belum ditunjuk. Jangan mengubah schema/migration; kebutuhan DB ditulis sebagai proposal di `../DB_CHANGE_PROPOSAL.md`.

## Tujuan
Menyelesaikan onboarding Staff berbasis invitation event-scoped dan UI permission sesuai PRD.

## Kondisi awal
Baca PRD §§2, 6.2, 10, 12, 13, 15–16; Tahap 2 contract/ownership; Tahap 1 baseline dan laporan; source controller invitation, Flutter membership, API client, router (read-only).

## Pekerjaan
Trace create/list/revoke, acceptance email/token validation, membership creation and scoped permission. Perbaiki UI/API handling hanya di owned paths; invitation expired/revoked/email mismatch, revoked membership and missing permission must deny. Acceptance authenticated; display event and outcome. Deep-link acceptance/redirect must use approved link contract; if central router change needed, request designated integration owner. Tests positive and negative synthetic.

## Files / dependencies
Allowed exclusively D1 paths in `FILE_OWNERSHIP.md`; prohibited all shared/locked paths and D2/D3 paths. D1 works in parallel using existing membership endpoints/contract; no dependency on D2 scanner implementation.

## Acceptance/tests
- Invite is for one event/email and permissions; revoke/expiry means acceptance denied.
- User must be logged in, matching invited email; acceptance creates only event-scoped membership.
- Organizer cannot manage other Organizer's event; role/user cannot elevate permissions outside approved model.
- No global Staff route/data access; test list and denial states.
- Target tests pass; document deep-link/runtime test limits.

Do not add database fields, routes or role. Fill report from diff and request shared interface changes through issue, not edit.
