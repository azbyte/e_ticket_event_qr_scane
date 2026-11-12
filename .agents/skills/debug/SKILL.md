---
name: debug
description: Mereproduksi dan menelusuri penyebab bug Flutter, Express, API, auth, Supabase atau pemindaian tiket tanpa memperluas perubahan.
---

# Skill Debugging

Beda sintom dan langkah minimum; gunakan data sintetis. Telusuri alur state/API
berdasarkan kode aktual dan bedakan sebab terbukti dari hipotesis. Jangan
menampilkan secrets atau data pribadi.

## 1. Prosedur Diagnosis
1. Catat gejala lengkap dan langkah reproduksi minimum.
2. Telusuri alur state dan API berdasarkan kode aktual.
3. Bedakan sebab terbukti dari hipotesis.
4. Tambahkan regression test yang mengunci perilaku bila memungkinkan.

## 2. Eksekusi dan Laporan
1. Jalankan checks terdampak terkait.
2. Laporkan diagnosis, perbaikan, hasil, dan keterbatasan integrasi/perangkat.
3. Jangan menampilkan secrets atau data pribadi dalam laporan.

## 3. Perintah Validasi
Di direktori `apps/`, jalankan `flutter analyze` dan `flutter test` untuk
memastikan tidak ada regresi baru.
Dokumentasikan diagnosis dan batasan ditemukan.