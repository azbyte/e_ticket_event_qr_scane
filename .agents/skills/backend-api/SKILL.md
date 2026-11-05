---
name: backend-api
description: Mengembangkan atau meninjau endpoint, middleware, validasi, autentikasi, authorization, tiket QR dan persistence Supabase pada backend Express.
---

# Skill Backend API

Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, route/controller/service terdampak,
`backend/src/config/`, dan migration terkait. Proyek memakai Express CommonJS,
Supabase, JWT; jangan menerapkan pola NestJS/Prisma dari proyek lain.

1. Ikuti jalur route → middleware → controller → service/model yang sudah ada;
   pertahankan response/error contract.
2. Validasi masukan di server. Periksa autentikasi, role, ownership event/tiket,
   dan batas tenant pada setiap pembacaan/mutasi sensitif.
   Organizer/staff hanya memiliki akses pada event dengan ownership/keanggotaan
   yang sah; role frontend atau hidden button bukan authorization.
3. Kunci service role/JWT secret hanya di backend environment; jangan log token,
   password, QR bearer data sensitif, atau PII. Jangan menaruh rahasia di Flutter.
4. Jangan mengubah skema atau migration tanpa kebutuhan teknis yang disetujui;
   buat perubahan idempotent dan pertimbangkan kompatibilitas bila diperlukan.
5. Tambahkan test unit terhadap fungsi murni/helper tanpa panggilan Supabase.
   Untuk QR/check-in pikirkan replay/scan ganda dan concurrency; untuk tiket,
   order dan pembayaran jaga idempotency serta jangan menyamakan simulasi dengan
   transaksi gateway. Integrasi DB/provider hanya diuji bila environment uji ada.
6. Jalankan `npm test`, `npm run check`; dokumentasikan batas integrasi dan hasil.
