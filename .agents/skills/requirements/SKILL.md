---
name: requirements
description: Menelaah PRD, role, acceptance criteria dan dampak perubahan UI/API e-ticket sebelum implementasi fitur atau kontrak.
---

# Skill Requirement dan Traceability

Baca `AGENTS.md`, PRD bagian terkait, dan `docs/ARCHITECTURE.md`. Inspeksi UI,
route, model, migration serta test aktual; dokumen dan source dapat berbeda.

## 1. Klasifikasi Permintaan
1. Klasifikasikan permintaan: klarifikasi requirement, perubahan perilaku, audit
   kontrak atau bukti implementasi. Jangan menganggap audit dokumen sebagai test.
2. Petakan aktor (participant/customer, organizer, staff per event, admin), objek,
   kepemilikan, permission, state sebelum/sesudah, hasil gagal dan batas demo.
3. Peran/istilah harus cocok dengan implementasi dan PRD yang aktif; catat konflik.

## 2. Analisis Perubahan Fungsional
1. Untuk perubahan fungsional, tulis acceptance criteria yang dapat diamati,
   termasuk role tidak berhak, loading/error/empty, retry, duplikasi dan batas
   ownership bila relevan.

## 3. Analisis API/Data
1. Untuk API/data, periksa route/controller/validator/model dan migration aktual.
2. Jangan menyimpulkan kontrak dari README historis saja atau mengubah schema
   sebagai efek samping. Perubahan payload perlu memperbarui dokumentasi/test
   yang terdampak.

## 4. Perbedaan Environment
1. Bedakan prototype/mock, backend lokal dan produksi. Jangan menyatakan pembayaran
   simulasi sebagai transaksi bank atau check-in UI sebagai verifikasi aman.

## 5. Kontrak Integrasi untuk Pembagian Tugas
1. Menghasilkan kontrak integrasi untuk pembagian tugas: File TXT pembagian tugas,
   interface contract, dependency map, dan acceptance criteria yang dapat digunakan
   oleh AI yang berbeda.

## 6. Laporan Requirement
1. Laporkan requirement yang berubah, file/kontrak terdampak, konflik tersisa
   dan bukti belum tersedia. Jika tidak ada perubahan fitur, nyatakan scope
   tetap dan jangan membuat requirement baru.