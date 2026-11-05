---
name: requirements
description: Menelaah PRD, role, acceptance criteria dan dampak perubahan UI/API e-ticket sebelum implementasi fitur atau kontrak.
---

# Skill requirement dan traceability

Baca `AGENTS.md`, PRD bagian terkait, dan `docs/ARCHITECTURE.md`. Inspeksi UI,
route, model, migration serta test aktual; dokumen dan source dapat berbeda.

1. Klasifikasikan permintaan: klarifikasi requirement, perubahan perilaku, audit
   kontrak atau bukti implementasi. Jangan menganggap audit dokumen sebagai test.
2. Petakan aktor (participant/customer, organizer, staff per event, admin), objek,
   kepemilikan, permission, state sebelum/sesudah, hasil gagal dan batas demo.
   Peran/istilah harus cocok dengan implementasi dan PRD yang aktif; catat konflik.
3. Untuk perubahan fungsional, tulis acceptance criteria yang dapat diamati,
   termasuk role tidak berhak, loading/error/empty, retry, duplikasi dan batas
   ownership bila relevan.
4. Untuk API/data, periksa route/controller/validator/model dan migration aktual.
   Jangan menyimpulkan kontrak dari README historis saja atau mengubah schema
   sebagai efek samping. Perubahan payload perlu memperbarui dokumentasi/test
   yang terdampak.
5. Bedakan prototype/mock, backend lokal dan produksi. Jangan menyatakan pembayaran
   simulasi sebagai transaksi bank atau check-in UI sebagai verifikasi aman.
6. Laporkan requirement yang berubah, file/kontrak terdampak, konflik tersisa
   dan bukti yang belum tersedia. Jika tidak ada perubahan fitur, nyatakan scope
   tetap dan jangan membuat requirement baru.
