# Peta Kerja Final — E-Ticket Event & QR Scanner

Dokumen ini adalah **controller proyek** untuk tugas Developer 1–3. PRD aktif
adalah [`../PRD.md`](../PRD.md); task rinci, allow-list ownership, integrasi,
laporan, dan gate tahap berada di folder `TAHAP_1/`, `TAHAP_2/`, dan
`TAHAP_3/`. Dokumen lama di `archive/` bersifat historis, bukan instruksi kerja.

## Cara memulai (prompt singkat — instruksi operasional)

Perintah yang didukung, tanpa prompt tambahan:

`Developer 1 — Tahap 1` · `Developer 2 — Tahap 1` · `Developer 3 — Tahap 1`
`Developer 1 — Tahap 2` · `Developer 2 — Tahap 2` · `Developer 3 — Tahap 2`
`Developer 1 — Tahap 3` · `Developer 2 — Tahap 3` · `Developer 3 — Tahap 3`

Perintah tersebut cukup untuk memilih dan melaksanakan task. AI wajib membaca
controller ini, task bernomor sama, allow-list `FILE_OWNERSHIP.md`,
`INTEGRATION_CONTRACT.md`, ledger Fase 1E, matriks PRD, authorization register,
laporan developer dan laporan integrasi/gate sebelumnya yang relevan, lalu source
terbatas yang dirujuk task. AI tidak meminta developer mengulang scope, analisis,
file, atau acceptance yang sudah ditetapkan dokumen. Perintah **bukan** approval:
status izin dinilai per task dan acceptance berdasarkan bukti approval/gate yang
berlaku, bukan blanket status fase.

AI harus menyatakan task/AC yang siap dan terblokir serta bukti/approval yang
kurang. Jika seluruh prasyarat task GO, langsung kerjakan seluruh scope yang
diizinkan, jalankan tes yang ditetapkan, isi laporan tahap milik developer, lalu
siapkan handoff untuk integrator. Jika BLOCKED, jangan implementasikan bagian
terdampak; sebutkan blocker spesifik, owner/approver dan bukti yang diperlukan,
serta kerjakan hanya sub-scope independen yang eksplisit diizinkan. Jangan beralih
ke tahap berikutnya otomatis. Untuk FINISHING, gunakan jalur otorisasi terpisah;
perintah singkat D1–D3 tidak memberi wewenang database kepada Developer 4.

## Authorization status saat snapshot

- `task/FASE_1C_AUTHORIZATION_REGISTER.md` dan
  `task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md` adalah catatan rekomendasi/
  blocker sampai kolom keputusan/approver/evidence benar-benar diisi pihak
  berwenang. Teks AI atau status dokumen saja tidak mengotorisasi implementasi.
- Untuk gate/ownership pending, baca
  [`FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md`](FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md).
- Snapshot saat ini tidak mempunyai approval tertulis/baseline sign-off: D1 T1
  auth adalah kandidat independent scope, tetapi tetap **BLOCKED** sampai
  maintainer mengesahkan baseline, technical gate dan test path; D2 T1 lifecycle
  dan D3 T1 order/payment tetap **BLOCKED** sesuai contract/OPEN decisions.

1. Identifikasi developer (1/2/3 atau FINISHING) dan tahap (1/2/3/FINISHING).
   Jika identitas/tahap tidak jelas, berhenti dan minta klarifikasi.
2. Periksa `git status --short --branch` dan diff. Jangan menimpa, membuang,
   atau mengatribusikan perubahan yang sudah ada. Jangan membaca `.env`.
3. Baca `PRD.md` hanya bagian yang dirujuk task terpilih; baca task developer
   tersebut, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACT.md`,
   [`FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md`](FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md),
   [`FASE_1E_TASK_SYSTEM_FINALIZATION.md`](FASE_1E_TASK_SYSTEM_FINALIZATION.md),
   laporan gate tahap sebelumnya, dan hanya source/tests yang disebut task bila
   gate mengizinkan.
4. Verifikasi gate sebelumnya dari laporan integrasi **dan** bukti baseline/CI
   yang dirujuk. Template kosong, klaim tanpa evidence, status NOT RUN, atau
   baseline tidak diketahui berarti **BLOCKED**. Periksa OPEN DECISION PRD per
   acceptance/task: hanya pekerjaan yang bergantung pada keputusan tersebut
   diblokir; jangan memperluas atau mengabaikan blocker secara sepihak.
5. Pastikan task belum selesai pada baseline aktif melalui laporan, PR/diff dan
   bukti terkait. Jangan mengulang task; bila status tidak terbukti, berhenti dan
   laporkan blocker.
6. Periksa semua file yang akan disentuh terhadap allow-list task. Jangan edit
   kontrak bersama, file developer lain, atau file di luar allow-list. Jika
   perlu perubahan interface/file milik orang lain, buat laporan kebutuhan:
   file/interface, alasan, dampak, dependency, acceptance/test, dan owner yang
   perlu menyetujui; hentikan bagian terdampak.
7. Kerjakan **hanya** task yang dipilih, tanpa fitur tambahan. Jalankan test
   relevan yang diizinkan; jangan mengakses database/provider sungguhan.
8. Periksa ulang status dan diff. Isi `LAPORAN_DEVELOPER_N.md` pada folder tahap
   aktif dengan fakta aktual dan status PASS/FAIL/BLOCKED/NOT RUN. Jangan tandai
   tahap GO; integrator menilai tahapnya, dan penanggung jawab FINISHING terpilih
   hanya berwenang pada gate FINISHING yang ditetapkan.
9. Untuk requirement-driven task, konsultasikan [`PRD_TRACEABILITY_MATRIX.md`](PRD_TRACEABILITY_MATRIX.md)
   dan [`TECHNICAL_GATE_CLOSURE.md`](TECHNICAL_GATE_CLOSURE.md); update status/evidence
   hanya berdasarkan hasil aktual, dan gunakan [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md)
   bila kebutuhan DB perlu dieskalasikan.

10. Periksa authorization state pada `FASE_1C_AUTHORIZATION_REGISTER.md`,
    `FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md` dan Fase 1E ledger. Approval hanya
    valid bila pihak berwenang, keputusan/scope, tanggal dan evidence tercatat;
    catatan rekomendasi AI bukan approval.

11. Tentukan izin **per task/acceptance**, bukan satu status blanket seluruh
    developer atau tahap. Laporkan GO/CONDITIONAL GO/BLOCKED, file allow/deny,
    dependency, approval dan evidence yang mendasarinya. CONDITIONAL GO baru
    mengizinkan mulai setelah kondisi tertulis benar-benar dipenuhi. Jika BLOCKED,
    jangan implementasi scope terdampak; sub-scope independen hanya boleh dikerjakan
    bila task/gate secara eksplisit menyatakannya. Jangan lanjut otomatis.

## Routing task

| Instruksi | Dokumen yang wajib dibaca |
|---|---|
| Developer 1, Tahap 1 | `TAHAP_1/DEVELOPER_1_TASK.md`, `TAHAP_1/FILE_OWNERSHIP.md`, `TAHAP_1/INTEGRATION_CONTRACT.md` |
| Developer 2, Tahap 1 | `TAHAP_1/DEVELOPER_2_TASK.md`, `TAHAP_1/FILE_OWNERSHIP.md`, `TAHAP_1/INTEGRATION_CONTRACT.md` |
| Developer 3, Tahap 1 | `TAHAP_1/DEVELOPER_3_TASK.md`, `TAHAP_1/FILE_OWNERSHIP.md`, `TAHAP_1/INTEGRATION_CONTRACT.md` |
| Developer 1/2/3, Tahap 2 | Task bernomor sama di `TAHAP_2/`, `TAHAP_2/FILE_OWNERSHIP.md`, `TAHAP_2/INTEGRATION_CONTRACT.md`, serta Tahap 1 gate |
| Developer 1/2/3, Tahap 3 | Task bernomor sama di `TAHAP_3/`, `TAHAP_3/FILE_OWNERSHIP.md`, `TAHAP_3/INTEGRATION_CONTRACT.md`, serta Tahap 2 gate |
| FINISHING | `FINISHING_AUTHORITY.md`, seluruh laporan tahap terkait, kontrak/ownership, diff PR dan checklist integrasi yang relevan |

Untuk semua task, ikuti batas database di `FINISHING_AUTHORITY.md`. Tidak ada
Developer 4 otomatis berwenang mengubah database. FINISHING hanya aktif ketika
penanggung jawabnya ditetapkan secara eksplisit dan gate FINISHING dibuka.

## Pemetaan PRD → Developer → Tahap → output → acceptance

Matriks di bawah merangkum seluruh requirement produk aktif §§1–16; traceability
rinci (API/DB/test/evidence per baris) ada di
[`PRD_TRACEABILITY_MATRIX.md`](PRD_TRACEABILITY_MATRIX.md). Setiap baris harus
ditutup dengan bukti aktual pada laporan task dan penerimaan integrator; `BLOCKED`
atau `NOT RUN` bukan pemenuhan requirement. Keputusan OPEN hanya memblokir
acceptance yang bergantung padanya. Kebutuhan lintas-domain berakhir pada integrasi
Tahap 3, FINISHING berotorisasi, dan demonstrasi; tugas yang secara eksplisit
dimiliki D4 ditandai demikian.

| Fitur PRD | Developer | Tahap | Output | Acceptance Criteria | Status |
|---|---|---:|---|---|---|
| Auth/session, role server-authoritative; no Participant account | D1 | 1 | Auth Flutter/backend milik D1; laporan + test evidence | Login valid/invalid, `/me`, logout/session, tidak ada role escalation atau mock fallback; AC-02/10 | BLOCKED sampai baseline/technical gate dan test path disetujui |
| Organizer event CRUD/ownership, validasi, auto-publish/private-invalid, suspend pascapublikasi | D2; D3 konsumen order gate; D4 integrasi | 1–2 | Event/category domain; moderation/report D3 T2; laporan + API/UI/DB evidence | Owner isolation, validasi lifecycle/status, publikasi sesuai PRD, alasan/audit suspend, suspended event tidak dapat dipesan; AC-02/05 | BLOCKED pada G-02/shared contract dan DB disposition terkait |
| Kategori tiket, kuota/periode jual, satu event satu kelas harga gratis/berbayar | D2; D3 validasi order | 1 | CRUD kategori + kontrak yang dikonsumsi checkout; laporan/test | Inactive/out-of-window/sold-out/mixed-price ditolak server; AC-04/06 | BLOCKED pada G-01/G-02 bagian yang membutuhkan shared/DB |
| Form pendaftaran dinamis, validasi jawaban, brosur opsional | D1 konfigurasi; D2 renderer; technical owner untuk shared API/storage; D4 validasi | 3 / FINISHING jika disetujui | UI dan public journey; kontrak/storage yang disetujui; laporan/evidence | Persist round-trip, validasi field/answer, renderer satu peserta, unggah hanya bila storage disahkan; AC-03/04 | BLOCKED G-07; shared interface/storage owner belum ditetapkan |
| Desain/template tiket dan tampilan tiket/QR | D1 presentation; D3 T1 issuance; D2 T3 journey; D4 validasi | 1, 3 | Issued ticket/QR sesuai record; UI dan test | Tiket gratis setelah validasi, berbayar setelah PAID; QR unik; template hanya jika persisted contract tersedia; AC-07 | BLOCKED pada kontrak/API/DB terkait; status bukan bukti QR aman |
| Link pendaftaran publik; guest tanpa akun; no manual/assisted; satu order/item/tiket/attendee dan repeat order | D3 domain; D2 journey; D4 integrasi | 1, 3 | Order API/domain dan UI guest; laporan + test/E2E | Tidak perlu akun, satu item dan quantity 1, harga snapshot, repeat selama terbuka, reject assisted/multi-item; AC-03/04/06 | BLOCKED pada G-01 dan DB compatibility yang relevan |
| Simulasi VA, fee Rp5.000 + 5%, payment status, guest payment authority, expiry/cancel/refund | D3; keputusan produk untuk C-01/C-02/expiry/cancel; D2 status UI | 1, 3 | Order/payment/ticket flow dan status UI; evidence server/test | Paid ticket hanya sesudah PAID; simulasi bukan gateway riil; nominal terjaga; formula/authority/status hanya sesudah keputusan; AC-06/07 | Sebagian OPEN/BLOCKED: C-01, C-02 dan policy terkait; scope independen tetap dinilai terpisah |
| Invitation Staff, membership event-scoped, permission dan accept link | D1 invitation/membership; D2 konsumen permission/scanner; maintainer owner router bila diperlukan; D4 integrasi | 2 | Invitation/membership; handoff interface; laporan + positive/negative test | Invite/revoke/expiry/email mismatch, authenticated accept, permission/event scope; tidak ada akses global; AC-08 | BLOCKED sampai Tahap 1 GO; G-04 router owner belum disahkan |
| Scanner dan check-in online/QR eligibility | D2; D1 membership upstream; D4 integrasi | 2 | Check-in/token service/UI; laporan + API/widget evidence | Authorized event permission, reject invalid/duplicate/ineligible, online only; no token leak; AC-08 | BLOCKED sampai Tahap 1 GO dan kontrak/DB/security evidence |
| Daftar peserta PAID-first, nomor/order stabil, export | D2 owns attendee source; D3 owns UI/export; D4 integrasi | 2 | Endpoint (D2), UI/export (D3), laporan + parity/CSV tests | Akses owner/permission, urutan paid-first dan stabil, export set/sort sama, CSV/privacy safe; AC-09 | BLOCKED G-06; endpoint/response belum memenuhi bukti lengkap |
| Admin monitoring akun/event/transaksi, suspend, audit/reports/notification | D3 eksklusif `eventMetricsController.js` T2; D2 event domain terkait; D4 validasi | 1–2 | Admin screens/report/metrics + API; laporan + authorization/persistence evidence | Admin-only backend, suspend beralasan/audit, monitoring/report sesuai scope approved; AC-02/09 | BLOCKED G-02; C-03 hanya untuk plan/entitlement |
| Plan/subscription, entitlement, email delivery/retry | Pemilik produk/technical owner untuk keputusan; D3 hanya scope T2 yang disetujui; D4 verifikasi | 2 / setelah keputusan | Keputusan tertulis, kontrak dan implementasi hanya setelah owner/gate; evidence | Tidak menciptakan paywall/entitlement atau mengklaim email terkirim tanpa keputusan dan evidence sandbox; AC terkait §13/15 | OPEN C-03/G-09; bukan blanket blocker untuk task lain |
| Responsive Android/Web, loading/error/empty/retry/accessibility states | D1–D3 sesuai file owned; D4 integrasi/build/smoke | 1–3 / FINISHING | UI state tests, builds, device/browser evidence | Narrow/wide journey tanpa mock fallback; test/build dan keterbatasan perangkat dicatat; AC-10 | BLOCKED sampai gate dan bukti per environment tersedia |
| Integrasi seluruh sistem, regression, build/smoke, demonstrasi & penutupan AC-01–10 | D4 integrator untuk Tahap 1–3; penanggung jawab FINISHING yang ditunjuk untuk scope FINISHING; D1–D3 handback domain | 1–FINISHING | Laporan integrasi tiap tahap, test/build/smoke evidence, checklist/runbook demonstrasi pada allow-list | Semua AC PRD terpetakan PASS dengan bukti backend/API/DB/UI yang sesuai; known gap ditutup/diterima pemilik; siap demonstrasi tanpa klaim mock-only | BLOCKED; tidak ada laporan GO/evidence integrasi final atau penunjukan FINISHING |

Tidak ada baris yang berstatus PASS hanya karena source atau task dokumennya ada.
Matriks traceability rinci tetap authoritative untuk evidence/test per requirement.

## Pemilik, keluaran, dan acceptance per tahap

| Tahap | Developer 1 | Developer 2 | Developer 3 | Output/gate integrasi |
|---|---|---|---|---|
| 1 — fondasi | Auth/session: backend + Flutter auth; test sesuai allow-list | Event/category CRUD, ownership, validasi | Order/payment/ticket/QR domain dan client | Tiga laporan developer, diff/PR terpisah, targeted tests, dependency/interface request dan integrator report. Acceptance & gate rinci di task/kontrak; integrator memverifikasi auth → event/category → order/payment. Tahap 1 GO hanya dengan acceptance wajib dan evidence. |
| 2 — operasi MVP | Invitation/membership; router hanya oleh owner yang disahkan | Scanner/check-in online dan attendee source endpoint | Attendee UI/export, Admin/report/metrics (eventMetricsController eksklusif D3) | Tiga laporan, tests, frozen contract/API, handoff membership → permission/scanner → attendee/Admin, laporan integrasi. Mulai hanya setelah Tahap 1 GO; fitur yang bergantung G-04/G-06/G-09 tetap scoped BLOCKED. |
| 3 — demo readiness | Form config/ticket presentation hanya bila kontrak persist tersedia | Public guest purchase journey/responsive UI | Demo runbook/checklist/smoke sesuai task/allow-list | Tiga laporan + test/runbook/harness evidence yang sungguh tersedia; integrator report/build/smoke. Mulai hanya setelah Tahap 2 GO; artifacts yang belum dibuat bukan bukti dan tidak boleh dipakai sebelum task diizinkan. |

Setiap developer mengisi laporan milik sendiri dengan tujuan/tugas, file aktual,
dependency, acceptance per kriteria, perintah test dan hasil, batas/NOT RUN,
blocker/interface request, serta status. Laporan tidak boleh mengklaim fitur,
integrasi, atau tahap selesai tanpa bukti.

## Urutan proyek dan gate

`Tahap 1 → Integrasi Tahap 1 → Tahap 2 → Integrasi Tahap 2 → Tahap 3 →
Integrasi Tahap 3 → FINISHING → Demonstrasi`.

Integrasi tahap 1/2 adalah gate/baseline GO sebelum maju. Integrasi tahap 3
memvalidasi feature PRs; FINISHING setelahnya menyelesaikan item lintas-domain
dan—hanya oleh penanggung jawab yang ditunjuk—database bila diperlukan. Demo
final ditutup setelah acceptance/evidence FINISHING lulus.

- D1–D3 tahap berjalan dari baseline yang sama, pada branch/PR terpisah dan
  allow-list masing-masing. Tidak menggabungkan branch satu sama lain saat
  implementasi. Pemeriksaan path **dan** semantik API/data/import wajib.
- Integrasi tahap dilakukan sesudah ketiga laporan/PR tersedia. Bug domain
  dikembalikan kepada developer pemilik; integrator tidak menggantikan task.
- Tahap berikutnya hanya mulai setelah laporan integrasi menyatakan GO dengan
  baseline/CI/test evidence yang dapat diverifikasi. GO tanpa evidence tidak sah.
- Tahap 1 task dapat dimulai hanya jika entry gate pada
  `FASE_1E_OWNERSHIP_AND_EXECUTION_LEDGER.md` dan approval maintainer mencatat GO
  atau conditional GO yang spesifik. Pada snapshot, tidak ada baseline/technical
  approval tertulis; semua task coding **BLOCKED**. D1 auth independen dari
  C-01–C-03 tetapi bukan otomatis GO. D2 lifecycle dan D3 acceptance yang
  bergantung kontrak/DB/OPEN DECISION tetap BLOCKED.
  Lihat `OPEN DECISION` di PRD; AI tidak boleh mengisi keputusan produk sendiri.
- FINISHING bukan tempat menutupi task tertunda. Setiap item harus memiliki
  laporan, owner, alasan, acceptance, dan bukti; pekerjaan developer yang dapat
  dilakukan tanpa database tetap milik developer.

## FINISHING dan demonstrasi

FINISHING mengintegrasikan pekerjaan lintas-domain, menjalankan regression/build
dan skenario demo, memeriksa keamanan/setup test, serta menyelesaikan hanya item
yang secara eksplisit diterima pada scope FINISHING. **Perubahan database hanya
boleh dilakukan oleh penanggung jawab FINISHING yang sudah ditetapkan, setelah
gate FINISHING dibuka.** Kebutuhan database dari Developer 1–3 adalah laporan
proposal, bukan izin edit. Prosedur lengkap di `FINISHING_AUTHORITY.md`.

Demo hanya dinyatakan siap jika acceptance wajib PRD memiliki bukti; API/DB
terisolasi dan bukan mock-only; skenario role/ownership negatif, event, guest
order/payment/ticket, Staff/check-in, attendee/export/Admin, error states dan
Android/Web diuji sesuai lingkungan; build/test dicatat. Provider eksternal,
device, keamanan atau E2E yang tidak diuji harus tetap ditandai NOT RUN/BLOCKED.

## Riwayat

Dokumen dan laporan T03 lama dipertahankan di `task/archive/` untuk sejarah;
isinya bukan handover atau instruksi aktif. Dokumen ini menggantikan kumpulan
versi pembagian tugas terdahulu sebagai peta workflow aktif.