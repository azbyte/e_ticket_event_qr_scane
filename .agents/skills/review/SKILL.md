---
name: review
description: Meninjau perubahan proyek e-ticket untuk bug, regresi, akses kontrol, kualitas UI, dan kelengkapan validasi.
---

# Skill Code Review

Mulai dari diff dan requirement/PRD relevan. Laporkan temuan terlebih dahulu,
urutkan berdasarkan severity, sertakan path/baris, kondisi reproduksi dan dampak.

## 1. Prioritas Review
1. Prioritaskan broken authorization/ownership, role escalation, secret leakage,
   ticket QR reuse/check-in race, data loss, API contract break, lalu regresi UI.
2. Pastikan status loading/error/empty, validasi backend dan migrasi cocok dengan
   implementasi. Data dummy bukan kontrol keamanan.

## 2. Prosedur Review
1. Periksa diff dari PR/change.
2. Laporkan temuan terverifikasi berdasarkan severity.
3. Bedakan temuan terverifikasi dari risiko potensial.
4. Jika tidak ada temuan, nyatakan cakupan file dan checks yang benar-benar
   dijalankan.

## 3. Aspek yang Direview
1. Validasi authorization/ownership pada backend.
2. Role escalation dan akses control.
3. Keamanan secret dan data sensitif.
4. Status UI: loading, error, empty state.
5. Validasi backend dan migrasi cocok dengan implementasi.
6. Perubahan dokumentasi/config.

## 4. Hasil Review
1. Urutkan berdasarkan severity.
2. Sertakan path/baris, kondisi reproduksi dan dampak.
3. Data dummy bukan kontrol keamanan.