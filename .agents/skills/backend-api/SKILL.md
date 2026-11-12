---
name: backend-api
description: Mengembangkan atau meninjau endpoint, middleware, validasi, autentikasi, authorization, QR ticket dan persistence Supabase pada backend Express.
---

# Skill Backend API

Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, route/controller/service terdampak,
`backend/src/config/`, dan migration terkait. Proyek memakai Express CommonJS,
Supabase, JWT; jangan menerapkan pola NestJS/Prisma dari proyek lain.

## 1. Jalur Endpoint
1. Ikuti urutan route → middleware → controller → service/model yang sudah ada.
2. Pertahankan response/error contract yang konsisten.
3. Dokumentasikan perubahan endpoint pada PRD dan interface contract.

## 2. Validasi dan Keamanan
1. Validasi masukan di server. Periksa autentikasi, role, ownership event/tiket,
   dan batas tenant pada setiap pembacaan/mutasi sensitif.
2. Organizer/staff hanya memiliki akses pada event dengan ownership/keanggotaan
   yang sah; role frontend atau hidden button bukan authorization.
3. Kunci service role/JWT secret hanya di backend environment; jangan log token,
   password, QR bearer data sensitif, atau PII. Jangan menaruh rahasia di Flutter.
4. Jangan mengubah skema atau migration tanpa kebutuhan teknis yang disetujui;
   buat perubahan idempotent dan pertimbangkan kompatibilitas bila diperlukan.

## 3. Test dan Integrasi
1. Tambahkan test unit terhadap fungsi murni/helper tanpa panggilan Supabase.
2. Untuk QR/check-in: pikirkan replay/scan ganda dan concurrency.
3. Untuk tiket: order dan pembayaran jaga idempotency serta jangan menyamakan
   simulasi dengan transaksi gateway.
4. Integrasi DB/provider hanya diuji bila environment uji ada.

## 4. Perintah Validasi
Jalankan: `npm test`, `npm run check`, `npm run format:check`.
`npm run lint` adalah alias pemeriksaan syntax yang sama dengan `npm run check`;
tidak perlu menjalankan keduanya.
Dokumentasikan batas integrasi dan hasil.