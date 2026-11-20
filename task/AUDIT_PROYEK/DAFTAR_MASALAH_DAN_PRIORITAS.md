# Masalah dan prioritas — 20 November 2026

Prioritas menilai kebutuhan MVP dan bukti aktual; status tidak mengubah PRD. P0 memblokir pembagian implementasi/demo, P1 melengkapi alur wajib, P2 risiko/penyempurnaan atau non-MVP.

| ID | Prioritas | Status | Masalah/aksi terukur | Dampak / exit evidence |
|---|---|---|---|---|
| P0-01 | P0 | Perlu Konfirmasi | Putuskan C-01 formula fee/commission, penanggung, free ticket, rounding/refund/cancel | Tidak ada hitung total/net payout tanpa angka/metode yang disahkan |
| P0-02 | P0 | Perlu Konfirmasi | Putuskan C-02 mekanisme guest authorization untuk order/status/payment simulation | Akses owner/replay/unauthorized tests lulus |
| P0-03 | P0 | Perlu Konfirmasi | Putuskan C-03 scope/harga/limit plan-subscription MVP | Entitlement tidak direka oleh engineer |
| P0-04 | P0 | Sebagian | G-01 single-ticket; source menerima/memodelkan quantity>1 dan assisted fields | API menolak quantity !=1 & assisted, tests; DB compatibility migration disetujui |
| P0-05 | P0 | Tidak Sesuai | G-02 source memiliki submit-review/moderation sedangkan PRD auto-publish | Valid auto-published; invalid hidden/actionable; suspend blocked; transitions tests |
| P0-06 | P0 | Sebagian | QR/check-in bearer code; token hash documented unused | Threat review, expiry/replay/atomic/permission tests dan keputusan token storage; belum siap production |
| P0-07 | P0 | Perlu Verifikasi | DB source/migration plural (`backend/prisma` dan legacy `backend/supabase`) | Source-of-truth & applied history diverifikasi read-only pada DB dedicated sebelum schema change |
| P1-01 | P1 | Sebagian | Dynamic form config/render/validation belum terbukti E2E | Public form mengikuti schema; server rejects malformed fields |
| P1-02 | P1 | Sebagian | Staff invite deep-link scanner belum terbukti | Auth email-bound accept dan redirect ke event-scoped scanner, unauthorized denied |
| P1-03 | P1 | Sebagian | Attendee ordering/export belum terbukti | Paid-first, stable number, CSV/Excel output assertions |
| P1-04 | P1 | Sebagian | Several Admin/business/report/notification/scanner operations in-memory/missing API per README | MVP action persisted through backend and reload; otherwise explicit blocker |
| P1-05 | P1 | Belum | API mode Android/Web build and complete E2E with DB not run | Test environment evidence for AC-01–10; no claim from mock tests |
| P1-06 | P1 | Perlu Konfirmasi | Expiry lifecycle and email delivery/retry details; CORS/device URL env-specific | Decisions + integration tests; no invented expiry/email success |
| P2-01 | P2 | Belum | Brochure storage/UI, ticket templates/default rendering not proven E2E | MVP acceptance with safe storage/template after contract |
| P2-02 | P2 | Tidak Relevan untuk MVP | Offline scanner, real gateway, manual registration are out of MVP | Do not implement unless separate approved post-MVP scope |
| P2-03 | P2 | Belum | Unused/duplicate file analysis not conclusive | Build import/caller graph, runtime/route/config verification before separate deletion proposal |

## Git/workflow concerns
- Status awal includes modified/untracked/deleted docs and `PRD.md`; preserve those. Current required task output is documentation-only; do not change app source or DB/config.
- Same branch baseline + disjoint globs reduce file conflicts, not semantic conflicts. PR file list and API contract checks are mandatory.
- PRD §16 blocks implementation until decisions/technical contracts exist. Stage task docs remain **conditional/no coding start** until gate signed by product owner and technical owner.
