# Backend - E Ticket Event QR Scan

Backend API untuk aplikasi mobile e-ticket event dengan verifikasi QR code.
Dibangun dengan **Node.js + Express + JavaScript** dan database **PostgreSQL via Supabase**.

## Fondasi Prisma

- Schema target berada di [`prisma/schema.prisma`](prisma/schema.prisma).
- Analisis entitas, relasi, konflik kontrak, dan prasyarat migration ada di
  [`docs/DATABASE.md`](../docs/DATABASE.md).
- Backend menjalankan query melalui PostgreSQL langsung (`pg`) di
  `src/config/db.js`. `src/config/supabase.js` hanya alias kompatibilitas dan
  tidak lagi membuat Supabase JS client.
- Migration Prisma **sudah diterapkan** pada database yang dikonfigurasi
  `DATABASE_URL` dan tercatat di `_prisma_migrations` (6 migration, terakhir
  `20261118000100_fix_payment_status_enum`).
- `npx prisma migrate diff --from-schema-datasource prisma/schema.prisma
  --to-schema-datamodel prisma/schema.prisma --script` menghasilkan
  `-- This is an empty migration.` yang berarti struktur database aktual sesuai
  schema.
- Function PostgreSQL `moderate_event`, `create_event_order`,
  `simulate_event_payment`, dan `expire_event_order_reservations` tersedia.
- RLS **belum diaktifkan pada seluruh 32 tabel aplikasi** (0 policy), sementara role
  Supabase `anon` dan `authenticated` masih memiliki 7 privilege penuh pada setiap
  tabel (SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER). Artinya data
  dapat dibaca dan diubah lewat Supabase REST bila `anon` key diketahui.
  Backend terhubung sebagai pemilik tabel (`postgres`), sehingga pengaktifan RLS
  tidak akan memutus backend. Ini prasyarat wajib sebelum rilis.
- Verifikasi schema berlapis: `npm run verify:db-schema` (introspeksi `prisma db
  pull` + `migrate diff` dua arah + perbandingan jumlah index). Hasil terakhir:
  tidak ada perbedaan.
- Audit read-only: `node scripts/audit-db.js`. Rekonsiliasi function yang hilang
  pada database lama: `node scripts/apply-db-functions.js --apply`.

## Struktur Folder

```
backend/
├── .env                  # Environment variables (buat dari .env.example)
├── .env.example          # Contoh variabel environment
├── .gitignore
├── package.json
├── server.js             # Entry point server
├── README.md
└── src/
    ├── app.js            # Express app setup & middleware
    ├── config/
    │   ├── env.js        # Validasi & ekspor environment variables
    │   └── supabase.js   # Alias kompatibilitas (tanpa Supabase JS client)
    ├── controllers/
    │   ├── authController.js      # Register, login, profile
    │   ├── eventController.js     # CRUD, visibilitas, dan moderasi event
    │   ├── eventMetricsController.js # Ringkasan event, grafik, dan moderasi
    │   ├── orderController.js    # Checkout dan akses order
    │   ├── paymentController.js  # Pembayaran Virtual Account simulasi
    │   ├── ticketController.js    # Buat tiket, lihat tiket, verifikasi QR
    │   └── ticketTypeController.js # CRUD kategori tiket
    ├── middleware/
    │   ├── authMiddleware.js      # Verifikasi JWT
    │   ├── errorMiddleware.js     # Global error handler
    │   ├── notFoundMiddleware.js  # 404 handler
    │   └── validationMiddleware.js# Hasil express-validator
    ├── models/            # Legacy (tidak dipakai runtime; lihat catatan di bawah)
    │   ├── User.js      # Model profil pengguna (legacy Supabase client)
    │   ├── Event.js     # Model event (legacy)
    │   └── Ticket.js    # Model tiket & QR code (legacy)
    ├── routes/
    │   ├── authRoutes.js
    │   ├── eventRoutes.js
    │   ├── organizerRoutes.js
    │   ├── orderRoutes.js
    │   ├── paymentRoutes.js
    │   ├── ticketRoutes.js
    │   └── ticketTypeRoutes.js
    ├── services/
    │   ├── authService.js          # Logic auth (token, hash password)
    │   ├── ticketTokenService.js   # Token QR tiket bertanda tangan (HMAC)
    │   ├── emailService.js         # Pengiriman email tiket
    │   ├── notificationService.js  # Notifikasi in-app
    │   ├── seedService.js          # Seed data demo
    │   └── adminBootstrapService.js# Bootstrap akun admin
    ├── utils/
    │   ├── response.js    # Helper response standar
    │   ├── constants.js   # Konstanta aplikasi
    │   └── validators.js  # Validator sederhana
    └── validators/
        ├── authValidator.js     # Validasi register/login
        └── ticketValidator.js   # Validasi tiket
```

> **Catatan legacy:** `src/models/*.js` dan `src/config/supabase.js` adalah sisa
> lapisan Supabase JS client lama. Runtime sekarang memakai `pg` melalui
> `src/config/db.js`, dan tidak ada modul yang mengimpor `models/*`. Keduanya
> dipertahankan sementara karena berada di area konfigurasi database yang
> wewenangnya ada pada FINISHING; lihat proposal di laporan audit struktur.

## Endpoint API

### Auth
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/auth/register` | Register pengguna baru (role organizer) | Public |
| POST | `/api/auth/login` | Login & dapatkan JWT | Public |
| GET | `/api/auth/me` | Profil pengguna login | Private |
| PUT | `/api/auth/me` | Perbarui nama/avatar | Private |
| POST | `/api/auth/logout` | Cabut token (revoked_tokens) | Private |

### Events
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| GET | `/api/events/public` | Event yang disetujui dan dipublikasikan | Public |
| GET | `/api/events/mine` | Event milik Organizer login | Organizer |
| GET | `/api/events` | Semua event untuk moderasi | Admin |
| GET | `/api/events/:id` | Detail event publik atau milik pengguna berhak | Public/owner/Admin |
| POST | `/api/events` | Buat draft event | Organizer |
| PUT | `/api/events/:id` | Perbarui event yang statusnya dapat diedit | Owner/Admin |
| DELETE | `/api/events/:id` | Hapus draft event | Owner/Admin |
| POST | `/api/events/:id/submit-review` | Ajukan event untuk moderasi | Organizer |
| GET/POST | `/api/events/:id/ticket-types` | Baca/buat kategori tiket | Public/Organizer |
| PUT/DELETE | `/api/events/:id/ticket-types/:ticketTypeId` | Ubah/hapus kategori tiket | Organizer |
| GET | `/api/events/:id/summary` | Ringkasan operasional event | Organizer/Admin |
| GET | `/api/events/:id/sales` | Seri tiket/check-in 7 hari | Organizer/Admin |
| GET/POST | `/api/events/:id/members` | Daftar/tambah staf event + izin | Owner |
| PUT | `/api/events/:id/members/:userId/permissions` | Ganti izin staf | Owner |
| DELETE | `/api/events/:id/members/:userId` | Hapus staf | Owner |
| GET/POST | `/api/events/:id/invitations` | Daftar/buat undangan staf | Owner/Admin |
| DELETE | `/api/events/:id/invitations/:invitationId` | Cabut undangan | Owner/Admin |
| POST | `/api/invitations/:token/accept` | Terima undangan (email harus cocok) | Private |
| GET | `/api/invitations/me` | Undangan pending milik pengguna | Private |
| GET | `/api/organizer/overview` | Ringkasan event Organizer | Organizer |
| GET | `/api/organizer/events/summaries` | Ringkasan per event Organizer | Organizer |
| PUT | `/api/admin/events/:id/moderation` | Keputusan moderasi atomik dan audit | Admin |
| GET | `/api/admin/accounts` | Daftar akun | Admin |
| PUT | `/api/admin/accounts/:id/status` | Aktif/nonaktifkan akun | Admin |

### Tickets
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/tickets` | Terbitkan tiket langsung (khusus owner event, legacy; alur utama via order) | Organizer/Admin |
| GET | `/api/tickets/my-tickets` | Tiket milik user login; guest mengirim `order_id` + header `X-Order-Access-Token` | Private/order token |
| GET | `/api/tickets/:id` | Detail tiket milik user login atau `order_id` + header `X-Order-Access-Token` | Private/order token |
| POST | `/api/tickets/validate` | Validasi QR tanpa mutasi; wajib izin petugas event | Private (staff) |
| POST | `/api/tickets/verify` | Verifikasi QR dan tandai tiket used secara atomik | Private (staff) |

### Check-in
| Method | Endpoint | Deskripsi | Akses |
|---|---|---|---|
| POST | `/api/check-ins` | Check-in online idempoten (satu check-in per tiket) | Private (staff) |
| GET | `/api/check-ins/events/:eventId/check-ins` | Riwayat check-in event | Private (staff) |
| POST | `/api/check-ins/sync` | Sinkronisasi antrean check-in offline | Private (staff) |
| GET | `/api/events/:eventId/attendees` | Daftar peserta/tiket event | Owner/staff |

### Notifikasi dan laporan dukungan
| Method | Endpoint | Deskripsi | Akses |
|---|---|---|---|
| GET | `/api/notifications` | Daftar notifikasi pengguna (`?unread=true`) | Private |
| POST | `/api/notifications/:id/read` | Tandai satu notifikasi dibaca | Private |
| POST | `/api/notifications/read-all` | Tandai semua notifikasi dibaca | Private |
| GET/POST | `/api/support-reports` | Daftar/buat laporan dukungan | Private |
| GET | `/api/support-reports/:id` | Detail laporan + aktivitas | Pelapor/admin/penanggung jawab |
| PUT/POST | `/api/support-reports/:id/status` | Ubah status | Admin/penanggung jawab |
| PUT/POST | `/api/support-reports/:id/priority` | Ubah prioritas | Admin/penanggung jawab |
| POST | `/api/support-reports/:id/reply` | Balasan publik | Pelapor/admin/penanggung jawab |
| POST | `/api/support-reports/:id/internal-note` | Catatan internal | Admin/penanggung jawab |

### Orders and simulated payments
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/orders` | Buat order dengan harga/kuota hasil validasi database; guest menerima token akses sekali | Public/Participant |
| GET | `/api/orders` | Riwayat order akun login | Private |
| GET | `/api/orders/:id` | Detail order; guest wajib menyertakan header `X-Order-Access-Token` | Owner/guest token |
| GET | `/api/payments/:orderId` | Status VA simulasi; guest wajib menyertakan header `X-Order-Access-Token` | Owner/guest token |
| POST | `/api/payments/simulate` | Simulasikan hasil pembayaran pada lingkungan yang diizinkan | Owner/guest token |

Endpoint simulasi dinonaktifkan secara default. Aktifkan hanya pada environment
non-produksi dengan `SIMULATED_PAYMENTS_ENABLED=true`; simulasi ini bukan
integrasi bank atau payment gateway.

## Instalasi

```bash
cd backend
npm install
cp .env.example .env
# Isi DATABASE_URL, DIRECT_URL, JWT_SECRET, dan ALLOWED_ORIGINS.
npx prisma migrate status --schema prisma/schema.prisma
npx prisma validate --schema prisma/schema.prisma
npm run dev
```

Untuk database yang sudah memiliki tabel tetapi belum memiliki riwayat migrasi,
lakukan rekonsiliasi setelah memverifikasi
`prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --script`
kosong:

```bash
npx prisma migrate resolve --applied <nama-migration>   # untuk setiap baseline
node scripts/apply-db-functions.js --apply              # bila function PL/pgSQL hilang
npx prisma migrate deploy
```

Jangan gunakan `prisma migrate reset` atau `db push` pada database berisi data.

## Roles, akun Admin, dan staf event

1. Isi `DATABASE_URL` (aplikasi) dan `DIRECT_URL` (migrasi) dengan kredensial
   PostgreSQL/Supabase. Jangan menaruh kredensial di Flutter atau repositori.
2. Jalankan `npx prisma migrate deploy` dan pastikan
   `npx prisma migrate status` menyatakan schema up to date.
3. Siapkan akun Admin pertama (tidak ada password default di source code):

   ```bash
   # backend/.env (jangan commit)
   ADMIN_EMAIL=admin@your-domain.test
   ADMIN_PASSWORD=<password kuat minimal 8 karakter>
   ADMIN_NAME=Administrator Platform
   ADMIN_USERNAME=admin
   ADMIN_RESET_PASSWORD=false
   ```

   ```bash
   npm run admin:provision
   ```

   Skrip bersifat idempotent: dijalankan berulang tidak membuat Admin duplikat
   dan tidak mengubah password kecuali `ADMIN_RESET_PASSWORD=true`. Akun
   tersimpan di tabel `profiles` dengan `role = 'admin'` dan hash bcrypt;
   mekanisme login sama dengan `POST /api/auth/login`. `npm start` juga
   menjalankan bootstrap ini bila kedua variabel terisi.
4. Akun Organizer dibuat lewat `POST /api/auth/register` (role selalu
   organizer). Tidak ada seed akun demo dengan password tetap.
5. Arahkan Flutter ke API dengan
   `--dart-define=API_BASE_URL=http://10.0.2.2:5000/api` (emulator Android).

Email akun Admin bukan "sertifikat" hak akses: role dibaca ulang dari database
pada setiap request (`authMiddleware`), sehingga perubahan role/disable berlaku
tanpa menunggu token kedaluwarsa. Jangan pernah memberi hak Admin berdasarkan
nama atau email yang dikirim klien.

`/api/auth/register` selalu membuat role organizer; role tidak diterima dari
input publik. Otorisasi event menggunakan role dari database dan `created_by`.
Staf event disimpan di `event_members` beserta izin granular di
`event_member_permissions`; undangan memakai `event_invitations` dengan hash
token dan masa berlaku.

## Variabel Environment (.env)

| Variabel | Deskripsi | Contoh |
|----------|-----------|--------|
| `PORT` | Port server | `5000` |
| `HOST` | Bind address | `0.0.0.0` |
| `NODE_ENV` | Environment | `development` |
| `DATABASE_URL` | Koneksi aplikasi (pooled) | `postgresql://...` |
| `DIRECT_URL` | Koneksi langsung untuk migrasi | `postgresql://...` |
| `JWT_SECRET` | Secret untuk sign JWT | nilai acak panjang |
| `JWT_EXPIRES_IN` | Masa berlaku token | `7d` |
| `ALLOWED_ORIGINS` | Daftar origin CORS dipisah koma | `http://localhost:3000` |
| `CORS_ORIGIN` | Alias lama CORS (kompatibilitas) | `http://localhost:3000` |
| `SIMULATED_PAYMENTS_ENABLED` | Aktifkan simulasi pembayaran non-produksi | `false` |
| `ADMIN_EMAIL` | Email akun Admin yang di-bootstrap ke tabel `profiles` | `admin@your-domain.test` |
| `ADMIN_PASSWORD` | Password awal Admin (minimal 8 karakter, hanya di `.env`) | nilai acak kuat |
| `ADMIN_NAME` | Nama tampilan Admin | `Administrator Platform` |
| `ADMIN_USERNAME` | Username login Admin (opsional) | `admin` |
| `ADMIN_RESET_PASSWORD` | Rotasi password Admin yang sudah ada saat bootstrap | `false` |
| `SEED_DEMO_ACCOUNTS` | Legacy; tidak lagi membuat akun dengan password tetap | `false` |

## Database Schema

Sumber kebenaran schema adalah `prisma/schema.prisma` dan migration di
`prisma/migrations/`. Database aktual memiliki 32 tabel aplikasi, 19 enum,
54 foreign key, dan 105 index aplikasi; seluruhnya cocok dengan schema
(`prisma migrate diff` kosong). Gunakan `node scripts/audit-db.js` untuk
memeriksa tabel, kolom, constraint, index, enum, function, RLS, dan riwayat
migrasi. Ringkasan relasi ada di `docs/DATABASE.md`.

Catatan keamanan (verifikasi read-only 23 November 2026, lihat
`../task/DATABASE_AUDIT_FINAL.md`): RLS aktif pada **32/32** tabel aplikasi dengan
**0 policy** (deny-by-default untuk akses REST langsung) dan **0 grant** untuk
`anon`/`authenticated`; hanya `service_role` memiliki privilege. Pemilik tabel
adalah `postgres` (juga role koneksi backend), sehingga aktivasi RLS tidak
memutus backend. Otorisasi aplikasi tetap ditegakkan di middleware/controller
backend, bukan oleh RLS.

## Integrasi dengan Flutter (Frontend)

Di Flutter (`frontend/lib/`), gunakan `http` atau `dio` untuk memanggil API:

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator
// static const String baseUrl = 'http://localhost:5000/api'; // iOS Simulator
// static const String baseUrl = 'https://api-evticket.com/api'; // Production
```

Sertakan header `Authorization: Bearer <token>` untuk endpoint yang memerlukan autentikasi.