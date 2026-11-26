# Kontrak integrasi — Tahap 1 (fondasi)

## Status kontrak dan cara memulai (non-blocking)

Dokumen ini adalah **referensi teknis non-blocking**, bukan gate izin. Perintah
pemilik proyek (“Kerjakan Developer N Tahap 1”) sudah merupakan otorisasi
implementasi; tidak diperlukan persetujuan tertulis tambahan untuk memulai.

Bila kontrak di dokumen ini belum lengkap atau berbeda dari kode aktual,
**rekonstruksi sendiri** dari route/controller/validator/serializer/schema, PRD
`../../PRD.md` §§15–16, dan implementasi terkait, lalu catat hasilnya sebagai
kontrak kerja pada laporan developer. Untuk OPEN DECISION PRD (C-01 formula fee,
C-02 guest payment authorization, C-03 plan/entitlement) dan catatan teknis
G-01…G-10: pilih interpretasi paling aman dan konsisten PRD, implementasikan
bagian yang tidak bertentangan, dan catat sebagai asumsi yang perlu konfirmasi —
jangan menghentikan pekerjaan. Perubahan schema/migration/SQL tetap wewenang
FINISHING dan dilaporkan sebagai proposal, bukan alasan memblokir seluruh task.

## Struktur dan ownership
Stack tetap Flutter Provider/`http`/secure-storage dan backend Express 4 CommonJS,
PostgreSQL via `pg`. `backend/prisma/schema.prisma` adalah sumber schema yang
ditetapkan dan migration Prisma berada di `backend/prisma/migrations/`;
`backend/prisma/legacy-migrations/` merupakan SQL legacy yang dipertahankan untuk
fungsi/riwayat tertentu, bukan pengganti baseline Prisma. Fungsi/status legacy
harus direkonsiliasi sebelum dijalankan; jangan hapus atau jalankan tanpa
persetujuan FINISHING. Ownership ada di `FILE_OWNERSHIP.md`; path lain dilarang.
Shared API routes/schema/global router dikunci, bukan perubahan paralel.

## API contracts — existing only
- Auth existing: `/api/auth/login`, `/register`, `/me`, `/logout`; Bearer JWT `Authorization: Bearer <token>`. Body/response ikuti controller+Flutter client saat ini; tidak memperkenalkan refresh/auth flow baru tanpa keputusan.
- Events/categories: `/api/events`, `/api/events/public`, `/api/events/mine`, `/api/events/:id`, `/api/events/:eventId/ticket-types` dan event-scoped CRUD sesuai route aktif. Organizer/Admin bearer sesuai middleware.
- Orders/payment: `POST /api/orders` (guest optional auth), `GET /api/orders/:id`, `/api/payments/:orderId`, `POST /api/payments/simulate`; guest payment authorization (C-02) dikerjakan dengan interpretasi paling aman dan konsisten PRD, lalu dicatat sebagai asumsi. Single-item request wajib ditentukan sesudah audit validator/controller aktual; tidak menambah payload berdasarkan asumsi. Gratis/berbayar dan satu order satu ticket adalah requirement PRD; behavior yang memerlukan DB/API shared file dikerjakan dengan perubahan minimum pada layer yang diizinkan dan dicatat pada laporan; kebutuhan DB ditulis sebagai proposal FINISHING.
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
5. PR report mendokumentasikan request/response/API/DB proposal, dependencies, tests, known limitations. Breaking/shared contract change dihindari; bila benar-benar diperlukan untuk menyelesaikan task, lakukan perubahan minimum yang menjaga kompatibilitas, catat file/alasan/dampak pada laporan developer, dan sampaikan ke pihak terdampak melalui laporan tersebut (bukan menunggu amendment tertulis).

## Urutan dan integrasi
Tiga PR terpisah dari satu base commit; gabung tiap PR hanya setelah review
ownership + contract. Urutan merge 1) auth/access, 2) event/category, 3)
order/payment. D1–D3 tidak melakukan perubahan DB; proposal database mengikuti
otoritas FINISHING terpisah. Integrator memeriksa setelah ketiganya merged dan
hanya bekerja pada file integration-owned. Bug domain dikembalikan kepada pemilik.
Baseline tahap berikutnya adalah commit integrasi GO dengan checks/evidence.
