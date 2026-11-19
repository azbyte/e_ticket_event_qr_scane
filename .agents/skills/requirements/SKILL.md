---
name: requirements
description: Analisis PRD, role, acceptance criteria, ownership dan kontrak data/API sebelum perubahan perilaku atau integrasi E-Ticket.
---

# Requirements & Traceability

Gunakan untuk requirement/kontrak yang berubah, ambigu atau berkonflik—bukan edit mekanis. Baca bagian PRD terkait dan source aktual; perluas ke route/model/migration/test hanya bila menyentuh API/data. Source dan migration mengungkap perilaku kini; PRD menyatakan intent. Catat perbedaan, jangan memilih diam-diam.

1. Petakan aktor dan akses: Participant, Organizer, Admin; Staff/Owner adalah membership/permission event, bukan role global baru. Catat objek, ownership, state sebelum/sesudah dan batas mock/backend/produksi.
2. Untuk perubahan fungsional, rumuskan acceptance criteria yang dapat diamati, termasuk unauthorized/ownership, input tidak valid, loading/error/empty, retry, duplikasi dan state transaksi bila relevan.
3. Untuk API/data, verifikasi route/controller/validator/service/model, migration dan tes aktual. Tetapkan payload, status/error dan konsistensi klien; jangan menyimpulkan dari README historis atau mengubah schema sebagai efek samping.
4. Bedakan prototype, mock, API lokal dan produksi. Pembayaran simulasi bukan transaksi bank; kontrol UI bukan authorization; QR yang ditampilkan bukan bukti check-in aman.
5. Laporkan keputusan/assumption, kriteria, file/kontrak terdampak, konflik dan bukti yang belum ada. Buat interface contract, dependency map atau file pembagian tugas hanya bila kolaborasi lintas pelaksana memang memerlukannya.

Tambahkan `backend-api`/`flutter-ui` hanya untuk stack yang disentuh; gunakan `debug` bila diagnosis bug dibutuhkan.