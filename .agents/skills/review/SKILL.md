---
name: review
description: Meninjau perubahan proyek e-ticket untuk bug, regresi, akses kontrol, kualitas UI, dan kelengkapan validasi.
---

# Skill code review

Mulai dari diff dan requirement/PRD relevan. Laporkan temuan terlebih dahulu,
urutkan berdasarkan severity, sertakan path/baris, kondisi reproduksi dan dampak.

- Prioritaskan broken authorization/ownership, role escalation, secret leakage,
  ticket QR reuse/check-in race, data loss, API contract break, lalu regresi UI.
- Pastikan status loading/error/empty, validasi backend dan migrasi cocok dengan
  implementasi. Data dummy bukan kontrol keamanan.
- Periksa tests serta perubahan dokumentasi/config; hindari opini tanpa dampak.
- Bedakan temuan terverifikasi dari risiko potensial. Jika tidak ada temuan,
  nyatakan cakupan file dan checks yang benar-benar dijalankan.
