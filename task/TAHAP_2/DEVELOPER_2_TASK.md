# Tahap 2 — Developer 2: Ticketing, Staff Workspace, Check-in

> **Ringkasan.** Sumber lengkap: [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §D, [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md), [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md).

## Peran

Developer 2 memiliki alur: **tiket terbit → QR nyata → invitation staff → workspace staff → scanner kamera → validasi → check-in → riwayat**, serta kepemilikan `checkInController.js`, `ticketController.js`, `eventInvitationController.js`, dan `apps/pubspec.yaml`.

## Kondisi awal yang harus dipahami

- `QrTicketDisplay` menggambar pseudo-QR (`qr_ticket_display.dart:41-73`); tidak ada dependency QR/kamera.
- `ScannerScreen` tanpa kamera dan masih menawarkan **mode offline** (non-MVP) (`scanner_screen.dart:96-108, 213-226`).
- `POST /api/tickets/verify` menandai tiket `used` tanpa membuat `check_ins` (`ticketController.js:129-153`).
- Flutter memanggil path riwayat yang salah (`check_in_service.dart:116`).
- UI membership masih in-memory (`organizer_membership_service.dart:79-171`).
- Tiket gratis belum tentu memiliki `token_hash`.

## Daftar task

| ID | Judul | Depends |
|---|---|---|
| D2-0 | Dependency `qr_flutter` + `mobile_scanner` (blocking Hari 1, PR terpisah) | — |
| D2-1 | QR e-ticket nyata + data tiket pribadi | — |
| D2-2 | Invitation staff E2E + `GET /api/me/memberships` + routing workspace | D1-1, D1-3 |
| D2-3 | Scanner kamera + validasi (online, MVP) | D2-1, D2-2 |
| D2-4 | Check-in tunggal, riwayat, konsolidasi verifikasi | D2-3 |
| D2-5 | Test regresi tiket–scan + dokumentasi endpoint | D2-1..D2-4 |

> **D2-0 wajib di-merge lebih dulu.** Tanpa dependency QR/kamera di `apps/pubspec.yaml`,
> branch D1 dan D3 tidak dapat menjalankan `flutter pub get`/`test` yang sama.
> Detail ada di [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §D (D2-0).

## Batas

- **Boleh:** hanya file D2 pada `INTEGRATION_CONTRACT.md` Bagian 2.
- **Dilarang:** schema/migration/seed, file D1/D3, menghapus fitur, menambah alur offline.
- Perubahan route (`app_router.dart`) **diajukan ke D1**, bukan diedit sendiri.
- Perubahan `checkInController.js` oleh D3 (attendee) memerlukan persetujuan tertulis D2.

## Definisi selesai

Kriteria K per task terpenuhi, `npm test` + `flutter analyze` + `flutter test` PASS, uji kamera Android/Web dicatat (PASS/NOT RUN), laporan diperbarui.

## Laporan

Isi [`LAPORAN_DEVELOPER_2.md`](LAPORAN_DEVELOPER_2.md) dengan baseline, task, file, dependency baru (`qr_flutter`, `mobile_scanner`), bukti test, status device/browser, risiko.
