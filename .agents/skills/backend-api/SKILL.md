---
name: backend-api
description: Implementasi atau review backend Express/API e-ticket: route, validasi, JWT/role, ownership, QR/check-in, dan persistence Supabase/PostgreSQL.
---

# Backend API

Gunakan untuk endpoint, middleware, business logic atau persistence. Ikuti source/migration aktual; jangan anggap roadmap PRD, README historis, Prisma atau mock sebagai kontrak/runtime. Baca `AGENTS.md`, arsitektur terkait dan hanya route/controller/service/model/config/migration yang terdampak.

## Implementasi
- Ikuti pola Express CommonJS dan alur route → middleware → controller → service/model; pertahankan response/error contract dan gunakan validasi/error middleware server.
- Operasi sensitif: verifikasi JWT, role, izin, ownership/keanggotaan dan tenant di server; periksa RLS/policy aktual dan jangan mengandalkan RLS sebagai pengganti authorization endpoint. Tombol tersembunyi bukan kontrol akses.
- Gunakan akses data terparameterisasi; jaga constraint, transaksi dan konsistensi multi-write. Jangan ubah schema/API/role tanpa mandat; migration perlu aman, kompatibel, dan idempotent bila sesuai.
- Rahasiakan secret, token, QR bearer data dan PII dari Flutter, log, fixture, laporan. Pembayaran simulasi bukan transaksi gateway.
- QR/check-in: otorisasi event, expiry, replay dan race/concurrency. Order/pembayaran: idempotency dan status konsisten.

## Validasi
- Uji logika murni dengan unit test; integration/provider/DB hanya pada environment uji sintetis.
- Endpoint/backend: `npm test`, `npm run check`; tambah `npm run format:check` bila format/JSON berubah. `npm run lint` adalah alias `check`.
- Laporkan kontrak/dokumentasi yang terdampak, checks/hasil dan integrasi yang belum diuji. Sebelum PR gunakan `pr-quality-gate`.