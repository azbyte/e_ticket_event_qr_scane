# Peta Kerja Final — E-Ticket Event & QR Scanner

Dokumen ini adalah **controller proyek** untuk tugas Developer 1–3. PRD aktif
adalah [`../PRD.md`](../PRD.md); task rinci, allow-list ownership, integrasi,
laporan, dan gate tahap berada di folder `TAHAP_1/`, `TAHAP_2/`, dan
`TAHAP_3/`. Dokumen lama di `archive/` bersifat historis, bukan instruksi kerja.

## Cara memulai (perintah singkat pemilik proyek)

Perintah yang didukung, tanpa prompt tambahan:

`Kerjakan Developer 1 Tahap 2` · `Kerjakan Developer 2 Tahap 1` ·
`Lanjutkan tugas Developer 3` · `Selesaikan seluruh tugas Developer 2` ·
`Perbaiki bug yang ditemukan pada tahap sebelumnya`

Bentuk lama `Developer N — Tahap M` / `Saya Developer N, kerjakan Tahap M` tetap
valid dan setara.

**Perintah pemilik proyek adalah otorisasi implementasi.** Setelah perintah
diberikan, AI langsung menjalankan seluruh protokol di dokumen ini sampai selesai
dan menghasilkan laporan akhir. AI **tidak** meminta approval kedua dalam bentuk
apa pun (technical approval, scope approval, baseline sign-off, authorization
registry, test-location approval, persetujuan membuat file), **tidak** menanyakan
hal yang sudah tersedia di repository, dan **tidak** berhenti di tengah untuk
menunggu konfirmasi teknis.

Jika perintah hanya menyebut developer tanpa tahap, tentukan sendiri tahap yang
paling tepat: periksa laporan tahap dan status repository, pilih tahap paling awal
yang belum selesai, lalu lanjutkan dari progres yang ada — jangan mengulang dari
awal. Bila pekerjaan terputus (working tree berisi diff task tersebut), lanjutkan
diff itu. Bila seluruh tahap developer tersebut terbukti selesai, laporkan
faktanya beserta bukti.

## Mode kerja: implementasi vs audit

- **Default = mode implementasi autonomous.** Kata "kerjakan", "lanjutkan",
  "selesaikan", "perbaiki" berarti: ubah kode/dokumen, uji, perbaiki error, dan
  laporkan. Analisis, audit, GAP report, dan authorization report adalah proses
  internal — bukan hasil akhir dan bukan alasan berhenti.
- **Mode read-only hanya bila diminta eksplisit** dengan kata "audit", "analisis
  read-only", "review tanpa perubahan", "investigasi tanpa implementasi", atau
  "periksa status". Aturan read-only dari tugas audit sebelumnya **tidak** dibawa
  ke tugas implementasi berikutnya.
- Laporan audit lama, status BLOCKED lama, dan approval gate lama **tidak**
  menghalangi tugas baru yang telah diperintahkan pemilik proyek. Dokumen gate
  (`FASE_1C`/`FASE_1D`/`FASE_1E`, `TECHNICAL_GATE_CLOSURE`,
  `PRD_TRACEABILITY_MATRIX`) adalah referensi teknis/historis, bukan sumber izin.

## Pengecualian wajib — Developer 1 Tahap 1 (FROZEN)

Developer 1 Tahap 1 sudah/sedang dikerjakan dan **dikecualikan** dari workflow
autonomous ini:

- Jangan mengubah `TAHAP_1/DEVELOPER_1_TASK.md`, `TAHAP_1/LAPORAN_DEVELOPER_1.md`,
  **Amendment A-1** pada `TAHAP_1/FILE_OWNERSHIP.md`, maupun catatan approval
  "GO (limited)" D1 T1 di `FASE_1C_AUTHORIZATION_REGISTER.md` dan
  `FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md`.
- Jangan mengerjakan ulang, mengulang audit, atau "merapikan" D1 T1 ketika
  menjalankan task developer/tahap lain. Perubahan lokal (working tree) milik
  D1 T1 dipertahankan apa adanya; jangan di-revert, di-commit paksa, atau
  diatribusikan ke task lain.
- Gate/batas khusus yang tercatat pada artefak D1 T1 tetap berlaku untuk artefak
  tersebut; protokol baru tidak membatalkannya dan tidak menjadikan D1 T1 sebagai
  contoh workflow baru.
- Pengecualian ini **hanya** untuk Developer 1 Tahap 1. Seluruh developer dan
  tahap lain mengikuti protokol autonomous di bawah.

## Prosedur wajib — Autonomous Execution Protocol

Berlaku untuk seluruh tugas Developer 1–4/FINISHING **kecuali Developer 1 Tahap 1**
(FROZEN). Jalankan berurutan sampai selesai tanpa berhenti meminta persetujuan.

### STEP 1 — CONTEXT DISCOVERY

Tentukan sendiri: developer dan tahap yang diminta; scope pekerjaan; task dan
acceptance criteria; bagian PRD yang relevan; implementasi sebelumnya;
ketergantungan pada developer lain; status repository (`git status --short --branch`
beserta diff) dan perubahan lokal yang harus dipertahankan. Baca `PRD.md` bagian
yang dirujuk task, task developer tersebut, `FILE_OWNERSHIP.md`,
`INTEGRATION_CONTRACT.md`, laporan tahap sebelumnya, serta source/test yang
relevan. Jangan membaca `.env`/secret, dan jangan meminta pemilik proyek mengulang
informasi yang sudah tersedia di repository. Pastikan task memang belum selesai:
bila laporan/diff menunjukkan DONE, jangan diulang — lanjutkan bagian yang belum
selesai atau laporkan bukti penyelesaiannya.

### STEP 2 — ANALYSIS

Petakan fitur yang belum dikerjakan, bug/GAP, konflik implementasi, dependency,
risiko, file yang perlu diubah, dan test yang diperlukan. Analisis adalah proses
internal untuk menentukan tindakan — **jangan berhenti** setelah menghasilkan
analisis, audit report, atau GAP report bila tugasnya adalah implementasi.

### STEP 3 — AUTONOMOUS DECISION

Ambil seluruh keputusan teknis yang dibutuhkan untuk memulai dan menyelesaikan
pekerjaan, lalu catat keputusan penting sebagai asumsi. Tidak ada keputusan teknis
yang dimintakan persetujuan; lihat "Aturan keputusan mandiri" di bawah.

### STEP 4 — IMPLEMENTATION

Implementasikan seluruh scope task: perubahan kode **dan** dokumentasi yang
diperlukan. Jangan hanya membuat rencana, daftar file yang harus diubah,
authorization report, atau GAP report; jangan menunggu konfirmasi atas keputusan
teknis; jangan membiarkan fitur yang seharusnya dapat diselesaikan tetap belum
dikerjakan. Kerjakan task yang dipilih tanpa fitur tambahan di luar scope.

### STEP 5 — TESTING

Uji secara mandiri. Jalankan test relevan beserta pemeriksaan sesuai teknologi
proyek: dari `apps/` → `flutter analyze`, `flutter test`; dari `backend/` →
`npm test`, `npm run check`, `npm run format:check`. Bila test belum tersedia, buat
test mengikuti konvensi repository dan tentukan sendiri lokasinya (pola aktif:
`backend/test/<domain>_*.test.js` dan `apps/test/features/<domain>/**_test.dart`).
Bila test gagal: analisis penyebabnya, perbaiki, jalankan ulang. Jangan mengubah
atau menghapus test valid hanya agar hasil terlihat PASS, dan jangan mengarang
hasil. Jangan mengakses database produksi atau provider berbayar; gunakan fixture
sintetis.

### STEP 6 — SELF-REPAIR

Ulangi siklus analisis error → akar masalah → perbaikan → pemeriksaan sampai
selesai atau sampai benar-benar ada hambatan eksternal yang tidak dapat diatasi.
Jangan menyerahkan error kepada pemilik proyek selama masih dapat diperbaiki sendiri.

### STEP 7 — FINAL AUDIT

Pastikan implementasi memenuhi task dan PRD, tidak melewati scope, tidak merusak
fitur atau pekerjaan developer lain, test relevan telah dijalankan, dokumentasi
wajib diperbarui, status task akurat, dan tidak ada pekerjaan yang diam-diam
tertinggal. Periksa ulang `git status`/diff dan pertahankan perubahan lokal yang
bukan bagian task (termasuk seluruh diff Developer 1 Tahap 1).

### STEP 8 — COMPLETION REPORT

Isi `LAPORAN_DEVELOPER_N.md` pada folder tahap aktif dengan: tugas yang
diselesaikan, file yang diubah, implementasi utama, test yang dijalankan beserta
hasilnya, keputusan teknis/asumsi penting, status PASS/FAIL/BLOCKED/NOT RUN per
kriteria, dan sisa pekerjaan bila benar-benar ada. Laporan adalah **hasil akhir**
pengerjaan, bukan alasan berhenti. Untuk requirement-driven task, perbarui
[`PRD_TRACEABILITY_MATRIX.md`](PRD_TRACEABILITY_MATRIX.md) dan
[`TECHNICAL_GATE_CLOSURE.md`](TECHNICAL_GATE_CLOSURE.md) berdasarkan hasil aktual,
serta gunakan [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md) untuk kebutuhan
database.


## Aturan keputusan mandiri

Jika menemukan detail yang belum ditentukan, AI **wajib memutuskan sendiri** dengan
urutan: (1) periksa PRD dan dokumentasi proyek; (2) periksa implementasi yang sudah
ada; (3) periksa struktur folder dan pola coding; (4) periksa task developer dan
batas scope; (5) periksa test yang tersedia; (6) bandingkan beberapa solusi bila
perlu; (7) pilih solusi paling aman, konsisten, sederhana, dan sesuai arsitektur;
(8) catat asumsi/keputusan teknis penting; (9) langsung lanjutkan pekerjaan.

Berikut adalah **keputusan teknis AI** dan tidak boleh dimintakan persetujuan:
lokasi dan nama file test; pendekatan implementasi; metode debugging; cara
memperbaiki error; urutan implementasi; struktur file yang sesuai struktur proyek;
metode validasi; rekonstruksi technical contract dari kode/dokumentasi yang
tersedia; penyesuaian kode agar fitur bekerja; solusi atas GAP teknis; refactoring
terbatas yang diperlukan untuk menyelesaikan tugas.

Bila ada beberapa solusi yang masuk akal, pilih yang terbaik berdasarkan konteks
proyek. **Jangan menampilkan daftar opsi lalu menunggu pemilik proyek memilih.**

Detail yang belum lengkap ditangani sebagai berikut, bukan sebagai alasan berhenti:

- **Lokasi test belum ditentukan** → tentukan sendiri mengikuti konvensi repository
  (`backend/test/<domain>_*.test.js`, `apps/test/features/<domain>/**_test.dart`),
  buat folder/file bila belum ada.
- **Technical contract belum terdokumentasi** → rekonstruksi dari route, controller,
  validator, serializer, schema, PRD, dan implementasi terkait; catat sebagai
  kontrak kerja pada laporan.
- **Dependency atau pekerjaan developer lain belum selesai** → pakai implementasi
  yang sudah tersedia, buat adapter/mock sesuai kontrak, atau kerjakan bagian lain
  lebih dahulu.
- **OPEN DECISION PRD (C-01/C-02/C-03) atau catatan teknis G-01…G-10** → pilih
  interpretasi paling aman dan konsisten PRD (utamakan nominal/aturan yang sudah
  CONFIRMED), implementasikan bagian yang tidak bertentangan, dan catat sebagai
  asumsi yang perlu konfirmasi. Jangan mengarang kebijakan produk baru yang
  bertentangan dengan PRD.
- **Dokumentasi tidak lengkap** → bukan alasan otomatis untuk BLOCKED.

## Aturan BLOCKED

BLOCKED hanya boleh dipakai untuk hambatan nyata yang **tidak dapat diatasi AI
secara mandiri**: credential/secret eksternal yang memang tidak tersedia; layanan
eksternal wajib yang tidak dapat diakses; environment/hardware yang benar-benar
diperlukan tidak tersedia (mis. device Android fisik, database uji terisolasi);
konflik yang membutuhkan perubahan kebijakan bisnis dan tidak dapat ditentukan dari
PRD; tugas bertentangan dengan instruksi eksplisit pemilik proyek; operasi eksternal
destruktif/tidak dapat dipulihkan di luar otorisasi; perubahan database yang
merupakan wewenang FINISHING.

Ketika menemui blocker:

- Jangan menghentikan seluruh pekerjaan — selesaikan bagian yang tidak terblokir.
- Cari workaround yang tidak melanggar requirement.
- Jangan mengarang hasil test; jangan menyatakan PASS bila validasi tidak dapat
  dilakukan (gunakan NOT RUN untuk pemeriksaan yang tidak bisa dijalankan).
- Dokumentasikan blocker secara spesifik: apa hambatannya, mengapa tidak dapat
  diatasi sendiri, apa yang sudah dikerjakan, dan apa yang dibutuhkan.

**Dilarang BLOCKED hanya karena**: belum ada approval teknis, lokasi test belum
ditentukan, file belum dibuat, pendekatan belum dipilih, dokumentasi belum lengkap,
atau AI belum melakukan analisis.

## Batas yang tetap terkunci (bukan approval gate)

Autonomous bukan berarti mengubah proyek sesuka hati. Tetap dilarang: mengubah
schema/migration/SQL/seed/config database (wewenang FINISHING — laporkan sebagai
proposal di [`DB_CHANGE_PROPOSAL.md`](DB_CHANGE_PROPOSAL.md)); membaca atau menaruh
secret/`.env`; mutasi database produksi atau provisioning akun sungguhan;
menghubungi provider berbayar; operasi Git destruktif (reset, force push,
menghapus branch/data remote); menghapus file penting, laporan, pembagian tugas,
task, atau dokumentasi historis; mengubah flow bisnis/role di luar scope; menutupi
kegagalan atau mengarang persetujuan dan hasil test; merusak pekerjaan developer
lain. Perubahan lintas developer yang benar-benar diperlukan: analisis dependency,
lakukan perubahan minimum, dokumentasikan dampak, dan lanjutkan.

## Routing task

| Instruksi | Dokumen yang wajib dibaca |
|---|---|
| Kerjakan Developer 1 Tahap 1 | **FROZEN — jangan dikerjakan ulang/diubah.** Lihat "Pengecualian wajib"; artefak: `TAHAP_1/DEVELOPER_1_TASK.md`, `TAHAP_1/LAPORAN_DEVELOPER_1.md`, Amendment A-1 di `TAHAP_1/FILE_OWNERSHIP.md` |
| Kerjakan Developer 2 Tahap 1 | `TAHAP_1/DEVELOPER_2_TASK.md`, `TAHAP_1/FILE_OWNERSHIP.md`, `TAHAP_1/INTEGRATION_CONTRACT.md` |
| Kerjakan Developer 3 Tahap 1 | `TAHAP_1/DEVELOPER_3_TASK.md`, `TAHAP_1/FILE_OWNERSHIP.md`, `TAHAP_1/INTEGRATION_CONTRACT.md` |
| Kerjakan Developer 1/2/3 Tahap 2 | Task bernomor sama di `TAHAP_2/`, `TAHAP_2/FILE_OWNERSHIP.md`, `TAHAP_2/INTEGRATION_CONTRACT.md`, laporan Tahap 1 developer terkait |
| Kerjakan Developer 1/2/3 Tahap 3 | Task bernomor sama di `TAHAP_3/`, `TAHAP_3/FILE_OWNERSHIP.md`, `TAHAP_3/INTEGRATION_CONTRACT.md`, laporan Tahap 2 developer terkait |
| Lanjutkan tugas Developer N | `LAPORAN_DEVELOPER_N.md` di `TAHAP_1..TAHAP_3` + `git status`/diff → tentukan tahap paling awal yang belum selesai, lanjutkan dari progres yang ada |
| Selesaikan seluruh tugas Developer N | Seluruh task N pada `TAHAP_1 → TAHAP_2 → TAHAP_3` secara berurutan; lewati yang terbukti DONE |
| Perbaiki bug tahap sebelumnya | Laporan tahap terkait + file domain pemiliknya; gunakan skill `debug` lalu perbaiki langsung |
| FINISHING | `FINISHING_AUTHORITY.md`, seluruh laporan tahap terkait, kontrak/ownership, diff PR dan checklist integrasi yang relevan |

Semua baris di atas (kecuali Developer 1 Tahap 1) dieksekusi dengan protokol
autonomous: perintah pemilik proyek sudah merupakan otorisasi, jadi tidak ada
tahap "menunggu izin" sebelum coding.

Untuk semua task, ikuti batas database di `FINISHING_AUTHORITY.md`. Tidak ada
Developer 4 otomatis berwenang mengubah database. FINISHING hanya aktif ketika
penanggung jawabnya ditetapkan secara eksplisit dan gate FINISHING dibuka. Batas ini tidak menghentikan task developer: seluruh pekerjaan non-DB tetap diselesaikan dan diuji.

## Pemetaan PRD → Developer → Tahap → output → acceptance

Matriks di bawah merangkum seluruh requirement produk aktif §§1–16; traceability
rinci (API/DB/test/evidence per baris) ada di
[`PRD_TRACEABILITY_MATRIX.md`](PRD_TRACEABILITY_MATRIX.md). Setiap baris harus
ditutup dengan bukti aktual pada laporan task; `BLOCKED`
atau `NOT RUN` bukan pemenuhan requirement. Keputusan OPEN tidak menghentikan
pekerjaan: acceptance terkait dikerjakan dengan interpretasi paling aman dan
dicatat sebagai asumsi. Kebutuhan lintas-domain berakhir pada integrasi
Tahap 3, FINISHING berotorisasi, dan demonstrasi; tugas yang secara eksplisit
dimiliki D4 ditandai demikian.

| Fitur PRD | Developer | Tahap | Output | Acceptance Criteria | Status |
|---|---|---:|---|---|---|
| Auth/session, role server-authoritative; no Participant account | D1 | 1 | Auth Flutter/backend milik D1; laporan + test evidence | Login valid/invalid, `/me`, logout/session, tidak ada role escalation atau mock fallback; AC-02/10 | BLOCKED sampai baseline/technical gate dan test path disetujui |
| Organizer event CRUD/ownership, validasi, auto-publish/private-invalid, suspend pascapublikasi | D2; D3 konsumen order gate; D4 integrasi | 1–2 | Event/category domain; moderation/report D3 T2; laporan + API/UI/DB evidence | Owner isolation, validasi lifecycle/status, publikasi sesuai PRD, alasan/audit suspend, suspended event tidak dapat dipesan; AC-02/05 | SIAP (autonomous); G-02/DB ditangani dengan interpretasi aman + proposal DB |
| Kategori tiket, kuota/periode jual, satu event satu kelas harga gratis/berbayar | D2; D3 validasi order | 1 | CRUD kategori + kontrak yang dikonsumsi checkout; laporan/test | Inactive/out-of-window/sold-out/mixed-price ditolak server; AC-04/06 | SIAP (autonomous); bagian DB dicatat sebagai proposal FINISHING |
| Form pendaftaran dinamis, validasi jawaban, brosur opsional | D1 konfigurasi; D2 renderer; technical owner untuk shared API/storage; D4 validasi | 3 / FINISHING jika disetujui | UI dan public journey; kontrak/storage yang disetujui; laporan/evidence | Persist round-trip, validasi field/answer, renderer satu peserta, unggah hanya bila storage disahkan; AC-03/04 | SIAP (autonomous); kontrak storage direkonstruksi mandiri |
| Desain/template tiket dan tampilan tiket/QR | D1 presentation; D3 T1 issuance; D2 T3 journey; D4 validasi | 1, 3 | Issued ticket/QR sesuai record; UI dan test | Tiket gratis setelah validasi, berbayar setelah PAID; QR unik; template hanya jika persisted contract tersedia; AC-07 | SIAP (autonomous); klaim keamanan QR dibatasi bukti uji |
| Link pendaftaran publik; guest tanpa akun; no manual/assisted; satu order/item/tiket/attendee dan repeat order | D3 domain; D2 journey; D4 integrasi | 1, 3 | Order API/domain dan UI guest; laporan + test/E2E | Tidak perlu akun, satu item dan quantity 1, harga snapshot, repeat selama terbuka, reject assisted/multi-item; AC-03/04/06 | SIAP (autonomous); kebutuhan DB dicatat sebagai proposal |
| Simulasi VA, fee Rp5.000 + 5%, payment status, guest payment authority, expiry/cancel/refund | D3; keputusan produk untuk C-01/C-02/expiry/cancel; D2 status UI | 1, 3 | Order/payment/ticket flow dan status UI; evidence server/test | Paid ticket hanya sesudah PAID; simulasi bukan gateway riil; nominal terjaga; formula/authority/status hanya sesudah keputusan; AC-06/07 | SIAP (autonomous); C-01/C-02 dikerjakan dengan interpretasi aman dan dicatat sebagai asumsi |
| Invitation Staff, membership event-scoped, permission dan accept link | D1 invitation/membership; D2 konsumen permission/scanner; maintainer owner router bila diperlukan; D4 integrasi | 2 | Invitation/membership; handoff interface; laporan + positive/negative test | Invite/revoke/expiry/email mismatch, authenticated accept, permission/event scope; tidak ada akses global; AC-08 | SIAP (autonomous); perubahan router minimum bila diperlukan |
| Scanner dan check-in online/QR eligibility | D2; D1 membership upstream; D4 integrasi | 2 | Check-in/token service/UI; laporan + API/widget evidence | Authorized event permission, reject invalid/duplicate/ineligible, online only; no token leak; AC-08 | SIAP (autonomous); kontrak/security direkonstruksi mandiri |
| Daftar peserta PAID-first, nomor/order stabil, export | D2 owns attendee source; D3 owns UI/export; D4 integrasi | 2 | Endpoint (D2), UI/export (D3), laporan + parity/CSV tests | Akses owner/permission, urutan paid-first dan stabil, export set/sort sama, CSV/privacy safe; AC-09 | SIAP (autonomous); endpoint/adapter diselesaikan pada scope sendiri |
| Admin monitoring akun/event/transaksi, suspend, audit/reports/notification | D3 eksklusif `eventMetricsController.js` T2; D2 event domain terkait; D4 validasi | 1–2 | Admin screens/report/metrics + API; laporan + authorization/persistence evidence | Admin-only backend, suspend beralasan/audit, monitoring/report sesuai scope approved; AC-02/09 | SIAP (autonomous); C-03 dicatat sebagai asumsi |
| Plan/subscription, entitlement, email delivery/retry | Pemilik produk/technical owner untuk keputusan; D3 hanya scope T2 yang disetujui; D4 verifikasi | 2 / setelah keputusan | Interpretasi aman dan kontrak hasil rekonstruksi, implementasi, evidence sandbox | Tidak menciptakan paywall/entitlement atau mengklaim email terkirim tanpa keputusan dan evidence sandbox; AC terkait §13/15 | SIAP (autonomous); C-03/G-09 dicatat sebagai asumsi, email tanpa sandbox = NOT RUN |
| Responsive Android/Web, loading/error/empty/retry/accessibility states | D1–D3 sesuai file owned; D4 integrasi/build/smoke | 1–3 / FINISHING | UI state tests, builds, device/browser evidence | Narrow/wide journey tanpa mock fallback; test/build dan keterbatasan perangkat dicatat; AC-10 | SIAP (autonomous); bukti device/browser yang tidak tersedia = NOT RUN |
| Integrasi seluruh sistem, regression, build/smoke, demonstrasi & penutupan AC-01–10 | D4 integrator untuk Tahap 1–3; penanggung jawab FINISHING yang ditunjuk untuk scope FINISHING; D1–D3 handback domain | 1–FINISHING | Laporan integrasi tiap tahap, test/build/smoke evidence, checklist/runbook demonstrasi pada allow-list | Semua AC PRD terpetakan PASS dengan bukti backend/API/DB/UI yang sesuai; known gap ditutup/diterima pemilik; siap demonstrasi tanpa klaim mock-only | SIAP (autonomous); dijalankan dari kondisi repository aktual |

Tidak ada baris yang berstatus PASS hanya karena source atau task dokumennya ada.
Matriks traceability rinci tetap authoritative untuk evidence/test per requirement.

## Pemilik, keluaran, dan acceptance per tahap

| Tahap | Developer 1 | Developer 2 | Developer 3 | Output/gate integrasi |
|---|---|---|---|---|
| 1 — fondasi | Auth/session: backend + Flutter auth; test sesuai allow-list | Event/category CRUD, ownership, validasi | Order/payment/ticket/QR domain dan client | Tiga laporan developer, diff/PR terpisah, targeted tests, dependency/interface request dan integrator report. Acceptance & gate rinci di task/kontrak; integrator memverifikasi auth → event/category → order/payment. Tahap 1 dinyatakan selesai oleh integrator berdasarkan acceptance wajib dan evidence; ini bukan syarat izin memulai Tahap 2. |
| 2 — operasi MVP | Invitation/membership; perubahan router/global navigation dilakukan minimum bila benar-benar diperlukan dan didokumentasikan | Scanner/check-in online dan attendee source endpoint | Attendee UI/export, Admin/report/metrics (eventMetricsController eksklusif D3) | Tiga laporan, tests, frozen contract/API, handoff membership → permission/scanner → attendee/Admin, laporan integrasi. Dapat dimulai atas perintah pemilik proyek tanpa menunggu Tahap 1 GO; fitur yang bergantung G-04/G-06/G-09 dikerjakan dengan interpretasi aman dan perubahan minimum yang didokumentasikan. |
| 3 — demo readiness | Form config/ticket presentation; kontrak persist direkonstruksi mandiri dari kode/API aktual | Public guest purchase journey/responsive UI | Demo runbook/checklist/smoke sesuai task/allow-list | Tiga laporan + test/runbook/harness evidence yang sungguh tersedia; integrator report/build/smoke. Dapat dimulai atas perintah pemilik proyek tanpa menunggu Tahap 2 GO; artifacts yang belum dibuat bukan bukti, jadi buat artifacts tersebut sebagai bagian task. |

Setiap developer mengisi laporan milik sendiri dengan tujuan/tugas, file aktual,
dependency, acceptance per kriteria, perintah test dan hasil, batas/NOT RUN,
blocker/interface request, serta status. Laporan tidak boleh mengklaim fitur,
integrasi, atau tahap selesai tanpa bukti.

## Urutan proyek (referensi teknis, bukan gate izin)

`Tahap 1 → Integrasi Tahap 1 → Tahap 2 → Integrasi Tahap 2 → Tahap 3 →
Integrasi Tahap 3 → FINISHING → Demonstrasi`.

Urutan ini adalah panduan kerja dan urutan integrasi yang wajar, **bukan** syarat
izin. Perintah pemilik proyek untuk suatu tahap sudah cukup untuk memulai tahap
tersebut; AI tidak menunggu laporan integrasi GO, baseline yang diverifikasi
maintainer, atau approval tertulis. Integrasi tahap memvalidasi hasil kerja;
FINISHING setelahnya menyelesaikan item lintas-domain dan — hanya oleh penanggung
jawab yang ditunjuk — database bila diperlukan.

- D1–D3 pada suatu tahap bekerja dari kondisi repository yang sama, pada branch/PR
  terpisah, dengan allow-list ownership sebagai urutan preferensi. Tidak
  menggabungkan branch satu sama lain saat implementasi. Pemeriksaan path **dan**
  semantik API/data/import tetap wajib.
- Integrasi tahap idealnya dilakukan sesudah ketiga laporan/PR tersedia. Bila
  belum, integrator mengaudit kondisi yang ada dan mencatat sisanya NOT RUN. Bug
  domain dikembalikan kepada developer pemilik; integrator tidak menggantikan task.
- Bila laporan integrasi tahap sebelumnya belum GO, tahap berikutnya tetap boleh
  dikerjakan: periksa kode aktual, kerjakan scope yang dapat diselesaikan, dan
  catat asumsi serta dampaknya. Kekurangan evidence bukan alasan berhenti.
- OPEN DECISION di PRD tidak diisi sembarangan sebagai kebijakan produk baru, tetapi
  juga tidak menghentikan pekerjaan: pilih interpretasi paling aman dan konsisten
  PRD, implementasikan, lalu catat sebagai asumsi yang perlu konfirmasi pada
  laporan developer.
- FINISHING bukan tempat menutupi task tertunda. Setiap item harus memiliki
  laporan, owner, alasan, acceptance, dan bukti; pekerjaan developer yang dapat
  dilakukan tanpa database tetap milik developer tahapnya.

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

**Amendment workflow (2026-11-20) — autonomous execution.** Controller ini diubah
menjadi *Autonomous Execution Protocol*. Perintah tugas pemilik proyek diakui
sebagai otorisasi implementasi, sehingga approval gate teknis (baseline sign-off,
technical contract approval, test-location approval, authorization registry,
"menunggu maintainer") dihapus untuk seluruh task **kecuali Developer 1 Tahap 1**
yang berstatus FROZEN beserta seluruh artefaknya. Dokumen gate Fase 1C/1D/1E,
`TECHNICAL_GATE_CLOSURE.md`, `PRD_TRACEABILITY_MATRIX.md`, dan
`DB_CHANGE_PROPOSAL.md` dipertahankan sebagai referensi non-blocking. Batas yang
tidak berubah: wewenang database FINISHING, larangan secret, larangan operasi Git
destruktif, larangan merusak pekerjaan developer lain, dan kewajiban melaporkan
hasil test secara jujur.