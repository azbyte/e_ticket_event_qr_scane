---
name: review
description: Review diff E-Ticket untuk bug, regresi, authorization/ownership, kebocoran data, kontrak API, migrasi, UI state dan validasi.
---

# Code Review

Mulai dari diff; baca requirement/PRD, source dan migration hanya pada bagian yang terpengaruh. Jangan mengedit saat hanya diminta review.

Urutkan temuan berdasarkan severity: akses/role/ownership atau secret; QR replay/race, transaksi/data loss; kontrak/API dan validasi; regresi UI/state; maintainability. Verifikasi alur dan kondisi reproduksi. Bedakan bug terbukti dari risiko potensial.

Laporkan setiap temuan dengan severity, `path:baris`, kondisi, dampak dan bukti. Periksa autentikasi, authorization server-side, validasi input, error contract, transaksi/idempotency bila relevan, migration/constraint serta loading/error/empty state. Data dummy/hidden button bukan kontrol keamanan.

Jika tidak ada temuan, sebutkan cakupan file dan checks yang benar-benar dijalankan serta keterbatasannya; jangan menyatakan fitur atau keamanan keseluruhan lulus.