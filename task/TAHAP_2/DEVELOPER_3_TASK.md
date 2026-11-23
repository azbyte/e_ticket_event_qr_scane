# Tahap 2 — Developer 3: Attendee, Export, Order Monitoring, Admin Platform

> **Ringkasan.** Sumber lengkap: [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §E, [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md), [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md).

## Peran

Developer 3 memiliki alur: **daftar peserta paid-first + nomor registrasi → detail → export → order/payment monitoring → revenue organizer → seluruh konsol Admin → notifikasi Organizer**, serta kepemilikan `backend/src/app.js` dan util `auditLog.js`.

## Kondisi awal yang harus dipahami

- Endpoint attendee hanya membaca `tickets` dan urut `purchased_at DESC` (`checkInController.js:230-265`); tanpa nomor registrasi/status payment → tidak memenuhi AC-09.
- UI attendee memakai repository in-memory dengan `eventId` default `evt-1001` (`attendee_list_screen.dart:35-56`).
- Export hanya CSV mock (`organizer_operations_repository.dart:776-813`).
- Akun Admin, audit, settings, revenue, paket, langganan adalah mock; `audit_logs`/`platform_settings` belum dipakai backend.
- Dashboard Admin memakai angka hardcoded (`admin_dashboard_screen.dart:38-43, 643-676`).
- Suspend akun tanpa alasan & tanpa audit (`adminController.js:15-31`).
- Notifikasi Organizer **selalu** mock (`organizer_notifications_service.dart:68-74`).

## Daftar task

| ID | Judul | Depends |
|---|---|---|
| D3-A | `utils/auditLog.js` + mount path kosong di `app.js` (blocking Hari 1) | — |
| D3-1 | Attendee data nyata: paid-first, nomor registrasi, detail, permission | — |
| D3-2 | Export CSV, order/payment monitoring, revenue & laporan Organizer | D3-1 |
| D3-3 | Admin akun + audit log + platform settings (backend & UI) | — |
| D3-4 | Admin dashboard nyata + revenue + paket + langganan | D3-3 |
| D3-5 | Admin event monitoring/suspend, laporan, notifikasi, integrasi Tahap 2 | D1-3, D2-2, D3-1..D3-4 |

> **D3-A wajib di-merge lebih dulu.** Helper audit dan mount path kosong di
> `app.js` harus ada agar D1/D2 dapat menambah route tanpa mengedit `app.js`.
> D3-A juga prasyarat D3-3/D3-4. Detail di [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §E.

## Batas

- **Boleh:** hanya file D3 pada `INTEGRATION_CONTRACT.md` Bagian 2.
- **Dilarang:** schema/migration/seed, file D1/D2, mengubah kontrak yang dipakai developer lain, menghapus fitur.
- `listEventAttendees` di `checkInController.js` adalah **area koordinasi** dengan D2 — tulis spesifikasi lalu sepakati.
- Fee/komisi CONFIRMED tidak boleh diubah selama C-01 terbuka.

## Definisi selesai

Kriteria K per task terpenuhi, `npm test` + `flutter analyze` + `flutter test` PASS, bukti data nyata (bukan mock), laporan diperbarui, ringkasan gate G2 disiapkan.

## Laporan

Isi [`LAPORAN_DEVELOPER_3.md`](LAPORAN_DEVELOPER_3.md) dengan baseline, task, file, endpoint baru (`/admin/audit-logs`, `/admin/settings`, `/admin/subscriptions`, `/admin/overview`, `/events/:id/orders`, `/events/:id/attendees/export`), bukti test, status platform, risiko.
