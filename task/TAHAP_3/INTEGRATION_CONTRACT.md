# Kontrak integrasi — Tahap 3 (demo readiness)

## Gate dan baseline

Mulai hanya setelah Tahap 2 memiliki laporan integrasi **GO** dengan baseline,
CI dan bukti yang bisa diperiksa. Keputusan PRD yang mempengaruhi task, kontrak
API/data, environment demo, serta proposal yang menyentuh database harus sudah
diselesaikan sebelum pekerjaan terkait. Jika laporan gate kosong/tidak memiliki
bukti, keputusan masih terbuka, atau baseline tidak dapat diverifikasi: **BLOCKED**.

## Kontrak bersama

- Flutter menggunakan API mode secara default. `MOCK_MODE=true` hanya untuk unit/
  widget test terisolasi, bukan bukti E2E atau penerimaan demo.
- D1/D2 hanya menggunakan payload, model dan extension point yang benar-benar
  tersedia pada baseline dan disetujui. Tidak mengarang endpoint atau respons.
- Form, brosur dan ticket presentation tidak boleh mengklaim persist jika API/
  storage baseline tidak menyimpan datanya. Missing capability adalah blocker.
- Guest journey mengikuti aturan yang sudah CONFIRMED di PRD: guest tanpa akun,
  satu ticket per order, harga order terkunci, gratis langsung issue dan berbayar
  setelah PAID, kategori event homogen free/paid. Bagian yang memerlukan formula
  C-01, guest payment authority C-02 atau subscription gate C-03 tetap BLOCKED
  sampai keputusan disahkan. API failure tetap error, tidak fallback ke mock.
- Ticket/check-in menggunakan tiket dan otorisasi server. Email/provider hanya
  diklaim berhasil jika dibuktikan oleh sandbox yang diizinkan.
- UI wajib mempertahankan loading, empty, error, unauthorized, retry, success
  serta responsive states sesuai acceptance PRD.
- Tidak mengubah response/error envelope, JWT/role, route, konfigurasi global,
  atau kontrak shared tanpa persetujuan tertulis dan owner tunggal sebelum coding.
- Database source schema yang ditetapkan ialah `backend/prisma/schema.prisma`;
  migration aktifnya di `backend/prisma/migrations/`. SQL `backend/supabase/
  migrations/` adalah legacy yang dipertahankan dan status/fungsinya harus
  direkonsiliasi sebelum dijalankan. Jangan mengubah atau menjalankan migration
  pada Tahap 3. Otoritas FINISHING dijelaskan di `../FINISHING_AUTHORITY.md`.

## Batas Tahap 3

- **Developer 1:** konfigurasi form Organizer dan presentasi default/template
  tiket hanya jika didukung kontrak/storage baseline. Tidak mengambil alih
  registration rendering milik D2. Brosur upload tidak boleh disimulasikan;
  bila tidak ada kontrak upload persisten, catat blocker dan bukti yang perlu.
  Form fields saat ini ada sebagai `events.attendee_fields`, tetapi typed schema,
  versioning dan persisted UX belum dibuktikan; jangan mengklaim konfigurasi
  selesai sampai contract read/write + validation disepakati. Template/default
  ticket storage/selector belum terverifikasi; belum ada owner API/storage shared.
- **Developer 2:** public guest journey event → form → order → payment → ticket,
  responsive UI, menggunakan API/interface yang ada dan keputusan final. Tidak
  menunggu branch D1; tidak memakai code yang belum merge. Dynamic form rendering
  tergantung payload pada baseline; bila tidak lengkap, issue interface dan block
  hanya acceptance rendering yang terdampak.
- **Developer 3:** runbook/checklist/smoke evidence untuk kemampuan yang benar-
  benar tersedia pada baseline. Tidak menggantikan implementasi fitur, membuat
  dummy integration, atau menutupi acceptance yang gagal.
- **Integrator:** pasca-merge memeriksa ownership, kontrak semantik, API/data,
  import/navigation, test/build dan laporan. Integrator tidak mengerjakan ulang
  domain atau mengubah database secara otomatis.

Allow-list authoritative berada di [`FILE_OWNERSHIP.md`](FILE_OWNERSHIP.md).
Ketiga developer bekerja dari baseline sama dengan PR terpisah; file-path tidak
overlap bukan bukti semantic compatibility. Perubahan kontrak/ownership mesti
disepakati tertulis sebelum branch dibuat.

## Data and evidence dependency notes

- `attendee_fields` dan `poster_url` pada schema/API bukan bukti upload/storage
  persisten atau dynamic field types/validation lengkap.
- D1 form, D2 renderer dan backend event payload perlu contract fields, stable
  identifiers, validation errors and owner for any shared endpoint/model before
  implementation can claim end-to-end acceptance.
- Ticket template/default presentation must consume an existing persisted
  template identifier/data; no local-only picker success.
- If any required shared API/model/router or DB work is missing, report the exact
  interface and block only affected AC. Do not edit locked paths.

## Acceptance dan integrasi

Setiap PR menyertakan baseline, file aktual, pemetaan acceptance PRD, perubahan
kontrak (atau “tidak ada”), tests dan hasil, status API/DB/device/provider
(PASS/FAIL/BLOCKED/NOT RUN), serta blocker/risiko. Runbook/checklist D3 harus
tertaut dan diuji terhadap command yang ada; data sintetis dan environment demo
terisolasi saja.

Integrasi Tahap 3 hanya GO jika seluruh mandatory acceptance yang masuk tahap
terbukti, tests/build relevan lulus atau batasan diterima secara eksplisit,
tidak ada mismatch kontrak/blocker P0, dan demo tidak bergantung mock-only.
Setelah itu FINISHING berjalan menurut otoritas tertulis; demo final GO hanya
berdasarkan bukti API/DB/E2E dan Android/Web yang benar-benar tersedia. Bug domain
dikembalikan kepada owner, bukan disamarkan sebagai task finishing.