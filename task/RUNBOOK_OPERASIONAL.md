# Runbook Operasional — E-Ticket Event & QR Scanner

- **Berlaku untuk:** Tahap 3 (FASE 2), hasil integrasi Developer 1.
- **Acuan:** `README.md`, `docs/ARCHITECTURE.md`, `backend/README.md`,
  `task/TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`.
- **Prinsip:** setiap perintah di bawah sudah dijalankan pada environment
  pengembangan saat penyusunan dokumen ini, kecuali yang ditandai
  `BELUM DIVERIFIKASI` atau `NOT RUN` beserta alasannya.

---

## 1. Start / stop

### Backend

```bash
cd backend
npm ci                       # sekali per clone
npm run prisma:generate      # setelah schema berubah
npm start                    # produksi lokal
npm run dev                  # nodemon untuk pengembangan
```

Health check (membuktikan koneksi database):

```bash
curl http://127.0.0.1:5000/health
# {"success":true,"message":"Server is running","database":"connected", ...}
```

Menghentikan: `Ctrl+C` pada terminal yang menjalankan server. Pada Windows,
`Get-Process node | Stop-Process` menghentikan **semua** proses Node — pastikan
tidak ada proses lain yang sedang dipakai.

#### Backend gagal start / "crash"

Sejak Tahap 3, `server.js` menangani error `listen` dan mencetak pesan yang
dapat ditindaklanjuti (bukan stack trace mentah). `npm run dev` juga menjalankan
**preflight port** sebelum nodemon dinyalakan, sehingga penyebab paling umum
(port sudah dipakai) dilaporkan lebih awal.

| Pesan | Penyebab | Solusi |
|---|---|---|
| `[preflight] Port 5000 ... sudah dipakai proses lain.` | Ada backend/proses lain di port itu (sering sisa `npm run dev` sebelumnya) | Ikuti PID yang dicetak: `Stop-Process -Id <PID> -Force`, **atau** jalankan `npm run dev:reset` (menghentikan otomatis), **atau** `PORT=5001 npm run dev` |
| `[startup] Port 5000 masih dipakai (percobaan n/10)` | Socket lama belum dilepas saat nodemon restart | Normalnya pulih sendiri; bila habis 10 percobaan berarti proses lain benar-benar memegang port — jalankan `npm run dev:reset` |
| `Missing required environment variables: - DATABASE_URL` | `backend/.env` belum ada/belum diisi | `cp .env.example .env` lalu isi `DATABASE_URL` dan `JWT_SECRET` |
| `Account bootstrap failed: connect ECONNREFUSED ...` | Database tidak dapat dijangkau | Server tetap hidup; `/health` melaporkan `database: disconnected`. Periksa `DATABASE_URL`/jaringan |
| `Tidak punya izin mengikat port ...` | Port < 1024 | Gunakan port di atas 1024 |

Perintah bantu:

```bash
npm run dev          # preflight port + nodemon (launcher aman)
npm run dev:reset    # hentikan proses yang memegang port, lalu jalankan dev
npm start            # jalankan tanpa nodemon (produksi lokal)
```

Mencari proses pemakai port di Windows:

```powershell
Get-NetTCPConnection -LocalPort 5000 -State Listen | Select-Object OwningProcess
Get-Process -Id <PID>
Stop-Process -Id <PID> -Force
```

**Catatan arsitektur proses.** Pada Windows, `nodemon` tidak selalu berhasil
menghentikan anaknya, dan terminal yang ditutup meninggalkan proses yatim yang
tetap memegang port — inilah penyebab `npm run dev` tampak "tidak bisa
dijalankan" berulang kali. Karena itu:

- `npm run dev` memakai `scripts/dev.js` yang menghentikan seluruh pohon proses
  (`taskkill /T`) dan memantau induk lewat heartbeat `backend/.dev-heartbeat`;
- `server.js` berhenti sendiri bila stdin induk ditutup (SIGTERM tidak selalu
  tersampaikan di Windows);
- `server.js` mencoba bind ulang hingga 10× bila port belum dilepas saat restart.

### Flutter (web demo)

```bash
cd apps
flutter pub get
flutter run -d chrome --web-port=3100 \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
```

Atau memakai build statis (tanpa dev server):

```bash
cd apps
flutter build web --release \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
cd ..
node scripts/serve-web.js 3100 apps/build/web
```

Buka `http://127.0.0.1:3100`.

> **Catatan port.** Port `3000` pada mesin pengembangan dipakai layanan lain
> (VPN). Gunakan `3100` dan sesuaikan `APP_PUBLIC_URL` serta `ALLOWED_ORIGINS`
> pada `backend/.env`. Jika origin berbeda, CORS akan menolak request browser.

### Android

```bash
cd apps
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://10.0.2.2:5000/api   # emulator
```

`10.0.2.2` adalah loopback host dari emulator Android. Untuk perangkat fisik,
gunakan IP LAN host dan pastikan backend mendengarkan `HOST=0.0.0.0`.

---

## 2. Konfigurasi environment

Semua variabel berada di `backend/.env` (tidak di-commit). Template:
`backend/.env.example`.

| Variabel | Wajib | Keterangan |
|---|---|---|
| `DATABASE_URL` | ya | Koneksi PostgreSQL (pooled). Backend berhenti bila kosong. |
| `DIRECT_URL` | tidak | Koneksi langsung untuk migrasi/tooling. |
| `JWT_SECRET` | ya | Wajib acak dan kuat. |
| `JWT_EXPIRES_IN` | tidak | Default `7d`. |
| `TICKET_TOKEN_SECRET` | produksi | Secret HMAC token QR; fallback `JWT_SECRET`. |
| `APP_PUBLIC_URL` | ya | Basis `public_url` event dan `invite_url` di email. |
| `ALLOWED_ORIGINS` / `CORS_ORIGIN` | ya (web) | Daftar origin dipisah koma. |
| `SIMULATED_PAYMENTS_ENABLED` | demo | `true` hanya non-produksi. |
| `SMTP_HOST` dkk. | opsional | Tanpa SMTP, email dicatat `NOT_CONFIGURED` (bukan diklaim terkirim). `SMTP_HOST=json` memakai transport JSON untuk uji lokal. |
| `ADMIN_EMAIL`/`ADMIN_PASSWORD`/`ADMIN_NAME` | sekali | Untuk `npm run admin:provision`. |
| `RATE_LIMIT_*` | tidak | Batas rate limit; naikkan saat menjalankan uji beban/e2e. |

**Jangan** menaruh secret pada repository, dokumentasi, atau `apps/`.

---

## 3. Provisioning akun Admin

```bash
cd backend
# isi ADMIN_EMAIL, ADMIN_PASSWORD (kuat), ADMIN_NAME pada .env
npm run admin:provision
```

Skrip idempotent: akun tidak dibuat ganda. Password hanya diubah bila
`ADMIN_RESET_PASSWORD=true`. Tidak ada password default di source code.

Akun Organizer dibuat sendiri lewat `POST /api/auth/register` atau layar
registrasi aplikasi.

---

## 4. Smoke test setelah deploy

Urutan minimum (semua sudah diverifikasi pada Tahap 3):

```bash
cd backend
npm test                 # unit + integration (mock pg), 177 test
npm run check            # sintaks 67 file JS
npm run format:check     # trailing whitespace + JSON
npm run test:e2e         # butuh server berjalan + DATABASE_URL nyata
```

`npm run test:e2e` menjalankan 80 pemeriksaan alur PRD terhadap API dan database
sungguhan: health, register/login Organizer, event + kategori, auto-publish,
event invalid, order guest (idempotency, quantity, field dinamis), pembayaran
simulasi, tiket + token QR, undangan & membership staf, scan/check-in/riwayat,
peserta + export CSV, order per event, revenue, konsol Admin (suspend/audit,
settings/history, overview/revenue/paket/langganan), moderasi event, serta
skenario negatif keamanan.

**Peringatan:** skrip ini MENULIS data uji ke database `DATABASE_URL` (tidak
menghapus data). Jalankan hanya pada database pengembangan/uji.

Frontend:

```bash
cd apps
flutter analyze --no-pub
flutter test --no-pub
```

---

## 5. Backup dan restore

Belum ada skrip backup di repository. Prosedur manual (PostgreSQL/Supabase):

```bash
# BACKUP (kredensial dibaca dari environment, jangan ditulis ke shell history bersama)
pg_dump "$DIRECT_URL" --format=custom --file=backup_YYYYMMDD_HHMM.dump

# RESTORE ke database kosong (DESTRUKTIF — konfirmasi dulu)
pg_restore --clean --if-exists --no-owner --dbname="$DIRECT_URL" backup_YYYYMMDD_HHMM.dump
```

Aturan:

1. `pg_restore --clean` menghapus objek yang ada. Jangan jalankan pada database
   bersama tanpa persetujuan pemilik proyek.
2. Uji restore ke database terpisah sebelum menyentuh produksi.
3. Setelah restore, jalankan `npm run verify:db-schema` dan `npm run test:e2e`.

`NOT RUN`: prosedur backup/restore tidak dijalankan pada sesi ini karena tidak
ada `pg_dump`/`pg_restore` di environment dan database yang dipakai adalah
database pengembangan bersama.

---

## 6. Rotasi JWT dan token tiket

1. **JWT_SECRET** — mengganti nilai membuat seluruh token sesi lama tidak valid
   (pengguna harus login ulang). Langkah:
   - set `JWT_SECRET` baru (nilai acak ≥32 byte),
   - restart backend,
   - verifikasi login dan satu alur terlindungi,
   - komunikasikan logout paksa ke pengguna.
2. **TICKET_TOKEN_SECRET** — token QR deterministik dari `id + issued_at`.
   Mengganti secret membuat semua QR tiket lama tidak lagi valid untuk scan.
   Lakukan hanya bila ada indikasi kebocoran, dan umumkan bahwa peserta perlu
   membuka ulang e-ticket (token baru diturunkan dari data tiket).
3. Token mentah tidak pernah disimpan; database hanya menyimpan `token_hash`.
   Tidak ada rotasi per-tiket yang diperlukan untuk operasi normal.

---

## 7. Retry email tiket

1. Status setiap pengiriman dicatat pada `ticket_email_deliveries`
   (`SENT`, `FAILED`, `NOT_CONFIGURED`).
2. Jalankan retry massal (Admin):

```bash
curl -X POST http://127.0.0.1:5000/api/admin/email/retry \
  -H "Authorization: Bearer <token-admin>" \
  -H "Content-Type: application/json" \
  -d '{"limit":20}'
```

3. Respons memuat `attempted`, `sent`, `pending`, `failed`, dan detail per tiket.
   `pending` berarti SMTP belum dikonfigurasi — bukan kegagalan aplikasi.
4. Bila SMTP belum tersedia, sampaikan ke peserta bahwa QR **tidak** dikirim via
   email (sesuai PRD C-02); peserta membuka e-ticket dari perangkat pemesanan.

---

## 8. Penanganan insiden

| Gejala | Pemeriksaan | Tindakan |
|---|---|---|
| Login Admin 401 `Invalid credentials` padahal akun ada di `profiles` | log startup `Account bootstrap: PASSWORD_MISMATCH` | Password tersimpan berbeda dari `ADMIN_PASSWORD`. Putar sekali: `$env:ADMIN_RESET_PASSWORD='true'; npm run admin:provision` lalu login dengan `ADMIN_EMAIL`/`ADMIN_PASSWORD` di `.env`. |
| Login Admin gagal `Tidak dapat terhubung ke server (<origin>)` | apakah backend hidup (`GET /health`), dan origin pada pesan error | Pesan kini menyebut alamat yang dituju. Jalankan backend (`npm run dev` dari `backend/`), lalu tekan **Cek koneksi server** di layar login; jawaban yang benar `database: connected`. Login Admin memakai `ADMIN_EMAIL` (atau `ADMIN_USERNAME`) + `ADMIN_PASSWORD` dari `backend/.env`, bukan `admin@event.com` (akun itu hanya persona `MOCK_MODE`). |
| Dashboard Admin menampilkan seluruh metrik 0 | `GET /api/admin/overview` dan isi tabel `events`/`event_orders` | 0 adalah nilai database yang sebenarnya bila belum ada event/order. Bila API gagal, banner merah "Gagal memuat ringkasan dari database" muncul beserta tombol **Muat ulang** — sebelumnya kegagalan disembunyikan dan angka contoh tetap tampil. |
| Pengaturan platform gagal disimpan | respons `PUT /api/admin/settings/:key` | Sejak perbaikan, kegagalan API ditampilkan sebagai SnackBar dan form tidak diklaim "berhasil". Periksa backend dan hak Admin. |
| Login & registrasi gagal bersamaan ("Tidak dapat terhubung ke server") | base URL aplikasi (`AppConfig.apiBaseUrl`) vs host backend | Default mengikuti target (web/desktop `127.0.0.1:5000/api`, emulator Android `10.0.2.2:5000/api`). Perangkat fisik/LAN memerlukan `--dart-define=API_BASE_URL=http://<IP-LAN>:5000/api`. |
| Registrasi Organizer 400 `Validation failed` | body response `errors[].field` | Pesan kini menyebut field yang gagal (mis. `email: Valid email is required`). Perbaiki input sesuai field tersebut. |
| `/health` → 503 | `database: disconnected` | Periksa `DATABASE_URL`, status PostgreSQL, kuota pool. |
| Semua scan/check-in 500 | log `column "status" does not exist` | Regresi `assertScanPermission`; jalankan `npm test` (test `d1_integration_regression`). |
| Scan kamera 400 | log validasi `ticket_code is required` | Regresi `verifyTicketValidator`; test regresi menangkap ini. |
| Daftar peserta/export 500 | log `profiles.phone` atau `UNION types` | Regresi query peserta; lihat test `d1_integration_regression`. |
| Suspend akun "sukses" tapi akun aktif | `audit_logs` tidak bertambah | Regresi `updateAccountStatus`; pastikan klien mengirim `is_active`. |
| Admin tidak bisa memulihkan event | 400 `Invalid moderation decision` | Regresi pemetaan `PUBLISHED`→`APPROVED` di `moderateEvent`. |
| Browser gagal memanggil API (CORS) | header `Access-Control-Allow-Origin` | Tambahkan origin ke `ALLOWED_ORIGINS`, restart backend. |
| 429 pada login/order | rate limit | Tunggu jendela `RATE_LIMIT_WINDOW_MS` atau naikkan batas pada environment uji. |
| Tiket tidak bisa dibayar | `status` order `EXPIRED` | Order kedaluwarsa tidak dapat dibayar; buat order baru. |
| QR tidak tampil | tiket `PENDING`/`CANCELLED`/`REVOKED` | QR hanya dirender untuk tiket valid; cek status tiket. |

Jangan menutupi bug dengan fallback mock. Semua jalur API gagal harus
menampilkan error yang jujur ke pengguna.

---

## 9. Pemeriksaan berkala

| Frekuensi | Tindakan |
|---|---|
| Harian | `/health`, tinjau log `unhandled_error`, cek `ticket_email_deliveries` `FAILED`. |
| Mingguan | `npm test`, `flutter analyze`, tinjau `audit_logs` untuk aksi Admin. |
| Sebelum rilis | `npm run test:e2e`, `flutter test`, `flutter build web`, smoke test per role. |

---

## 10. Batasan yang diketahui

- Kamera pada web memerlukan HTTPS atau `localhost`; pada emulator Android
  gunakan `10.0.2.2`.
- Pengiriman email nyata bergantung pada kredensial SMTP; tanpa itu status
  tercatat `NOT_CONFIGURED`.
- Backup/restore belum tersedia sebagai skrip; gunakan prosedur manual di §5.
