---
name: flutter-ui
description: Implementasi/review UI Flutter E-Ticket: widget, Provider state, layout Android/Web, tema, aksesibilitas dan loading/error/empty state.
---

# Flutter UI

Gunakan saat mengubah tampilan atau state UI Flutter. Baca `AGENTS.md`, arsitektur dan hanya bagian PRD, tema, analyzer config serta widget/provider yang terdampak. Ikuti struktur fitur dan Provider yang ada; API melalui service, bukan request di widget.

- Pertahankan tema dan komponen visual aktual; jangan membuat identitas/warna baru atau menambah dependency UI tanpa alasan. Reuse komponen bila mengurangi duplikasi nyata.
- Jaga layout Android/Web pada ukuran sempit/lebar, teks panjang, semantik/tooltip dan target sentuh. Uji kondisi yang relevan: loading, success, empty, error, retry dan no-permission.
- Model, service dan provider harus konsisten dengan kontrak API; tampilkan error yang benar, jangan fallback diam-diam ke mock pada API mode. Demo/mock bukan authentication atau bukti transaksi/check-in nyata.
- Tambahkan/ubah widget test untuk perilaku UI; jalankan `flutter analyze` dan `flutter test` di `apps/`. Catat temuan lama/batas validasi perangkat, jangan lakukan cleanup massal tak terkait.

Tambahkan `requirements` jika perilaku/role berubah, `debug` untuk bug, atau `backend-api` jika backend juga diubah. Gunakan `pr-quality-gate` untuk gate pra-PR.