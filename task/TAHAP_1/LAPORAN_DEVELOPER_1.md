# Laporan Developer 1 — Tahap 1 (selesai — scope auth/session)

- **Status:** DONE untuk scope pekerjaan D1 Tahap 1. **Bukan gate integrasi.**
  Alur: audit/trace read-only dikerjakan lebih dulu dan dilaporkan BLOCKED, lalu
  maintainer menyetujui blocker B-1…B-4 sehingga GAP-1…GAP-4 diimplementasikan
  dan diuji. Tidak ada bagian terdampak yang diimplementasikan sebelum approval.
- **Baseline commit / branch / PR:** branch `update/featur`, base commit `5413de1`
  ("docs: perbarui audit dan dokumentasi proyek") — disetujui sebagai baseline
  Tahap 1 melalui Amendment A-1 butir 1. Sebelum pekerjaan dimulai working tree
  bersih (`git status --porcelain` kosong); kini berisi diff pekerjaan D1 T1:
  5 file source diubah, 2 file test baru, 4 dokumen task. **PR/commit belum dibuat**
  — operasi Git pengubah state menunggu instruksi maintainer (field "Instruksi
  integrasi" butir 6).
- **Authorization/gate evidence:** **ADA — GO (limited) untuk D1 T1.**
  - Approver: maintainer proyek. Keputusan diberikan sebagai instruksi langsung
    pada sesi kerja "Developer 1 — Tahap 1" tanggal 2026-11-20, menyetujui
    **B-1 s.d. B-4** sekaligus (baseline + technical contract, pengesahan lokasi
    test auth, amendment `authMiddleware.js`, dan owner tunggal OR-1…OR-4).
  - Instrumen tertulis yang mencatat keputusan itu (dibuat sebagai bagian
    pekerjaan ini, sebelum source diubah):
    - `../TAHAP_1/FILE_OWNERSHIP.md` → bagian baru **"Amendment A-1 — Tahap 1,
      disetujui maintainer 2026-11-20"** (rincian mengikat per file/tujuan).
    - `../FASE_1C_AUTHORIZATION_REGISTER.md` §5 → baris D1 T1 diubah menjadi
      "GO (limited) — approved 2026-11-20" + paragraf keputusan berisi
      approver/scope/evidence.
    - `../FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md` §5 (baris D1 T1 + catatan
      update), §8 (bullet Developer 1 dan Tahap 1 keseluruhan).
  - Baseline disetujui: branch `update/featur`, commit `5413de1`.
  - Batas yang **tidak** dibuka oleh approval ini: C-01/C-02/C-03 tetap OPEN;
    database/schema/migration tetap wewenang FINISHING; baris D2/D3 tetap BLOCKED;
    Tahap 2/3 tidak terbuka; `backend/src/routes/**`, `backend/src/app.js`,
    `backend/src/config/**`, Prisma/Supabase, pubspec/lock dan CI tetap terlarang.
  - Riwayat: sebelum approval, status task ini BLOCKED sesuai
    `../FASE_1E_TASK_SYSTEM_FINALIZATION.md` kriteria 4 dan temuan #7; audit
    read-only tetap dikerjakan dan blocker dirinci di Lampiran B.
- **PRD requirement/AC yang dikerjakan:** PRD v2.2 §2 (2.1–2.4 aktor/hak akses),
  §12 dan §12.1 (kontrak teknis + route auth terverifikasi), §13 (aturan bisnis
  kanonis), §14 AC-02/AC-05/AC-08; §§15–16 dibaca sebagai gate aktif. Task:
  `TAHAP_1/DEVELOPER_1_TASK.md` pekerjaan 1–5 dan 5 kriteria verifikasi.
- **Ringkasan:** Trace dua arah login/register/me/updateMe/logout Flutter ↔
  Express diselesaikan dengan bukti `file:line` (Lampiran A): mapping
  request/header/JSON **konsisten** dengan kontrak yang ada, Bearer token benar,
  role ditetapkan server, dan **tidak ada** fallback ke mock saat API gagal. Audit
  menemukan 4 gap; setelah approval maintainer (Amendment A-1) **keempatnya
  ditutup** — GAP-1 pesan error eksplisit, GAP-2 state sesi ter-reset saat server
  membatalkan token (401), GAP-3 logout tidak lagi menghapus token akses order
  guest, GAP-4 kosakata role diselaraskan dengan PRD §2 secara additif. Ditambahkan
  17 test kontrak auth backend dan 22 test alur auth Flutter (sebelumnya test auth
  tidak ada sama sekali); seluruh suite backend dan Flutter lulus.
- **Fitur berhasil diselesaikan:**
  1. **GAP-1** — `AuthProvider` memetakan `AppException`/`FormatException` ke
     pesannya, sehingga UI tidak lagi menampilkan nama kelas internal
     (`AuthException: …`); exception tak dikenal dipetakan ke pesan generik.
  2. **GAP-2** — `SessionService` memancarkan `onSessionInvalidated`; `ApiClient`
     memicunya saat HTTP 401; `AuthProvider` berlangganan lalu mengosongkan
     `_user` dan menampilkan `sessionExpiredMessage`. Sesi yang dibatalkan server
     tidak lagi tampak "masih login" sampai aplikasi dibuka ulang.
  3. **GAP-3** — `SessionService.clear()` hanya menghapus `auth_token` dan
     `profile_name`; `order_access_token_*` milik alur guest order dipertahankan.
  4. **GAP-4** — `USER_ROLES` diselaraskan dengan PRD §2 (menambah `STAFF`,
     menandai `CUSTOMER` legacy) dan `UserRole.fromString` memetakan alias legacy
     `customer` secara eksplisit ke role tanpa hak istimewa.
  5. **Test auth** (sebelumnya tidak ada sama sekali): 17 test kontrak auth backend
     dan 22 test alur auth Flutter.
- **File dibuat:**
  - `backend/test/auth_contract.test.js` — 17 test; lapisan `config/db` di-stub
    melalui `require.cache` **sebelum** controller di-require, tanpa koneksi
    database sungguhan.
  - `apps/test/features/auth/auth_flow_test.dart` — 22 test; fake `AuthService`
    mengikuti pola `apps/test/widget_test.dart` dan `apps/test/app_router_test.dart`.
- **File diubah:**
  - `apps/lib/providers/auth_provider.dart` — allow-list D1 (GAP-1, GAP-2)
  - `apps/lib/core/services/session_service.dart` — OR-3 (GAP-2, GAP-3)
  - `apps/lib/core/network/api_client.dart` — OR-2 (GAP-2; 3 baris)
  - `apps/lib/models/user/user_role.dart` — OR-4 (GAP-4; additif)
  - `backend/src/utils/constants.js` — OR-4 (GAP-4; additif)
  - `task/TAHAP_1/FILE_OWNERSHIP.md` — Amendment A-1 (instrumen approval)
  - `task/FASE_1C_AUTHORIZATION_REGISTER.md` dan
    `task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md` — pencatatan keputusan
  - `task/TAHAP_1/LAPORAN_DEVELOPER_1.md` — laporan ini
  - **Sengaja tidak diubah** walau ownership-nya diberikan: `apps/lib/services/auth/auth_service.dart`
    (OR-1), `apps/lib/app.dart` (OR-2), dan `backend/src/middleware/authMiddleware.js`
    (B-3) — tidak ada perubahan yang diperlukan, agar diff tetap minimal.
- **File dihapus (alasan/bukti dependency):** Tidak ada.
- **Database/schema/migration:** Tidak ada perubahan; tidak ada koneksi database,
  migration, seed, atau SQL yang dijalankan. Dependency yang ditemukan (hanya
  dilaporkan, **bukan** approval, wewenang FINISHING sesuai
  `../FINISHING_AUTHORITY.md`): `backend/prisma/schema.prisma:158`
  `profiles.role String @db.Text` tanpa enum/CHECK, sehingga integritas nilai role
  tidak dijaga di level DB (`@@index([role])` di :183). Relevan untuk GAP-4;
  keputusan penambahan constraint adalah proposal FINISHING (lihat
  `../DB_CHANGE_PROPOSAL.md`), bukan pekerjaan D1.
- **API request/response:** Tidak ada perubahan kontrak. Hasil trace read-only
  (bukti `file:line` di Lampiran A): `POST /api/auth/login`,
  `POST /api/auth/register`, `GET /api/auth/me`, `PUT /api/auth/me`,
  `POST /api/auth/logout`. Envelope top-level `{success, token?, user?}` yang
  dikembalikan controller cocok dengan cara klien membaca response, dan
  `Authorization: Bearer <token>` dikirim otomatis oleh API client. Catatan
  dokumentasi (tanpa perubahan): `INTEGRATION_CONTRACT.md` baris 24 hanya menyebut
  `/login, /register, /me, /logout`, sedangkan `PUT /me` (profile update) aktif di
  `authRoutes.js:11` tetapi belum tercantum di kontrak → perlu dicatat integrator.
- **Data model:** Tidak ada perubahan schema/tabel/kolom. Yang berubah hanya
  pemetaan nilai role, bersifat additif: `apps/lib/models/user/user_role.dart` kini
  mengenali alias legacy backend `customer` → `UserRole.attendee` secara eksplisit
  (PRD §2.4: Participant tidak memiliki akun), dan `backend/src/utils/constants.js`
  menambah `USER_ROLES.STAFF = 'staff'` (PRD §2.3) serta menandai `CUSTOMER`
  sebagai legacy. `user_model.dart` dan `backend/src/models/User.js` **tidak**
  diubah; tidak ada migrasi data yang dibutuhkan karena nilai lama tetap terbaca.
- **Dependencies/config:** Tidak ada perubahan dependency, `pubspec.lock`,
  `package.json`, CI, atau `.env`; tidak ada secret yang dibaca/ditulis.
  `flutter analyze`/`flutter test` memicu `pub get` (resolusi paket lokal), tetapi
  tidak ada file lock/pubspec yang berubah — `git status` hanya menampilkan file
  source/test/dokumen yang memang disengaja. `AppConfig.mockMode` default `false`
  (`apps/lib/core/config/app_config.dart:23-26`): mode demo hanya aktif melalui
  `--dart-define=MOCK_MODE=true`, sesuai kontrak integrasi.
- **Tests (command, PASS/FAIL/SKIP/NOT RUN) + evidence:**
  - Test auth target (baru): **PASS** — lokasi disahkan Amendment A-1 butir 2.
    - `backend> npm test` (`node --test`) → **PASS** — `# tests 44 / # pass 44 /
      # fail 0 / # skipped 0` (baseline 27 + **17 test auth baru** dari
      `backend/test/auth_contract.test.js`).
    - `apps> flutter test` → **PASS** — `00:05 +172: All tests passed!`
      (baseline 150 + **22 test auth baru** dari
      `apps/test/features/auth/auth_flow_test.dart`). Tidak ada test lama yang
      regress.
  - Check lain setelah perubahan:
    - `backend> npm run check` → **PASS** — "Syntax OK: 61 JavaScript files checked."
    - `backend> npm run format:check` → **PASS** — "Formatting check passed (trailing whitespace and JSON syntax)."
    - `backend> npm run validate:skills` → **PASS** — "Validated 7 skills and links in 8 Markdown files."
    - `apps> flutter analyze` → **PASS** — "No issues found! (ran in 2.3s)"
  - Cakupan test auth baru: register mengabaikan `role` klien dan selalu menyimpan
    Organizer; register menolak email duplikat/field wajib/email invalid/password
    pendek tanpa INSERT; login valid (email **dan** username) → token + role dari
    DB; login 401 untuk password salah/user tidak ada/akun disabled tanpa token;
    login 400 tanpa identitas; `getMe`/`updateMe` memakai `req.user.id` dan hanya
    menerima `name`/`avatar_url`; logout menyimpan hash SHA-256 ke `revoked_tokens`;
    `authMiddleware` 401 untuk tanpa token/tanda tangan salah/token dicabut/akun
    disabled/user terhapus, dan **role dari DB mengalahkan klaim JWT**; sisi Flutter:
    pesan error tanpa nama kelas, tidak ada sesi mock saat gagal, invalidasi sesi
    401 mengosongkan state, logout membersihkan error, provider ter-dispose aman,
    `clear()` mempertahankan token order guest, dan pemetaan role legacy/tak dikenal
    tidak menghasilkan eskalasi hak.
  - Batas evidence: test berjalan dengan stub DB (`require.cache`) dan fake
    `AuthService`/mock secure storage — **bukan** integrasi Supabase/API hidup.
    Tidak ada klaim live auth, build Android/Web, E2E, atau deployment telah diuji.
    Test dijalankan lokal pada Windows, bukan CI.
- **Error/masalah belum selesai:**
  - **GAP-1 s.d. GAP-4: SELESAI** (rincian pada field "Fitur berhasil diselesaikan",
    bukti pada field "Tests"). Tidak ada test yang FAIL/SKIP pada suite backend
    maupun Flutter setelah perubahan.
  - **Sisa yang sengaja tidak dikerjakan pada Tahap 1** (di luar scope atau bukan
    wewenang D1):
    1. `profiles.role` bertipe TEXT tanpa enum/CHECK
       (`backend/prisma/schema.prisma:158`), sehingga integritas nilai role tidak
       dijaga di level DB. Penambahan constraint adalah wewenang FINISHING
       (`../FINISHING_AUTHORITY.md`, `../DB_CHANGE_PROPOSAL.md`); D1 tidak
       menyentuh schema/migration.
    2. **Penyediaan role Staff belum lengkap.** Backend tidak pernah menulis
       `profiles.role = 'staff'`: undangan Staff hanya mengisi
       `event_members.role = 'staff'`
       (`backend/src/controllers/eventInvitationController.js:173-175`), sedangkan
       `apps/lib/app.dart:77-78` merutekan `role == 'staff'` ke StaffDashboard.
       Akibatnya akun Staff hasil registrasi publik tetap ber-role `organizer`.
       Ini dependency kontrak invitation/membership = **scope D1 Tahap 2**, bukan
       Tahap 1 → diserahkan sebagai handoff, tidak diselesaikan di sini agar tidak
       membuka tahap berikutnya.
    3. `loginValidator` tersedia di `authValidator.js` tetapi tidak dipasang pada
       `authRoutes.js:9`, dan `PUT /me` belum memiliki validator. Memasangnya
       berarti mengubah `backend/src/routes/**` yang **tetap locked** bagi D1 →
       interface request ke maintainer/integrator. Perilaku saat ini tetap aman:
       controller memvalidasi manual dan `updateMe` memakai whitelist kolom.
    4. `AppConfig.apiBaseUrl` default `http://10.0.2.2:5000/api` (emulator
       Android); konfigurasi per-platform ada di `core/config` (shared) dan tidak
       diubah pada tahap ini.

- **Risiko konflik/owner request:**
  - **Konflik dokumen — SELESAI.** `FILE_OWNERSHIP.md` baris 7 memberi D1
    `backend/src/middleware/authMiddleware.js` sedangkan `INTEGRATION_CONTRACT.md`
    menyatakan perubahan auth middleware breaking/locked. Sesuai
    `FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md` ("bila ada selisih, hentikan
    perubahan dan minta maintainer menetapkan amendment"), D1 menghentikan
    perubahan dan meminta keputusan; maintainer menetapkannya lewat **Amendment
    A-1 butir 3** (D1 boleh mengubah hanya untuk perubahan non-breaking). Pada
    pelaksanaannya file itu **tidak diubah** karena tidak ada perubahan yang
    dibutuhkan, sehingga konflik tidak menimbulkan risiko sisa.
  - **OR-1…OR-4 — SELESAI sebagai owner tunggal D1** (Amendment A-1 butir 4),
    dibatasi pada file dan tujuan yang tercantum. Realisasi: OR-2 dipakai hanya 3
    baris di `api_client.dart`; OR-3 di `session_service.dart`; OR-4 di
    `user_role.dart` + `constants.js`; **OR-1 tidak dipakai** (`auth_service.dart`
    tidak diubah) dan `app.dart` tidak diubah.
  - **Risiko sisa yang perlu diperhatikan reviewer/integrator:**
    1. `SessionService.clear()` kini bersifat selektif. Bila ada fitur lain yang
       mengandalkan `deleteAll()` untuk reset penuh, perilakunya berubah — audit
       menunjukkan pemanggil hanya `auth_service.dart` dan `api_client.dart`
       (keduanya auth), jadi dampak terkendali.
    2. `AuthProvider` kini berlangganan stream global `SessionService.instance`.
       Langganan dibatalkan di `dispose()` dan notify dijaga `_disposed`, sehingga
       tidak ada "notifyListeners after dispose". Provider yang dibuat di test lama
       (`widget_test.dart`, `app_router_test.dart`, dll.) tidak terdampak — seluruh
       150 test lama tetap lulus.
    3. `USER_ROLES.STAFF` ditambahkan tetapi belum ada route yang memakainya;
       penyediaan role Staff sebenarnya adalah handoff Tahap 2 (lihat field
       "Error/masalah belum selesai" butir 2).
  - Tidak ada allow-glob yang tumpang tindih dengan D2/D3; D1 tidak menyentuh file
    developer lain, test global, maupun `backend/src/routes/**`.
- **Instruksi integrasi:** Perubahan D1 siap di-review sebagai **PR ke-1 (auth/access)**
  sesuai urutan merge `INTEGRATION_CONTRACT.md` (1 auth/access, 2 event/category,
  3 order/payment), dari base commit `5413de1`. Yang diminta dari integrator:
  1. Verifikasi ownership: diff hanya menyentuh 5 file source + 2 file test baru +
     dokumen approval/laporan (daftar lengkap pada field "File dibuat"/"File diubah").
     Tidak ada `backend/src/routes/**`, `backend/src/app.js`, `backend/src/config/**`,
     Prisma/Supabase, pubspec/lock, maupun CI.
  2. Jalankan ulang gate: `backend> npm test`, `npm run check`,
     `npm run format:check`; `apps> flutter analyze`, `flutter test`.
  3. Perhatikan 3 risiko sisa pada field "Risiko konflik/owner request", khususnya
     perubahan semantik `SessionService.clear()` (selektif, bukan `deleteAll()`).
  4. Tambahkan `PUT /api/auth/me` ke daftar kontrak auth pada
     `INTEGRATION_CONTRACT.md` baris 24 agar selaras dengan `authRoutes.js:11`
     (dokumen kontrak bukan milik D1).
  5. Teruskan handoff Tahap 2: penyediaan `profiles.role = 'staff'` pada alur
     invitation/membership (field "Error/masalah belum selesai" butir 2).
  6. **Belum ada commit/branch/PR yang dibuat.** Seluruh perubahan masih berupa
     working-tree diff pada branch `update/featur`; operasi Git pengubah state
     (branch/commit/push/PR) menunggu instruksi maintainer.

- **Kriteria task:** ID → status + evidence. Bukti gabungan code review
  (`file:line` pada baseline) **dan** test otomatis yang baru dibuat; bukan
  runtime/live auth terhadap backend hidup.
  - **K-1** Login valid → session/role ditetapkan benar; invalid credentials →
    error tanpa mock session → **PASS** (code review + test otomatis).
    Evidence: klien mengirim `{'email': ...}` bila
    input mengandung `@`, selain itu `{'username': ...}` + `password`
    (`auth_service.dart:60-69`); backend membaca
    `req.body.email || req.body.username` (`authController.js:70`) dan menolak
    identitas/password salah dengan 401 (`:88-102`); response `{success, token, user}`
    top-level (`:107-124`) dibaca klien sebagai `response['token']`/`response['user']`
    (`auth_service.dart:70-75`) karena API client meneruskan map apa adanya bila
    berisi key `success` (`api_client.dart:74`); token disimpan lalu role/user
    dibentuk dari payload server (`auth_service.dart:74-75`). `AppConfig.mockMode`
    default `false` (`app_config.dart:23-26`) dan jalur API tidak punya catch yang
    beralih ke demo account (`auth_service.dart:60-76`); kegagalan jaringan
    dilempar sebagai `NetworkException` (`api_client.dart:87-92`). Test:
    `backend/test/auth_contract.test.js` (login valid via email **dan** username →
    token + role DB; 401 password salah/user tidak ada/akun disabled tanpa token;
    400 tanpa identitas) dan `apps/test/features/auth/auth_flow_test.dart` (login
    sukses menyimpan user/role dari server; login gagal tidak menghasilkan sesi mock).
  - **K-2** `/me` dan profile update mengirim Bearer token yang benar; unauthorized
    ditangani → **PASS**. Evidence: header `Authorization: Bearer <token>` dari
    `SessionService.readToken()` (`api_client.dart:57-58`); `GET /auth/me` →
    `{success, user}` (`authController.js:126-138`) dibaca `response['user']`
    (`auth_service.dart:100-113`); `PUT /auth/me` body `{name}` → `{success, user}`
    (`authController.js:140-169`, `auth_service.dart:115-128`); status 401/403 →
    `_session.clear()` + `AuthException` (`api_client.dart:80-84`); `authMiddleware`
    menolak tanpa token/token invalid/token revoked dengan 401
    (`authMiddleware.js:50-63`). GAP-1 dan GAP-2 **sudah ditutup**: pesan
    unauthorized kini eksplisit dan state Provider ikut ter-reset saat 401. Test:
    `auth_contract.test.js` (getMe/updateMe memakai `req.user.id`; authMiddleware
    401 tanpa token/tanda tangan salah/token dicabut/akun disabled/user terhapus)
    dan `auth_flow_test.dart` (restoreSession sukses & gagal, updateProfile hanya
    mengirim `name`, invalidasi sesi 401 mengosongkan state + pesan
    `sessionExpiredMessage`).
  - **K-3** Logout membersihkan credential lokal; reopen tidak menganggap user
    logged-in → **PASS**. Evidence: `AuthService.logout` memanggil
    `POST /auth/logout` lalu `_session.clear()` di blok `finally` sehingga
    credential tetap terhapus walau request gagal (`auth_service.dart:130-140`);
    `SessionService.clear()` kini menghapus `auth_token` + `profile_name`
    (`session_service.dart:35-44`); `AuthProvider.logout` men-set `_user = null`
    dan membersihkan `_error` di `finally`; pada pembuatan provider dipanggil
    `restoreSession()` (`app.dart:22`) yang memverifikasi ke `/auth/me` dan
    melakukan logout bila gagal, lalu `AuthGate` menampilkan `LoginScreen` ketika
    `!isAuthenticated` (`app.dart:40-51`). GAP-3 **sudah ditutup**: token akses
    order guest tidak lagi ikut terhapus. Test: `auth_contract.test.js` (logout
    menyimpan hash SHA-256 ke `revoked_tokens`, bukan token mentah) dan
    `auth_flow_test.dart` (logout eksplisit membersihkan user+error; `clear()`
    menghapus credential auth tetapi mempertahankan `order_access_token_*`;
    restoreSession gagal → tidak terautentikasi).
  - **K-4** Role tidak dapat di-upgrade melalui input client; server tetap otoritas
    role → **PASS**. Evidence: validator registrasi hanya memvalidasi `name`,
    `email`, `password` — tidak ada field `role` (`authValidator.js:3-7`);
    controller hanya men-destructure `{name, email, password}`
    (`authController.js:14`) dan menulis role hardcoded `USER_ROLES.ORGANIZER`
    (`:50`), sesuai PRD §2.2/§13 bahwa registrasi publik menghasilkan Organizer;
    `updateMe` hanya menerima `name` dan `avatar_url` (`:146-155`) dengan identitas
    dari `req.user.id` hasil verifikasi JWT (`:129`, `:161`); role pada token
    berasal dari record DB (`:54`, `:105`; `authService.js:13-19`) dan
    `authMiddleware` memuat ulang role dari DB sehingga klaim JWT lama tidak
    dipercaya (`authMiddleware.js:19-43`). Sisi Flutter tidak mengirim maupun
    memilih role (`register_screen.dart:16-18,44-51`; `auth_service.dart:78-98`).
    GAP-4 **sudah ditutup** secara additif (alias legacy `customer`, `USER_ROLES.STAFF`).
    Test: `auth_contract.test.js` (register mengabaikan `role: 'admin'` dan tetap
    menyimpan Organizer — parameter INSERT tidak pernah berisi `admin`; updateMe
    membuang `role`/`email` klien; authMiddleware: token ber-klaim `admin` tetap
    menghasilkan `req.user.role === 'organizer'` dari DB) dan `auth_flow_test.dart`
    (register tidak pernah mengirim key `role`; role `customer`/tak dikenal
    dipetakan ke `attendee` tanpa eskalasi hak).
    Sisa di luar wewenang D1: `profiles.role` TEXT tanpa constraint
    (`schema.prisma:158`) → proposal FINISHING; penyediaan `profiles.role='staff'`
    → handoff Tahap 2.
  - **K-5** Jalankan test target baru/terdampak; catat command/result/skips →
    **PASS**. `backend> npm test` 44/44 PASS (17 test auth baru),
    `apps> flutter test` 172/172 PASS (22 test auth baru), `npm run check` PASS,
    `npm run format:check` PASS, `npm run validate:skills` PASS,
    `apps> flutter analyze` PASS — 0 skip, 0 fail (rincian pada field Tests).
    Tidak ada klaim live auth/provider, integrasi Supabase, build Android/Web,
    atau E2E telah diuji.

- **Integration handoff:**
  - **Interface/API contract yang dipakai (existing, tidak diubah):** envelope
    `{success, token, user}` untuk `POST /auth/login` (200) dan `POST /auth/register`
    (201); `{success, user}` untuk `GET /auth/me` dan `PUT /auth/me`;
    `{success, message}` untuk `POST /auth/logout`; error memakai
    `{success:false, message}` dari `errorMiddleware.js:37` (400 untuk input kurang,
    401 invalid credentials/akun disabled, 404 user not found). Header
    `Authorization: Bearer <token>`; login menerima `email` **atau** `username`.
  - **Revocation server nyata, bukan karangan:** logout menyimpan hash token ke
    tabel `revoked_tokens` (`authController.js:171-183`, hash SHA-256 via
    `authService.js:9-11`) dan `authMiddleware` menolaknya pada request berikutnya.
    Task pekerjaan 5 terpenuhi tanpa mengarang mekanisme baru.
  - **Dependency owner pasca Amendment A-1:** OR-2 (`api_client.dart`), OR-3
    (`session_service.dart`) dan OR-4 (`constants.js`, `user_role.dart`) dipegang D1
    untuk scope Tahap 1 dan telah dipakai seperlunya. OR-1
    (`apps/lib/services/auth/auth_service.dart`) serta `apps/lib/app.dart` juga
    diberikan ke D1 tetapi **tidak diubah** karena mapping yang ada sudah benar.
    `backend/src/routes/authRoutes.js` tetap locked — dibutuhkan hanya bila
    `loginValidator`/validator `PUT /me` ingin dipasang (interface request).
  - **Unresolved blockers:** tidak ada blocker otorisasi yang tersisa untuk D1 T1
    (B-1…B-4 diputuskan maintainer; bukti di Lampiran B). Yang tersisa bersifat
    handoff, bukan blocker scope ini: (a) constraint `profiles.role` → FINISHING;
    (b) penyediaan `profiles.role = 'staff'` pada alur invitation/membership →
    D1 Tahap 2; (c) pemasangan validator pada `authRoutes.js` → keputusan
    maintainer/integrator; (d) integrasi Tahap 1 tetap menunggu PR D2/D3 yang
    saat ini masih BLOCKED.
  - **Untuk D3:** `SessionService.clear()` **tidak lagi** memanggil `deleteAll()`;
    `order_access_token_*` milik alur guest order kini bertahan setelah logout
    akun. Bila D3 membutuhkan reset penuh, tambahkan API eksplisit (jangan
    mengandalkan efek samping logout) dan koordinasikan dengan D1 sebagai owner OR-3.
  - **Untuk D2:** tidak ada dependensi auth yang menghambat scope event/category;
    `authMiddleware`/`optionalAuth` tidak diubah sama sekali.


Isi berdasarkan git diff/test aktual; jangan menandai rencana sebagai hasil.

---

## Lampiran A — Trace auth dua arah (pekerjaan 1), bukti `file:line`

Baseline `5413de1`; seluruh path relatif root repo. Semua dibaca read-only.

| Alur | Sisi Flutter (pemanggil) | HTTP | Sisi backend | Hasil mapping |
|---|---|---|---|---|
| Login | `apps/lib/services/auth/auth_service.dart:44-76` — body `{'email': …}` bila input mengandung `@`, selain itu `{'username': …}`, plus `'password'` | `POST /auth/login` | `backend/src/routes/authRoutes.js:9` → `controllers/authController.js:68-124`; identity `req.body.email \|\| req.body.username` (`:70`), 400 bila kosong (`:73`), 401 user tidak ada/password salah/akun disabled (`:88-102`) | **COCOK** — 200 `{success, token, user}` top-level (`:107-124`) dibaca `response['token']`/`response['user']` (`auth_service.dart:70-75`); API client meneruskan map apa adanya karena berisi key `success` (`apps/lib/core/network/api_client.dart:74`) |
| Register | `auth_service.dart:78-98` — body hanya `{name, email, password}`; **tanpa field role** | `POST /auth/register` | `authRoutes.js:8` (+`registerValidator`, `validationMiddleware`) → `authController.js:13-61`; validator whitelist `name/email/password` (`validators/authValidator.js:3-7`); role di-hardcode `USER_ROLES.ORGANIZER` (`:50`) | **COCOK** — 201 `{success, token, user}` (`:56-60`); mode demo justru menolak registrasi (`auth_service.dart:83-86`) sehingga tidak ada akun palsu |
| Me | `auth_service.dart:100-113` → `_api.get('/auth/me')`, baca `response['user']` | `GET /auth/me` + Bearer | `authRoutes.js:10` (`authMiddleware`) → `authController.js:126-138`; 404 bila profil hilang | **COCOK** — `{success, user}` (`:137`); Bearer dipasang `api_client.dart:57-58` |
| UpdateMe | `auth_service.dart:115-128` → `_api.put('/auth/me', body: {'name': …})` | `PUT /auth/me` + Bearer | `authRoutes.js:11` → `authController.js:140-169`; hanya `name` & `avatar_url` yang diterima (`:146-155`), 400 bila kosong (`:156-159`), identitas `req.user.id` (`:161`) | **COCOK** — `{success, user}` (`:168`); role tidak dapat diubah klien |
| Logout | `auth_service.dart:130-140` → `POST /auth/logout`, lalu `_session.clear()` di `finally` (`:137-138`) | `POST /auth/logout` + Bearer | `authRoutes.js:12` → `authController.js:171-183`; hash token disimpan ke `revoked_tokens` (`:177-179`); hash SHA-256 `services/authService.js:9-11` | **COCOK** — credential lokal tetap terhapus walau request gagal; revocation server **nyata** dan diperiksa `middleware/authMiddleware.js` |

Penanganan error/sesi di lapisan bersama:
`api_client.dart:80-83` → pada HTTP 401 sesi dibersihkan **dan**
`notifySessionInvalidated()` dipancarkan (baris 82 = hasil perbaikan GAP-2),
`:84-86` → 401/403 dilempar `AuthException`, `:87` dan `:91-95` → kegagalan
`NetworkException` dengan pesan Indonesia. Tidak ada jalur yang mengembalikan data
mock/demo saat API gagal, dan `AppConfig.mockMode` default `false`
(`apps/lib/core/config/app_config.dart:23-26`) — sesuai kontrak integrasi baris 27 & 33.

State di Provider (`apps/lib/providers/auth_provider.dart`; 117 baris saat audit,
171 baris setelah perbaikan): `isAuthenticated => _user != null`, `restoreSession()`
verifikasi via `me()` dan `logout()` + `_user = null` bila gagal, `login`,
`register`, `updateProfile`, `logout`. Saat audit, ketiga blok `catch` menyimpan
`_error = e.toString()` (`:48`, `:72`, `:88`) → **GAP-1**, kini diganti
`_error = _messageForError(e)`; ditambah `_onSessionInvalidated()` (GAP-2) dan
`dispose()` yang membatalkan langganan stream.
UI: loading & error eksplisit di `features/auth/screens/login_screen.dart:52-55`,
`register_screen.dart:52-55`, `profile_edit_screen.dart:66-77` (tombol nonaktif +
spinner saat `isLoading`, SnackBar saat gagal); gate role di `apps/lib/app.dart:40-63`.
Ketiga layar auth **tidak diubah** — perbaikan dilakukan di lapisan Provider
sehingga seluruh layar otomatis mendapat pesan yang eksplisit.


---

## Lampiran B — Blocker spesifik, approver, bukti yang dibutuhkan

**Status akhir: B-1…B-4 DIPUTUSKAN maintainer pada 2026-11-20** dan dicatat pada
`TAHAP_1/FILE_OWNERSHIP.md` → "Amendment A-1", `FASE_1C_AUTHORIZATION_REGISTER.md`
§5, serta `FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md` §5/§8. Tabel di bawah
dipertahankan sebagai **jejak audit**: inilah blocker yang sempat membuat seluruh
scope D1 T1 berstatus BLOCKED (sesuai langkah 8 `PEMBAGIAN_TUGAS_FINAL.md`, bagian
terdampak tidak diimplementasikan sebelum approval ada), beserta bukti yang
kemudian dipenuhi.

| ID | Blocker spesifik | Owner / approver | Bukti yang dibutuhkan | Yang terblokir | Status |
|---|---|---|---|---|---|
| **B-1** | Baseline Tahap 1 dan technical contract belum disetujui tertulis. `FASE_1C` §5/§7 dan `FASE_1D` §5/§8 menyatakan "D1 T1 — Cannot start / belum resmi boleh mulai"; kolom keputusan-approver-evidence kosong. Perintah "Developer 1 — Tahap 1" bukan approval. | Maintainer / pemilik produk + technical owner (bukan AI, bukan D1, bukan D4 otomatis) | Catatan tertulis: branch + commit baseline (usulan: `update/featur` @ `5413de1`), keputusan GO untuk kontrak `TAHAP_1/INTEGRATION_CONTRACT.md`, nama approver, tanggal, dan rujukan evidence | Seluruh implementasi D1 T1 dan semua acceptance yang butuh perubahan kode/test | **TERPENUHI** — Amendment A-1 butir 1 + baris GO di `FASE_1C` §5 |
| **B-2** | Lokasi & ownership test auth belum disahkan. `apps/test/features/auth/**` dan `backend/test/auth_*.test.js` belum ada; `FASE_1E` temuan #7 melarang membuat file test sebelum lokasinya disetujui allow-list/amendment. | Maintainer (amendment `TAHAP_1/FILE_OWNERSHIP.md`) | Konfirmasi tertulis bahwa kedua path tersebut boleh dibuat oleh D1 sebagai author tunggal, plus kesepakatan tidak menyentuh test global/existing | K-1…K-5 untuk bukti test; pekerjaan 3 (audit/perbaikan test role/auth) | **TERPENUHI** — Amendment A-1 butir 2; 2 file test dibuat, test existing tidak disentuh |
| **B-3** | Konflik dokumen: `FILE_OWNERSHIP.md` baris 7 memberi D1 `backend/src/middleware/authMiddleware.js`, sedangkan `INTEGRATION_CONTRACT.md` menyatakan perubahan auth middleware = breaking/locked. `FASE_1E` mewajibkan berhenti dan meminta amendment bila ada selisih. | Maintainer (amendment allow-list **atau** kontrak) | Amendment tertulis yang menetapkan salah satu: (a) `authMiddleware.js` milik D1 untuk perubahan non-breaking, atau (b) tetap locked → D1 hanya mengajukan interface request | Perubahan apa pun pada `authMiddleware.js` | **TERPENUHI** — Amendment A-1 butir 3 memilih opsi (a); file akhirnya tidak diubah |
| **B-4** | GAP-2/GAP-3/GAP-4 hanya dapat ditutup di file locked/shared (OR-1…OR-4). | Maintainer + owner domain terkait (D3 untuk `order_access_token_*`; FINISHING untuk `profiles.role`) | Penunjukan owner tunggal tertulis per file + amendment allow-list; untuk constraint DB → proposal FINISHING terpisah | K-2 (sesi kedaluwarsa di tengah sesi), K-3 (efek samping `deleteAll()`), K-4 (kosakata role vs PRD §2) | **TERPENUHI sebagian** — Amendment A-1 butir 4 memberi owner tunggal OR-1…OR-4; GAP-2/3/4 ditutup. Constraint `profiles.role` **tetap** wewenang FINISHING dan tidak dikerjakan |



### Rencana implementasi — **SUDAH DIEKSEKUSI** setelah B-1 + B-2 disetujui

Rencana ini disusun saat status masih BLOCKED dan dieksekusi setelah Amendment A-1
disahkan. Seluruhnya berada di dalam kolom "boleh" D1 pada
`TAHAP_1/FILE_OWNERSHIP.md` baris 7 **plus** OR-1…OR-4 dari Amendment A-1 butir 4;
tidak ada perubahan DB/schema/route/kontrak, dan Tahap 2 tidak dibuka.
Realisasi per butir (butir 1–4 = rencana asli; butir 5–7 = tambahan yang menjadi
mungkin setelah OR-2/OR-3/OR-4 disetujui):

1. **GAP-1 — SELESAI.** `apps/lib/providers/auth_provider.dart` kini memakai
   `_messageForError(e)`: `AppException → e.message`, `FormatException → e.message`
   (pesan Indonesia dari `AuthService`), selain itu pesan generik
   `"Terjadi kesalahan. Silakan coba lagi."`. Public API Provider tidak berubah
   (hanya menambah konstanta `sessionExpiredMessage`), sesuai
   `INTEGRATION_CONTRACT.md` baris 31. Ditambah penjaga `_disposed` agar tidak ada
   `notifyListeners()` setelah `dispose()`.
2. **Test Flutter — SELESAI (22 test).** `apps/test/features/auth/auth_flow_test.dart`
   memakai fake `_FakeAuthService extends AuthService` mengikuti pola
   `apps/test/widget_test.dart`/`app_router_test.dart` — **bukan** `MockClient`,
   karena `AuthService` membangun `ApiClient()` singleton internally sehingga tidak
   ada titik injeksi HTTP. Konsekuensinya pemetaan HTTP diuji lewat bukti code
   review (Lampiran A) + test level Provider; ini dicatat sebagai keterbatasan,
   bukan klaim integrasi.
3. **Test backend — SELESAI (17 test).** `backend/test/auth_contract.test.js`
   memakai `node:test` + `node:assert/strict` (pola `backend/test/utils.test.js`)
   dan men-stub `../src/config/db` melalui `require.cache` **sebelum**
   controller/middleware di-require (keduanya men-destructure `query`/`getOne` saat
   import). Tanpa koneksi database; `node --test` mengisolasi tiap file dalam
   proses terpisah sehingga stub tidak bocor ke test lain.
4. **Verifikasi — SELESAI.** `backend> npm test` 44/44, `npm run check`,
   `npm run format:check`, `npm run validate:skills`, `apps> flutter analyze`,
   `apps> flutter test` 172/172 — semua PASS, 0 fail/0 skip (field Tests).
   Diff ditinjau terhadap allow-list + Amendment A-1 sebelum diserahkan.
5. **GAP-2 — SELESAI** (OR-2 + OR-3). `SessionService.onSessionInvalidated`
   (broadcast) dipicu `ApiClient` saat HTTP 401; `AuthProvider` berlangganan dan
   mengosongkan `_user` + men-set `sessionExpiredMessage`. `app.dart` tidak diubah.
6. **GAP-3 — SELESAI** (OR-3). `SessionService.clear()` mengganti `deleteAll()`
   dengan penghapusan `auth_token` + `profile_name` saja.
7. **GAP-4 — SELESAI secara additif** (OR-4). `USER_ROLES` menambah `STAFF`
   dan menandai `CUSTOMER` legacy; `UserRole.fromString` memetakan alias
   `customer`. `user_model.dart` dan `app.dart` **tidak** diubah; keputusan taksonomi
   role yang lebih dalam (constraint DB, penyediaan `profiles.role='staff'`)
   diserahkan sebagai handoff, bukan diputuskan sepihak.


### Owner request — status setelah Amendment A-1

Semua permintaan di bawah dikabulkan maintainer sebagai **owner tunggal D1**
(Amendment A-1 butir 4), dibatasi pada file dan tujuan yang tercantum.

| ID | File/interface persis | Permintaan | Alasan/kriteria terdampak | Status |
|---|---|---|---|---|
| **OR-1** | `apps/lib/services/auth/auth_service.dart` | Tetapkan owner tunggal atau tambahkan ke allow-list D1 | Pusat mapping HTTP auth; setiap perbaikan request/response auth jatuh di file ini, tetapi di luar kolom "boleh" D1 (K-1, K-2) | Dikabulkan; **tidak dipakai** — mapping sudah benar, file tidak diubah |
| **OR-2** | `apps/lib/core/network/api_client.dart` (401 → `_session.clear()` di `:80`) + `apps/lib/app.dart` (`AuthGate` `:40-51`) | Sediakan mekanisme notifikasi invalidasi sesi ke `AuthProvider` (callback/stream/penanda) | GAP-2: UI tetap terautentikasi setelah token kedaluwarsa/dicabut di tengah sesi (K-2) | Dikabulkan; dipakai 3 baris di `api_client.dart` (`notifySessionInvalidated()`), `app.dart` tidak diubah |
| **OR-3** | `apps/lib/core/services/session_service.dart:22` (`clear()` → `deleteAll()`) | Pisahkan penghapusan credential auth dari `order_access_token_*`, atau konfirmasi perilaku ini disengaja | GAP-3: logout akun menghapus akses order guest milik domain D3 (K-3) | Dikabulkan; `clear()` kini selektif + ditambah stream `onSessionInvalidated` |
| **OR-4** | `backend/src/utils/constants.js:12-16` (`USER_ROLES`), `apps/lib/models/user/user_role.dart`, `user_model.dart:39`, `apps/lib/app.dart` (`_homeForRole`) | Putuskan kosakata role kanonis sesuai PRD §2 (Admin/Organizer/Staff/Participant-tanpa-akun) dan hilangkan fallback diam-diam ke `attendee` | GAP-4: `customer` (backend) tidak dikenal Flutter → dipetakan ke `attendee` dan diberi layar daftar event, bertentangan dengan PRD §2.4 (K-4) | Dikabulkan; perubahan **additif** pada `constants.js` + `user_role.dart`. `user_model.dart`/`app.dart` tidak diubah; taksonomi penuh + constraint DB diserahkan sebagai handoff |

### Pernyataan kepatuhan

Tahap audit (sebelum approval) hanya membaca source/dokumen, menjalankan check/test
yang ada, dan mengisi laporan; tidak ada source yang diubah saat status masih
BLOCKED. Setelah maintainer menyetujui B-1…B-4 dan Amendment A-1 dicatat, perubahan
dilakukan **hanya** pada file yang tercantum di field "File dibuat"/"File diubah".
Sepanjang pekerjaan ini: tidak ada perubahan schema/migration/SQL/seed, tidak ada
koneksi atau mutasi database (test backend memakai stub `require.cache`), tidak ada
dependency baru, tidak ada secret/`.env`/token yang dibaca atau ditulis ke repo,
tidak ada perubahan pada `backend/src/routes/**`, `backend/src/app.js`,
`backend/src/config/**`, Prisma/Supabase, pubspec/lock, atau CI, tidak ada operasi
Git pengubah state (commit/push/merge/branch), dan Tahap 2/3 tidak dibuka.
Klaim keberhasilan dibatasi pada unit/widget test lokal — **bukan** integrasi
Supabase/API hidup, build Android/Web, E2E, deployment, atau keamanan penuh.


