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

## DP-05 — rekonsiliasi SQL legacy (`backend/prisma/legacy-migrations/`) ke riwayat Prisma

- **Dasar:** kebersihan/kejelasan sumber kebenaran migration. `AGENTS.md` dan
  `docs/DATABASE.md` menetapkan `backend/prisma/migrations/` sebagai riwayat
  migration aktif, sedangkan SQL legacy (dulu `backend/supabase/migrations/`,
  sekarang `backend/prisma/legacy-migrations/`) dipertahankan untuk
  riwayat/fungsi tertentu. Tujuannya menghindari dua lokasi migration yang
  membingungkan operator.
- **Bukti read-only (26 November 2026):** `npx prisma migrate status` → 9
  migration ditemukan, `Database schema is up to date!`. `_prisma_migrations`
  berisi 9 baris; file legacy `202611040001_role_access_and_event_members.sql`
  **tidak** tercatat di sana. Objek legacy yang sudah tercakup migration Prisma:
  kolom `profiles.username`, `profiles.disabled_at`, `password_hash` nullable,
  tabel `revoked_tokens` + `revoked_tokens_expires_at_idx`, tabel `event_members`,
  `events_created_by_idx`, `event_members_user_id_idx`, serta RLS deny-by-default
  dengan 0 policy (migration `20261118000200_rls_and_supabase_grants`) yang
  setara/lebih ketat daripada policy `using (false)` versi legacy.
- **Celah nyata (hanya ada di file legacy):** unique index
  `profiles_username_lower_unique` pada `lower(username) WHERE username IS NOT NULL`.
  Index ini **tidak** didefinisikan di schema.prisma maupun 9 migration Prisma,
  dan hasil pemeriksaan `pg_indexes` menunjukkan index tersebut **tidak ada** di
  database saat ini. Konsekuensinya username hanya unik secara case-sensitive
  (`profiles_email_key` hanya untuk email), sehingga `Admin` dan `admin` dapat
  hidup berdampingan.
- **Proposal:** (1) pindahkan celah tersebut ke migration Prisma baru
  (mis. `20261126000000_reconcile_legacy_username_uniqueness`) yang hanya berisi
  index residual tersebut, atau (2) putuskan secara tertulis bahwa username
  case-sensitive sudah memadai dan index legacy tidak diperlukan. Setelah
  keputusan (1) diterapkan dan diverifikasi, arsipkan file legacy (pindah ke
  `task/archive/` atau hapus) sehingga hanya `backend/prisma/migrations/` yang
  menjadi riwayat migration.
- **Status relokasi (26 November 2026):** atas instruksi pemilik proyek, file
  legacy sudah **dipindahkan** dari `backend/supabase/migrations/` ke
  `backend/prisma/legacy-migrations/` (isi tidak diubah, riwayat Git
  dipertahankan lewat `git mv`), sehingga hanya ada satu folder database yaitu
  `backend/prisma/`. Folder `backend/supabase/` dihapus. Penempatan itu sengaja
  **di luar** `backend/prisma/migrations/` karena Prisma memperlakukan setiap
  subfolder di sana sebagai migration: probe Prisma 6.19 menunjukkan folder
  `migrations/legacy/` terbaca sebagai migration `legacy` yang belum diterapkan
  (`migrate status` exit 1, `migrate deploy` akan menjalankannya), sedangkan file
  `.sql` lepas diabaikan. Verifikasi setelah relokasi: `prisma migrate status`
  tetap `9 migrations found` + `Database schema is up to date!`.
  **Celah `profiles_username_lower_unique` masih terbuka** dan tetap menunggu
  keputusan pada proposal ini.
- **Larangan teknis:** jangan menghapus/menulis ulang 9 direktori migration
  Prisma yang sudah diterapkan — checksum di `_prisma_migrations` akan membuat
  `prisma migrate status`/`deploy` melaporkan migration hilang. Rekonsiliasi
  dilakukan dengan **menambah** migration baru, bukan menggabungkan riwayat lama.
- **Prasyarat index unik:** sebelum `CREATE UNIQUE INDEX`, periksa duplikat
  `lower(username)` pada data aktual; bila ada, selesaikan penamaan ulang
  terlebih dahulu. Buat index dengan `CREATE UNIQUE INDEX CONCURRENTLY` bila
  tabel sudah besar dan downtime tidak diizinkan.
- **Test/validasi yang disyaratkan:** `prisma migrate deploy` + `prisma migrate
  status` pada database disposable, `node scripts/audit-db.js`, registrasi
  Organizer dengan username yang hanya berbeda kapitalisasi (harus 409/400,
  bukan membuat baris baru), login Admin/Organizer tetap 200, serta `npm test`.
- **Owner:** hanya penanggung jawab FINISHING setelah gate dibuka; Developer 1–3
  tidak mengimplementasikan. File legacy (`backend/prisma/legacy-migrations/**`)
  tercatat **beku** pada `task/TAHAP_3/FILE_OWNERSHIP.md`, sehingga
  pemindahan/penghapusan lebih lanjut memerlukan keputusan pemilik proyek.

## Proses review FINISHING yang disyaratkan

Untuk setiap proposal di atas, sebelum perubahan: pemilik produk mengesahkan acceptance terkait; maintainer menetapkan penanggung jawab FINISHING; gate FINISHING dibuka; proposal, data impact, baseline dan file scope disetujui; disposable DB/no secrets tersedia; reviewer serta forward/rollback plan dicatat. Sampai terpenuhi, status tetap **BLOCKED / PROPOSAL ONLY**.