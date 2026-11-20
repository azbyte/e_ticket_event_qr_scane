# Tahap 1 — Developer 2: event dan kategori tiket

> Trace/validasi independen boleh dilakukan setelah baseline task disahkan. Implementasi lifecycle auto-publish/suspend **BLOCKED** sampai G-02/shared route-state contract dan disposition kebutuhan DB disetujui tertulis. D2 tidak mengubah API global, database/migration, atau router shared.

## Tujuan
Memastikan organizer event/ticket-category CRUD mematuhi validasi/ownership dan menyiapkan event domain sebagai kontrak stabil untuk checkout tahap berikutnya. Keputusan status lifecycle auto-publish vs legacy moderation harus disahkan sebelum perubahan behavior.

## Kondisi awal
Baca `../../PRD.md` §§2–5, 10, 12–16; `../../README.md`, `../../docs/ARCHITECTURE.md`, `../../docs/DATABASE.md`, `INTEGRATION_CONTRACT.md`, `FILE_OWNERSHIP.md`; telusuri event/category controllers, routes (read-only), serializers, screen/provider, tests. Mulai perubahan lifecycle hanya setelah G-02 dan kontrak implementasi disetujui.

## Pekerjaan
1. Trace Organizer create/update/delete/list/detail + public event response dan category CRUD, termasuk server validation/owner checks.
2. Perbaiki hanya event-domain controller/serializer/screen ownership paths untuk validasi dan keadaan loading/error/empty konsisten.
3. Terapkan lifecycle PRD hanya jika kontrak status/API telah dibekukan dan dapat dipenuhi dalam allow-list. Jika perlu shared route/state/DB perubahan, serahkan interface/DB proposal dan tandai acceptance lifecycle BLOCKED; jangan membuat status/migration/API baru.
4. Category inactive, out-of-window, zero/invalid quota dan sold-out tidak boleh menerima checkout baru; pastikan kategori dalam event sama-sama free atau paid sesuai PRD. Jangan mengubah order controller milik D3.
5. Tambahkan regression tests domain event/category dan documented fixtures synthetic.

## File / dependensi
Boleh hanya D2 paths dalam `FILE_OWNERSHIP.md`; dilarang shared routes/provider/global API/schema, D1/D3 paths. Tidak menunggu D1/D3: gunakan auth/API existing dan contract yang disetujui. Bila perlu mengubah shared event model/route, blokir dan ajukan file/interface ke maintainer.

## Kriteria / verifikasi
- CRUD owner valid berhasil; cross-owner update/delete ditolak oleh backend tests.
- Public list hanya memuat status sesuai kontrak; invalid event tidak muncul.
- Ticket category validation dilakukan server; inactive/sold-out/out-of-window ditolak.
- Screen mengomunikasikan loading/empty/error tanpa dummy fallback dalam API mode.
- Tests target lulus; response serializer tidak mematahkan Flutter contract. Catat batas test DB.

## Hindari / laporan
Jangan implementasi approval Admin pre-publish; jangan edit event routes, schema, app_router, payment/checkout, package/dependencies. Isi laporan D2 dengan file diff dan kriteria pass/fail; interface request dilaporkan bukan diedit.
