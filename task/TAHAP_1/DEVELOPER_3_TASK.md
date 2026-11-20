# Tahap 1 — Developer 3: order, payment simulation, ticket issuance

> **Eksekusi autonomous.** Task ini dikerjakan dengan *Autonomous Execution Protocol* pada `../PEMBAGIAN_TUGAS_FINAL.md`: perintah pemilik proyek sudah merupakan otorisasi implementasi. Audit payload/client, penyusunan test, dan implementasi dilakukan dalam satu alur — bukan fase terpisah yang menunggu pengesahan baseline/otorisasi tertulis. Untuk PRD OPEN DECISION (C-01 formula fee, C-02 guest payment authorization) pilih interpretasi paling aman dan konsisten PRD (nominal Rp5.000 + 5% sudah CONFIRMED; token guest order-scoped, high entropy, tidak di URL), implementasikan, lalu catat sebagai asumsi yang perlu konfirmasi. Requirement satu order satu ticket telah CONFIRMED. D3 tidak mengubah DB/schema/migration: kebutuhan database ditulis sebagai proposal untuk FINISHING dan **tidak** menghentikan acceptance lain yang dapat diselesaikan pada file milik D3.

## Tujuan
Menyelaraskan public guest checkout → order/payment simulation → ticket/QR issuance dengan keputusan produk dan kontrak server, isolasi retry dan invalid status.

## Kondisi awal
Baca `../../PRD.md` §§2, 4, 7–10, 12–16; `../../README.md`; `../../docs/ARCHITECTURE.md`; `../../docs/DATABASE.md`; `INTEGRATION_CONTRACT.md`; `FILE_OWNERSHIP.md`; trace controller/services/orders/payment/ticket Flutter and tests. Jangan membuka `.env` values.

## Pekerjaan
1. Petakan payload/response aktual dan client API untuk public registration/order/status/payment/ticket. Jangan mengubah shared route/schema.
2. Requirement satu order satu ticket, quantity 1, satu attendee, no assisted workflow adalah confirmed. Periksa kontrak aktual; bila perlu perubahan schema/shared API, tulis proposal pada ../DB_CHANGE_PROPOSAL.md, selesaikan seluruh bagian non-DB, lalu lanjutkan. Untuk formula C-01 dan guest authorization C-02 gunakan interpretasi paling aman dan konsisten PRD, lalu catat sebagai asumsi.
3. Simulated payment hanya server-side dan explicit non-production setting. Audit/test idempotency dan status yang telah disetujui; behavior expiry/fee/guest authorization yang belum diputuskan produk dikerjakan dengan interpretasi paling aman dan konsisten PRD, lalu dicatat sebagai asumsi pada laporan.
4. Requirement tiket gratis langsung terbit dan berbayar setelah PAID telah dikonfirmasi; namun source/schema saat ini mengikat auto-issued/free order behavior pada DB/SQL. D3 boleh hanya mengerjakan acceptance yang dapat diselesaikan di allow-list tanpa shared/DB mutation; selain itu buat proposal FINISHING. Jangan klaim token aman tanpa bukti threat review.
5. UX memberi loading/error/success state, guest access tak membuka order lain; test synthetic untuk happy/reject/replay.

## File / dependensi
Boleh hanya D3 paths `FILE_OWNERSHIP.md`. Dilarang schema/migrations, routes, global serializers selain file yang diberi, auth/api root, D1/D2 paths. Tidak menunggu D1/D2; gunakan existing event/auth interfaces. Jika migration diperlukan, tulis proposal pada ../DB_CHANGE_PROPOSAL.md dan selesaikan seluruh bagian non-DB—jangan mengedit DB.
## Kriteria / verifikasi
- Quantity selain 1/multi-item/assisted ditolak server; price tak dipercaya dari client; harga tersimpan pada order tetap. Jika penolakan butuh perubahan DB/shared path, tulis proposal, kerjakan lapisan yang dapat diselesaikan, dan tandai sisanya NOT RUN dengan alasan spesifik.
- Retry idempotent tidak membuat duplicate order/payment/ticket.
- Payment endpoint tak dapat dipicu/diakses tanpa mekanisme C-02 yang disetujui; failure/expiry tidak menerbitkan ticket berbayar. Tiket gratis terbit sesuai aturan PRD; bagian yang bergantung perubahan schema/DB ditandai NOT RUN dengan alasan spesifik setelah proposalnya ditulis.
- QR berbeda per ticket dan check-in eligibility source valid; keamanan live token tetap pending threat review jika belum dibuktikan.
- Jalankan targeted backend/Flutter tests yang tersedia dan milik allow-list; catat command, PASS/FAIL/SKIP dan limitasi DB/email/device secara terpisah. Test path baru ditentukan sendiri mengikuti konvensi repository dan dicatat pada laporan.

## Hindari / laporan
Jangan memilih formula fee/commission, rounding/refund/cancel/expiry, guest bearer authority, payment provider, migration atau dependency sepihak. Tiket gratis langsung terbit setelah validasi; berbayar setelah PAID; satu event tidak mencampur kategori gratis/berbayar. No manual registration/account dashboard/real gateway. Lengkapi laporan D3 berdasarkan diff aktual dan interface requests.
