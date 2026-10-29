# Backend - E Ticket Event QR Scan

Backend API untuk aplikasi mobile e-ticket event dengan verifikasi QR code.
Dibangun dengan **Node.js + Express + JavaScript** dan database **PostgreSQL via Supabase**.

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
    │   └── supabase.js   # Inisialisasi Supabase client
    ├── controllers/
    │   ├── authController.js      # Register, login, profile
    │   ├── eventController.js     # CRUD event
    │   └── ticketController.js    # Buat tiket, lihat tiket, verifikasi QR
    ├── middleware/
    │   ├── authMiddleware.js      # Verifikasi JWT
    │   ├── errorMiddleware.js     # Global error handler
    │   ├── notFoundMiddleware.js  # 404 handler
    │   └── validationMiddleware.js# Hasil express-validator
    ├── models/
    │   ├── User.js      # Model profil pengguna (Supabase)
    │   ├── Event.js     # Model event
    │   └── Ticket.js    # Model tiket & QR code
    ├── routes/
    │   ├── authRoutes.js
    │   ├── eventRoutes.js
    │   └── ticketRoutes.js
    ├── services/
    │   ├── authService.js   # Logic auth (token, hash password)
    │   └── qrService.js     # Generate & parse QR code
    ├── utils/
    │   ├── response.js    # Helper response standar
    │   ├── constants.js   # Konstanta aplikasi
    │   └── validators.js  # Validator sederhana
    └── validators/
        ├── authValidator.js     # Validasi register/login
        └── ticketValidator.js   # Validasi tiket
```

## Endpoint API

### Auth
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/auth/register` | Register pengguna baru | Public |
| POST | `/api/auth/login` | Login & dapatkan JWT | Public |
| GET | `/api/auth/me` | Profil pengguna login | Private |

### Events
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| GET | `/api/events` | Daftar semua event | Public |
| GET | `/api/events/:id` | Detail event | Public |
| POST | `/api/events` | Buat event baru | Private (organizer) |
| PUT | `/api/events/:id` | Update event | Private (organizer) |
| DELETE | `/api/events/:id` | Hapus event | Private (organizer) |

### Tickets
| Method | Endpoint | Deskripsi | Akses |
|--------|----------|-----------|-------|
| POST | `/api/tickets` | Beli/buat tiket & generate QR | Private |
| GET | `/api/tickets/my-tickets` | Tiket milik user login | Private |
| POST | `/api/tickets/verify` | Verifikasi QR tiket saat scan | Private (staff) |

## Instalasi

```bash
# Masuk ke folder backend
cd backend

# Install dependencies
npm install

# Salin file environment
cp .env.example .env

# Isi nilai SUPABASE_URL, SUPABASE_ANON_KEY, dll di file .env

# Jalankan development server
npm run dev

# Atau production
npm start
```

## Variabel Environment (.env)

| Variabel | Deskripsi | Contoh |
|----------|-----------|--------|
| `PORT` | Port server | `5000` |
| `NODE_ENV` | Environment | `development` |
| `SUPABASE_URL` | URL project Supabase | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Anon key Supabase | `...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (admin) | `...` |
| `JWT_SECRET` | Secret untuk sign JWT | `rahasia` |
| `JWT_EXPIRES_in` | Masa berlaku token | `7d` |
| `CORS_ORIGIN` | URL frontend yang diizinkan | `http://localhost:3000` |

## Database Schema (Supabase)

Tabel yang diperlukan di Supabase:

```sql
-- Profiles (extends Supabase Auth)
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  name text,
  email text unique,
  password_hash text,
  role text default 'customer',
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Events
create table events (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  event_date timestamp with time zone,
  location text,
  total_tickets integer default 0,
  price numeric default 0,
  created_by uuid references profiles(id),
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Tickets
create table tickets (
  id uuid default gen_random_uuid() primary key,
  ticket_code text unique not null,
  event_id uuid references events(id) on delete cascade,
  user_id uuid references profiles(id),
  qr_code_data text,
  status text default 'active',
  purchased_at timestamp with time zone default timezone('utc'::text, now()),
  used_at timestamp with time zone
);
```

## Integrasi dengan Flutter (Frontend)

Di Flutter (`frontend/lib/`), gunakan `http` atau `dio` untuk memanggil API:

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator
// static const String baseUrl = 'http://localhost:5000/api'; // iOS Simulator
// static const String baseUrl = 'https://api-evticket.com/api'; // Production
```

Sertakan header `Authorization: Bearer <token>` untuk endpoint yang memerlukan autentikasi.