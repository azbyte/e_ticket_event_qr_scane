# LAPORAN AUDIT & PERBAIKAN — PENGIRIMAN TIKET MELALUI EMAIL

- **Tanggal:** 2026-11-26
- **Ruang lingkup:** formulir pendaftaran (field email), alur pendaftaran →
  penerbitan tiket → pengiriman PDF, integrasi SMTP, status & kegagalan
  pengiriman, serta lima permasalahan yang sebelumnya tercatat belum selesai.
- **Ringkasan status:** implementasi **selesai dan teruji** untuk seluruh bagian
  yang dapat dikerjakan di lingkungan ini. Dua verifikasi eksternal tetap
  **BLOCKED** karena membutuhkan kredensial SMTP nyata dan perangkat fisik
  (lihat §D dan §E). Tidak ada hasil pengujian yang dikarang.

---

## A. Ringkasan Permasalahan

### A.1 Akar penyebab

| # | Masalah | Akar penyebab | Dampak |
|---|---|---|---|
| P1 | Tiket tidak pernah sampai ke inbox peserta | `backend/.env` memakai `SMTP_HOST=json` (transport uji). Kode lama **mencatat `SENT`** untuk transport json, sehingga sistem tampak berhasil padahal tidak ada email keluar | Peserta tidak menerima tiket; status di aplikasi menyesatkan |
| P2 | Status pengiriman tidak dapat dipercaya | `SENT` ditulis walau transport json; tidak ada pembeda "belum dikirim" vs "sedang dikirim" vs "gagal" | Tim mengira email terkirim; kegagalan tidak pernah ditindaklanjuti |
| P3 | Data lama berisi klaim palsu | 4 baris `ticket_email_deliveries` berstatus `SENT` dengan `last_error` "json transport ... TIDAK dikirim" | Riwayat pengiriman tidak dapat dipakai untuk audit |
| P4 | Respons pendaftaran/pembayaran menunggu SMTP | `sendOrderTicketEmails()` dipanggil `await` di dalam request; seluruh percakapan SMTP (EHLO/MAIL/RCPT/DATA + lampiran PDF) terjadi sebelum respons | Request lambat/gagal bila SMTP lambat atau tidak tersedia |
| P5 | Field email dapat hilang dari formulir | `normalizeAttendeeFields()` hanya mewajibkan `name`; `email` opsional di konfigurasi. Form publik mengikuti konfigurasi apa adanya | Event bisa dibuat tanpa field email → tiket tidak punya alamat tujuan |
| P6 | Email tidak dapat dikunci | Tidak ada konsep "field terkunci"; Organizer dapat mengubah `required` dan `type` email | Email bisa dihapus/dijadikan opsional, memutus pengiriman tiket |
| P7 | Validasi format email tidak konsisten | Backend hanya memvalidasi email pada payload order; konfigurasi field tidak memaksa tipe/format email | Email tidak valid dapat lolos ke database |
| P8 | Konfigurasi SMTP tidak divalidasi | `SMTP_PORT`/`SMTP_USER`/`SMTP_PASS`/`EMAIL_FROM` tidak diperiksa; `EMAIL_FROM` punya fallback hardcoded | Kegagalan baru terlihat saat kirim; pengirim tidak valid |
| P9 | Retry tidak terkendali | `retryPendingDeliveries()` mengambil semua PENDING/FAILED tanpa batas percobaan dan tanpa menghormati `next_attempt_at` | Percobaan berulang tanpa henti, beban SMTP naik |
| P10 | Data uji mencemari database | `npm run test:registration-flow` tidak membersihkan event/akun sintetis | Jumlah data bertambah setiap kali uji dijalankan (ditemukan saat audit ini) |

### A.2 Status sebelum perbaikan

| Item | Sebelum |
|---|---|
| Field email wajib pada konfigurasi formulir | Tidak dijamin (bisa dihapus) |
| Transport json | Dicatat `SENT` (klaim palsu) |
| Pengiriman email | Sinkron di dalam request |
| Status pengiriman | Hanya `PENDING`/`SENT`/`FAILED`, tanpa `SENDING`/`NOT_CONFIGURED` |
| Validasi SMTP | Tidak ada |
| Retry | Tanpa batas percobaan |
| Data delivery | 4 baris `SENT` palsu |
| Data uji E2E | Meninggalkan event/akun di database |

---

## B. Perbaikan yang Dilakukan

### B.1 Backend — formulir & validasi email

| File | Perubahan |
|---|---|
| `src/utils/eventValidation.js` | `LOCKED_ATTENDEE_FIELD_KEYS` (`name`,`email`); `EMAIL_PATTERN`; `ensureLockedAttendeeFields()`; `normalizeAttendeeFields()` **selalu menambahkan `email` wajib** bila tidak ada; `email` dipaksa `type: 'text'` + `required: true`; `validateAttendeeAnswers()` memvalidasi format email di server |
| `src/utils/eventResponse.js` | `normalizedAttendeeFields()` — `attendee_fields` pada response API selalu array bertipe dan memuat `email` wajib (termasuk event lama/JSON teks) |
| `src/controllers/eventController.js` | Update event menyimpan `attendee_fields` hasil normalisasi, bukan payload mentah |

### B.2 Backend — layanan email & antrean

| File | Perubahan |
|---|---|
| `src/services/emailService.js` | `smtpStatus()` baru: validasi `SMTP_HOST`, `SMTP_PORT` (1–65535), pasangan `SMTP_USER`/`SMTP_PASS`, dan `EMAIL_FROM` valid — tanpa membocorkan nilai; `EMAIL_FROM` tidak lagi fallback hardcoded; `markQueued()` mencatat status belum terkirim tanpa menimpa `SENT`; `retryPendingDeliveries()` dibatasi 5 percobaan + `next_attempt_at` |
| `src/services/emailQueue.js` (**baru**) | Antrean in-process tanpa dependensi baru: `enqueueTicket/enqueueOrder` (jadwalkan via `setImmediate`), penjaga in-flight anti email ganda, `drain()`, `retryPending()`, `startRetryWorker()` (interval 5 menit, `unref`), `summarize()` untuk status jujur |
| `src/controllers/orderController.js` | Event gratis: tiket terbit + `enqueueOrder()`; respons memakai `emailQueue.summarize()` |
| `src/controllers/paymentController.js` | Setelah `PAID`: `enqueueOrder()`; respons memakai `summarize()` |
| `src/controllers/ticketController.js` | Status `SENDING` saat pekerjaan benar-benar berjalan; respons kirim ulang menambah `already_sent` |
| `src/routes/admin.js` | `POST /api/admin/email/retry` memakai antrean (tidak menunggu SMTP) |
| `server.js` | Mencetak status email (mode + variabel yang belum diisi, tanpa kredensial) dan menjalankan retry worker |

### B.3 Backend — skrip verifikasi & pemeliharaan

| File | Fungsi |
|---|---|
| `scripts/verify-email-delivery.js` | SMTP sink lokal (bukti transmisi nyata) **+** pemeriksaan kesiapan SMTP nyata; bila kredensial belum ada → `BLOCKED` (bukan `PASS` palsu); bila ada `VERIFY_EMAIL_TO` → kirim sungguhan |
| `scripts/verify-async-email-queue.js` (**baru**) | SMTP sink **lambat**; membuktikan penjadwalan jauh lebih cepat daripada pengiriman, status awal `QUEUED/PENDING`, lalu `SENT`, tanpa email ganda |
| `scripts/retry-ticket-emails.js` (**baru**) | `npm run retry:emails` — coba ulang delivery yang tertunda |
| `scripts/repair-email-delivery-status.js` (**baru**) | Menurunkan `SENT` palsu (transport json) menjadi `PENDING`, dengan backup JSON; default dry-run |
| `scripts/cleanup-e2e-data.js` (**baru**) | Membersihkan data sintetis E2E dengan pola khusus (`Event E2E %`, `org.e2e.%@example.test`) |
| `scripts/e2e-registration-scenarios.js` | Memanggil pembersihan di akhir uji |
| `scripts/integration/backend.integration.cjs` | Asersi diperbaiki: transport json **tidak boleh** `SENT` |

### B.4 Frontend (Flutter)

| File | Perubahan |
|---|---|
| `models/event/attendee_field_definition.dart` | `ensureRequiredFields()` — `name`/`email` selalu ada, wajib, bertipe teks; field dinamis lain utuh |
| `models/event/event_model.dart`, `services/organizer_events/organizer_event_contract.dart` | `resolvedAttendeeFields`/`resolvedAttendeeFieldDefinitions` memakai `ensureRequiredFields()` |
| `features/organizer/events/widgets/attendee_field_builder.dart` | Dialog field: tipe & "Wajib diisi" **dinonaktifkan** untuk `name`/`email`; catatan bahwa email tidak dapat dihapus/dijadikan opsional |
| `models/payment/email_delivery_model.dart` | Field `queued`/`status`, getter `isSending`, pesan jujur untuk `SENDING`/`NOT_CONFIGURED`/gagal |
| `providers/order_provider.dart`, `services/order/order_service.dart` | `email_delivery` diteruskan dari respons API (mode demo melaporkan `NOT_CONFIGURED`) |
| `features/public_event/screens/public_registration_screen.dart` | Meneruskan status email ke daftar tiket |
| `features/tickets/screens/ticket_list_screen.dart` | Banner status email (`ticket-list-email-status`) dengan warna sesuai keadaan |
| `features/tickets/screens/ticket_detail_screen.dart` | Pesan `SENDING`, `NOT_CONFIGURED`, `PENDING`, `FAILED` dibedakan |

### B.5 Database

- **Tidak ada perubahan skema/migrasi baru.** Kolom `ticket_design`,
  `ticket_design_orientation` beserta migrasi orientasi sudah ada dan sesuai.
- Perbaikan **data** (bukan struktur): 4 baris delivery `SENT` palsu → `PENDING`,
  `sent_at=NULL`, alasan jujur. Backup:
  `backend/backups/email-delivery-sent-repair-2026-11-26T14-37-15-106Z.json`.
- Data uji E2E yang sempat tertinggal (2 event, 2 tiket, 2 delivery, 2 order,
  1 akun organizer) dibersihkan; jumlah data kembali ke baseline terverifikasi.

### B.6 Konfigurasi email

- `backend/.env.example`: `EMAIL_FROM` dikosongkan (wajib diisi untuk SMTP nyata),
  ditambah `VERIFY_EMAIL_TO` untuk uji kirim ke inbox nyata.
- Tidak ada kredensial yang ditulis, diubah, atau ditampilkan.
- `SMTP_HOST=json` pada `backend/.env` **tidak diubah** (sesuai instruksi).

---

## C. Hasil Pengujian

Semua perintah dijalankan dari folder yang disebutkan, pada mesin ini
(Windows, Node 22, PostgreSQL/Supabase aktif).

| # | Pengujian | Perintah | Hasil aktual | Status |
|---|---|---|---|---|
| C1 | Backend unit/integration | `cd backend; npm test` | **226 pass, 0 fail** | PASS |
| C2 | Sintaks seluruh source | `npm run check` | Syntax OK: 57 file | PASS |
| C3 | Format & JSON | `npm run format:check` | passed | PASS |
| C4 | Validasi skills | `npm run validate:skills` | 7 skills, 8 file | PASS |
| C5 | Validator sinkronisasi | `npm run test:sync-config` | 14 pass, 0 fail | PASS |
| C6 | Analisis statis Flutter | `cd apps; flutter analyze` | No issues found | PASS |
| C7 | Seluruh test Flutter | `flutter test` | **317 test lulus** | PASS |
| C8 | Verifikasi email (SMTP sink + kesiapan nyata) | `cd backend; npm run verify:email` | **17 PASS, 0 FAIL, 1 BLOCKED** (inbox nyata) | PASS (lokal) / BLOCKED (inbox) |
| C9 | Bukti pengiriman tidak memblokir request | `npm run verify:email-queue` | **8 PASS, 0 FAIL** (enqueue 316 ms vs kirim 2788 ms) | PASS |
| C10 | Alur tiket HTTP + DB nyata | `npm run verify:ticket-flow` | **38 PASS, 0 FAIL** | PASS |
| C11 | Rendering PDF kedua orientasi | `npm run verify:ticket-pdf` | 13 OK | PASS |
| C12 | E2E registrasi nyata (server + DB) | `npm run test:registration-flow` | **32/32 lulus**, data uji dibersihkan (18 baris) | PASS |
| C13 | Status migrasi | `npx prisma migrate status` | 12 migrasi, "Database schema is up to date!" | PASS |
| C14 | Sinkronisasi schema ↔ DB | `npm run verify:db-schema` | PASS (tanpa perbedaan) | PASS |
| C15 | Jumlah data sebelum/sesudah | query `count(*)` | 1 event / 1 kategori / 4 tiket / 4 delivery / 4 peserta / 4 order — **tidak berubah** | PASS |
| C16 | UI perangkat fisik (Android/iOS) | — | tidak ada perangkat/emulator | BLOCKED |
| C17 | Pengiriman ke inbox email asli | `npm run verify:email` (bagian nyata) | `SMTP_HOST=json` → mode `disabled`; BLOCKED | BLOCKED |

### C.1 Skenario wajib (15 skenario)

| No. | Skenario | Bukti | Hasil |
|---|---|---|---|
| 1 | Event dibuat tanpa konfigurasi field email | `email_ticket_delivery_rules.test.js` (normalisasi menambahkan `email` wajib); widget test "event tanpa field email tetap menampilkan email wajib" | PASS |
| 2 | Peserta mendaftar tanpa email | Validasi backend (`Every selected ticket must have valid attendee details`) + widget test "field wajib peserta divalidasi" | PASS |
| 3 | Format email tidak valid | Backend: `validateAttendeeAnswers` menolak; frontend: widget test "format email tidak valid ditolak" | PASS |
| 4 | Daftar event gratis | `verify-ticket-flow`: order `PAID`, 1 tiket terbit, email dijadwalkan | PASS |
| 5 | Daftar event berbayar | `verify-ticket-flow`: `pending_payment`, 0 tiket sebelum bayar | PASS |
| 6 | Pembayaran berhasil | `verify-ticket-flow`: tiket terbit setelah simulasi pembayaran `paid` | PASS |
| 7 | SMTP tidak dikonfigurasi | `verify-ticket-flow`: `transport=disabled`, `delivered=false`, delivery `PENDING` | PASS |
| 8 | SMTP gagal mengirim | `verify-email-delivery`: status `FAILED` + `last_error` tersimpan, tiket tetap ada | PASS |
| 9 | Kirim ulang tiket | `verify-email-delivery`: `SKIPPED/already_sent`; `verify-ticket-flow`: tetap 1 baris delivery | PASS |
| 10 | Desain tiket kustom | `verify-ticket-pdf`: PDF memakai desain kustom (ukuran & rasio benar) | PASS |
| 11 | Orientasi landscape | `verify-ticket-pdf` + `verify-ticket-flow` (template landscape) | PASS |
| 12 | Orientasi portrait | `verify-ticket-flow`: PDF tiket 440×704 pt | PASS |
| 13 | Event lama tanpa desain | `verify-ticket-pdf`: default landscape 720×288 pt | PASS |
| 14 | Pengiriman ke SMTP sink lokal | `verify-email-delivery`: RCPT TO, subjek, lampiran PDF, `SENT` | PASS |
| 15 | Pengiriman ke SMTP nyata | belum ada kredensial → `BLOCKED` (tidak diklaim berhasil) | BLOCKED |

### C.2 Bukti penting

- `verify-email-queue` (bukti P4 selesai):

  ```
  PASS  status respons adalah QUEUED (bukan klaim SENT)
  PASS  delivery dicatat PENDING saat antre :: PENDING
  PASS  penjadwalan ganda ditolak (in-flight guard)
  PASS  pengiriman latar benar-benar melewati SMTP lambat :: 2788 ms
  PASS  penjadwalan email tidak menunggu SMTP lambat :: enqueue 316 ms vs kirim 2788 ms
  PASS  delivery berubah SENT setelah antrean selesai :: SENT
  ```

- `verify-email` (bukti P1/P2/P3 di tingkat lokal):

  ```
  PASS  RCPT TO memakai email peserta :: uji-tiket@example.test
  PASS  subjek email adalah E-Ticket
  PASS  lampiran PDF tiket ikut terkirim
  PASS  kirim ulang tidak mengirim email ganda :: SKIPPED/already_sent
  PASS  kegagalan SMTP dicatat FAILED (tidak diklaim terkirim)
  BLOCKED  pengiriman ke inbox nyata :: SMTP nyata belum siap.
  PEMERIKSAAN LOKAL LULUS; 1 verifikasi eksternal BLOCKED
  ```

- `verify-ticket-flow` (bukti alur HTTP nyata):

  ```
  PASS  event gratis langsung PAID :: paid
  PASS  email tidak diklaim terkirim saat SMTP tidak aktif :: transport=disabled delivered=false
  PASS  nama event pada tiket sama dengan nama event dibuat
  PASS  email peserta pada tiket benar :: peserta.verify...@example.test
  PASS  PDF tiket mengikuti orientasi portrait kategori :: {"w":440,"h":704}
  PASS  tidak ada catatan delivery ganda setelah kirim ulang :: jumlah=1
  ```

---

## D. Status Lima Permasalahan yang Tersisa

### D.1 Pengiriman ke inbox email asli — **BLOCKED**

- **Kondisi:** `backend/.env` masih `SMTP_HOST=json`; tidak ada kredensial SMTP
  nyata di lingkungan kerja. Karena itu pengiriman ke inbox asli **belum dapat
  dibuktikan**.
- **Yang sudah dibuktikan (bukan klaim):** transmisi SMTP nyata ke **SMTP sink
  lokal** (EHLO/MAIL FROM/RCPT TO/DATA), penerima = email peserta, subjek
  `E-Ticket …`, lampiran `application/pdf` ada, status `SENT`, dan tidak ada
  email ganda saat kirim ulang (`verify:email` 17 PASS).
- **Yang sudah disiapkan agar kredensial nyata langsung bisa dipakai tanpa ubah
  kode:** semua variabel dibaca dari `backend/.env`; `smtpStatus()` memvalidasi
  konfigurasi; `npm run verify:email` akan benar-benar mengirim bila
  `SMTP_HOST/PORT/USER/PASS/EMAIL_FROM` terisi **dan** `VERIFY_EMAIL_TO` diisi.
- **Yang masih dibutuhkan:** pengisian kredensial oleh pemilik proyek
  (lihat §E). Sampai itu terjadi, status tetap **BLOCKED** — tidak dinaikkan
  menjadi PASS.

### D.2 Konfigurasi `SMTP_HOST=json` — **SELESAI**

- `SMTP_HOST=json` di luar `NODE_ENV=test` → mode `disabled`; tidak ada
  transport, tidak ada percobaan jaringan, dan **tidak pernah** `SENT`.
- Di dalam `NODE_ENV=test` transport json tetap dipakai untuk pengujian otomatis,
  tetapi hasilnya dicatat `PENDING` + alasan "email TIDAK dikirim".
- Tiket tetap terbit dan dapat diakses (event gratis maupun berbayar); pengguna
  mendapat pesan jelas (`NOT_CONFIGURED`).
- Nilai `SMTP_HOST=json` **tidak** diganti dengan SMTP fiktif.
- Bukti: `email_ticket_delivery_rules.test.js` (2 test), `verify-ticket-flow`
  (`transport=disabled delivered=false`), dan perbaikan 4 baris `SENT` palsu.

### D.3 Pengiriman email sinkron di dalam request — **SELESAI**

- Pendaftaran (event gratis) dan pembayaran kini hanya: menerbitkan tiket →
  mencatat delivery `PENDING` → **menjadwalkan** email (`setImmediate`), lalu
  langsung merespons.
- Bukti kuantitatif (`verify:email-queue`): penjadwalan **316 ms** sementara
  pengiriman SMTP berlangsung **2788 ms** (SMTP sengaja dilambatkan 300 ms per
  langkah). Respons tidak menunggu SMTP.
- Tidak ada dependensi runtime baru (tanpa Redis/BullMQ). Alasan teknis memilih
  antrean in-process: satu proses backend, volume tiket kecil, dan status
  tersimpan di database sehingga pekerjaan yang terputus tetap tercatat
  `PENDING` dan diambil worker retry.
- Anti email ganda: penjaga in-flight per tiket + `sendTicketEmail` menolak
  catatan `SENT` + `SKIPPED/already_sent` saat kirim ulang.
- Retry aman: worker periodik 5 menit (hanya aktif saat SMTP nyata), maksimum 5
  percobaan otomatis, menghormati `next_attempt_at`.

### D.4 Pengujian UI pada perangkat fisik — **BLOCKED (manual)**

- `flutter analyze`: **No issues found**.
- `flutter test`: **317 test lulus**, termasuk pengujian responsif yang sudah ada
  (tidak dihapus/dilemahkan) dan widget test baru untuk field email wajib,
  validasi format email, serta banner status email.
- **Belum dilakukan:** uji pada perangkat/emulator Android & iOS fisik. Tidak
  ada perangkat di lingkungan ini, sehingga tidak diklaim sudah diuji. Tata
  letak sempit/lebar diverifikasi lewat widget test, bukan perangkat nyata.

### D.5 Migrasi database & normalisasi desain tiket — **SELESAI (terverifikasi)**

- `npx prisma migrate status`: 12 migrasi, **"Database schema is up to date!"**.
- `npm run verify:db-schema`: **PASS** — tidak ada perbedaan schema Prisma vs DB.
- **Tidak ada migrasi baru** dibuat (tidak diperlukan).
- Data tidak berubah: 1 event, 1 kategori tiket, 4 tiket, 4 delivery, 4 peserta,
  4 order, 4 pembayaran — sama seperti sebelum pekerjaan ini.
- Event tanpa desain (`ticket_design IS NULL`) tetap memakai **desain default**
  (dibuktikan `verify-ticket-pdf`: default landscape 720×288 pt; `verify-ticket-flow`).
- Event dengan desain memakai desain penyelenggara; orientasi `NULL` mewarisi
  level di atasnya (event → default sistem).
- Penanganan `NULL` konsisten di backend (`normalizeDesign`, `orientationOrDefault`)
  dan frontend (`TicketDesignModel`), termasuk saat render PDF.

---

## E. Hal yang Masih Membutuhkan Pengguna

1. **Mengisi konfigurasi SMTP nyata pada `backend/.env`** (jangan dikirim melalui
   percakapan; isi langsung di file lokal, dan jangan commit):
   ```
   SMTP_HOST=smtp.example.com
   SMTP_PORT=587
   SMTP_SECURE=false
   SMTP_USER=alamat-pengirim@domain-anda
   SMTP_PASS=<app password / kredensial SMTP>
   EMAIL_FROM=alamat-pengirim@domain-anda
   VERIFY_EMAIL_TO=alamat-inbox-anda@domain-anda
   ```
   Catatan Gmail/Workspace: gunakan **App Password**, bukan password akun.
2. **Menjalankan verifikasi email setelah konfigurasi tersedia:**
   `cd backend; npm run verify:email`. Bila `SENT` tercapai, tetap periksa inbox
   (termasuk folder spam) — skrip menandai bahwa bukti masuk inbox bersifat
   manual. Setelah itu jalankan `npm run retry:emails` untuk tiket lama yang
   masih `PENDING`.
3. **Melakukan pengujian pada perangkat fisik** Android/iOS (formulir
   pendaftaran, validasi email, banner status email, tampilan tiket) bila
   perangkat tersedia.
4. **Opsional:** menjalankan `npm run cleanup:e2e-data` bila pernah menjalankan
   uji E2E dengan versi lama skrip (data uji lama akan dibersihkan).

---

## F. Kesimpulan Kesiapan Aplikasi

**Siap dengan catatan.**

- Implementasi pengiriman tiket PDF melalui email **sudah berfungsi** di seluruh
  alur yang dapat diuji di lingkungan ini: field email wajib & terkunci,
  validasi dua lapis, email peserta tersimpan pada record yang benar, tiket
  terbit sesuai aturan gratis/berbayar, PDF memakai desain & orientasi
  penyelenggara, pengiriman asinkron tanpa email ganda, status jujur, dan
  mekanisme kirim ulang tanpa tiket/transaksi baru.
- Seluruh pengujian internal **PASS**: 226 test backend, 317 test Flutter,
  `flutter analyze` bersih, 38 pemeriksaan alur tiket, 17 pemeriksaan email
  lokal, 8 pemeriksaan antrean asinkron, 13 pemeriksaan PDF, 32 pemeriksaan E2E,
  migrasi & schema sinkron, jumlah data tidak berubah.
- **Belum siap untuk klaim "email diterima di inbox"** sampai pengguna mengisi
  kredensial SMTP nyata dan memverifikasi inbox (D.1) serta melakukan uji
  perangkat fisik (D.4). Kedua hal tersebut berada di luar kendali AI dan
  dilaporkan sebagai **BLOCKED**, bukan PASS.
