# Penutupan Technical Gate — Fase 1B

> **STATUS: REFERENSI TEKNIS / HISTORIS — NON-BLOCKING.** Sejak perbaikan workflow
> autonomous, dokumen ini **bukan lagi syarat izin** untuk mulai bekerja. Seluruh
> status `BLOCKED`, "menunggu approval/persetujuan tertulis", "gate", "baseline
> sign-off", dan "authorization" di dalamnya digantikan oleh *Autonomous Execution
> Protocol* pada [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md): perintah
> pemilik proyek adalah otorisasi implementasi, keputusan teknis diambil mandiri,
> OPEN DECISION dan gate teknis dikerjakan dengan interpretasi paling aman lalu
> dicatat sebagai asumsi, dan BLOCKED hanya untuk hambatan eksternal nyata. Isi
> dokumen dipertahankan sebagai referensi analisis dan kontrak. **Pengecualian:**
> catatan Developer 1 Tahap 1 (baris "GO (limited)" dan Amendment A-1) tetap berlaku
> apa adanya, tidak diubah, dan tidak dikerjakan ulang.


- **Tanggal pemeriksaan:** 2026-11-20
- **PRD aktif:** [`../PRD.md`](../PRD.md) v2.2
- **Status:** dokumentasi/evidence review selesai; tidak ada implementation gate yang dinyatakan GO oleh dokumen ini.
- **Batas pemeriksaan:** source route/controller/service/schema/migration terkait dibaca read-only. Tidak ada DB connection, migration execution, perubahan aplikasi, atau operasi Git pengubah state.

## Hasil per gate

### G-01 — quantity dan assisted registration

**Requirement:** PRD §§7, 13 dan AC-03 menetapkan satu order = satu event, satu kategori, satu attendee, satu item quantity 1; tidak ada assisted registration. Pemesanan terpisah boleh berulang saat pendaftaran terbuka. Harga order disimpan saat order dibuat.

**Bukti teknis lokal:**

- `backend/src/controllers/orderController.js:createOrder` menerima object berisi banyak ticket type dan quantity positif sampai 20; attendees dicocokkan dengan total quantity.
- `backend/prisma/schema.prisma`: enum `RegistrationMethod` berisi `ASSISTED`; `EventPermission` berisi `ASSIST_REGISTRATION`; `EventOrder` memiliki `assistedByMemberId` dan `registrationMethod`; `OrderItem` mempunyai quantity; `Attendee` terikat ke item.
- `backend/prisma/migrations/20261113000400_event_orders_payments/migration.sql` memproses banyak item dan quantity, membatasi total 20, menghasilkan banyak attendee/tiket, dan menghitung subtotal berdasarkan quantity.
- `eventController.js` menyimpan `attendee_fields`; event permission normalizer memasukkan `ASSIST_REGISTRATION`.

**Kesimpulan:** **BLOCKED — implementasi tidak sesuai requirement.**

**Perubahan aplikasi yang diperlukan (proposal, belum diimplementasikan):**

1. Backend order validator/controller harus menolak selain tepat satu item dengan quantity 1 dan tepat satu attendee; hanya field yang disetujui boleh diterima.
2. Backend harus menolak assisted order/permission pada jalur MVP, dan checkout harus memvalidasi event/kategori/availability serta harga server-side.
3. Klien public registration harus mengirim satu item/satu attendee dan mendukung order terpisah berulang, tanpa akun Participant.
4. Acceptance test harus meliputi jumlah 0/2, beberapa item, jumlah attendee salah, assisted fields, harga manipulasi, retry/idempotency dan event/kuota invalid.

**Batas D1–D3:** perubahan validator/controller yang diizinkan task dapat dilakukan hanya pada allow-list dan hanya bila tidak bergantung pada DB/shared file. Prisma schema dan migration saat ini masih memungkinkan quantity/assisted. D1–D3 dilarang mengubah DB atau migration. Proposal DB terpisah di [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md); bagian yang tidak dapat diterima oleh schema/runtime baseline **menunggu FINISHING**, dan tidak boleh diklaim PASS sebelum compatibility solution disetujui dan diuji.

### G-02 — event lifecycle

**Requirement:** PRD §§3–5, 10, 13, AC-01: event Draft yang lolos validasi dipublikasikan otomatis tanpa persetujuan Admin; invalid tetap non-public dan actionable; Admin dapat suspend pascapublikasi dengan alasan; suspend menutup order baru.

**Bukti teknis lokal:**

- `eventController.js:createEvent` selalu menyimpan status `DRAFT`, `is_public=false`.
- `eventRoutes.js` menyediakan `POST /:id/submit-review`; controller mengubah status menjadi `PENDING_REVIEW`.
- `eventController.js:getEvents` hanya menampilkan `is_public=true` dengan status `APPROVED` atau `PUBLISHED`.
- `eventMetricsController.js:moderateEvent` dan `backend/src/routes/adminRoutes.js` memberikan Admin keputusan `APPROVED`, `REVISION_REQUESTED`, `REJECTED`, `SUSPENDED`, dengan note pada keputusan tertentu.
- Prisma schema/initial migration memiliki status moderation legacy dan tabel `event_moderations`; migration 002 membuat fungsi `moderate_event`.
- Checkout SQL `create_event_order` hanya menerima event public berstatus `APPROVED`/`PUBLISHED`.

**Kesimpulan:** **BLOCKED — source/API/DB legacy lifecycle berlawanan dengan PRD.**

**Kontrak teknis yang harus dipakai tanpa shared ownership:**

1. `POST /api/events` tetap membuat Draft private.
2. Perubahan event ke public dilakukan setelah validasi server atas field mandatory dan aturan event/kategori; sukses menghasilkan status publik yang disepakati teknis, invalid menghasilkan validation errors dan tidak mempublikasikan.
3. Public event list/detail dan order creation menerima hanya event yang memenuhi keadaan Published menurut kontrak baru; client tidak menentukan status.
4. Admin suspend hanya pascapublikasi, wajib alasan/audit, dan harus membuat order baru ditolak server.
5. Perubahan path/response/status di `backend/src/routes/eventRoutes.js`, admin routes, schema atau SQL tidak boleh dilakukan D2 sendiri. D2 mengerjakan hanya validator/controller/serializer/screen yang berada di allow-list; shared route/state/DB requirement menjadi proposal dan blocker.

Kontrak ini **belum menjadi API versioned/frozen yang implementable** karena route/state semantics existing tidak sesuai dan shared paths locked. Owner teknis harus menyetujui API/status transition amendment sebelum perubahan lifecycle. Proposal DB terkait state/constraints tercatat di proposal; tidak ada migration dibuat.

### G-04 — Staff invitation/deep-link

**Bukti backend:** `eventRoutes.js` expose `POST/GET/DELETE /api/events/:eventId/invitations`; `invitationsRoutes.js` expose `POST /:token/accept` dan `GET /me`. `eventInvitationController.js` menghasilkan raw token acak, menyimpan hash, event/email scope dan permission; default expiry implementation 7 hari, validasi expiry, status, dan email matching dilakukan pada acceptance.

**Bukti Flutter:** `apps/lib/app_router.dart` dan `apps/lib/app.dart` adalah routing aktif. Pencarian source/task aktif tidak menemukan route handler `/invite/<token>` atau pemetaan token invitation ke acceptance lalu redirect event scanner. Hasil ini adalah pencarian terbatas pada source terkait, bukan klaim audit tiap platform launch configuration.

**Kontrak integrasi yang diperlukan:**

- Organizer create invitation untuk event/email/permission; response memuat invitation id, expiry/status dan link/token satu kali. Token hanya dibawa dalam link yang disepakati dan tidak dicatat di log.
- Flutter menerima `/invite/{opaque-token}`, meminta login bila perlu, kemudian POST `/api/invitations/{token}/accept` dengan Bearer JWT; backend mensyaratkan email sama, token pending/belum expired/revoked, lalu mengembalikan event id/title dan permission aktif.
- Setelah sukses, Flutter route ke scanner scoped untuk event itu, dengan server tetap memeriksa membership/permission pada setiap request. Invalid/expired/revoked/email mismatch diberi error yang aman dan retry/return route.
- Owner backend invitation: D1 Tahap 2; UI/route deep-link perlu owner tunggal untuk path router locked. Sampai amendment ownership menunjuk pemilik route/global app changes, D1 melaporkan interface request dan implementasi redirect **BLOCKED**. Tidak ada owner yang sah untuk perubahan router dalam allow-list tahap kini.

Default expiry 7 hari adalah perilaku kode, bukan keputusan expiry pembayaran/order; perubahan durasi invitation tidak diusulkan di sini.

### G-05/G-08 — QR, guest ownership dan authorization

**Yang ditetapkan PRD:** QR opaque tanpa PII; server memeriksa ticket/event/payment/permission; satu online check-in; duplicate/wrong-event/unpaid/unauthorized ditolak (AC-08). Participant guest tidak wajib punya akun. C-02 tetap OPEN dan **bukan** izin payment.

**Bukti teknis:**

- `ticketTokenService.js` membuat token HMAC dari ticket id + issued/purchased time, menyimpan hash SHA-256 dan membandingkan constant-time; presentasi menghilangkan hash. Secret server menjadi dependency keamanan.
- `ticketController.js` membatasi pembacaan guest ticket memakai order id + `X-Order-Access-Token`, melalui `getAuthorizedOrder`, lalu memeriksa ticket belongs-to-order.
- `orderController.js` owner-scope guest order dengan access-token hash. `paymentController.js` memakai optional JWT, tetapi juga mengirim guest token hash ke `simulate_event_payment`; itu adalah perilaku implementasi, bukan keputusan C-02.
- `ticketController.js:verifyTicket` memeriksa permission event dan status used, tetapi pada potongan yang diperiksa tidak memanggil `orderOfTicket` untuk memastikan order PAID sebelum mengubah ticket menjadi used; check-in controller memeriksa PAID pada record-check-in. Ini mismatch yang perlu regression/security review sebelum menyatakan verify/check-in setara.
- `checkInController.js:syncCheckIns` memiliki jalur `OFFLINE_SYNC` yang melakukan write, sementara offline adalah Post-MVP. Route tersedia; keberadaan route tidak mengubah scope PRD.
- `backend/prisma/schema.prisma` dan migration mengandung `tickets.token_hash`, `qr_code_data`, `event_orders.guest_access_token_hash`; live deployment/security tidak diverifikasi.

**Status:** **BLOCKED untuk sign-off keamanan/AC-08**, karena ownership menyeluruh guest token belum dibuktikan, verify/check-in berbeda, token secret lifecycle dan replay tests perlu evidence, serta offline sync route harus dipastikan tidak dianggap acceptance MVP. Bukan klaim bahwa semua jalur rentan; ini batas evidence.

**Test required:** tiket valid paid/free policy yang disahkan; unpaid/unknown/expired/revoked/used; token milik ticket lain; wrong event; organizer/admin/staff permission positif/negatif; duplicate/concurrent check-in; guest order A mencoba order/ticket B; guest read/status/payment disertai keputusan C-02; log tidak memuat bearer token; expiry/key rotation threat review. Tidak boleh menggunakan token nyata/PII.

### G-06 — attendee sorting dan export

PRD §§7/13 dan AC-09 mensyaratkan PAID-first lalu nomor registrasi/order asli yang stabil pada UI dan export, sama filter/urutan.

`checkInController.js:listEventAttendees` saat ini mengurutkan `t.purchased_at DESC`, tidak paid-first dan output yang diperiksa tidak mengandung order number. Order model/migration mempunyai unique `event_orders.order_number`, tetapi PRD menuntut nomor pendaftaran yang ditampilkan stabil; hubungan/presentasi/export belum terbukti. Tidak ditemukan export Excel/CSV route aktif pada router yang diperiksa. Tahap 2 D3 memiliki UI attendee/admin/report paths dan test, tetapi tidak memiliki backend check-in/controller path (D2) atau routes locked.

**Status:** **BLOCKED** untuk persyaratan paid-first/export penuh. Kontrak: D2 owner endpoint yang tersedia/ditetapkan mengembalikan satu dataset terfilter dengan `registration_number` dari order asli, `payment_status`, sort keys/urutan normatif; D3 hanya UI/export menggunakan dataset dan urutan sama pada path miliknya. Namun endpoint/file shared harus dialokasikan melalui amendment; D3 tidak mengedit route/controller milik D2. Test owner-scope, null/free paid status mapping yang disetujui, stable order number selepas status change, deterministic tie-breaker, CSV escaping/column privacy dan row equality UI/export.

### G-07 — dynamic form, brochure, ticket template

PRD §§4–5, 10, AC-03/04: Organizer mengonfigurasi field dan backend memvalidasi jawaban; brochure opsional; ticket default/template.

Backend `events.attendee_fields` JSON ada dalam schema/migration. `eventController.js` menerima array field dengan whitelist sederhana (name/email/phone/organization). Namun tidak ditemukan kontrak bertipe lengkap (label/type/required/options/validation), versi/validasi server yang lengkap untuk jawaban, API penyimpanan brochure/storage, atau ticket-template selection/persistence yang terbukti di source yang diperiksa. `poster_url` ada pada schema/migration dan create event menerima URL, tetapi URL field bukan bukti upload/storage. D1 Tahap 3 memiliki `event_form_screen.dart`/QR display; D2 memiliki public `registration_screen.dart`; model/API shared locked.

**Status:** **BLOCKED** untuk konfigurasi/render yang harus persist dan server validation; brochure tidak punya dependency storage yang disahkan. Kontrak perlu mendefinisikan form schema, field id/type/label/required/options/rules, payload jawaban dan server errors; event create/update GET mengembalikan config yang sama; public form render dari baseline config. Ticket presentation hanya pilihan default/template yang benar-benar ada pada record. Brochure upload menunggu owner teknis menyetujui storage/API dan keamanan file; jangan buat local-only success. Owner D1 config, D2 renderer, shared model/API owner belum ditugaskan (interface proposal diperlukan sebelum task dapat GO).

### G-09/G-10 — expiry, email/retry, responsive

- PRD §§8/15 G-09: durasi expiry payment/order masih terbuka. SQL migration menetapkan caller-supplied `expires_at` dan fungsi expiration; order controller snapshot yang dibaca menghitung 24 jam. Ini implementasi, bukan durasi produk yang disetujui. Jangan mengunci duration/task acceptance sebelum owner memutuskan atau memberi allowance teknis tertulis.
- Pembatalan order/status dan refund nyata berbeda dari payment `FAILED`/`EXPIRED`/`CANCELLED`. Refund nyata Post-MVP; expiry dan cancel policy masih OPEN. Test harus menguji setiap state terpisah setelah policy tersedia, release hold hanya untuk state yang berhak, no ticket for non-PAID paid order, retry/idempotency, harga snapshot.
- Email service memiliki pending/failed/sent, retry endpoint Admin `/api/admin/email/retry`, status transport `disabled/json/smtp`. `json` hanya render lokal; bukan delivery. SMTP belum dibuktikan. Test disabled, transient failure, retry limits/idempotency dan no false SENT; ops owner/admin route dan UI notification dependency perlu bukti.
- PRD G-10 hanya menetapkan narrow/wide usable, tidak angka viewport/browser. Tidak ada breakpoint angka yang boleh dikarang. Test plan: Web viewport sempit/lebar yang pemilik teknis tetapkan sebelum acceptance, Android device/emulator, keyboard/focus, long text, loading/empty/error/unauthorized/retry/success, overflow dan screenshot/evidence tanpa PII.

**Status:** **BLOCKED** untuk expiry/cancel behavior final dan responsive target kuantitatif; boleh melakukan test exploratory UI pada ukuran sempit/lebar non-normatif, tapi tidak menetapkannya sebagai acceptance threshold resmi.

## Ringkasan gate

| Gate | Status | Batas yang dapat dikerjakan tanpa DB |
|---|---|---|
| G-01 | BLOCKED | Audit/validator UI/backend lokal dapat dilakukan pada allow-list; rejection semua request memerlukan implementasi/test dan DB compatibility perlu FINISHING proposal. |
| G-02 | BLOCKED | Validasi independen bisa dikerjakan; lifecycle auto-publish/suspend menunggu owner kontrak/shared API/database. |
| G-04 | BLOCKED sebagian | D1 dapat mengaudit invitation API; deep-link/redirect menunggu penunjukan owner router dan contract. |
| G-05/G-08 | BLOCKED untuk acceptance security | Analisis/test murni yang tersedia boleh; keseluruhan auth/paid/ownership/concurrency evidence belum cukup. C-02 tetap OPEN. |
| G-06 | BLOCKED | UI D3 dapat memakai baseline data yang ada; paid-first/order number/export lengkap menunggu interface owner/D2 amendment. |
| G-07 | BLOCKED | D1 hanya boleh memakai extension point yang benar-benar persist; saat ini contract belum terbukti. Renderer D2 juga bergantung schema payload. |
| G-09/G-10 | BLOCKED untuk keputusan normatif | Email/test terbatas dapat dijalankan di sandbox; expiry dan viewport target perlu keputusan/technical signoff. |

## Catatan koreksi dokumentasi

Audit lama di `task/AUDIT_PROYEK/` menyebut PRD v2.1 dan belum memuat aturan produk v2.2. Perlakukan audit tersebut sebagai snapshot; matriks baru merujuk section PRD v2.2. Jangan memakai tugas historis `task/archive/` sebagai instruction.