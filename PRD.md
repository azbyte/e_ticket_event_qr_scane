# PRODUCT REQUIREMENTS DOCUMENT (PRD)
# E-Ticket Event Platform

- **Versi:** 2.2 — Rekonsiliasi keputusan produk
- **Tanggal:** 2026-11-20
- **Status:** Sumber acuan kebutuhan; keputusan CONFIRMED dan OPEN DECISION dipisahkan di §15. Task yang tidak terdampak keputusan terbuka dapat berjalan setelah gate tahap yang relevan lulus.
- **Platform:** Flutter Android dan Flutter Web (responsive)
- **Backend/database target:** Node.js + Express; PostgreSQL
- **Role:** Admin, Organizer, Staff (membership event), Participant (guest)
- **Pembayaran MVP:** Simulasi Virtual Account; ini satu-satunya proses bisnis yang disimulasikan.
- **Model bisnis disahkan:** biaya layanan Rp5.000 dan komisi 5%; dasar perhitungan/penanggung belum ditetapkan.

## 0. Sumber kebenaran dan status

Keputusan produk final 2026-11-20 dalam mandat rekonsiliasi adalah sumber utama. Dokumen ini (`PRD.md`) menjadi acuan kebutuhan aktif. Dokumen backup/arsip dan audit lama hanya sumber sejarah; schema dan implementasi adalah bukti kondisi teknis, bukan requirement produk. Bila source berbeda, requirement produk di bawah tetap berlaku dan gap dicatat, tidak disesuaikan diam-diam.

- **CONFIRMED:** keputusan produk yang telah ditetapkan.
- **OPEN DECISION:** keputusan pemilik produk yang belum ditetapkan.
- **TECHNICAL GAP:** produk sudah jelas, tetapi kontrak/implementasi belum tersedia atau terverifikasi.
- Data mock/in-memory, hardcoded business logic atau fallback demo bukan kebutuhan produk dan bukan bukti penerimaan. Akun demo harus merupakan record database seeded eksplisit.

## 1. Ringkasan, tujuan, dan batas produk

E-Ticket Event mengelola event, tiket, pendaftaran publik, pembayaran simulasi, penerbitan e-ticket, dan check-in. Tujuan produk adalah memberi Organizer alur pengelolaan event; Participant guest alur pembelian yang tidak memerlukan akun; Staff akses terbatas per event; dan Admin alat pengawasan platform.

**MVP:** aplikasi Flutter Android/Web; akun Organizer/Admin/Staff; event yang lolos validasi otomatis langsung dipublikasikan; kategori tiket dan form dinamis; brosur opsional; desain tiket default/template; link pendaftaran publik; invitation Staff; satu order/satu peserta/satu tiket; pembayaran simulasi backend; e-ticket/QR; scanner/check-in online; daftar peserta, ekspor dan laporan dasar; pengelolaan paket serta fee/komisi dengan batas konfirmasi pada §8.

**Bukan MVP:** offline scanner/sinkronisasi; payment gateway riil; registrasi manual/assisted; akun/dashboard Participant; persetujuan Admin sebelum publikasi. Fitur Post-MVP lain harus memiliki scope dan acceptance criteria terpisah.

## 2. Aktor dan hak akses

### 2.1 Admin

Tujuan: mengelola operasi platform. Dapat memantau akun, seluruh event dan transaksi; mengelola paket/konfigurasi yang telah ditetapkan; menangani laporan; melihat audit/pendapatan; dan menangguhkan event bermasalah dengan alasan tercatat. **Admin tidak menyetujui/menolak event sebelum publikasi.** Hak admin hanya melalui autentikasi dan otorisasi backend.

### 2.2 Organizer

Tujuan: membuat dan mengelola event miliknya. Dapat mengatur informasi event, kategori/kuota/periode jual, form dinamis, brosur opsional, template tiket, link publik, melihat peserta/order/check-in/laporan, serta mengundang/mencabut Staff dan mengatur permission per event. Tidak dapat mengakses/mengubah event Organizer lain atau fungsi Admin.

### 2.3 Staff

Staff adalah akun pengguna yang memperoleh membership melalui undangan Organizer untuk event tertentu, **bukan akses global**. Dapat membuka scanner langsung setelah invitation diterima, akun terautentikasi, membership aktif dan permission check-in tersedia; akses data peserta/order/laporan hanya jika permission terkait diberikan. Backend memeriksa event scope dan permission pada setiap request. Staff tidak dapat membuat event, mengakses event lain tanpa undangan, atau mendaftarkan peserta.

### 2.4 Participant

Participant tidak wajib memiliki akun, tidak memiliki dashboard, dan memakai link pendaftaran publik. Data kontak/form tersimpan terkait event/order. Participant mengakses status order dan tiket melalui mekanisme guest terbatas; mekanisme otorisasi untuk simulasi pembayaran masih C-02.

## 3. Event dan publikasi otomatis

Organizer membuat Draft, mengisi data wajib, lalu meminta validasi/publikasi. Sistem memeriksa kelengkapan dan aturan validasi. **CONFIRMED:** bila valid, event dipublikasikan otomatis tanpa menunggu persetujuan Admin; bila tidak valid, tetap non-publik dan sistem mengembalikan kesalahan yang dapat diperbaiki. Admin tetap dapat mengawasi dan menangguhkan event pascapublikasi sesuai kebijakan dengan alasan tercatat.

**Acceptance criteria:** event invalid tidak muncul di publik dan menyebutkan masalah; event valid menjadi Published tanpa aksi Admin; event suspended tidak menerima order baru; akses edit/pantau dibatasi owner/Admin sesuai hak. Status warisan `PENDING_REVIEW`, `APPROVED`, `REVISION_REQUESTED`, `REJECTED` bukan langkah produk MVP.

## 4. Kategori tiket dan form pendaftaran

Kategori memuat nama/deskripsi, harga rupiah (nol untuk gratis), kuota, periode penjualan, dan status aktif/nonaktif. Peserta hanya dapat memilih kategori aktif pada event Published, dalam periode jual dan dengan kuota. Kategori nonaktif menghentikan order baru. Order yang sudah tercatat dapat diselesaikan hingga expiry sesuai order/hold yang berlaku; setelah expiry tidak dapat dibayar dan hold dilepas. Masa expiry spesifik adalah TECHNICAL GAP, bukan angka yang boleh diasumsikan.

Organizer mengatur field form dan urutannya. Field required, tipe/format, dan nilai harus divalidasi backend. Form order mengumpulkan data satu peserta untuk satu tiket.

Brosur event opsional dan dapat ditampilkan pada halaman publik. File upload/storage, format/ukuran dan kebijakan penyimpanan harus divalidasi; implementasi storage aktual belum terverifikasi (G-07).

**Acceptance criteria:** inactive/out-of-window/sold-out category tidak membuat order; field wajib/format salah ditolak server dengan error yang dapat ditindaklanjuti; form publik mengikuti konfigurasi event; brosur tidak wajib untuk publikasi/registrasi.

## 5. Desain e-ticket

Sistem menyediakan template desain dan desain default. Organizer dapat memilih template yang tersedia, bukan editor bebas. Informasi peserta/event/kategori/order dihasilkan dari record backend. Setiap ticket menampilkan QR unik serta informasi event/peserta secukupnya. Desain default digunakan bila Organizer tidak memilih template lain. Integrasi template/render, versi desain dan upload custom bila diaktifkan masih TECHNICAL GAP; keberadaan layar bukan bukti fitur selesai.

## 6. Dua link berbeda

### 6.1 Link pendaftaran publik

Dibuat untuk event Published dan dibagikan ke Participant. Menampilkan informasi event/brosur/kategori/form dan memungkinkan checkout tanpa akun. Tidak memberi akses ke data privat atau fungsi Staff.

### 6.2 Invitation/link Staff

Organizer membuat invitation untuk email dan satu event, menetapkan permission, expiry dan kemampuan revoke. Invitation bukan link scanner publik dan bukan pengganti autentikasi. Acceptance memerlukan akun login dengan email yang cocok, token valid belum dipakai/expired/revoked, lalu membuat membership Staff pada event tersebut. Sesudah autentikasi serta otorisasi server berhasil, Staff dengan permission scanner diarahkan langsung ke scanner event itu. Invitation invalid/expired/revoked, user/email tidak cocok, membership dicabut atau permission kurang harus ditolak.

**TECHNICAL GAP:** route acceptance ada di backend, tetapi deep-link Flutter dan redirect langsung scanner belum terverifikasi (G-04).

## 7. Registrasi, order, dan daftar peserta

Seluruh peserta mendaftar sendiri melalui link publik; tidak ada registrasi manual Organizer/Staff atau assisted registration. Participant tidak perlu login.

**CONFIRMED:** Participant tidak wajib memiliki akun; pendaftaran hanya melalui tautan publik. Organizer/Staff tidak mendaftarkan peserta secara manual atau assisted dalam MVP. Form registrasi dapat dikonfigurasi Organizer.

**CONFIRMED satu order = satu tiket:** tepat satu event, satu kategori, satu Attendee, satu OrderItem dengan quantity 1, dan paling banyak satu ticket terbit. Tidak ada multi-ticket/multi-attendee dalam satu order. Peserta boleh membuat order terpisah berulang kali selama registrasi masih terbuka dan syarat event/kategori/kuota berlaku.

Order menyimpan nomor pendaftaran/order stabil saat dibuat. Perubahan status payment tidak membuat nomor baru. Backend menentukan harga dan memvalidasi event Published, kategori, masa jual, kuota, data form dan idempotency. Harga yang dikunci pada order yang sudah dibuat tidak berubah; harga/order state tidak dapat diubah sepihak oleh frontend.

Daftar peserta dan Excel/CSV: peserta dengan payment PAID lebih dahulu, lalu urut berdasarkan nomor pendaftaran asli; aturan sama untuk tampilan dan ekspor. Nomor registrasi tidak berubah akibat payment status. Peserta pending/expired/cancelled dapat ditampilkan dengan status jelas.

**Acceptance criteria:** input quantity selain 1, banyak kategori, atau banyak attendee ditolak; harga berasal dari server; retry idempotent tidak membuat order/tiket baru; order number stabil; list dan export memakai urutan identik.

## 8. Pembayaran dan model bisnis

Pembayaran MVP adalah simulasi VA. Payment record/status disimpan dalam database dengan status yang membedakan keadaan payment seperti pending, paid, failed, dan expired sesuai kontrak yang disetujui. Hanya backend yang memvalidasi dan mengubah status; frontend tidak dapat memaksa PAID. Kebijakan cancel order dan transisi statusnya adalah keputusan tersendiri; jangan menyamakan cancel order dengan status simulasi payment. Pembayaran sungguhan, provider/bank/webhook tidak termasuk MVP.

**CONFIRMED:** semua kategori tiket dalam satu event harus sama-sama gratis atau berbayar. Order gratis tidak menjalani pembayaran berbayar dan tiketnya langsung diterbitkan sesuai validasi backend. Untuk order berbayar, ticket diterbitkan hanya setelah simulasi payment berhasil/PAID. Harga item yang telah dicatat pada order tidak berubah jika harga kategori berubah kemudian.

Kedaluwarsa order/payment harus membedakan state order/payment dan melepas reservasi sesuai kontrak; durasi expiry masih TECHNICAL GAP. Pembatalan order dan transisi statusnya belum memiliki kebijakan produk lengkap. Refund berarti pengembalian dana sebenarnya dan tidak tersedia pada MVP (pembayaran gateway riil/refund-accounting Post-MVP); perubahan status simulasi bukan refund.

Setelah payment sukses PAID, backend memicu penerbitan satu ticket dan QR yang terkait dengan attendee, event, kategori dan order. Pembayaran gagal/expired tidak menerbitkan ticket. Email/link adalah sarana delivery; status terkirim tidak boleh diklaim tanpa konfirmasi provider.

### 8.1 Biaya layanan/komisi

**CONFIRMED:** nominal biaya layanan Rp5.000 dan rate komisi 5% berlaku sebagai nilai model bisnis transaksi tiket. Ini belum menetapkan formula maupun pemikul biaya.

**OPEN DECISION C-01:** dasar pengenaan Rp5.000 dan 5%, pihak penanggung, apakah biaya ditambahkan ke tagihan atau dipotong dari payout, hubungan paket, aturan rounding, dan perlakuan terhadap pembatalan. Tiket gratis tidak dikenai pembayaran tiket; perlakuan fee/komisi untuk order gratis tetap menunggu keputusan, tanpa mengubah aturan tiket gratis langsung diterbitkan. Jangan menurunkan formula dari migration/source atau menentukan `grand_total`/net payout sebelum keputusan. Implementasi existing yang menyimpan snapshot bukan pengganti keputusan produk.

Admin mengelola katalog paket; Organizer dapat menggunakan paket sesuai aturan yang akan ditetapkan. **OPEN DECISION C-03:** apakah subscription/plan gate wajib di MVP, harga, periode, batas fitur/kuota, entitlement, status masa tenggang dan hubungan paket dengan fee. Jangan mengarang nominal/batas/hak akses. Selama keputusan ini terbuka, jangan mengimplementasikan paywall/entitlement baru; fungsi paket yang tidak bergantung pada keputusan dapat diaudit/dikerjakan sesuai task dan kontrak yang sudah disahkan.

### 8.2 Guest payment authorization

Backend aktual memakai optional JWT dan guest order access token untuk owner/order-scoped access; simulasi payment menerima `order_id` dan `simulate_success`. **OPEN DECISION C-02:** apakah guest access token boleh menjadi otorisasi bagi guest untuk membaca status dan meminta simulasi pembayaran tanpa JWT, atau diperlukan mekanisme lain. Participant tetap tidak diwajibkan memiliki akun. Apa pun keputusan akhirnya, token guest harus berentropi tinggi, di-hash saat disimpan server, dibatasi satu order, tidak berada pada URL/log, dan tidak membuka order lain. JWT digunakan untuk operasi akun. Endpoint refresh JWT tidak ditemukan pada routes yang diperiksa (G-03).

## 9. QR Scanner dan check-in online

MVP scanner wajib online; validasi/check-in memerlukan respons backend. Saat jaringan/API tidak tersedia, tidak ada check-in lokal yang dianggap sukses; tampilkan error dan izinkan retry online. **Offline scanner dan sinkronisasi adalah Post-MVP**, bukan konfirmasi terbuka untuk MVP.

QR mengandung token opaque unik, tidak berisi PII/payment data. Server memetakan token ke ticket dan memvalidasi: token/ticket ada; event cocok; order/payment PAID atau keadaan gratis sah; ticket belum used/cancelled/revoked; user terautentikasi dan memiliki owner/Admin access atau membership Staff aktif dengan permission event. Check-in dicatat atomik; scan ganda ditolak. Hasil scan hanya menampilkan informasi minimum kepada petugas berizin.

**Acceptance criteria:** token palsu/tidak dikenal, wrong event, unpaid, invalid/used/revoked ticket, unauthorized user dan permission kurang ditolak tanpa record check-in; scan valid membuat satu check-in; request bersamaan hanya satu sukses; scan kedua menyatakan already used. Backend source saat ini memakai bearer ticket code; token hash belum terbukti dipakai scanner (G-05), jadi keamanan belum dapat dianggap selesai hanya karena QR tersedia.

**Post-MVP offline:** rancangan kelak harus memutuskan dataset lokal, expiry validasi, status “belum diverifikasi server”, idempotency, dedup/conflict multi-device dan sync. Tidak ada optimistic acceptance di MVP.

## 10. Alur end-to-end MVP

1. Organizer register/login; membuat Draft dan mengatur event/kategori/form/brosur/template.
2. Backend validasi; publish otomatis bila lolos, jika gagal kembalikan error yang dapat diperbaiki.
3. Organizer membagikan public link dan invitation Staff terpisah.
4. Participant guest mengisi satu registrasi dan membuat satu order/satu tiket.
5. Backend membuat order/payment record, nomor stabil dan akses order terbatas; client tidak menentukan harga/status.
6. Participant menjalankan simulasi; backend menetapkan hasil. Hanya PAID menerbitkan tiket/QR.
7. Ticket diakses melalui link/email; non-delivery ditampilkan jujur.
8. Staff menerima invitation, login/accept, diotorisasi dan membuka scanner event.
9. Scanner validasi QR online ke backend; check-in tersimpan satu kali.
10. Organizer memantau peserta/order/sales/check-in, laporan dan ekspor dengan paid-first lalu nomor registrasi.
11. Admin memantau platform, paket, transaksi/komisi dan laporan; dapat suspend event pelanggar, bukan approve publikasi.

Kegagalan input, kuota, sale window, auth, ownership, event scope, payment atau API ditolak dengan state/error jelas. Mock/in-memory bukan fallback bisnis.

## 11. UI/UX dan platform

Flutter Android dan Flutter Web. UI konsisten, sederhana, bahasa Indonesia; loading, empty, error, unauthorized, retry dan success ditampilkan relevan. Alur kritis usable pada layar sempit maupun lebar tanpa overflow/aksi terpotong; keyboard/focus/semantics dan kontras diperhatikan.

**TECHNICAL GAP G-10:** browser target, viewport minimum/breakpoint belum ditetapkan; jangan mengarang angka viewport.

## 12. Arsitektur dan kontrak teknis

Kondisi repository yang diperiksa: Flutter/Dart Android/Web dengan Provider, HTTP dan secure storage; backend Node.js CommonJS/Express 4; PostgreSQL query runtime melalui `pg`; Prisma schema/migrations lokal adalah tooling schema/migration, bukan Prisma runtime. API/database adalah sumber kebenaran. Backend memeriksa auth, ownership, membership dan permission; kontrol UI bukan boundary keamanan. Detail stack diperiksa 2026-11-20 dan perlu ditinjau ulang jika source berubah.

### 12.1 Route backend terverifikasi 2026-11-20

Route dari `backend/src/app.js` dan routers yang dibaca; route bukan bukti UX end-to-end selesai. Payload/status lengkap yang belum disebut tetap TECHNICAL GAP.

| Tujuan | Route aktif dan catatan |
|---|---|
| Auth | `POST /api/auth/register`, `/login`, `GET/PUT /api/auth/me`, `POST /api/auth/logout`. Register menetapkan Organizer; tidak ditemukan refresh endpoint. |
| Event | `GET /api/events/public`, `/mine`, `/:id`; `POST /api/events`, `PUT/DELETE /:id`; `POST /api/events/:id/submit-review`. Submit-review ada di source dan bertentangan dengan auto-publish final. Auto-publish route/logic belum ditemukan. |
| Ticket type | `GET /api/events/:eventId/ticket-types`; `POST/PUT/DELETE /api/events/:eventId/ticket-types/:ticketTypeId`. |
| Order | `POST /api/orders`, `GET /api/orders`, `GET /api/orders/:id`. Create/get guest mendukung optional JWT/token. Source menerima quantity >1; harus diselaraskan menjadi quantity=1. |
| Payment | `GET /api/payments/:orderId`, `POST /api/payments/simulate`; optional JWT dan order owner/guest token; simulasi dibatasi konfigurasi environment non-production. Body aktif memuat `order_id` dan boolean `simulate_success`. Guest policy C-02. |
| Ticket | `GET /api/tickets/my-tickets`, `GET /api/tickets/:id`, `POST /api/tickets/:id/email`, `POST /api/tickets/validate`, `POST /api/tickets/verify`. Validate/verify memerlukan JWT/permission event. Tidak ada public create-ticket route. |
| Check-in | `POST /api/check-ins`, `GET /api/check-ins/events/:eventId/check-ins`, `POST /api/check-ins/sync`. Sync route tidak berarti offline termasuk MVP. |
| Invitation | `POST/GET/DELETE /api/events/:eventId/invitations`, `POST /api/invitations/:token/accept`, `GET /api/invitations/me`; acceptance JWT dan email cocok. |
| Plan/subscription/Admin | `/api/plans`, `/api/subscriptions`, `/api/admin`, `/api/revenue`; akses mengikuti middleware/role source. Tidak ada event approval sebagai kebutuhan produk. |

Daftar API historis lain bersifat non-normatif jika berbeda dari tabel ini. Jangan mengarang route/payload. Contract tests dan request/response lengkap perlu diperbarui setelah backend selaras dengan requirement.

### 12.2 Model data konseptual

User (Admin/Organizer/Staff) → Event; Event → TicketType, form fields, template, invitation, EventOrder; satu EventOrder → tepat satu OrderItem quantity=1, satu Attendee, Payment, dan paling banyak satu Ticket; Ticket → QR token/check-in; invitation acceptance → EventMember scoped ke Event dan EventMemberPermission; Plan/Subscription/PlatformTransaction mendukung model bisnis.

Schema Prisma aktual memiliki `OrderItem.quantity`, assisted fields/permission serta event moderation statuses lama dan karenanya tidak memenuhi model produk. Model di atas adalah requirement konseptual, bukan usulan schema/migration final. Penyesuaian teknis G-01/G-02 diperlukan.

## 13. Aturan bisnis kanonis

1. Satu order hanya satu tiket, satu peserta dan satu kategori.
2. Registrasi hanya lewat public link; Participant tanpa akun/dashboard; no manual/assisted registration.
3. Ticket type inactive/di luar masa jual/sold-out tidak menerima order baru.
4. Order valid yang sudah dibuat mempertahankan harga saat order dibuat. Order/payment hanya dapat diselesaikan sesuai status dan expiry yang ditetapkan server; durasi expiry TECHNICAL GAP. Pembatalan order harus dibedakan dari expiry; kebijakan pembatalan belum ditetapkan. Refund uang sebenarnya bukan bagian MVP.
5. Nomor registrasi stabil dan tidak berubah oleh payment status.
6. List dan ekspor: PAID dahulu, kemudian nomor registrasi asli.
7. Payment status hanya diubah backend; ticket berbayar hanya setelah PAID; tiket gratis langsung diterbitkan backend setelah validasi tanpa pembayaran berbayar. Satu event tidak mencampur kategori gratis dan berbayar.
8. QR check-in wajib online, validasi backend, event scope dan permission; satu ticket tidak dapat check-in berulang.
9. Staff hanya event invitation/membership-nya dan permission yang diberikan.
10. Validasi event otomatis; jika lolos auto-publish tanpa Admin approval.
11. Biaya layanan Rp5.000 dan komisi 5% adalah nominal/rate CONFIRMED; formula/penanggung terkait OPEN DECISION C-01.
12. Mock/hardcoded data tidak menjadi aturan bisnis atau bukti MVP.

## 14. MVP dan Post-MVP

**MVP end-to-end:** seluruh alur §§2–13 berjalan melalui backend/database, termasuk auto-publish, event/ticket setup, public guest checkout quantity 1, simulated payment, ticket/QR, Staff invitation scoped, online check-in, peserta/ekspor dan Admin monitoring. Offline tidak dibutuhkan untuk lulus. Paket/komisi mengandung nilai confirmed; perhitungan penuh dibatasi C-01/C-03.

**Post-MVP:** offline scanning/queue/sync; payment gateway, refunds/accounting; SMS/WhatsApp/reminders; bulk invitations; advanced analytics, custom domain/white label, third-party API, scale architecture. Tidak boleh memindahkan fitur inti MVP ke Post-MVP hanya karena belum terimplementasi.

### Acceptance criteria MVP (ringkas)

| ID | Hasil yang dapat diuji |
|---|---|
| AC-01 Event | Invalid event tidak public; valid event auto Published tanpa admin; suspend menghilangkan pendaftaran baru. |
| AC-02 Role | Cross-owner/event dan unauthorized operation ditolak backend. |
| AC-03 Order | Order tepat satu kategori, attendee dan ticket; quantity selain 1 ditolak; guest dapat mengulang order selama registrasi terbuka; harga dari server dikunci pada order; retry idempotent tidak menduplikasi. |
| AC-04 Participant | Registrasi publik tanpa akun; tidak ada dashboard/assisted flow. |
| AC-05 Staff | Invitation email/event scoped; invalid/expired/revoked/wrong account ditolak; permission per request; scanner langsung setelah authorized. |
| AC-06 Payment | Client tidak mengubah status; pembayaran berbayar hanya simulasi backend; status dibedakan; non-PAID tidak menerbitkan ticket berbayar; guest access sesuai C-02. Order gratis tidak memerlukan payment dan tidak mencampur kategori berbayar pada event yang sama. |
| AC-07 Ticket | PAID menghasilkan paling banyak satu ticket/QR terkait event/order/attendee; order gratis langsung menerbitkan paling banyak satu ticket setelah validasi; non-delivery tidak diklaim sent. |
| AC-08 Scanner | Token/event/payment/status/permission validasi server; satu scan sukses; duplicate/wrong-event/unpaid/unauthorized ditolak; offline tidak sukses. |
| AC-09 List/export | PAID-first lalu nomor registrasi asli pada layar dan ekspor; nomor stabil. |
| AC-10 UI | Loading/empty/error/unauthorized/retry/success jelas; API gagal tidak diganti hasil mock; layar sempit/lebar tetap usable. |

## 15. OPEN DECISION dan TECHNICAL GAP

### OPEN DECISION — keputusan produk yang belum ditetapkan

| ID | Hal | Dampak |
|---|---|---|
| C-01 | Formula dasar untuk Rp5.000 dan komisi 5%; pihak penanggung; biaya ditambahkan atau dipotong; perlakuan fee/komisi terhadap order gratis; rounding; pengaruh paket; perlakuan uang pada pembatalan. Refund uang sebenarnya bukan fitur MVP. | Total/net payout dan formula accounting belum bisa menjadi kontrak. Nilai Rp5.000 dan 5% CONFIRMED; tiket gratis langsung diterbitkan tetap CONFIRMED. |
| C-02 | Apakah guest order access token cukup sebagai otorisasi untuk membaca status dan meminta simulasi pembayaran tanpa JWT, atau memerlukan mekanisme lain. | Payment authorization guest belum final. Participant tetap guest tanpa akun; token harus order-scoped dan terlindungi. |
| C-03 | Apakah subscription/plan gate wajib di MVP; harga, periode, batas fitur/kuota dan entitlement. | Scope billing/entitlement belum final. Jangan mengarang angka atau memblokir pekerjaan non-paket yang tidak bergantung pada keputusan ini. |

Keputusan operasional tambahan yang masih terbuka: durasi expiry pembayaran/order; kebijakan pembatalan order dan transisi statusnya; refund uang sebenarnya tidak tersedia di MVP. Jangan menyamakan simulasi payment status, cancel, expiry, dan refund.

### TECHNICAL GAP — bukan perubahan keputusan produk

| ID | Gap | Dampak |
|---|---|---|
| G-01 | API/schema menerima quantity>1 dan menyimpan assisted fields/permission. | Selaraskan backend, schema, UI, test dengan order quantity 1 dan no assisted. |
| G-02 | Source event masih punya submit-review/moderasi; auto-publication logic belum ditemukan. | Implementasi harus mengikuti auto-publish final. |
| G-03 | Auth routes yang diperiksa tidak memuat refresh-token endpoint. | JWT session lifecycle belum lengkap/terverifikasi. |
| G-04 | Invitation API ada; Flutter deep-link/redirect scanner belum terverifikasi. | Staff flow belum E2E. |
| G-05 | Docs database menyebut scanner memakai bearer code, bukan hash token. | Review token storage/replay/expiry/abuse sebelum produksi. |
| G-06 | Sorting/export Excel/CSV belum terverifikasi sebagai implementasi. | Kriteria list/export belum terpenuhi bukti. |
| G-07 | Upload brosur, dynamic form dan template tiket belum terbukti E2E. | Tetap requirement MVP; implementasi perlu diselesaikan. |
| G-08 | Guest-token/JWT ownership belum diverifikasi pada seluruh akses order/ticket. | Risiko paparan data lintas order. |
| G-09 | Masa expiry, email retry/delivery dan status order perlu cocok dengan API aktual. | UX expiry/retry belum lengkap; jangan mengarang durasi. |
| G-10 | Breakpoint/browser/viewports responsive belum ditentukan. | Developer/test perlu konfirmasi target teknis. |

## 16. Kesiapan pembagian tugas

PRD menjadi sumber kebutuhan aktif. Aturan peserta/order, simulasi payment, tiket gratis/berbayar, homogenitas harga kategori per event, dan harga order terkunci telah CONFIRMED pada versi 2.2 berdasarkan mandat pemilik produk tanggal 2026-11-20. C-01–C-03 tetap OPEN DECISION; task yang bergantung pada formula biaya, guest payment authority atau plan entitlement masih BLOCKED. Developer dapat mengerjakan scope yang independen dari keputusan tersebut hanya setelah gate tahap, ownership, kontrak teknis, dan acceptance terkait dinyatakan lulus. G-01/G-02/G-04/G-06 serta gap lain tetap merupakan dependency teknis, bukan keputusan yang boleh ditebak.

## 17. Rujukan teknis dan batas audit

Dokumen pendukung yang diperiksa: `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `backend/README.md`, `backend/prisma/schema.prisma`, route/controller backend, `apps/lib/app_router.dart` dan layar registrasi/scanner. Implementasi/schema menunjukkan kondisi teknis saat diperiksa, bukan kebutuhan produk. Tidak ada koneksi database, deployment, layanan email/pembayaran, build atau E2E yang diverifikasi saat finalisasi ini.

## 18. Riwayat

### Versi 2.2 — Rekonsiliasi keputusan produk 2026-11-20

- Berdasarkan mandat eksplisit pemilik produk: mengonfirmasi public guest registration, form Organizer configurable, no manual/assisted registration, satu tiket per order dengan repeat orders selama terbuka, harga order terkunci, simulasi payment, status payment, tiket gratis langsung diterbitkan, berbayar setelah PAID, serta kategori event harus seluruhnya gratis atau berbayar.
- Menjaga formula/pihak penanggung Rp5.000 + 5%, guest payment authorization, plan/subscription gate, pembatalan dan expiry sebagai terbuka sesuai bukti yang tersedia; membedakan refund uang sebenarnya dari simulasi status.
- C-01–C-03 tidak otomatis memblokir seluruh task; blocker berlaku pada acceptance/kontrak yang bergantung pada keputusan tersebut.

### Versi 2.1 — Rekonsiliasi 2026-11-20

- Menetapkan `PRD.md` sebagai sumber requirement aktif.
- Menerapkan satu order/satu tiket; public-only registration; no manual/assisted; auto-publish; offline Post-MVP; biaya Rp5.000 dan komisi 5%.
- Menambahkan alur MVP, acceptance criteria dan status konfirmasi/gap.
- Memisahkan keputusan produk dari ketidaksesuaian implementasi.

Versi 2.0 dan 1.2 adalah riwayat; dokumen arsip/audit bukan sumber requirement aktif. Ketentuan lama yang menyimpang dari §0–16 tidak berlaku.
