# Kontrak integrasi — Tahap 2 (operasi event, staff, scanner, admin)

## Baseline dan cara memulai (non-blocking)

Dokumen ini referensi teknis, **bukan gate izin**. Perintah pemilik proyek
(“Kerjakan Developer N Tahap 2”) sudah merupakan otorisasi implementasi. Bila
laporan integrasi Tahap 1 belum GO, template kosong, atau status NOT RUN: jangan
berhenti — periksa kondisi kode aktual, kerjakan scope Tahap 2 yang dapat
diselesaikan di atas implementasi yang tersedia, dan catat asumsi serta dampaknya
pada laporan.

Interface invitation/deep-link, scanner permissions, export dan Admin operations
yang belum tersedia **tidak perlu disepakati lebih dulu**: rekonstruksi kontraknya
dari kode/PRD, atau buat adapter/extension point minimum sesuai pola repository.
Bila acceptance memerlukan perubahan pada app router/global navigation (di luar
allow-list D1–D3), lakukan perubahan minimum yang diperlukan dan dokumentasikan
file/alasan/dampak pada laporan — jangan menandai acceptance sebagai BLOCKED hanya
karena ownership belum diamandemen. Kontrak bersama tidak boleh diubah sepihak
tanpa pencatatan; perubahan schema/migration/SQL tetap wewenang FINISHING dan
dilaporkan sebagai proposal.

## Kontrak umum
Flutter Provider/HTTP/API mode; backend Express CommonJS/PostgreSQL via `pg`.
Schema authority: `backend/prisma/schema.prisma`; Prisma migration set di
`backend/prisma/migrations/`. `backend/supabase/migrations/` berisi SQL legacy
yang fungsi/statusnya tidak boleh diasumsikan sebagai set aktif. JWT Bearer sesuai
auth existing; Staff membership, event scope dan permission diperiksa server-side.
Routes, router, global middleware, schema/migrations/SQL/seed, app Provider root
terkunci bagi D1–D3. Response mengikuti envelope existing; tidak ada mock
fallback. Database proposal dilaporkan untuk FINISHING, lihat
`../FINISHING_AUTHORITY.md`; Developer 4 bukan pemilik DB otomatis.

## Feature boundaries
- Invitation/team API/UI owns invitation lifecycle and membership permission assignment; event-scoped identifiers required. Accept requires authenticated account/email match, valid unrevoked/unexpired token and active membership.
- Scanner/check-in client calls existing online endpoints only. Server determines ticket/payment eligibility, event scope, permission and atomic one-time check-in. Offline sync is outside MVP and must not be offered as MVP success.
- Admin/reports/notifications use only Admin-authorized server paths; no Organizer/Staff privilege inheritance. Every admin suspend action requires reason/audit per approved PRD.
- Export uses exactly the same server-filtered/sorted attendee set as UI; stable registration number and paid-first order. File format/fields follow approved data/privacy scope.
- `backend/src/controllers/eventMetricsController.js` adalah ownership tunggal Developer 3 Tahap 2 karena mencakup Admin moderation dan event summary/sales/overview. Developer 2 memakai endpoint summary/sales baseline secara read-only; tidak mengedit file tersebut. Perubahan endpoint dilakukan oleh owner tunggal dengan perubahan minimum dan dicatat pada laporan developer, bukan menunggu amendment yang harus disetujui lebih dulu.
- Attendee source endpoint berada pada `backend/src/controllers/checkInController.js`, milik Developer 2. Developer 3 hanya mengerjakan presentation/export pada path miliknya dari payload yang tersedia. Jika `registration_number`, PAID-first atau field kontrak belum ada, D3 menyelesaikan bagian yang dapat dikerjakan dari payload yang tersedia, mencatat kebutuhan field pada laporan, dan bila benar-benar diperlukan melakukan perubahan minimum pada endpoint dengan dokumentasi alasan/dampak; jangan memblokir acceptance hanya karena field belum ada.

## Parallel safety and merge
Ownership globs in `FILE_OWNERSHIP.md` are disjoint. D1, D2, D3 start from same Tahap 1 baseline, no sync/merge from each other while implementing. PR contract includes endpoint/JSON/role semantics and fixtures. Merge after ownership + semantic review; D4 only after all PRs. Any genuinely needed change outside the allow-list is made as a minimum documented change (file, reason, impact) in the developer report; only database/schema needs are escalated to FINISHING as a proposal.
