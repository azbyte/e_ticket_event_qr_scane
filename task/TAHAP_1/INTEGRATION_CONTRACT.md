# Kontrak integrasi — Tahap 1 (fondasi)

## Gate sebelum mulai
PRD `../../PRD.md` §§15–16 adalah gate aktif. Scope yang tidak bergantung C-01–C-03
boleh mulai hanya setelah baseline task yang sama dicatat dan technical contract /
acceptance untuk scope itu disetujui tertulis. C-01–C-03 scoped per acceptance:
D3 order/payment behavior yang memerlukan fee formula atau guest payment
authorization tetap **BLOCKED**; plan entitlement juga menunggu C-03. Jangan
menebak. G-01 DB compatibility dan G-02 lifecycle/route contract harus memiliki
disposition teknis sebelum acceptance terkait dijanjikan. Template/laporan kosong
bukan evidence gate.

## Struktur dan ownership
Stack tetap Flutter Provider/`http`/secure-storage dan backend Express 4 CommonJS,
PostgreSQL via `pg`. `backend/prisma/schema.prisma` adalah sumber schema yang
ditetapkan dan migration Prisma berada di `backend/prisma/migrations/`;
`backend/supabase/migrations/` merupakan SQL legacy yang dipertahankan untuk
fungsi/riwayat tertentu, bukan pengganti baseline Prisma. Fungsi/status legacy
harus direkonsiliasi sebelum dijalankan; jangan hapus atau jalankan tanpa
persetujuan FINISHING. Ownership ada di `FILE_OWNERSHIP.md`; path lain dilarang.
Shared API routes/schema/global router dikunci, bukan perubahan paralel.

## API contracts — existing only
- Auth existing: `/api/auth/login`, `/register`, `/me`, `/logout`; Bearer JWT `Authorization: Bearer <token>`. Body/response ikuti controller+Flutter client saat ini; tidak memperkenalkan refresh/auth flow baru tanpa keputusan.
- Events/categories: `/api/events`, `/api/events/public`, `/api/events/mine`, `/api/events/:id`, `/api/events/:eventId/ticket-types` dan event-scoped CRUD sesuai route aktif. Organizer/Admin bearer sesuai middleware.
- Orders/payment: `POST /api/orders` (guest optional auth), `GET /api/orders/:id`, `/api/payments/:orderId`, `POST /api/payments/simulate`; guest payment authorization tetap OPEN pada C-02. Single-item request wajib ditentukan sesudah audit validator/controller aktual; tidak menambah payload berdasarkan asumsi. Gratis/berbayar dan satu order satu ticket adalah requirement PRD; behavior yang memerlukan DB/API shared file diblokir dan dilaporkan.
- Response mengikuti `successResponse`/`errorResponse`, serializers `eventResponse`/`orderResponse`; JSON fields existing dipertahankan. Validation errors tidak boleh dipetakan menjadi success atau mock fallback.
- Jangan mengubah HTTP method/path, payload, response envelope, status enums, permissions, tabel, migrations, expiry atau hitungan uang tanpa keputusan dan owner database/API tertulis.

## Aturan modul dan kualitas
1. Provider/DTO/service public API, route arguments, named routes, shared widgets dan app bootstrap tidak boleh berubah kecuali maintainer menetapkan owner tunggal dan amendment allow-list/contract tertulis sebelum coding. Persetujuan informal bukan perubahan ownership.
2. Modul tetap independen; imports hanya dari public APIs existing. Tidak boleh circular imports, duplicate client/service, direct database access dari Flutter.
3. Server-authoritative validation, ownership/role, transaction dan errors; secret hanya backend env. Demo/mock hanya explicit; jangan fallback mock saat API error.
4. D1–D3 tidak boleh mengubah atau menjalankan perubahan database apa pun,
   termasuk schema, migration, SQL, seed/config atau perintah mutasi. Catat
   proposal DB untuk FINISHING sesuai `../FINISHING_AUTHORITY.md`; Developer 4
   tidak otomatis berwenang.
5. PR report mendokumentasikan request/response/API/DB proposal, dependencies, tests, known limitations. Breaking/shared contract change memblokir scope sampai owner/maintainer menetapkan amendment dan pihak terdampak menyetujui tertulis; tidak ada perubahan unilateral.

## Urutan dan integrasi
Tiga PR terpisah dari satu base commit; gabung tiap PR hanya setelah review
ownership + contract. Urutan merge 1) auth/access, 2) event/category, 3)
order/payment. D1–D3 tidak melakukan perubahan DB; proposal database mengikuti
otoritas FINISHING terpisah. Integrator memeriksa setelah ketiganya merged dan
hanya bekerja pada file integration-owned. Bug domain dikembalikan kepada pemilik.
Baseline tahap berikutnya adalah commit integrasi GO dengan checks/evidence.
