# Tahap 1 — Developer 2: event dan kategori tiket

> **Eksekusi autonomous.** Task ini dikerjakan dengan *Autonomous Execution Protocol* pada `../PEMBAGIAN_TUGAS_FINAL.md`: perintah pemilik proyek sudah merupakan otorisasi implementasi. Jangan menunggu pengesahan baseline, technical gate (G-02), disposition DB, atau approval tertulis — tentukan sendiri keputusan teknisnya, implementasikan, uji, perbaiki, lalu laporkan. Status lifecycle auto-publish vs legacy moderation diputuskan dari PRD §§4–5 dan perilaku kode aktual, lalu dicatat sebagai asumsi. D2 tidak mengubah API global, database/migration, atau router shared secara sepihak; bila perubahan semacam itu benar-benar diperlukan untuk menyelesaikan task, lakukan perubahan **minimum**, jaga kompatibilitas kontrak, dan dokumentasikan file/alasan/dampak pada laporan. Kebutuhan schema/DB ditulis sebagai proposal di `../DB_CHANGE_PROPOSAL.md` dan tidak menghentikan bagian non-DB.

## Tujuan
Memastikan organizer event/ticket-category CRUD mematuhi validasi/ownership dan menyiapkan event domain sebagai kontrak stabil untuk checkout tahap berikutnya. Status lifecycle auto-publish vs legacy moderation diputuskan sendiri dari PRD dan perilaku kode aktual, lalu dicatat sebagai asumsi pada laporan.

## Kondisi awal
Baca `../../PRD.md` §§2–5, 10, 12–16; `../../README.md`, `../../docs/ARCHITECTURE.md`, `../../docs/DATABASE.md`, `INTEGRATION_CONTRACT.md`, `FILE_OWNERSHIP.md`; telusuri event/category controllers, routes (read-only), serializers, screen/provider, tests. Kerjakan perubahan lifecycle langsung: rekonstruksi kontrak implementasi dari kode dan PRD, putuskan sendiri penanganan G-02, lalu catat keputusan teknis tersebut pada laporan.

## Pekerjaan
1. Trace Organizer create/update/delete/list/detail + public event response dan category CRUD, termasuk server validation/owner checks.
2. Perbaiki hanya event-domain controller/serializer/screen ownership paths untuk validasi dan keadaan loading/error/empty konsisten.
3. Terapkan lifecycle PRD hanya jika kontrak status/API telah dibekukan dan dapat dipenuhi dalam allow-list. Jika perlu shared route/state/DB perubahan, serahkan interface/DB proposal dan tandai acceptance lifecycle BLOCKED; jangan membuat status/migration/API baru.
4. Category inactive, out-of-window, zero/invalid quota dan sold-out tidak boleh menerima checkout baru; pastikan kategori dalam event sama-sama free atau paid sesuai PRD. Jangan mengubah order controller milik D3.
5. Tambahkan regression tests domain event/category dan documented fixtures synthetic.

## File / dependensi
Boleh hanya D2 paths dalam `FILE_OWNERSHIP.md`; dilarang shared routes/provider/global API/schema, D1/D3 paths. Tidak menunggu D1/D3: gunakan auth/API existing dan contract yang disetujui. Bila perlu mengubah shared event model/route, lakukan perubahan minimum yang diperlukan, jaga kompatibilitas kontrak, dan dokumentasikan file/alasan/dampak pada laporan.

## Kriteria / verifikasi
- CRUD owner valid berhasil; cross-owner update/delete ditolak oleh backend tests.
- Public list hanya memuat status sesuai kontrak; invalid event tidak muncul.
- Ticket category validation dilakukan server; inactive/sold-out/out-of-window ditolak.
- Screen mengomunikasikan loading/empty/error tanpa dummy fallback dalam API mode.
- Tests target lulus; response serializer tidak mematahkan Flutter contract. Catat batas test DB.

## Hindari / laporan
Jangan implementasi approval Admin pre-publish; jangan edit event routes, schema, app_router, payment/checkout, package/dependencies. Isi laporan D2 dengan file diff dan kriteria pass/fail; kebutuhan interface lintas owner diselesaikan dengan perubahan minimum dan didokumentasikan pada laporan.
