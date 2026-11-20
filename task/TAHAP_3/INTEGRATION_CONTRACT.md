# Kontrak integrasi — Tahap 3 (demo readiness)

## Baseline dan cara memulai (non-blocking)

Dokumen ini referensi teknis, **bukan gate izin**. Perintah pemilik proyek
(“Kerjakan Developer N Tahap 3”) sudah merupakan otorisasi implementasi. Laporan
integrasi Tahap 2 yang belum GO, keputusan PRD yang masih terbuka, atau baseline
yang tidak dapat diverifikasi **bukan** alasan berhenti: periksa kondisi kode
aktual, kerjakan scope yang dapat diselesaikan, dan catat asumsi, bukti yang
tersedia, serta bagian yang benar-benar memerlukan environment demo (mis. device/
build) sebagai NOT RUN bila tidak dapat dijalankan di lingkungan kerja.

## Kontrak bersama

- Flutter menggunakan API mode secara default. `MOCK_MODE=true` hanya untuk unit/
  widget test terisolasi, bukan bukti E2E atau penerimaan demo.
- D1/D2 hanya menggunakan payload, model dan extension point yang benar-benar
  tersedia pada baseline dan disetujui. Tidak mengarang endpoint atau respons.
- Form, brosur dan ticket presentation tidak boleh mengklaim persist jika API/
  storage baseline tidak menyimpan datanya. Missing capability adalah blocker.
- Guest journey mengikuti aturan yang sudah CONFIRMED di PRD: guest tanpa akun,
  satu ticket per order, harga order terkunci, gratis langsung issue dan berbayar
  setelah PAID, kategori event homogen free/paid. Bagian yang bersinggungan dengan
  formula C-01, guest payment authority C-02 atau subscription gate C-03
  **dikerjakan dengan interpretasi paling aman dan konsisten PRD** (utamakan angka
  yang sudah CONFIRMED, mis. fee Rp5.000 + 5%), lalu dicatat sebagai asumsi pada
  laporan — bukan dihentikan. API failure tetap error, tidak fallback ke mock.
- Ticket/check-in menggunakan tiket dan otorisasi server. Email/provider hanya
  diklaim berhasil jika dibuktikan oleh sandbox yang diizinkan; bila tidak
  tersedia, tandai NOT RUN dan lanjutkan bagian lain.
- UI wajib mempertahankan loading, empty, error, unauthorized, retry, success
  serta responsive states sesuai acceptance PRD.
- Tidak mengubah response/error envelope, JWT/role, route, konfigurasi global,
  atau kontrak shared secara sepihak tanpa pencatatan. Bila perubahan semacam itu
  benar-benar diperlukan untuk menyelesaikan task: lakukan perubahan minimum, jaga
  kompatibilitas, dan dokumentasikan file/alasan/dampak pada laporan.
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