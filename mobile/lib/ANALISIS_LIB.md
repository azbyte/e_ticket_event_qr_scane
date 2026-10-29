# ANALISIS FOLDER `mobile/lib`

File ini menjelaskan secara rinci struktur folder `lib/` pada aplikasi Flutter
**E-Ticket Event & QR Scanner**. Tujuannya adalah untuk membantu Anda memahami
fungsi setiap folder dan file sehingga mudah menavigasi, menambah fitur, atau
melakukan perbaikan.

---

## GAMBARAN UMUM

Folder `lib/` adalah tempat semua kode sumber Dart (`.dart`) aplikasi Flutter
berada. Struktur yang digunakan mengikuti pola modular dengan pemisahan antara:

- `core/`         -> Kode inti yang digunakan di seluruh aplikasi
- `features/`     -> Fitur-fitur bisnis (auth, event, tiket, dll.)
- `models/`       -> Model data
## STRUKTUR LENGKAP `lib/`

```
lib/
├── app.dart                      # Root widget aplikasi (MaterialApp)
├── main.dart                     # Entry point pertama kali dijalankan
├── core/                         # Kode inti (shared across app)
│   ├── config/
│   │   └── app_config.dart       # Konfigurasi aplikasi (nama, baseUrl, dll)
│   ├── constants/
│   │   └── app_constants.dart    # Konstanta global (teks, label, padding, dll)
│   ├── errors/
│   │   └── app_exception.dart    # Custom exception class untuk error handling
│   ├── network/
│   │   └── api_client.dart       # HTTP client (Dio/http) untuk panggilan API
│   ├── theme/
│   │   └── app_theme.dart        # Tema warna, typografi, gaya UI global
│   ├── utils/
│   │   └── date_utils.dart       # Utilitas pemformatan tanggal & waktu
│   └── validators/
│       └── input_validator.dart  # Fungsi validasi input (email, password, dll)
│
├── features/                     # Fitur-fitur bisnis aplikasi
│   ├── admin/                    # Fitur untuk role admin
│   │   ├── screens/
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── event_moderation_screen.dart
│   │   │   └── report_management_screen.dart
│   │   └── tabs/
│   │       └── admin_tab_controller.dart
│   ├── auth/                     # Fitur autentikasi (login/register)
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   └── widgets/
│   │       └── auth_divider.dart
│   ├── check_in/                 # Fitur check-in tiket via QR scan
│   │   ├── screens/
│   │   │   ├── check_in_history_screen.dart
│   │   │   └── check_in_screen.dart
│   │   └── widgets/
│   ├── events/                   # Fitur daftar & detail event
│   │   ├── screens/
│   │   │   ├── event_detail_screen.dart
│   │   │   └── event_list_screen.dart
│   │   └── widgets/
│   │       └── event_card.dart
│   ├── home/                     # Halaman beranda (home)
│   │   └── screens/
│   │       └── home_screen.dart
│   ├── notifications/            # Fitur notifikasi
│   │   └── screens/
│   │       └── notification_list_screen.dart
│   ├── orders/                   # Fitur pemesanan/tiket
│   │   └── screens/
│   │       ├── order_detail_screen.dart
│   │       └── order_list_screen.dart
│   ├── organizer/                # Fitur untuk role organizer
│   │   ├── screens/
│   │   │   ├── attendee_list_screen.dart
│   │   │   ├── event_form_screen.dart
│   │   │   ├── event_management_screen.dart
│   │   │   ├── organizer_dashboard_screen.dart
│   │   │   └── staff_management_screen.dart
│   │   └── tabs/
│   │       └── organizer_tab_controller.dart
│   ├── payments/                 # Fitur pembayaran
│   │   └── screens/
│   │       └── ...
│   ├── profile/                  # Fitur profil pengguna
│   │   └── screens/
│   │       └── profile_screen.dart
│   ├── tickets/                  # Fitur tiket & QR
│   │   ├── screens/
│   │   │   ├── ticket_detail_screen.dart
│   │   │   ├── ticket_list_screen.dart
│   │   │   └── ticket_purchase_screen.dart
│   │   └── widgets/
│   │       └── qr_ticket_display.dart
│   └── (setiap fitur bisa memiliki: screens/, widgets/, tabs/)
│
├── models/                       # Model data (class Dart)
│   ├── check_in/
│   │   └── check_in_model.dart
│   ├── event/
│   │   ├── event_model.dart
│   │   └── ticket_type_model.dart
│   ├── order/
│   │   ├── order_item_model.dart
│   │   └── order_model.dart
│   ├── payment/
│   │   └── payment_model.dart
│   ├── report/
│   │   ├── report_activity_model.dart
│   │   └── support_report_model.dart
│   ├── ticket/
│   │   └── ticket_model.dart
│   └── user/
│       ├── user_model.dart
│       └── user_role.dart
│
├── providers/                    # State management dengan Provider
│   ├── auth_provider.dart
│   ├── check_in_provider.dart
│   ├── event_provider.dart
│   ├── notification_provider.dart
│   ├── order_provider.dart
│   ├── payment_provider.dart
│   ├── report_provider.dart
│   ├── ticket_provider.dart
│   └── user_provider.dart
│
├── routes/                       # Konfigurasi navigasi
│   ├── app_router.dart           # Logic generateRoute (nama route -> widget)
│   └── app_routes.dart           # Daftar konstanta nama route
│
└── services/                     # Logika bisnis & layanan eksternal
    ├── api/
## PENJELASAN SETIAP FOLDER

### 1. `main.dart` — Entry Point Aplikasi
File ini adalah titik pertama yang dijalankan Flutter. Berisi fungsi `main()`
yang memanggil `runApp(MyApp())`. Saat ini masih menggunakan template default
Flutter (counter app), perlu diubah untuk menggunakan `MyApp` dari `app.dart`.

### 2. `app.dart` — Root Widget
Berisi class `MyApp` yang mengatur:
- `MaterialApp` sebagai root widget
- Judul aplikasi dari `AppConfig`
- Tema dari `AppTheme`
- Route awal (`initialRoute`) dan generator route (`AppRouter`)
- Catatan: Provider masih dalam status TODO (belum diimplementasi penuh)

### 3. `core/` — Kode Inti (Shared)
Kode yang digunakan di banyak tempat di seluruh aplikasi, bukan milik satu fitur
tertentu.

| Subfolder | Fungsi |
|-----------|--------|
| `config/` | Konfigurasi global (nama app, base URL API, debug mode) |
| `constants/` | Nilai konstan yang sering digunakan (teks placeholder, ukuran, warna default) |
| `errors/` | Class exception kustom untuk menangani error secara terstruktur |
| `network/` | Klien HTTP untuk berkomunikasi dengan backend (Dio atau http package) |
| `theme/` | Definisi tema warna, typografi, dan gaya UI yang konsisten |
| `utils/` | Fungsi utilitas umum (format tanggal, format uang, dll) |
| `validators/` | Fungsi validasi input (format email, password minimal, required field) |

### 4. `features/` — Fitur Bisnis
Ini adalah bagian terbesar. Setiap fitur dipecah menjadi subfolder sesuai
peran pengguna atau modul bisnis. Setiap fitur biasanya memiliki:

- **`screens/`** — Halaman UI (StatelessWidget/StatefulWidget lengkap)
- **`widgets/`** — Widget kecil yang digunakan ulang di dalam fitur tersebut
- **`tabs/`** — Controller untuk TabBar/BottomNavigation (opsional)

**Daftar fitur yang tersedia:**

| Fitur | Role Target | Deskripsi singkat |
|-------|-------------|-------------------|
| `admin` | Admin | Dashboard admin, moderasi event, laporan |
| `auth` | Semua user | Login & register |
| `check_in` | Staff/Organizer | Scan QR tiket & riwayat check-in |
| `events` | Semua user | Daftar event & detail event |
| `home` | Semua user | Halaman beranda |
| `notifications` | Semua user | Daftar notifikasi |
| `orders` | Customer | Daftar & detail pesanan |
| `organizer` | Organizer | Kelola event, peserta, staf |
| `payments` | Customer | Halaman pembayaran |
| `profile` | Semua user | Profil pengguna |
| `tickets` | Customer | Daftar tiket, beli tiket, tampilkan QR |
    │   └── api_service.dart      # Service untuk memanggil backend API
    ├── auth/
    │   └── auth_service.dart     # Logic login/register/logout
    ├── check_in/
    │   └── check_in_service.dart # Logic scan & verifikasi check-in
    ├── event/
    │   └── event_service.dart    # Logic CRUD event

### 5. `models/` — Model Data
Berisi class Dart yang merepresentasikan struktur data dari backend API.
Contoh: `User`, `Event`, `Ticket`, `Order`, `Payment`, `CheckIn`, dll.
Model biasanya digunakan untuk:
- Mengubah JSON response dari API menjadi objek Dart (`fromJson`)
- Mengubah objek Dart menjadi JSON untuk dikirim ke API (`toJson`)

### 6. `providers/` — State Management
Digunakan untuk mengelola state aplikasi menggunakan package `provider`.
Setiap provider bertanggung jawab atas satu domain data, misalnya:
- `AuthProvider` -> status login, data user, token
- `EventProvider` -> daftar event, event yang dipilih
- `TicketProvider` -> daftar tiket milik user
- `OrderProvider` -> daftar pesanan

Catatan: Folder ini sudah ada namun belum terhubung ke `app.dart` (TODO).

### 7. `routes/` — Navigasi
Berisi konstanta nama route dan logika routing:
- `app_routes.dart` -> Daftar semua nama route sebagai konstanta (hindari typo)
- `app_router.dart` -> Fungsi `generateRoute` yang memetakan nama route ke Widget

### 8. `services/` — Logika Bisnis
Tempat logika yang tidak terikat pada UI. Pemisahan ini membuat kode lebih
mudah diuji (testable) dan dipelihara.

| Service | Fungsi |
|---------|--------|
| `api_service.dart` | Wrapper panggilan HTTP ke backend API |
| `auth_service.dart` | Login, register, logout, refresh token |
| `event_service.dart` | Ambil daftar event, buat/update/hapus event |
| `ticket_service.dart` | Beli tiket, ambil daftar tiket, verifikasi QR |
| `order_service.dart` | Buat pesanan, lihat detail pesanan |
| `payment_service.dart` | Proses pembayaran |
| `check_in_service.dart` | Scan QR, catat check-in |
| `scanner_service.dart` | Integrasi kamera QR scanner |
| `notification_service.dart` | Kirim/terima notifikasi |
| `report_service.dart` | Generate laporan aktivitas |

## ALUR DATA (DATA FLOW)

```
USER ACTION (Screen)
        |
        v
PROVIDER (State Management)
        |
        v
SERVICE (Logic Bisnis)
        |
        v
API CLIENT (Network/HTTP)
        |
        v
BACKEND API (Node.js + Express + Supabase)
```

Contoh: Saat user menekan tombol "Login":
1. `login_screen.dart` (features/auth/screens) memanggil `AuthProvider`
2. `AuthProvider` memanggil `AuthService`
3. `AuthService` memanggil `ApiClient` (HTTP POST ke `/api/auth/login`)
4. Respons diterima dan state provider diupdate

## KONVENSI PENAMAAN

| Jenis | Contoh | Penjelasan |
|-------|--------|------------|
| File screen | `login_screen.dart` | Akhir dengan `_screen` |
| File widget | `event_card.dart` | Akhir dengan nama widget |
| File model | `user_model.dart` | Akhir dengan `_model` |
| File provider | `auth_provider.dart` | Akhir dengan `_provider` |
| File service | `event_service.dart` | Akhir dengan `_service` |
| Folder | `kebab-case` | Semua huruf kecil, pemisah strip bawah |
| Class | `LoginScreen` | PascalCase |
| Variabel/fungsi | `isLoggedIn` | camelCase |

## PERBAIKAN YANG DISARANKAN

1. **Selesaikan `main.dart`** — Saat ini masih menggunakan template default
   Flutter. Ganti `home` dengan `MyApp()` dari `app.dart`.
2. **Aktifkan `provider`** — Tambahkan package `provider` ke `pubspec.yaml` dan
   uncomment import di `app.dart`.
3. **Lengkapi `app_routes.dart`** — Isi semua nama route agar navigasi
   terstruktur.
4. **Tambahkan `repositories/`** (opsional) — Jika ingin memisahkan logika API
   dari service secara lebih detail.
5. **Tambahkan file `export`** — Buat file `lib/core/exports.dart` dll untuk
   memudahkan impor.

## KESIMPULAN

Folder `lib/` diorganisir dengan pendekatan modular berdasarkan fitur
(`features/`) dan lapisan (`core/`, `models/`, `providers/`, `services/`,
`routes/`). Ini membuat proyek mudah untuk dikembangkan secara berkolaborasi,
karena setiap developer dapat fokus pada satu fitur tanpa mengganggu kode inti
aplikasi.

Jika Anda ingin menambahkan fitur baru, misalnya "Riwayat Transaksi", langkahnya
biasanya:
1. Buat folder `features/transactions/`
2. Tambahkan `screens/` untuk halaman UI
3. Tambahkan `models/` untuk model data transaksi
4. Tambahkan `providers/` untuk state management
5. Tambahkan `services/` untuk logika panggilan API
6. Daftarkan route di `app_routes.dart` dan `app_router.dart`

---
*File ini dibuat sebagai panduan analisis struktur `mobile/lib` untuk
proyek E-Ticket Event & QR Scanner.*