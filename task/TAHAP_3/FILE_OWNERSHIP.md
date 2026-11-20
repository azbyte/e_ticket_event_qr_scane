# Kepemilikan file — Tahap 3

**Allow-list preferensi Tahap 3** (bukan gate izin). Developer dapat langsung mulai
bila pemilik proyek memerintahkannya; tidak diperlukan GO Tahap 2 atau baseline
yang dicatat maintainer. Kerjakan path pada baris pemilik lebih dulu; perubahan di
luarnya diperbolehkan bila benar-benar diperlukan dengan perubahan minimum dan
didokumentasikan pada laporan. Tabel ini memeriksa path; konflik API/data/semantik
tetap wajib ditinjau dalam integration contract. Yang terkunci absolut:
schema/migration/SQL/seed/config DB, secret/`.env`, dependency lockfile tanpa
kebutuhan sah, dan operasi Git destruktif.

| Pemilik | Tanggung jawab | Path yang boleh diubah |
|---|---|---|
| Developer 1 | Form konfigurasi Organizer dan presentasi tiket | `apps/lib/features/organizer/screens/event_form_screen.dart`; `apps/lib/features/tickets/widgets/qr_ticket_display.dart`; test `apps/test/features/organizer/events/form_*.dart`, `apps/test/features/tickets/template_*.dart` (buat bila perlu) |
| Developer 2 | Public guest journey dan responsive states | `apps/lib/features/registration/screens/registration_screen.dart`; `apps/lib/features/events/screens/event_detail_screen.dart`; `apps/lib/features/orders/screens/order_detail_screen.dart`; `apps/lib/features/orders/screens/order_list_screen.dart`; `apps/lib/features/payments/screens/**`; `apps/lib/features/tickets/screens/**`; test `apps/test/features/registration/public_*.dart`, `apps/test/features/orders/public_*.dart` |
| Developer 3 | Runbook, checklist, smoke evidence | `task/DEMO_RUNBOOK.md`; `task/DEMO_CHECKLIST.md`; `backend/scripts/integration/demo_smoke.cjs` (baru); `apps/test/demo_smoke_test.dart` (baru); `backend/test/demo_contract_smoke.test.js` (baru) |
| Integrator pasca-merge | Validasi integrasi saja | `task/TAHAP_3/LAPORAN_DEVELOPER_4.md`; `backend/test/stage3_integration.test.js`; `apps/test/stage3_integration_test.dart` |

## Batas dan interaksi

- Semua file lain terkunci: termasuk router/bootstrap/provider global, shared
  services/models, backend production source/routes/config, schema/migration,
  seed, dependency/lockfile, CI, environment/secret dan file developer lain.
- D1 mengutamakan path miliknya dan tidak membuat komponen yang hanya tersedia
  pada branch D1 untuk dipakai D2. Jika form/config atau storage API yang
  dipersist belum tersedia, rekonstruksi kontraknya dari kode/API aktual, kerjakan
  lapisan yang dapat diselesaikan, buat adapter minimum, dan catat kebutuhan
  interface pada laporan; jangan membuat local-only success atau mengklaim data
  tersimpan.
- D2 hanya memakai interface pada baseline; tidak mengarang API/payload atau
  mengimpor branch belum merge. Guest/payment behavior mengikuti keputusan PRD
  yang telah disahkan.
- D3 hanya memakai path yang tercantum. Smoke harness tidak boleh membuat write
  path tersembunyi; test bersifat sintetis/non-destructive dan dilarang memakai
  `.env`/database pengguna. Runbook/checklist baru pada allow-list ini menjadi
  output D3; belum ada berarti task belum selesai.
- Tidak ada overlap path antar D1–D3 pada kondisi normal. Bila shared file
  benar-benar diperlukan untuk menyelesaikan task, lakukan perubahan minimum yang
  konsisten, lalu catat path, alasan, interface, dampak, dan acceptance/test pada
  laporan developer. Jangan berhenti menunggu amendment ownership.
- Developer 1–3 dilarang menyentuh semua database/schema/migration/seed/SQL.
  Proposal kebutuhan database dilaporkan sesuai `../FINISHING_AUTHORITY.md`.
- Integrator tidak otomatis menjadi otoritas database. Perubahan integrasi kecil
  pada file D1–D3 tidak diperbolehkan tanpa hand-back/approval tertulis dan
  amendment ownership terpisah.