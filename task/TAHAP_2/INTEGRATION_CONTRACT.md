# TAHAP 2 — KONTRAK INTEGRASI & KEPEMILIKAN FILE

- **Versi:** 3.0 (2026-11-23), menggantikan versi pra-audit.
- **Acuan:** [`RENCANA_KERJA.md`](RENCANA_KERJA.md), [`../PEMBAGIAN_TUGAS_FINAL.md`](../PEMBAGIAN_TUGAS_FINAL.md).
- **Tujuan:** mencegah konflik Git dan memastikan setiap developer tahu batas file & bentuk data yang harus dipertahankan.

---

## Bagian 1 — Kontrak integrasi

### 1.1 Prinsip

1. Kontrak yang sudah ada **tidak boleh dipecah**; perubahan hanya boleh **menambah** field.
2. Perubahan yang memecah kontrak wajib dicatat di dokumen ini pada PR yang sama dan dilaporkan ke pemilik proyek **sebelum** merge.
3. Semua endpoint baru harus terdaftar di §1.3 dan dipakai oleh minimal satu layar Flutter pada akhir Tahap 2 (G2-10).

### 1.2 Kontrak yang dibekukan (dipakai lintas developer)

| Endpoint | Pemakai | Aturan |
|---|---|---|
| `GET /api/events/public` | Guest (D1) | Bentuk response tetap; hanya event `APPROVED`/`PUBLISHED` + `is_public` |
| `GET /api/events/:id` | Guest & Organizer & Staff | Field baru boleh ditambah (`public_url`, `validation_errors`) |
| `GET /api/events/:id/ticket-types` | Guest & Organizer | Field `remaining_quota`, `is_available` tetap |
| `POST /api/orders` | Guest (D1) | Body `{ event_id, items, attendees, guest_name, guest_email, guest_phone, idempotency_key }`; response `{ order, order_access_token }`; qty wajib 1 |
| `GET /api/orders/:id` | Guest (token) | Header `X-Order-Access-Token` tetap |
| `POST /api/payments/simulate` | Guest | Body/response tetap |
| `GET /api/tickets/my-tickets`, `GET /api/tickets/:id` | Guest & Staff | `token` hanya untuk pemilik/admin |
| `POST /api/tickets/validate` | Staff (D2) | Body `{ token, event_id }`; hasil enum tetap |
| `POST /api/check-ins` | Staff (D2) | Idempotent; 409 untuk duplikat |
| `GET /api/check-ins/events/:eventId/check-ins` | Staff (D2) | Bentuk response tetap |
| `POST /api/events/:eventId/invitations` | Organizer (D2) | Tambah `invite_url` (aditif) |
| `POST /api/invitations/:token/accept` | Staff (D2) | Aturan email cocok tetap |
| `GET /api/events/:eventId/attendees` | Organizer/Staff (D3) | Tambah `order_number`, `payment_status`, `order_status`, `custom_fields`, `checked_in_at` |
| `GET /api/admin/accounts`, `PUT /api/admin/accounts/:id/status` | Admin (D3) | Suspend wajib `reason` (aditif pada body) |
| `GET /api/revenue/admin/summary`, `/admin/transactions`, `/me` | Admin & Organizer (D3) | Bentuk response tetap |
| `GET /api/plans`, `/api/plans/admin/*` | Admin & Organizer (D3) | Bentuk response tetap |
| `GET /api/support-reports`, `/:id`, status/priority/reply | Admin (D3) & Organizer (D3) | Bentuk response tetap |
| `GET /api/notifications`, `/:id/read`, `/read-all` | Organizer (D3) | Bentuk response tetap |

### 1.3 Endpoint baru Tahap 2 (wajib didokumentasikan saat dibuat)

| Endpoint | Owner | Tujuan | Digunakan oleh |
|---|---|---|---|
| `POST /api/events/:id/publish` | D1 | Validasi + publish otomatis | Form/daftar event Organizer |
| `GET /api/invitations/:token` | D2 | Pratinjau undangan (public, minimal) | Halaman `/invite/:token` |
| `GET /api/me/memberships` | D2 | Event yang diikuti user (staff) | Workspace staff |
| `GET /api/events/:id/orders` | D3 | Order & pembayaran per event | Layar order Organizer |
| `GET /api/events/:id/attendees/export` | D3 | CSV peserta (paid-first, nomor registrasi) | Tombol export |
| `GET /api/admin/audit-logs` | D3 | Audit log platform | Layar audit |
| `GET /api/admin/settings`, `PUT /api/admin/settings/:key` | D3 | Settings platform + history | Layar settings |
| `GET /api/admin/subscriptions` | D3 | Daftar langganan | Layar langganan Admin |
| `GET /api/admin/overview` | D3 | Statistik dashboard Admin | Dashboard Admin |

### 1.4 Kontrak data lintas developer

| Data | Bentuk | Konsumen |
|---|---|---|
| `attendee_fields` (event) | JSON array objek `{ key, label, type, required, options }` (kompatibel array string) | D1 (form publik), D3 (detail peserta) |
| `attendees.custom_fields` | JSON objek `{ key: value }` | D1 (tulis), D3 (baca) |
| `public_url` | string absolut dari `APP_PUBLIC_URL` untuk event `PUBLISHED`, `null` lainnya | D1 (tampil & salin), D3 (monitoring) |
| `invite_url` | string absolut `/invite/{rawToken}` saat pembuatan undangan | D2 (UI team), D1 (panel tautan) |
| `order_number` | string stabil dari `event_orders.order_number` | D3 (daftar & export), D1 (tampilan tiket) |
| `payment_status` | `PENDING/PAID/EXPIRED/FAILED/CANCELLED` | D3 (daftar), D1 (status pembayaran) |
| Ticket `token` | string HMAC (bearer QR) | D2 (QR), D1 (tiket guest) |
| Membership | `{ event_id, event_title, status, permissions[], expires_at }` | D2 (workspace), D1 (routing) |

### 1.5 Aturan tambahan

- Semua endpoint baru wajib memakai `authMiddleware` + `allowRoles` sesuai role, kecuali endpoint publik yang didokumentasikan (`GET /api/invitations/:token`).
- Semua endpoint event mengembalikan `404` untuk event tak ada dan `403` untuk bukan pemilik/tanpa permission.
- Semua perubahan status administratif wajib menulis `audit_logs` (util D3).

---

## Bagian 2 — Kepemilikan file (allow-list)

> Hanya file di bawah ini yang boleh diubah oleh masing-masing developer pada Tahap 2. File lain = permintaan tertulis ke owner.

### Developer 1

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/routes/app_routes.dart
apps/lib/features/public_event/**
apps/lib/features/registration/screens/registration_screen.dart
apps/lib/features/events/screens/event_detail_screen.dart
apps/lib/features/payments/**
apps/lib/features/tickets/screens/ticket_list_screen.dart      (koordinasi D2)
apps/lib/services/public_event/**
apps/lib/services/order/**
apps/lib/services/payment/**
apps/lib/services/event/**
apps/lib/services/organizer_events/api_organizer_event_repository.dart
apps/lib/services/organizer_events/organizer_event_contract.dart
apps/lib/features/organizer/screens/event_form_screen.dart
apps/lib/features/organizer/screens/event_management_screen.dart
apps/lib/features/organizer/events/screens/organizer_event_detail_screen.dart
apps/lib/models/event/**
apps/test/**                                                     (hanya test milik D1)
backend/src/controllers/eventController.js
backend/src/routes/eventRoutes.js
backend/src/utils/eventValidation.js                            (baru)
backend/src/utils/eventResponse.js
backend/src/controllers/orderController.js
backend/src/controllers/paymentController.js
backend/src/services/emailService.js                            (teks/link saja)
backend/src/utils/validators.js
backend/test/event_auto_publish.test.js                         (baru)
backend/test/event_public_links.test.js                         (baru)
backend/test/attendee_dynamic_fields.test.js                    (baru)
```

### Developer 2

```
apps/pubspec.yaml
apps/lib/features/tickets/widgets/qr_ticket_display.dart
apps/lib/features/tickets/screens/ticket_detail_screen.dart
apps/lib/features/tickets/screens/ticket_list_screen.dart
apps/lib/features/scanner/**
apps/lib/features/check_in/**
apps/lib/features/staff/**
apps/lib/features/organizer/membership/team_management_screen.dart
apps/lib/features/organizer/screens/staff_management_screen.dart
apps/lib/features/organizer/operations/organizer_scanner_screen.dart
apps/lib/services/ticket/**
apps/lib/services/scanner/**
apps/lib/services/check_in/**
apps/lib/services/organizer_membership/**
apps/lib/providers/check_in_provider.dart
apps/lib/models/ticket/**
apps/test/**                                                     (hanya test milik D2)
backend/src/controllers/checkInController.js
backend/src/controllers/ticketController.js
backend/src/controllers/eventInvitationController.js
backend/src/routes/checkInRoutes.js
backend/src/routes/ticketRoutes.js
backend/src/routes/invitationsRoutes.js
backend/src/services/ticketTokenService.js
backend/test/event_invitation*.test.js
backend/test/check_in*.test.js
backend/README.md                                                (endpoint tiket/check-in/invitation/membership)
```

### Developer 3

```
apps/lib/features/admin/**
apps/lib/features/organizer/screens/attendee_list_screen.dart
apps/lib/features/organizer/operations/**                        (kecuali organizer_scanner_screen.dart)
apps/lib/features/organizer/shell/organizer_shell.dart
apps/lib/features/organizer/support/**
apps/lib/features/organizer/plans/**
apps/lib/services/admin/**
apps/lib/services/organizer_operations/**
apps/lib/services/organizer_plans/**
apps/lib/services/organizer_support/**
apps/lib/services/organizer_notifications/**
apps/lib/services/report/**
apps/lib/models/admin/**
apps/lib/models/report/**
apps/test/**                                                     (hanya test milik D3)
backend/src/app.js
backend/src/controllers/adminController.js
backend/src/controllers/auditLogController.js                    (baru)
backend/src/controllers/platformSettingsController.js            (baru)
backend/src/controllers/adminOverviewController.js               (baru)
backend/src/controllers/planController.js
backend/src/controllers/subscriptionController.js
backend/src/controllers/revenueController.js
backend/src/controllers/reportController.js
backend/src/controllers/notificationController.js
backend/src/controllers/eventMetricsController.js
backend/src/routes/adminRoutes.js
backend/src/routes/planRoutes.js
backend/src/routes/subscriptionRoutes.js
backend/src/routes/revenueRoutes.js
backend/src/routes/reportRoutes.js
backend/src/routes/notificationRoutes.js
backend/src/routes/organizerRoutes.js
backend/src/utils/auditLog.js                                    (baru)
backend/test/admin_*.test.js                                     (baru)
backend/test/event_attendees_order.test.js                       (baru)
backend/test/event_export.test.js                                (baru)
```

### File yang TIDAK boleh disentuh siapa pun (Tahap 2)

```
backend/prisma/**
backend/supabase/**
PRD.md
task/TAHAP_1/**
task/archive/**
.github/**
.githooks/**
```

### File test eksisting — owner ditetapkan (bukan milik bersama)

Test di bawah **sudah ada** pada baseline dan menyentuh file milik developer lain. File ini **tidak** termasuk allow-list `apps/test/**` milik siapapun; perubahannya harus melalui owner.

| File test | Owner | Alasan |
|---|---|---|
| `apps/test/app_router_test.dart` | **D1** | Menguji `app_router.dart` (milik D1) |
| `apps/test/widget_test.dart` | **D1** | Menguji shell aplikasi/auth |
| `apps/test/stage1_integration_test.dart` | **D1** | Integrasi alur order/auth |
| `apps/test/features/auth/**` | **D1** | Auth |
| `apps/test/features/orders/**` | **D1** | Order/payment |
| `apps/test/features/registration/**` | **D1** | Registrasi guest |
| `apps/test/features/organizer/events/**` | **D1** | Event & kategori tiket |
| `apps/test/developer_2_flow_test.dart` | **D2** | Alur tiket/scan/membership |
| `apps/test/features/organizer/shell/organizer_membership_test.dart` | **D2** | Membership |
| `apps/test/features/check_in/**` (bila dibuat) | **D2** | Check-in |
| `apps/test/features/admin/**` | **D3** | Layar Admin |
| `apps/test/features/organizer/operations/**` | **D3** | Attendee/export/scanner organizer |
| `apps/test/features/organizer/shell/organizer_shell_test.dart` | **D3** | Shell Organizer/notifikasi |
| `apps/test/features/organizer/shell/organizer_plans_and_support_test.dart` | **D3** | Plans & support |
| `apps/test/services/api_mode_no_fallback_test.dart` | **D3** | Lintas service; koordinasi tertulis bila D1/D2 perlu menambah kasus |
| `apps/test/helpers/test_mock_server.dart` | **D3** | Helper bersama; perubahan hanya aditif & dikoordinasikan |
| `backend/test/**` (seluruh file eksisting) | **pemilik file sumber yang diuji** | Mis. `order_*.test.js` → D1, `check_in*.test.js` → D2, `admin_*.test.js` → D3 |

**Aturan tambahan:**
- Developer hanya boleh **menambah file test baru** di `apps/test/**` / `backend/test/**` bila nama file jelas menunjukkan task-nya (mis. `d1_public_link_test.dart`, `admin_settings.test.js`).
- Developer **tidak boleh** mengubah test milik developer lain, meskipun test tersebut gagal akibat perubahannya. Bila perubahan developer X memecahkan test milik Y, X wajib: (1) melaporkan di PR, (2) menyertakan bukti kegagalan, (3) menyerahkan perbaikan test kepada Y.
- Satu file test **tidak boleh** diubah oleh dua developer pada PR berbeda dalam periode yang sama.

### Area koordinasi (wajib permintaan tertulis)

| File | Owner | Pemohon | Prosedur |
|---|---|---|---|
| `backend/src/controllers/checkInController.js` | D2 | D3 (`listEventAttendees`) | D3 menulis spesifikasi query + field; D2/D3 (dengan persetujuan D2) mengedit; dicatat di kedua laporan |
| `backend/src/routes/eventRoutes.js` | D1 | D2 (`GET /me/memberships`) | D1 menambahkan route sesuai spesifikasi D2 |
| `apps/lib/app_router.dart` | D1 | D2 (`/invite/:token`, `/staff`) | D1 mengimplementasikan route; D2 menyediakan screen |
| `backend/src/app.js` | D3 | D1/D2 (route baru) | D3 me-mount route baru sesuai §1.3 |
| `apps/lib/features/tickets/screens/ticket_list_screen.dart` | D2 | D1 (navigasi pasca-checkout) | D2 menambah parameter; D1 memakai |

---

## Bagian 3 — Checklist integrasi per PR

Setiap PR Tahap 2 wajib mencantumkan:

- [ ] Baseline commit.
- [ ] Task ID dan file yang diubah (cocok dengan allow-list).
- [ ] Endpoint baru/diubah (dan pembaruan `INTEGRATION_CONTRACT.md` bila aditif).
- [ ] Bukti test: perintah + hasil.
- [ ] Status per platform: API / DB / Web / Android (`PASS`/`NOT RUN` + alasan).
- [ ] Dampak ke developer lain (bila ada).
- [ ] Konfirmasi tidak menyentuh schema/migration/seed.


