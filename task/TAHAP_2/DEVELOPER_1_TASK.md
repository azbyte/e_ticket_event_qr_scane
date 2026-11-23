# Tahap 2 — Developer 1: Publishable Event & Public Registration

> **Ringkasan.** Dokumen ini adalah lembar kerja ringkas. Sumber lengkap: [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §C, [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md), [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md).

## Peran

Developer 1 memiliki alur: **event Organizer → validasi → publish otomatis → dua tautan → guest mendaftar → order → pembayaran**, serta kepemilikan tunggal `apps/lib/app.dart`, `app_router.dart`, `routes/app_routes.dart`.

## Kondisi awal yang harus dipahami

- Router Flutter memaksa login pada hampir semua route (`app_router.dart:217-220`); route publik belum ada.
- Event masih berstatus `DRAFT`/`PENDING_REVIEW` dan menunggu approval Admin (`eventController.js:210, 347`).
- `events.public_url` tidak pernah diisi; UI menampilkan tautan demo (`organizer_event_contract.dart:493-498`).
- Order & pembayaran guest sudah nyata dan wajib 1 tiket (`orderController.js:91-99`).

## Daftar task

| ID | Judul | Depends |
|---|---|---|
| D1-A | Stub `public_event/`, `services/public_event/`, dan route publik (blocking Hari 1) | — |
| D1-1 | Fondasi routing publik & kepemilikan route | — |
| D1-2 | Auto-publish event (validasi → `PUBLISHED`) | — |
| D1-3 | Dua tautan: `public_url` + staff invitation URL | D1-2 |
| D1-4 | Landing publik + registrasi guest + checkout | D1-1, D1-2 |
| D1-5 | Perbaikan order/payment/tiket guest + dynamic attendee data | D1-4 |

> **D1-A wajib di-merge lebih dulu.** Stub route publik harus ada agar D2 (invite)
> dan D1 (fitur publik) tidak berebut `app_router.dart`. Detail di
> [`RENCANA_KERJA.md`](RENCANA_KERJA.md) §C dan §B.1.

## Batas

- **Boleh:** hanya file D1 pada `INTEGRATION_CONTRACT.md` Bagian 2.
- **Dilarang:** schema/migration/seed, file D2/D3, menghapus fitur, mengubah kontrak order/payment yang sudah dipakai.
- Permintaan perubahan route ke D1 datang dari D2; D1 yang mengedit `app_router.dart`.

## Definisi selesai

Seluruh kriteria K pada setiap task terpenuhi, `npm test` + `flutter analyze` + `flutter test` PASS, laporan diperbarui dengan bukti PASS/FAIL/NOT RUN.

## Laporan

Isi [`LAPORAN_DEVELOPER_1.md`](LAPORAN_DEVELOPER_1.md) dengan: baseline, task selesai, file disentuh, endpoint baru, bukti test, status platform, risiko.
