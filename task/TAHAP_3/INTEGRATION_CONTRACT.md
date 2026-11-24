# TAHAP 3 — KONTRAK INTEGRASI

- **Versi:** 2.0 (2026-11-25)
- **Menggantikan:** versi 20-11-2026 pada nama file yang sama dan menjadi acuan di atas `TAHAP_2/INTEGRATION_CONTRACT.md` untuk pekerjaan Tahap 3.
- **Berlaku untuk:** Developer 2 dan Developer 3 (FASE 1), Developer 1 (FASE 2).
- **Sifat:** kontrak **sudah ditetapkan sebelum implementasi**. Developer 2/3 tidak menunggu keputusan Developer 1.

---

## Bagian 1 — Prinsip dan konvensi

### 1.1 Prinsip

1. Kontrak yang sudah dipakai **tidak boleh dipecah**. Perubahan hanya boleh **menambah field** atau **menambah endpoint**.
2. Setiap endpoint baru wajib dipakai minimal satu layar pada akhir Tahap 3.
3. Backend adalah sumber kebenaran untuk harga, status pembayaran, status tiket, permission, dan urutan peserta.
4. Frontend tidak boleh menghitung ulang harga, komisi, payout, atau status yang sudah ditentukan server.
5. Mock hanya boleh aktif pada `MOCK_MODE=true`. Pada `MOCK_MODE=false`, kegagalan API harus menjadi state error — **bukan** fallback ke data mock.
6. Setiap perubahan kontrak dicatat pada dokumen ini dan pada laporan PR yang sama.

### 1.2 Konvensi HTTP

| Aspek | Konvensi |
|---|---|
| Base path | `/api` |
| Auth | `Authorization: Bearer <JWT>` |
| Guest order access | Header `X-Order-Access-Token: <token>` |
| Content type | `application/json` kecuali CSV (`text/csv; charset=utf-8`) |
| Sukses | `{ "success": true, ... }` dengan field domain di root atau `data` |
| Error | `{ "success": false, "message": "<pesan>" }` + HTTP status |
| 400 | Input tidak valid |
| 401 | Tidak terautentikasi / token tidak valid |
| 403 | Terautentikasi tetapi tidak berhak |
| 404 | Resource tidak ada atau tidak boleh diketahui |
| 409 | Konflik status (mis. check-in ganda) |
| 422 | Validasi domain gagal (mis. publish event tidak valid) |
| 429 | Rate limit |
| Pagination | `page` (1-based), `limit`; response `{ page, limit, total, items/data }` |
| Tanggal | ISO-8601 UTC string |
| Uang | integer rupiah pada payload baru; field lama `numeric` tetap diterima sebagai number |
| Bahasa pesan | Indonesia untuk pesan yang tampil ke pengguna; kode status tetap bahasa teknis |

### 1.3 Aturan kompatibilitas

- Field lama **tidak dihapus** dan **tidak diganti tipe**.
- Field baru bersifat opsional bagi konsumen lama.
- Enum baru harus ditangani UI sebagai status yang tidak dikenal (tampilkan pesan aman), bukan crash.

---

## Bagian 2 — Peta endpoint

### 2.1 Endpoint beku (dipakai lintas developer)

| Endpoint | Owner backend | Konsumen | Aturan |
|---|---|---|---|
| `GET /api/events/public` | D1 | Guest | Hanya event `APPROVED`/`PUBLISHED` + `is_public=true` |
| `GET /api/events/:id` | D1 | Guest, Organizer, Staff, Admin | Field `public_url`, `validation_errors`, `attendee_fields` aditif |
| `GET /api/events/:eventId/ticket-types` | D1 | Guest, Organizer | `remaining_quota`, `is_available` tetap |
| `POST /api/orders` | D1 | Guest | Body `{ event_id, items, attendees, guest_name, guest_email, guest_phone, idempotency_key }`; response `{ order, order_access_token }`; quantity wajib 1 |
| `GET /api/orders/:id` | D1 | Guest | Butuh JWT atau `X-Order-Access-Token`; tidak membuka order lain |
| `POST /api/payments/simulate` | D1 | Guest | Body `{ order_id, simulate_success }`; hanya non-production |
| `GET /api/tickets/my-tickets` | D2 | Guest, Staff | `token` hanya untuk pemilik/admin |
| `GET /api/tickets/:id` | D2 | Guest, Staff | `token` hanya untuk pemilik/admin; `order_id` opsional untuk guest |
| `POST /api/tickets/validate` | D2 | Staff | Body `{ token, event_id }`; hasil enum tetap |
| `POST /api/tickets/verify` | D2 | Staff | Harus membuat `check_ins`; tidak boleh hanya mengubah status |
| `POST /api/check-ins` | D2 | Staff | Idempotent; 409 untuk duplikat |
| `GET /api/check-ins/events/:eventId/check-ins` | D2 | Staff, Organizer | Bentuk response tetap |
| `POST /api/events/:eventId/invitations` | D2 | Organizer | `invite_url` aditif |
| `GET /api/invitations/:token` | D2 | Publik | Data minimal, tanpa PII lengkap |
| `POST /api/invitations/:token/accept` | D2 | Staff | Email akun harus cocok |
| `GET /api/me/memberships` | D2 | Staff | `{ memberships: [...] }` |
| `GET /api/events/:eventId/attendees` | D2 | Organizer, Staff | Field aditif `order_number`, `payment_status`, `order_status`, `custom_fields`, `checked_in_at` |
| `GET /api/events/:id/attendees/export` | D2 | Organizer | CSV; urutan identik daftar peserta |
| `GET /api/events/:id/orders` | D2 | Organizer | Order + payment + peserta per event |
| `GET /api/admin/accounts`, `PUT /api/admin/accounts/:id/status` | D3 | Admin | Suspend wajib `reason` |
| `GET /api/admin/audit-logs` | D3 | Admin | Filter + pagination |
| `GET /api/admin/settings`, `PUT /api/admin/settings/:key` | D3 | Admin | Fee/komisi read-only selama C-01 |
| `GET /api/admin/overview` | D3 | Admin | Agregasi server |
| `GET /api/admin/subscriptions` | D3 | Admin | Daftar langganan |
| `GET /api/revenue/me` | D3 | Organizer | Revenue organizer |
| `GET /api/revenue/admin/summary`, `/admin/transactions` | D3 | Admin | Revenue platform |
| `GET /api/plans`, `/api/plans/:id`, `/api/plans/admin/all` | D3 | Organizer, Admin | Katalog |
| `POST/PUT/DELETE /api/plans/admin*` | D3 | Admin | CRUD paket + audit |
| `GET /api/subscriptions/me`, `/payments` | D3 | Organizer | Langganan Organizer |
| `GET/POST /api/support-reports`, `/:id`, status/priority/reply/internal-note` | D3 | Organizer, Admin | Laporan dukungan |
| `GET /api/notifications`, `/:id/read`, `/read-all` | D3 | Organizer, Admin | Notifikasi in-app |
| `GET /api/organizer/overview`, `/events/summaries` | D3 | Organizer | Metrik dashboard |
| `POST /api/events/:id/publish` | D1 | Organizer | `200` valid / `422` tidak valid |

### 2.2 Endpoint yang tidak boleh diubah pada Tahap 3

- `POST /api/auth/*` (kecuali bug keamanan yang terbukti).
- Bentuk `POST /api/orders` dan `order_access_token`.
- Nama/format status pembayaran.
- Skema permission yang sudah ada.

### 2.3 Endpoint yang tidak boleh ditambah tanpa persetujuan

- Endpoint baru yang memerlukan perubahan schema/migration.
- Endpoint baru yang mengubah model bisnis (mis. paywall paket, refund, pembatalan order).
- Endpoint `DELETE` untuk data historis.

---

## Bagian 3 — DTO bersama

### 3.1 Event

```json
{
  "id": "uuid",
  "title": "string",
  "description": "string|null",
  "status": "DRAFT|PUBLISHED|SUSPENDED|CANCELLED|APPROVED|PENDING_REVIEW|REJECTED|REVISION_REQUESTED",
  "is_public": true,
  "public_url": "https://app.example/e/uuid|null",
  "registration_qr_url": "string|null",
  "start_at": "ISO-8601",
  "end_at": "ISO-8601",
  "location": "string|null",
  "is_online": false,
  "online_url": "string|null",
  "poster_url": "string|null",
  "category": "string|null",
  "attendee_fields": [
    { "key": "name", "label": "Nama", "type": "text", "required": true, "options": [] }
  ],
  "validation_errors": ["alasan 1", "alasan 2"],
  "ticket_types": []
}
```

Aturan:
- `public_url` hanya terisi untuk event tayang (`PUBLISHED`/`APPROVED`), selain itu `null`.
- `validation_errors` berasal dari validasi server, bukan teks statis UI.
- `attendee_fields` mendukung format lama `["name","email"]` dan format baru objek; UI wajib menormalkan keduanya.

### 3.2 Ticket type

```json
{
  "id": "uuid",
  "event_id": "uuid",
  "name": "VIP",
  "description": "string|null",
  "price": 150000,
  "quota": 100,
  "sold": 12,
  "held": 3,
  "remaining_quota": 85,
  "is_active": true,
  "is_available": true,
  "sales_start_at": "ISO-8601",
  "sales_end_at": "ISO-8601"
}
```

### 3.3 Order

```json
{
  "id": "uuid",
  "order_number": "ORD-20261125-0001",
  "event_id": "uuid",
  "status": "PENDING_PAYMENT|PAID|EXPIRED|FAILED|CANCELLED",
  "subtotal": 150000,
  "service_fee": 5000,
  "grand_total": 155000,
  "items": [
    { "ticket_type_id": "uuid", "ticket_type_name": "VIP", "quantity": 1, "unit_price": 150000 }
  ],
  "attendees": [
    { "id": "uuid", "name": "string", "email": "string", "phone": "string|null", "custom_fields": {} }
  ],
  "created_at": "ISO-8601",
  "expires_at": "ISO-8601|null"
}
```

Aturan:
- `order_number` stabil sejak order dibuat dan tidak berubah karena status pembayaran.
- `quantity` selalu 1.
- `service_fee` dan `grand_total` adalah nilai server; UI tidak menghitung ulang.

### 3.4 Payment

```json
{
  "id": "uuid",
  "order_id": "uuid",
  "status": "PENDING|PAID|FAILED|EXPIRED|CANCELLED",
  "amount": 155000,
  "method": "VIRTUAL_ACCOUNT",
  "virtual_account_bank": "BCA",
  "virtual_account_number": "88081234567890",
  "paid_at": "ISO-8601|null",
  "expires_at": "ISO-8601|null"
}
```

### 3.5 Ticket

```json
{
  "id": "uuid",
  "ticket_code": "TKT-...",
  "order_id": "uuid",
  "event_id": "uuid",
  "attendee_id": "uuid",
  "ticket_type_id": "uuid",
  "status": "active|used|cancelled|revoked|pending",
  "token": "<opaque-hanya-untuk-pemilik>",
  "checked_in_at": "ISO-8601|null",
  "event": { "id": "uuid", "title": "string", "start_at": "ISO-8601", "location": "string|null" },
  "attendee": { "name": "string", "email": "string" }
}
```

Aturan:
- `token` tidak boleh masuk log, URL, analytics, atau pesan error.
- Payload QR hanya token; tidak berisi email/telepon/harga.
- `token_hash` tidak pernah dikirim ke klien.

### 3.6 Attendee (daftar peserta)

```json
{
  "id": "uuid",
  "ticket_id": "uuid",
  "ticket_code": "TKT-...",
  "order_id": "uuid",
  "order_number": "ORD-20261125-0001",
  "registration_number": "ORD-20261125-0001",
  "name": "string",
  "email": "string",
  "phone": "string|null",
  "ticket_type": "VIP",
  "payment_status": "PAID|PENDING|EXPIRED|FAILED|CANCELLED",
  "order_status": "PAID|PENDING_PAYMENT|EXPIRED|FAILED|CANCELLED",
  "ticket_status": "active|used|cancelled|revoked|pending",
  "checked_in_at": "ISO-8601|null",
  "custom_fields": {},
  "purchased_at": "ISO-8601"
}
```

Aturan urutan (wajib sama untuk layar dan export):
1. `payment_status = PAID` lebih dahulu.
2. Dalam kelompok yang sama, `order_number` menaik.
3. Nomor registrasi tidak berubah karena status pembayaran.

### 3.7 Hasil scan / check-in

`POST /api/tickets/validate` dan `POST /api/tickets/verify` mengembalikan status berikut:

| Status | Arti | HTTP | Efek DB |
|---|---|---|---|
| `VALID` | Tiket sah, event cocok, sudah dibayar, permission cukup | 200 | Tidak ada check-in pada validate; check-in pada verify/check-ins |
| `ALREADY_USED` | Tiket sudah check-in | 409 | Tidak ada baris baru |
| `WRONG_EVENT` | Tiket milik event lain | 200/400 | Tidak ada check-in |
| `PAYMENT_REQUIRED` | Order belum `PAID` | 200/402 | Tidak ada check-in |
| `CANCELLED` | Tiket/order dibatalkan | 200 | Tidak ada check-in |
| `REVOKED` | Tiket dicabut | 200 | Tidak ada check-in |
| `INVALID` | Token tidak dikenal/format salah | 404/400 | Tidak ada check-in |

Payload minimal:

```json
{
  "success": true,
  "valid": false,
  "status": "ALREADY_USED",
  "message": "Tiket sudah digunakan.",
  "ticket": {
    "ticket_code": "TKT-...",
    "attendee_name": "Nama",
    "ticket_type": "VIP",
    "checked_in_at": "ISO-8601"
  }
}
```

Aturan:
- UI wajib menampilkan `status` dan `message` dari server; tidak mengarang hasil.
- `ticket` pada hasil scan tidak boleh memuat `token`, `token_hash`, email lengkap, atau harga.
- Request ganda harus dicegah di UI (lock) dan tetap aman di server (transaksi + unique).

### 3.8 Membership

```json
{
  "memberships": [
    {
      "event_id": "uuid",
      "event_title": "string",
      "event_status": "PUBLISHED",
      "status": "ACTIVE|PENDING|REVOKED|EXPIRED",
      "role": "staff",
      "permissions": ["VIEW_EVENT", "SCAN_TICKET"],
      "expires_at": "ISO-8601|null"
    }
  ]
}
```

Permission yang dikenal: `VIEW_EVENT`, `VIEW_PARTICIPANTS`, `EXPORT_PARTICIPANTS`, `VIEW_ORDERS`, `SCAN_TICKET`, `CHECK_IN_TICKET`, `ASSIST_REGISTRATION` (legacy, tidak ditawarkan pada MVP).

### 3.9 Invitation

Pratinjau `GET /api/invitations/:token`:

```json
{
  "invitation": {
    "event_id": "uuid",
    "event_title": "string",
    "event_start_at": "ISO-8601",
    "organizer_name": "string",
    "email_masked": "n***@example.com",
    "permissions": ["SCAN_TICKET"],
    "expires_at": "ISO-8601",
    "status": "PENDING|ACCEPTED|REVOKED|EXPIRED"
  }
}
```

Accept `POST /api/invitations/:token/accept`:

```json
{
  "success": true,
  "membership": {
    "event_id": "uuid",
    "status": "ACTIVE",
    "permissions": ["SCAN_TICKET"]
  }
}
```

Aturan:
- Email akun login harus sama dengan email undangan; jika tidak → `403`.
- Token expired/revoked/reused → `410`/`403`.
- Response pembuatan undangan menyertakan `invite_url` absolut; `invite_url` berbeda dari `public_url`.

### 3.10 DTO Admin

**Account**

```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "role": "admin|organizer|staff",
  "status": "ACTIVE|SUSPENDED|DISABLED",
  "event_count": 3,
  "order_count": 120,
  "created_at": "ISO-8601"
}
```

**Audit log**

```json
{
  "id": "uuid",
  "actor_id": "uuid",
  "actor_name": "string",
  "actor_role": "admin",
  "action": "SUSPEND_ACCOUNT",
  "entity_type": "user",
  "entity_id": "uuid",
  "reason": "string|null",
  "details": {},
  "created_at": "ISO-8601"
}
```

**Platform setting**

```json
{
  "key": "service_fee",
  "value": "5000",
  "type": "number|string|boolean",
  "description": "string",
  "updated_at": "ISO-8601",
  "editable": false
}
```

Aturan: `service_fee` dan `commission_rate` **read-only** selama C-01 terbuka. `PUT` pada key tersebut harus ditolak `403`/`409` dengan pesan yang menjelaskan keputusan produk belum final.

**Admin overview**

```json
{
  "events": { "total": 10, "published": 6, "draft": 3, "suspended": 1 },
  "organizers": { "active": 4, "total": 5 },
  "orders": { "total": 120, "paid": 90, "pending": 20, "expired": 10 },
  "tickets": { "sold": 90, "checked_in": 40 },
  "attendees": { "total": 90 },
  "financials": { "gross_sales": 13500000, "platform_commission": 675000, "service_fee": 450000 },
  "period": { "from": "ISO-8601", "to": "ISO-8601" }
}
```

**Plan**

```json
{
  "id": "uuid",
  "name": "Professional",
  "description": "string",
  "price_monthly": 299000,
  "price_yearly": 2990000,
  "status": "active|inactive",
  "features": ["string"],
  "limits": { "max_events": 10, "max_tickets_per_event": 2000 }
}
```

**Subscription (Admin)**

```json
{
  "id": "uuid",
  "organizer_id": "uuid",
  "organizer_name": "string",
  "plan_id": "uuid",
  "plan_name": "string",
  "status": "active|suspended|expired|cancelled",
  "start_at": "ISO-8601",
  "end_at": "ISO-8601",
  "auto_renew": true
}
```

**Revenue**

```json
{
  "summary": {
    "gross_sales": 13500000,
    "platform_commission": 675000,
    "service_fee": 450000,
    "net_organizer": 12780000
  },
  "transactions": [
    {
      "id": "uuid",
      "order_id": "uuid",
      "order_number": "ORD-...",
      "event_title": "string",
      "organizer_name": "string",
      "gross_amount": 150000,
      "commission_amount": 7500,
      "net_organizer_amount": 142500,
      "status": "PAID",
      "paid_at": "ISO-8601"
    }
  ]
}
```

**Report**

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "category": "string",
  "subject": "string",
  "description": "string",
  "status": "OPEN|IN_PROGRESS|RESOLVED|CLOSED",
  "priority": "LOW|MEDIUM|HIGH",
  "status_token": "string",
  "replies": [],
  "internal_notes": [],
  "created_at": "ISO-8601"
}
```

**Notification**

```json
{
  "id": "uuid",
  "title": "string",
  "message": "string",
  "type": "EVENT|ORDER|PAYMENT|SYSTEM",
  "is_read": false,
  "created_at": "ISO-8601"
}
```

---

## Bagian 4 — Matriks permission (domain D2)

| Operasi | Organizer (owner) | Staff dengan permission | Admin | Guest |
|---|---|---|---|---|
| Lihat event miliknya | ya | `VIEW_EVENT` | ya | hanya event publik |
| Lihat daftar peserta | ya | `VIEW_PARTICIPANTS` | ya | tidak |
| Export peserta | ya | `EXPORT_PARTICIPANTS` | ya | tidak |
| Lihat order/payment event | ya | `VIEW_ORDERS` | ya | tidak |
| Validasi tiket | ya | `SCAN_TICKET` atau `CHECK_IN_TICKET` | ya | tidak |
| Check-in | ya | `SCAN_TICKET` atau `CHECK_IN_TICKET` | ya | tidak |
| Lihat riwayat check-in | ya | permission scan/check-in | ya | tidak |
| Undang/cabut staff | ya | tidak | tidak (kecuali owner) | tidak |
| Terima undangan | tidak | ya (email cocok) | tidak | tidak |
| Lihat tiket sendiri | ya (owner order) | ya (membership event) | ya | ya (order token) |

Aturan tambahan:
- `403` untuk terautentikasi tanpa hak; `404` bila resource tidak boleh diketahui.
- Staff tidak boleh melihat event lain meskipun mengetahui ID.
- `ASSIST_REGISTRATION` tidak boleh ditawarkan pada UI MVP dan tidak boleh menjadi syarat operasi baru.

---

## Bagian 5 — Matriks permission (domain D3)

| Operasi | Admin | Organizer | Staff |
|---|---|---|---|
| `/api/admin/*` | ya | tidak (403) | tidak (403) |
| Akun: list/suspend/aktifkan | ya | tidak | tidak |
| Audit log | ya | tidak | tidak |
| Settings platform | ya (kecuali fee/komisi read-only) | tidak | tidak |
| Overview platform | ya | tidak | tidak |
| Revenue platform/transaksi | ya | tidak | tidak |
| Paket layanan CRUD | ya | hanya katalog | tidak |
| Langganan semua organizer | ya | hanya miliknya | tidak |
| Revenue organizer | tidak | ya | tidak |
| Laporan dukungan | semua | miliknya | tidak |
| Notifikasi | miliknya | miliknya | miliknya |
| Moderasi event (suspend/restore) | ya | tidak | tidak |

Catatan C-03: aksi perpanjangan/aktivasi langganan oleh Admin hanya boleh dilakukan bila endpoint dan aturan produk tersedia. Bila belum, UI **read-only** dengan penjelasan, bukan aksi lokal palsu.

---

## Bagian 6 — Kontrak route Flutter

Route berikut adalah kontrak yang harus ada di `app_router.dart` setelah T3-D1-02. D2/D3 boleh membangun layar dan navigasi internal, tetapi **tidak mengedit router**.

| Path | Layar | Guard | Parameter |
|---|---|---|---|
| `/` | `AuthGate` | publik | — |
| `/login`, `/register` | Auth | publik | `redirect` opsional |
| `/e/:eventId` | `PublicEventScreen` | publik | `eventId` |
| `/e/:eventId/register` | `PublicRegistrationScreen` | publik | `eventId` |
| `/e/:eventId/payment/:orderId` | `PaymentScreen` | publik + order token | `eventId`, `orderId` |
| `/e/:eventId/ticket/:ticketId` | `TicketDetailScreen` | publik + order token | `eventId`, `ticketId`, `orderId` |
| `/registration/:eventId` | `RegistrationScreen` | publik | `eventId` |
| `/invite/:token` | `InvitationEntryScreen` / `AcceptInvitationScreen` | login + redirect | `token` |
| `/staff` | `StaffDashboardScreen` | login + membership | — |
| `/staff/:eventId` | `StaffDashboardScreen` | login + membership event | `eventId` |
| `/staff/scanner?eventId=` | `ScannerScreen` | login + `SCAN_TICKET` | `eventId` |
| `/staff/check-ins?eventId=` | `CheckInHistoryScreen` | login + permission | `eventId` |
| `/organizer` | `OrganizerDashboardScreen` | organizer | — |
| `/organizer/events` | `EventManagementScreen` | organizer | — |
| `/organizer/events/create` | `EventFormScreen` | organizer | — |
| `/organizer/events/:id` | `OrganizerEventDetailScreen` | organizer owner | `id` |
| `/organizer/events/:id/edit` | `EventFormScreen` | organizer owner | `id` |
| `/organizer/events/:id/attendees` | `AttendeeListScreen` | organizer/owner + permission | `id` |
| `/organizer/events/:id/orders` | `OrganizerOrderListScreen` | organizer/owner | `id` |
| `/organizer/events/:id/staff` | `StaffManagementScreen` | organizer owner | `id` |
| `/organizer/events/:id/scanner` | `OrganizerScannerScreen` | organizer owner | `id` |
| `/organizer/team` | `TeamManagementScreen` | organizer | `eventId` wajib dari konteks |
| `/organizer/plans`, `/organizer/plans/transactions` | `SubscriptionScreen` | organizer | — |
| `/organizer/support`, `/organizer/support/new` | `OrganizerSupportScreen` | organizer | — |
| `/admin` | `AdminTabController` | admin | — |
| `/admin/accounts` | `AccountManagementScreen` | admin | — |
| `/admin/events` | `EventModerationScreen` | admin | — |
| `/admin/reports` | `ReportManagementScreen` | admin | — |
| `/admin/packages` | `PackageManagementScreen` | admin | — |
| `/admin/subscriptions` | `SubscriptionManagementScreen` | admin | — |
| `/admin/transactions` | `TransactionRevenueScreen` | admin | — |
| `/admin/settings` | `AdminSettingsScreen` | admin | — |
| `/admin/audit-log` | `AuditLogScreen` | admin | — |
| `/admin/profile` | `AdminProfileScreen` | admin | — |

Aturan route:
- Route publik tidak boleh memaksa login.
- Route admin/organizer menolak role lain dengan `AccessDeniedScreen`.
- Tidak boleh ada fallback `evt-1001` pada router. Bila parameter tidak ada, tampilkan error state.
- `staff` diarahkan berdasarkan membership, bukan role global.

---

## Bagian 7 — Mock, error, dan state

### 7.1 Mock policy

| Kondisi | Perilaku wajib |
|---|---|
| `MOCK_MODE=true` | Mock boleh dipakai untuk demo; data harus ditandai demo pada UI |
| `MOCK_MODE=false` + API sukses | Data API |
| `MOCK_MODE=false` + API gagal | Tampilkan error + tombol retry; **tidak** menampilkan data mock/cache palsu |
| `MOCK_MODE=false` + data kosong | Empty state yang jelas |

Dilarang:
- `catch (_) { return mockData; }`
- `fallbackRevenue` yang menutupi API gagal.
- Angka konstanta bisnis (fee 2.500, komisi, payout) pada UI.
- `evt-1001`, `org-001`, nama staff, atau judul event hardcoded pada alur produksi.

### 7.2 State wajib per layar

Setiap layar in-scope wajib memiliki:
1. Loading.
2. Empty.
3. Error dengan pesan yang dapat ditindaklanjuti + retry.
4. Unauthorized/forbidden.
5. Success.
6. Layout sempit (360) dan lebar (1280+) tanpa overflow.

### 7.3 Pesan error

- Bahasa Indonesia.
- Tidak memuat stack trace, token, SQL, atau nama internal.
- Memberi langkah berikutnya ("Coba lagi", "Periksa koneksi", "Hubungi penyelenggara").

---

## Bagian 8 — Invariant data

1. Satu order = satu event, satu kategori, satu attendee, satu order item quantity 1, paling banyak satu tiket.
2. Harga order dikunci saat dibuat; perubahan harga kategori tidak mengubah order lama.
3. `order_number` stabil; tidak berubah karena status pembayaran.
4. Tiket berbayar hanya terbit setelah `PAID`; tiket gratis terbit setelah validasi backend.
5. `ticket_hash`/`token_hash` tersedia untuk semua tiket (gratis dan berbayar).
6. `check_ins` unik per tiket; scan ganda tidak membuat baris baru.
7. `scan_logs` mencatat setiap percobaan scan yang diproses server.
8. `audit_logs` bertambah untuk setiap aksi admin (suspend akun, suspend event, ubah setting, CRUD paket).
9. `platform_setting_history` bertambah untuk setiap perubahan setting yang diizinkan.
10. Event `SUSPENDED` tidak muncul publik dan menolak order baru.
11. Daftar peserta dan export memakai set, filter, dan urutan yang sama.
12. `attendees.custom_fields` menyimpan jawaban form dinamis sesuai `events.attendee_fields`.

---

## Bagian 9 — Prosedur perubahan kontrak

1. Perubahan hanya boleh aditif.
2. Catat di dokumen ini: endpoint/field, alasan, konsumen, tanggal.
3. Perbarui test kontrak pada PR yang sama.
4. Laporkan di laporan developer dan PR description.
5. Perubahan yang memecah kontrak harus disetujui pemilik proyek **sebelum** merge.

---

## Bagian 10 — Checklist PR

Setiap PR Tahap 3 wajib mencantumkan:

- [ ] Task ID dan fase.
- [ ] Baseline commit.
- [ ] Daftar file diubah (cocok allow-list).
- [ ] Endpoint baru/diubah + pembaruan kontrak.
- [ ] Perintah test yang dijalankan + hasil.
- [ ] Status platform: API / DB / Web / Android / email (`PASS`/`FAIL`/`BLOCKED`/`NOT RUN`).
- [ ] Konfirmasi tidak menyentuh schema/migration/seed.
- [ ] Konfirmasi tidak mengedit file developer lain.
- [ ] Dampak ke developer lain / permintaan integrasi.



