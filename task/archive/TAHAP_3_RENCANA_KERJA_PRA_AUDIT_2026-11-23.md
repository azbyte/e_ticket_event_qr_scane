# Rencana kerja Tahap 3 — hasil rekonsiliasi (2026-11-23)

Dokumen ini menggantikan asumsi rencana Tahap 3 lama. Isi teknis per developer
tetap mengacu pada [`DEVELOPER_1_TASK.md`](DEVELOPER_1_TASK.md),
[`DEVELOPER_2_TASK.md`](DEVELOPER_2_TASK.md), [`DEVELOPER_3_TASK.md`](DEVELOPER_3_TASK.md),
[`DEVELOPER_4_FINISHING_TASK.md`](DEVELOPER_4_FINISHING_TASK.md),
[`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md), dan [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md).

Basis: hasil Tahap 1 terverifikasi 2026-11-23
([`../TAHAP_1/LAPORAN_DEVELOPER_4.md`](../TAHAP_1/LAPORAN_DEVELOPER_4.md) §9),
rencana Tahap 2 yang direkonsiliasi ([`../TAHAP_2/RENCANA_KERJA.md`](../TAHAP_2/RENCANA_KERJA.md)),
serta schema/migration aktual (9 migration applied, 0 drift).

## A. Kondisi awal terverifikasi (jangan diulang)

| Kapabilitas | Bukti | Status |
|---|---|---|
| Guest checkout: event publik -> kategori -> order 1 tiket/1 attendee -> simulasi payment -> tiket/QR | Smoke D4 14/14; `GET /api/events/public`, `POST /api/orders`, `POST /api/payments/simulate`, `GET /api/tickets/my-tickets` | SELESAI (Tahap 1) |
| Form event dinamis tersimpan pada `events.attendee_fields` (array nama field) | `eventController` create/update; `EventModel.attendeeFields` | TERSEDIA (terbatas: belum typed schema) |
| Halaman publik & registrasi Flutter memakai API (bukan mock) | `features/events/**`, `features/registration/**`, `EventService`, `OrderService` | SELESAI (Tahap 1) |
| Akun Admin nyata + otorisasi role | verifikasi §9.2 | SELESAI |

## B. Pekerjaan yang dihapus/tidak relevan

1. **Selector template tiket persisted** — belum ada kolom/endpoint template pada
   schema. Jangan membuat picker lokal yang mengklaim tersimpan. Hanya gunakan
   desain default dari record tiket; kebutuhan kolom template ditulis ke
   `../DB_CHANGE_PROPOSAL.md` bila produk memutuskan.
2. **Upload brosur/ storage** — tidak ada storage tervalidasi; `poster_url` hanya
   URL teks. Jangan mensimulasikan unggah.
3. **Form builder bertipe (label/type/required/options)** — `attendee_fields`
   masih array nama; perlu keputusan kontrak (G-07). Jangan mengklaim validasi
   bertipe sudah ada.
4. **Mengulang implementasi guest journey** — sudah berjalan pada Tahap 1.
   Tahap 3 hanya menutup state/responsive/regression yang belum ada.
5. **Membuat akun/seed demo baru untuk runbook** — kredensial hanya disebut
   sebagai status provisioning, tanpa nilai.

## C. Pekerjaan tersisa

### C.1 Developer 1 — form config & ticket presentation

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| T3-D1-1 | Pastikan field form yang dapat disimpan (`attendee_fields`) round-trip: baca dari event, kirim pada create/update, tampil kembali | `event_form_screen.dart`, `EventModel`, `ApiOrganizerEventRepository` | — | Nilai tersimpan dan tampil kembali; field kosong/ganda/invalid ditolak | widget test + unit model |
| T3-D1-2 | Validasi sisi form untuk field wajib/format tanpa membuat kontrak baru | `event_form_screen.dart`, `organizer_event_validators.dart` | T3-D1-1 | Error dapat ditindaklanjuti; tidak ada klaim persist di luar API | widget test |
| T3-D1-3 | Presentasi tiket default: data peserta/event/kategori/order dari record issued | `features/tickets/**`, widget QR | — | Tidak ada data placeholder; desain default dipakai bila template tidak ada | widget test |
| T3-D1-4 | Catat kebutuhan kontrak typed form/template/brosur ke `../DB_CHANGE_PROPOSAL.md` (tanpa implementasi DB) | proposal doc | T3-D1-1 | Kebutuhan payload/kolom eksplisit | review dokumen |

### C.2 Developer 2 — guest journey & responsive UI

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| T3-D2-1 | Trace ulang alur publik -> form -> order -> payment -> tiket pada API aktual; pastikan tidak ada fallback mock | `features/registration/**`, `features/orders/**`, `features/payments/**`, `services/*` | — | Setiap kegagalan API menjadi error yang terlihat; tidak ada data mock | widget test + `api_mode_no_fallback_test` |
| T3-D2-2 | State lengkap: loading/empty/error/expiry/retry/sukses pada tiap layar | sama | T3-D2-1 | Tidak ada layar tanpa state; retry berfungsi | widget test |
| T3-D2-3 | Responsive sempit/lebar, keyboard/focus/semantics pada form guest | layar registrasi/checkout | T3-D2-1 | Tidak overflow pada lebar sempit; field dapat difokus; label terbaca | widget test ukuran + analyze |
| T3-D2-4 | Regression satu order/satu tiket, harga server, akses tiket guest | provider/service order & tiket | T3-D2-1 | Harga klien diabaikan; tiket hanya dari order/token benar | widget test |
| T3-D2-5 | Uji E2E API nyata untuk jalur guest | script/widget dengan API loopback | T3-D2-1 | Satu alur penuh terekam bukti | DB/API smoke (fixture + cleanup) |

### C.3 Developer 3 — runbook, checklist, smoke evidence

| # | Pekerjaan | File/komponen | Dependent on | Kriteria selesai | Uji |
|---|---|---|---|---|---|
| T3-D3-1 | `task/DEMO_RUNBOOK.md`: prasyarat, **nama** variabel environment, perintah start/health, Flutter API mode, target Web/device, status provisioning akun (tanpa kredensial) | dokumen baru | — | Semua command/link menunjuk file/perintah yang ada | review + jalankan command aman |
| T3-D3-2 | `task/DEMO_CHECKLIST.md`: acceptance PRD + negative access, event->guest->ticket, staff/check-in, attendee/export/Admin, UI state, Android/Web; tiap butir PASS/FAIL/BLOCKED/NOT RUN + evidence | dokumen baru | T3-D3-1 | Tidak ada item PASS tanpa bukti | review |
| T3-D3-3 | Harness smoke read-only/non-destruktif pada antarmuka yang ada (health, schema sync, function diagnose) | script uji pada allow-list D3 | T3-D3-1 | Tidak memutasi data/provider eksternal | jalankan harness |
| T3-D3-4 | Catat prasyarat eksternal (seed/provisioning, migration, SMTP, payment sandbox) dan yang belum diuji | runbook | — | Tidak ada klaim provider teruji | review |

## D. Urutan implementasi dan gate

1. **T3-D3-1/T3-D3-2** dapat dimulai sekarang (dokumentasi) sambil menunggu
   pekerjaan UI, karena runbook harus mencerminkan kemampuan aktual.
2. **T3-D1-1 → T3-D1-2 → T3-D1-3 → T3-D1-4** (form config lalu presentasi tiket).
3. **T3-D2-1 → T3-D2-2 → T3-D2-3 → T3-D2-4 → T3-D2-5** (state/regression dulu,
   E2E terakhir).
4. **Integrasi Tahap 3** (D4): jalankan quality checks + smoke pada environment
   yang tersedia; tulis PASS/FAIL/BLOCKED/NOT RUN apa adanya.

### Ketergantungan pada Tahap 2

- Export attendee (T3-D2/D3 checklist) bergantung pada **D2-4 + D3-5** Tahap 2.
- Alur Staff/check-in pada checklist bergantung pada **D2-1..D2-3** Tahap 2.
- Bagian Admin pada checklist bergantung pada **D3-2..D3-4** Tahap 2.
- Bila Tahap 2 belum selesai, butir terkait ditandai **BLOCKED** dengan alasan
  konkret, bukan PASS.

### Gate integrasi Tahap 3

- Seluruh command di runbook dapat dijalankan dan cocok dengan repository.
- `flutter analyze`, `flutter test`, `npm test`, `npm run check`,
  `npm run format:check` PASS.
- Smoke API/DB hanya pada fixture sintetis dengan cleanup; tanpa secret/PII.
- Tidak ada klaim demo-ready untuk item NOT RUN (device/browser/SMTP/sandbox).

