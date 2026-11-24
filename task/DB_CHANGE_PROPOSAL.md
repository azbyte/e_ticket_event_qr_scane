# Proposal Perubahan Database — Untuk FINISHING (belum disetujui / belum diimplementasikan)

> **OTORITAS DATABASE TETAP BERLAKU — TETAPI NON-BLOCKING UNTUK PEKERJAAN NON-DB.**
> Batas wewenang schema/migration/SQL/seed di dokumen ini adalah batas nyata (bukan
> approval gate teknis) dan tetap dipatuhi: Developer 1–3 tidak mengubah database,
> kebutuhan DB dicatat sebagai proposal di sini. Namun batas ini **tidak
> menghentikan task**: sesuai prosedur eksekusi pada
> [`PEMBAGIAN_TUGAS_FINAL.md`](PEMBAGIAN_TUGAS_FINAL.md) §1.1, seluruh bagian yang
> tidak memerlukan perubahan DB wajib diselesaikan, diuji, dan dilaporkan; hanya butir
> yang benar-benar bergantung perubahan DB yang ditandai NOT RUN disertai proposal
> dan alasan spesifik. Jangan memakai status "PROPOSAL ONLY / BLOCKED" sebagai
> alasan menghentikan acceptance lain.


**Status:** PROPOSAL SAJA. Tidak memberi izin mengubah schema/migration/SQL/seed. Developer 1–3 dilarang mengimplementasikan. Owner FINISHING dan gate harus ditetapkan eksplisit sesuai [`FINISHING_AUTHORITY.md`](FINISHING_AUTHORITY.md).

## DP-01 — kompatibilitas one-order/one-ticket dan no-assisted

- **Dasar PRD:** §§7, 8, 13; AC-03, AC-04. Satu order berisi satu event/kategori/item quantity 1/attendee dan maksimum satu ticket; tidak assisted; harga order snapshot tidak berubah.
- **Bukti schema saat ini:** `EventOrder` menyimpan `assistedByMemberId` FK ke `EventMember` dan `registrationMethod` enum `SELF_SERVICE/ASSISTED`; `OrderItem.quantity` adalah `Int`; `Attendee` berelasi ke `OrderItem` yang dapat punya banyak attendee. Initial migration membuat kolom/enum/FK dan tidak tampak constraint `quantity = 1`/satu attendee per item dari bagian yang diperiksa.
- **Bukti SQL/runtime:** `createOrder` menerima satu atau banyak UUID ticket type dan quantity sampai 20; SQL function `create_event_order` memproses banyak item, quantity/attendee array dan batas total 20, memeriksa per-ticket max-per-order; model event permission memuat `ASSIST_REGISTRATION`.
- **Proposal untuk FINISHING:** tentukan apakah compatibility diwujudkan dengan validasi DB/runtime-only atau perlu invariant DB. Jika DB diperlukan, evaluasi check/unique/foreign-key/enum/kolom yang memaksa satu item/quantity/attendee dan menonaktifkan assisted. Jangan menghapus kolom/enum/FK sebelum impact dan histori data terbukti.
- **Objek terdampak (berdasarkan bukti):** `event_orders.assisted_by_member_id`, `event_orders.registration_method`, enum `RegistrationMethod`, `order_items.quantity`, relasi `attendees.order_item_id`, `event_member_permissions.permission`/`EventPermission.ASSIST_REGISTRATION`; fungsi SQL `create_event_order` pada migration order/payment dan salinan revisinya.
- **Dampak data lama:** order multi-item, quantity >1, banyak attendee per item, assisted registrations dan permission historis mungkin ada. Tidak boleh dihapus/coerce; perlu read-only inventory di disposable/copy atau dataset yang disetujui, rencana backfill/retention, serta kompatibilitas API lama. Status data produksi belum diperiksa dalam Fase 1B.
- **Migration/test:** migration forward/backward-compatible yang direview hanya jika disetujui; existing order snapshot tetap dapat dibaca; rejection quantity !=1/multiple item/assisted; duplicate/replay idempotency; transaction rollback; concurrent quota; fixture sebelum/sesudah migration; Prisma validate dan diff pada environment test terisolasi; bukan live DB.
- **Dependency:** C-01/C-02 untuk biaya/authorization tetap keputusan terpisah; G-01 DB compatibility owner FINISHING. D3 dapat mengerjakan logic dalam allow-list yang tidak membutuhkan DB/shared route, tetapi penerimaan penuh menunggu validasi akhir bila schema masih menerima state bertentangan.

## DP-02 — Event auto-publish dan suspend sesuai lifecycle PRD

- **Dasar PRD:** §§3–5, 10, 13; AC-01. Event valid auto Published tanpa approval Admin; invalid non-public dengan error; suspend pascapublikasi menutup order baru dan memiliki alasan/audit.
- **Bukti:** `events.status` enum memuat `PENDING_REVIEW`, `REVISION_REQUESTED`, `APPROVED`, `REJECTED`, `PUBLISHED`, `SUSPENDED`; event moderator table/function dan SQL `moderate_event` menyimpan decision/note. `create_event_order` mensyaratkan `is_public` serta status APPROVED/PUBLISHED.
- **Proposal:** FINISHING menilai apakah kolom/status dapat direpresentasikan dengan status yang sudah ada plus `is_public`, atau perlu perubahan status/constraint/index/function. Harus memastikan semua query/API/admin moderation/order gating memakai satu state machine dan event suspended tidak menerima order. Tidak membuat `auto_publish_at` atau field baru tanpa kebutuhan terverifikasi.
- **Objek terdampak (kemungkinan; perlu inventaris penuh):** `events.status`, `events.is_public`, `review_note`, `submitted_at`, `event_moderations`, SQL function `moderate_event`, order function/status gates, index/check constraints terkait event lifecycle.
- **Dampak data lama:** event PENDING_REVIEW/APPROVED/REJECTED/REVISION_REQUESTED/SUSPENDED mungkin ada. Mapping state tidak boleh otomatis mempublikasikan event invalid atau membuka checkout pada suspended event. Perlu data-state audit read-only dan keputusan operator.
- **Migration/test:** transition matrix, event visibility/API authorization, suspend reason/audit, order create blocked under race after suspend, backfill no publish by assumption, SQL function integration di DB disposable; schema diff/rollback review.
- **Owner:** D2 owns event-specific non-shared source per allow-list, tapi route/admin shared serta DB dimiliki scope yang perlu amendment/FINISHING. D2 tidak dapat memenuhi DB change sendiri.

## DP-03 — ticket ücretsiz/berbayar dan homogeneity kategori

- **Dasar PRD:** §§7–8, 13; AC-06/07. Semua kategori dalam event sama-sama gratis atau berbayar; gratis langsung mengeluarkan tiket sesudah validasi; paid baru issue setelah PAID; harga item order terkunci.
- **Bukti schema/data model:** `ticket_types.price`, `event_orders.subtotal/service_fee/commission/grand_total`, `order_items.unit_price/subtotal`, payment record/status, tickets. SQL saat ini menerbitkan PAID otomatis ketika `grand_total=0`, tetapi formula fee snapshot dapat membuat total order nol/positif sesuai implementasi C-01 yang belum jadi keputusan produk.
- **Proposal:** cek constraint/transaction untuk mencegah campuran kategori free/paid satu event serta atomic issue/free order; jangan menjadikan detail service fee/commission implementasi sebagai keputusan. Order item harga snapshot dan sejarah harus dipertahankan.
- **Objek terdampak:** `ticket_types.event_id/price`, `order_items.ticket_type_id/unit_price/subtotal`, `event_orders` payment state, `order_payments`, `tickets`, SQL `create_event_order`/`simulate_event_payment`.
- **Dampak data lama:** event dengan kategori campuran, free order dengan service fee/non-zero total, ticket/order status kombinasi mungkin ada; inventory dan keputusan mapping perlu dilakukan pada test copy, tidak diubah otomatis.
- **Gate:** C-01 formula fee dan aturan fee/komisi free order tetap OPEN; jangan menetapkan DB behavior final berdasarkan migration. C-02 guest payment auth juga tetap OPEN.
- **Tests:** reject create/update mixed category; free order payment state/ticket issuance tanpa paid simulation; paid failure/expiry no ticket; paid success exactly-one ticket; price immutable per order; quota concurrency; rollback.

## DP-04 — penyimpanan `attendees.custom_fields` oleh RPC order

- **Dasar PRD:** §7 (form registrasi dapat dikonfigurasi Organizer), AC-04; kontrak data `attendees.custom_fields` pada `TAHAP_2/INTEGRATION_CONTRACT.md` §1.4.
- **Bukti:** fungsi `public.create_event_order` (migration `20261113000400` dan revisi `20261118000300`/`20261118000400`) hanya menulis `attendees(order_item_id, name, email, phone)`; kolom `attendees.custom_fields` (JSON) ada di schema tetapi tidak pernah diisi oleh RPC.
- **Penanganan sementara (tanpa DB):** `orderController.createOrder` menjalankan RPC dan `UPDATE attendees SET custom_fields` di dalam satu transaksi `BEGIN/COMMIT` pada koneksi yang sama, sehingga atomik. Validasi jawaban dilakukan sebelum RPC agar tidak ada order tanpa field wajib.
- **Proposal untuk FINISHING:** bila diinginkan satu langkah atomik penuh di database, tambahkan parameter `p_custom_fields JSONB` pada `create_event_order` (atau isi `attendees.custom_fields` dari `p_attendees`) pada migration baru. Perubahan bersifat aditif; signature lama harus tetap kompatibel atau diberi versi fungsi baru.
- **Dampak data lama:** order yang dibuat sebelum perubahan tidak memiliki `custom_fields`; tetap valid karena kolom nullable. Tidak ada backfill otomatis.
- **Test yang disarankan:** create order dengan field wajib kosong (ditolak), field select di luar opsi (ditolak), jawaban tersimpan dan terbaca kembali, rollback saat penyimpanan gagal.

## Proses review FINISHING yang disyaratkan

Untuk setiap proposal di atas, sebelum perubahan: pemilik produk mengesahkan acceptance terkait; maintainer menetapkan penanggung jawab FINISHING; gate FINISHING dibuka; proposal, data impact, baseline dan file scope disetujui; disposable DB/no secrets tersedia; reviewer serta forward/rollback plan dicatat. Sampai terpenuhi, status tetap **BLOCKED / PROPOSAL ONLY**.