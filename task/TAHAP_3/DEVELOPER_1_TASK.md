# Tahap 3 — Developer 1: Organizer form config dan ticket presentation

> Mulai setelah Tahap 2 GO. Audit UI/read-only boleh dilakukan dari baseline, tetapi konfigurasi persist/ticket template acceptance **BLOCKED** sampai storage/template contract dan owner shared interface disetujui. UI-only task; no API/database change.

## Tujuan/kondisi awal
Lengkapi konfigurasi field yang didukung form Organizer dan presentasi desain ticket default/template pada UI. Baca PRD §§4–5, 7, 10–16; ownership/contract tahap; `event_form_screen.dart`, model/repository event, registration screen, QR widget dan tests (read-only); keputusan final. Jangan buka `.env`.

## Pekerjaan
1. Trace current event form/config model dan field yang dapat disimpan melalui baseline API; implement config UI hanya dalam `event_form_screen.dart` bila ada extension point sesuai kontrak.
2. Jangan membuat persisted-success palsu: jika backend tidak menyimpan konfigurasi atau field, laporkan blocker dengan payload/interface yang dibutuhkan, jangan local-only.
3. Untuk ticket visual pilih default/template hanya dari pilihan yang disahkan dan tampilkan data issued record melalui QR presentation widget; jangan membuat editor/custom upload.
4. Jaga validation/state/error/accessibility/responsive pada screens owned; regression test khusus.

## File / dependency
Hanya D1 allow-list `FILE_OWNERSHIP.md`. Registration rendering milik D2; router/services/model/backend/schema/shared files dilarang. Mulai dari API interface baseline, tidak menunggu D2. Bila butuh shared extension, report blocker.

## Kriteria / verifikasi
Config UI mencerminkan nilai yang benar-benar dipersist; invalid values ditolak; default/template menampilkan record data benar; no fake brochure upload; loading/error state; focused tests + Flutter analyze pass. Laporan actual diff, criteria evidence, blockers.

