# TAHAP 3 — KEPEMILIKAN FILE

- **Versi:** 2.0 (2026-11-25)
- **Menggantikan:** versi 20-11-2026 pada nama file yang sama dan `TAHAP_2/FILE_OWNERSHIP.md` untuk pekerjaan Tahap 3.
- **Prinsip:** satu file = satu owner per fase. FASE 1: D2 dan D3 tidak boleh memiliki file yang sama. FASE 2: D1 menjadi owner akhir.

---

## Bagian 1 — Prinsip dan definisi

1. **Owner** adalah satu-satunya developer yang boleh mengedit file pada fase tersebut.
2. **File bersama** adalah file yang dipakai lebih dari satu domain. File bersama **hanya** dimiliki D1.
3. **File beku** adalah file yang tidak boleh diubah siapa pun pada Tahap 3 (schema, migration, PRD, laporan Tahap 1/2, arsip).
4. **Perubahan minimum** di luar daftar hanya boleh dilakukan bila benar-benar diperlukan untuk menyelesaikan tugas, dengan catatan file/alasan/dampak pada laporan.
5. **Tidak ada owner ganda.** Bila ditemukan overlap, dokumen ini harus diperbaiki sebelum implementasi.

Legenda fase:
- **F1-D2** = Developer 2, FASE 1.
- **F1-D3** = Developer 3, FASE 1.
- **F1-D1** = Developer 1, file bersama/tertutup selama FASE 1.
- **F2-D1** = Developer 1, FASE 2 (final owner).

---

## Bagian 2 — FASE 1: kepemilikan Developer 2

### 2.1 Backend

```
backend/src/controllers/checkInController.js
backend/src/controllers/ticketController.js
backend/src/controllers/eventInvitationController.js
backend/src/routes/checkInRoutes.js
backend/src/routes/ticketRoutes.js
backend/src/routes/invitationsRoutes.js
backend/src/routes/meRoutes.js
backend/src/services/ticketTokenService.js
backend/src/validators/ticketValidator.js
backend/test/checkin_rules.test.js
backend/test/event_invitation_tahap3.test.js          (baru)
backend/test/ticket_token_tahap3.test.js              (baru)
```

Catatan:
- `checkInController.js` juga memuat `listEventAttendees`, `exportEventAttendeesCsv`, dan `getEventOrders` yang dipakai D3. **D3 tidak mengedit file ini.** Bila D3 menemukan bug di endpoint tersebut, D3 menulis spesifikasi + bukti di laporan; D2 memperbaiki bila masih dalam FASE 1, atau D1 memperbaiki di FASE 2.
- `ticketTokenService.js` termasuk backfill `token_hash` untuk tiket gratis.

### 2.2 Flutter — `apps/lib`

```
apps/lib/features/tickets/**
apps/lib/features/scanner/**
apps/lib/features/check_in/**
apps/lib/features/staff/**
apps/lib/features/organizer/membership/**
apps/lib/features/organizer/screens/staff_management_screen.dart
apps/lib/features/organizer/operations/organizer_scanner_screen.dart
apps/lib/services/ticket/**
apps/lib/services/scanner/**
apps/lib/services/check_in/**
apps/lib/services/organizer_membership/**
apps/lib/providers/check_in_provider.dart
apps/lib/models/ticket/**
apps/lib/models/check_in/**
```

### 2.3 Test Flutter

```
apps/test/developer_2_flow_test.dart
apps/test/features/organizer/shell/organizer_membership_test.dart
apps/test/features/organizer/operations/attendee_access_widget_test.dart
apps/test/features/tickets/**                          (baru)
apps/test/features/scanner/**                          (baru)
apps/test/features/check_in/**                         (baru)
apps/test/features/staff/**                            (baru)
apps/test/features/organizer/membership/**             (baru)
```

### 2.4 File yang tidak boleh diubah D2

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/main.dart
apps/lib/routes/app_routes.dart
apps/pubspec.yaml
apps/pubspec.lock
apps/analysis_options.yaml
apps/lib/core/**
apps/lib/providers/auth_provider.dart
apps/lib/providers/event_provider.dart
apps/lib/providers/order_provider.dart
apps/lib/providers/payment_provider.dart
apps/lib/services/api/**
apps/lib/services/auth/**
apps/lib/services/event/**
apps/lib/services/order/**
apps/lib/services/payment/**
apps/lib/services/public_event/**
apps/lib/services/organizer_events/**
apps/lib/services/admin/**
apps/lib/services/organizer_operations/**
apps/lib/services/organizer_plans/**
apps/lib/services/organizer_support/**
apps/lib/services/organizer_notifications/**
apps/lib/services/organizer_shell/**
apps/lib/services/report/**
apps/lib/services/notification/**
apps/lib/features/admin/**
apps/lib/features/auth/**
apps/lib/features/events/**
apps/lib/features/home/**
apps/lib/features/orders/**
apps/lib/features/payments/**
apps/lib/features/public_event/**
apps/lib/features/registration/**
apps/lib/features/reports/**
apps/lib/features/notifications/**
apps/lib/features/organizer/screens/attendee_list_screen.dart
apps/lib/features/organizer/screens/organizer_order_list_screen.dart
apps/lib/features/organizer/screens/organizer_dashboard_screen.dart
apps/lib/features/organizer/operations/**              (kecuali organizer_scanner_screen.dart)
apps/lib/features/organizer/shell/**
apps/lib/features/organizer/plans/**
apps/lib/features/organizer/support/**
apps/lib/features/organizer/events/**
apps/lib/features/organizer/screens/event_form_screen.dart
apps/lib/features/organizer/screens/event_management_screen.dart
apps/lib/models/event/**
apps/lib/models/order/**
apps/lib/models/payment/**
apps/lib/models/user/**
apps/lib/models/admin/**
apps/lib/models/report/**
```

Lanjutan file yang tidak boleh diubah D2:

```
apps/test/stage1_integration_test.dart
apps/test/stage2_integration_test.dart
apps/test/app_router_test.dart
apps/test/widget_test.dart
apps/test/services/api_mode_no_fallback_test.dart
apps/test/helpers/test_mock_server.dart
apps/test/features/auth/**
apps/test/features/orders/**
apps/test/features/registration/**
apps/test/features/organizer/events/**
apps/test/features/public_event/**
apps/test/features/admin/**
apps/test/features/reports/**
apps/test/features/organizer/operations/attendee_operations_test.dart
apps/test/features/organizer/shell/organizer_shell_test.dart
apps/test/features/organizer/shell/organizer_plans_and_support_test.dart
backend/src/app.js
backend/src/config/**
backend/src/middleware/**
backend/src/controllers/authController.js
backend/src/controllers/eventController.js
backend/src/controllers/orderController.js
backend/src/controllers/paymentController.js
backend/src/controllers/ticketTypeController.js
backend/src/controllers/organizerProfileController.js
backend/src/controllers/adminController.js
backend/src/controllers/auditLogController.js
backend/src/controllers/platformSettingsController.js
backend/src/controllers/adminOverviewController.js
backend/src/controllers/planController.js
backend/src/controllers/subscriptionController.js
backend/src/controllers/revenueController.js
backend/src/controllers/reportController.js
backend/src/controllers/notificationController.js
backend/src/controllers/eventMetricsController.js
backend/src/routes/authRoutes.js
backend/src/routes/eventRoutes.js
backend/src/routes/orderRoutes.js
backend/src/routes/paymentRoutes.js
backend/src/routes/ticketTypeRoutes.js
backend/src/routes/adminRoutes.js
backend/src/routes/planRoutes.js
backend/src/routes/subscriptionRoutes.js
backend/src/routes/revenueRoutes.js
backend/src/routes/reportRoutes.js
backend/src/routes/notificationRoutes.js
backend/src/routes/organizerRoutes.js
backend/src/services/authService.js
backend/src/services/emailService.js
backend/src/services/adminBootstrapService.js
backend/src/services/seedService.js
backend/src/services/notificationService.js
backend/src/utils/auditLog.js
backend/src/utils/eventResponse.js
backend/src/utils/eventValidation.js
backend/src/utils/eventSummary.js
backend/src/utils/orderResponse.js
backend/src/utils/response.js
backend/src/utils/validators.js
backend/src/utils/constants.js
backend/src/utils/logger.js
backend/src/validators/authValidator.js
backend/src/models/**
backend/scripts/**
backend/package.json
backend/package-lock.json
README.md
backend/README.md
docs/**
task/**
```

---

## Bagian 3 — FASE 1: kepemilikan Developer 3

### 3.1 Backend

```
backend/src/controllers/adminController.js
backend/src/controllers/auditLogController.js
backend/src/controllers/platformSettingsController.js
backend/src/controllers/adminOverviewController.js
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
backend/src/utils/auditLog.js
backend/src/services/notificationService.js
backend/test/admin_platform_tahap2.test.js
backend/test/event_attendees_order.test.js
backend/test/event_export.test.js
backend/test/admin_tahap3_governance.test.js            (baru)
backend/test/organizer_revenue_tahap3.test.js           (baru)
```

Catatan:
- `event_attendees_order.test.js` dan `event_export.test.js` menguji fungsi di `checkInController.js` (milik D2). D3 boleh **menjalankan** dan **melaporkan** hasilnya, tetapi perubahan perilaku backend dilakukan D2. Bila D3 perlu menambah kasus test untuk endpoint tersebut, tambahkan file baru `backend/test/d3_attendee_contract_tahap3.test.js` (tidak mengedit file lama).

### 3.2 Flutter — `apps/lib`

```
apps/lib/features/admin/**
apps/lib/features/reports/**
apps/lib/features/notifications/**
apps/lib/features/organizer/screens/attendee_list_screen.dart
apps/lib/features/organizer/screens/organizer_order_list_screen.dart
apps/lib/features/organizer/screens/organizer_dashboard_screen.dart
apps/lib/features/organizer/operations/assisted_registration_screen.dart
apps/lib/features/organizer/operations/organizer_activity_log_screen.dart
apps/lib/features/organizer/operations/organizer_attendee_detail_screen.dart
apps/lib/features/organizer/operations/organizer_report_screen.dart
apps/lib/features/organizer/shell/**
apps/lib/features/organizer/plans/**
apps/lib/features/organizer/support/**
apps/lib/services/admin/**
apps/lib/services/organizer_operations/**
apps/lib/services/organizer_plans/**
apps/lib/services/organizer_support/**
apps/lib/services/organizer_notifications/**
apps/lib/services/organizer_shell/**
apps/lib/services/report/**
apps/lib/services/notification/**
apps/lib/services/mock/mock_attendee_repository.dart
apps/lib/providers/report_provider.dart
apps/lib/providers/notification_provider.dart
apps/lib/models/admin/**
apps/lib/models/report/**
```

Catatan:
- Folder `apps/lib/features/organizer/operations/` **tidak** diberikan sebagai wildcard ke D3 karena berisi satu file milik D2 (`organizer_scanner_screen.dart`). Kepemilikan ditulis per file: D2 memiliki `organizer_scanner_screen.dart`; D3 memiliki `assisted_registration_screen.dart`, `organizer_activity_log_screen.dart`, `organizer_attendee_detail_screen.dart`, dan `organizer_report_screen.dart`.
- `organizer_operations_repository.dart` dimiliki D3. D2 **tidak** mengeditnya. D2 memindahkan `OrganizerScannerScreen` ke `ScannerService`; setelah itu D3 menghapus bagian mock scanner/offline/assisted yang tidak lagi dipakai.
- `organizer_shell_service.dart` dimiliki D3; D1 tidak mengeditnya kecuali perbaikan integrasi di FASE 2.

### 3.3 Test Flutter

```
apps/test/features/admin/**
apps/test/features/reports/**
apps/test/features/notifications/**
apps/test/features/organizer/operations/attendee_operations_test.dart
apps/test/features/organizer/operations/attendee_export_tahap3_test.dart      (baru)
apps/test/features/organizer/operations/organizer_report_tahap3_test.dart     (baru)
apps/test/features/organizer/shell/organizer_shell_test.dart
apps/test/features/organizer/shell/organizer_plans_and_support_test.dart
```

### 3.4 File yang tidak boleh diubah D3

D3 tidak boleh mengubah:

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/main.dart
apps/lib/routes/app_routes.dart
apps/pubspec.yaml
apps/pubspec.lock
apps/lib/core/**
apps/lib/providers/auth_provider.dart
apps/lib/providers/event_provider.dart
apps/lib/providers/order_provider.dart
apps/lib/providers/payment_provider.dart
apps/lib/providers/check_in_provider.dart
apps/lib/services/api/**
apps/lib/services/auth/**
apps/lib/services/event/**
apps/lib/services/order/**
apps/lib/services/payment/**
apps/lib/services/public_event/**
apps/lib/services/organizer_events/**
apps/lib/services/ticket/**
apps/lib/services/scanner/**
apps/lib/services/check_in/**
apps/lib/services/organizer_membership/**
apps/lib/features/auth/**
apps/lib/features/events/**
apps/lib/features/home/**
apps/lib/features/orders/**
apps/lib/features/payments/**
apps/lib/features/public_event/**
apps/lib/features/registration/**
apps/lib/features/tickets/**
apps/lib/features/scanner/**
apps/lib/features/check_in/**
apps/lib/features/staff/**
apps/lib/features/organizer/membership/**
apps/lib/features/organizer/events/**
apps/lib/features/organizer/screens/event_form_screen.dart
apps/lib/features/organizer/screens/event_management_screen.dart
apps/lib/features/organizer/screens/staff_management_screen.dart
apps/lib/features/organizer/operations/organizer_scanner_screen.dart
apps/lib/models/event/**
apps/lib/models/order/**
apps/lib/models/payment/**
apps/lib/models/ticket/**
apps/lib/models/check_in/**
apps/lib/models/user/**
```

Lanjutan file yang tidak boleh diubah D3:

```
apps/test/stage1_integration_test.dart
apps/test/stage2_integration_test.dart
apps/test/app_router_test.dart
apps/test/widget_test.dart
apps/test/services/api_mode_no_fallback_test.dart
apps/test/helpers/test_mock_server.dart
apps/test/features/auth/**
apps/test/features/orders/**
apps/test/features/registration/**
apps/test/features/organizer/events/**
apps/test/features/public_event/**
apps/test/features/tickets/**
apps/test/features/scanner/**
apps/test/features/check_in/**
apps/test/features/staff/**
apps/test/features/organizer/membership/**
apps/test/features/organizer/operations/attendee_access_widget_test.dart
apps/test/developer_2_flow_test.dart
backend/src/app.js
backend/src/config/**
backend/src/middleware/**
backend/src/controllers/authController.js
backend/src/controllers/eventController.js
backend/src/controllers/orderController.js
backend/src/controllers/paymentController.js
backend/src/controllers/ticketController.js
backend/src/controllers/checkInController.js
backend/src/controllers/eventInvitationController.js
backend/src/controllers/ticketTypeController.js
backend/src/controllers/organizerProfileController.js
backend/src/routes/authRoutes.js
backend/src/routes/eventRoutes.js
backend/src/routes/orderRoutes.js
backend/src/routes/paymentRoutes.js
backend/src/routes/ticketRoutes.js
backend/src/routes/checkInRoutes.js
backend/src/routes/invitationsRoutes.js
backend/src/routes/meRoutes.js
backend/src/routes/ticketTypeRoutes.js
backend/src/services/authService.js
backend/src/services/emailService.js
backend/src/services/ticketTokenService.js
backend/src/services/adminBootstrapService.js
backend/src/services/seedService.js
backend/src/utils/eventResponse.js
backend/src/utils/eventValidation.js
backend/src/utils/eventSummary.js
backend/src/utils/orderResponse.js
backend/src/utils/response.js
backend/src/utils/validators.js
backend/src/utils/constants.js
backend/src/utils/logger.js
backend/src/validators/authValidator.js
backend/src/validators/ticketValidator.js
backend/src/models/**
backend/scripts/**
backend/package.json
backend/package-lock.json
README.md
backend/README.md
docs/**
task/**
```

---

## Bagian 4 — FASE 1: file bersama dan file tertutup (milik D1)

File berikut **tidak boleh** diedit D2/D3. Kebutuhan perubahan dicatat di laporan bagian "Permintaan Integrasi untuk Developer 1".

### 4.1 Aplikasi & routing

```
apps/lib/app.dart
apps/lib/app_router.dart
apps/lib/main.dart
apps/lib/routes/app_routes.dart
apps/pubspec.yaml
apps/pubspec.lock
apps/analysis_options.yaml
apps/lib/core/**
apps/lib/providers/auth_provider.dart
apps/lib/providers/event_provider.dart
apps/lib/providers/order_provider.dart
apps/lib/providers/payment_provider.dart
apps/lib/services/api/**
apps/lib/services/auth/**
apps/lib/services/event/**
apps/lib/services/order/**
apps/lib/services/payment/**
apps/lib/services/public_event/**
apps/lib/services/organizer_events/**
apps/lib/models/event/**
apps/lib/models/order/**
apps/lib/models/payment/**
apps/lib/models/user/**
apps/lib/features/auth/**
apps/lib/features/events/**
apps/lib/features/home/**
apps/lib/features/orders/**
apps/lib/features/payments/**
apps/lib/features/public_event/**
apps/lib/features/registration/**
apps/lib/features/organizer/events/**
apps/lib/features/organizer/screens/event_form_screen.dart
apps/lib/features/organizer/screens/event_management_screen.dart
```

### 4.2 Backend bersama

```
backend/src/app.js
backend/server.js
backend/src/config/**
backend/src/middleware/**
backend/src/controllers/authController.js
backend/src/controllers/eventController.js
backend/src/controllers/orderController.js
backend/src/controllers/paymentController.js
backend/src/controllers/ticketTypeController.js
backend/src/controllers/organizerProfileController.js
backend/src/routes/authRoutes.js
backend/src/routes/eventRoutes.js
backend/src/routes/orderRoutes.js
backend/src/routes/paymentRoutes.js
backend/src/routes/ticketTypeRoutes.js
backend/src/services/authService.js
backend/src/services/emailService.js
backend/src/services/adminBootstrapService.js
backend/src/services/seedService.js
backend/src/utils/eventResponse.js
backend/src/utils/eventValidation.js
backend/src/utils/eventSummary.js
backend/src/utils/orderResponse.js
backend/src/utils/response.js
backend/src/utils/validators.js
backend/src/utils/constants.js
backend/src/utils/logger.js
backend/src/validators/authValidator.js
backend/src/models/**
backend/scripts/**
backend/package.json
backend/package-lock.json
```

### 4.3 Test lintas domain

```
apps/test/stage1_integration_test.dart
apps/test/stage2_integration_test.dart
apps/test/app_router_test.dart
apps/test/widget_test.dart
apps/test/services/api_mode_no_fallback_test.dart
apps/test/helpers/test_mock_server.dart
apps/test/features/auth/**
apps/test/features/orders/**
apps/test/features/registration/**
apps/test/features/organizer/events/**
apps/test/features/public_event/**
backend/test/stage1_integration.test.js
backend/test/stage2_integration.test.js
backend/test/security_and_services.test.js
backend/test/auth_contract.test.js
backend/test/order_*.test.js
backend/test/payment_simulation.test.js
backend/test/event_auto_publish.test.js
backend/test/event_public_links.test.js
backend/test/event_ownership_rules.test.js
backend/test/event_response.test.js
backend/test/event_summary.test.js
backend/test/attendee_dynamic_fields.test.js
backend/test/ticket_type_rules.test.js
backend/test/utils.test.js
backend/test/integration_safety.test.js
backend/test/admin_bootstrap.test.js
```

### 4.4 Dokumentasi dan konfigurasi

```
README.md
backend/README.md
docs/**
task/**
.github/**
.githooks/**
.editorconfig
.gitattributes
.gitignore
```

---

## Bagian 5 — FASE 2: kepemilikan Developer 1

Setelah FASE 1 lulus, D1 menjadi **final owner** untuk seluruh file aplikasi, backend, test, konfigurasi, dan dokumentasi. File D2/D3 berstatus **frozen** kecuali:

1. Diperlukan untuk memperbaiki bug integrasi yang terbukti.
2. Diperlukan untuk menyelesaikan kontrak yang gagal (mis. route tidak meneruskan parameter).
3. Diperlukan untuk audit/pembersihan file mati.

Setiap perubahan pada file D2/D3 wajib dicatat di laporan D1:

| File | Alasan | Perubahan | Dampak |
|---|---|---|---|
| (diisi) | (diisi) | (diisi) | (diisi) |

D1 juga memiliki seluruh file berikut pada FASE 2:

```
apps/lib/**
apps/test/**
apps/pubspec.yaml
apps/pubspec.lock
backend/src/**
backend/test/**
backend/scripts/**
backend/package.json
backend/package-lock.json
README.md
backend/README.md
docs/**
task/RUNBOOK_OPERASIONAL.md
task/PRD_TRACEABILITY_MATRIX.md
```

File beku yang tetap tidak boleh diubah D1:

```
backend/prisma/schema.prisma
backend/prisma/migrations/**
backend/supabase/**
PRD.md
task/TAHAP_1/**
task/TAHAP_2/**          (laporan/dokumen historis)
task/archive/**
task/FASE_1C_AUTHORIZATION_REGISTER.md
task/FASE_1D_AUTHORIZATION_AND_UNBLOCKING.md
task/FASE_1E_*.md
task/TECHNICAL_GATE_CLOSURE.md
.github/**
.githooks/**
```

Pengecualian dokumentasi: D1 **boleh** memperbarui `task/PEMBAGIAN_TUGAS_FINAL.md`, `task/FINAL_ACCEPTANCE_CHECKLIST.md` (root), `task/PRD_TRACEABILITY_MATRIX.md`, dan `task/DB_CHANGE_PROPOSAL.md` karena statusnya dokumen perencanaan aktif, bukan laporan historis.

---

## Bagian 6 — Inventaris backend

| File | F1 owner | F2 owner | Catatan |
|---|---|---|---|
| `src/app.js` | D1 | D1 | Mount route, middleware, 404 |
| `server.js` | D1 | D1 | Bootstrap |
| `src/config/db.js` | D1 | D1 | Koneksi PostgreSQL |
| `src/config/env.js` | D1 | D1 | Env & validasi |
| `src/config/supabase.js` | D1 | D1 | Legacy; kandidat hapus |
| `src/middleware/authMiddleware.js` | D1 | D1 | JWT |
| `src/middleware/errorMiddleware.js` | D1 | D1 | Error envelope |
| `src/middleware/notFoundMiddleware.js` | D1 | D1 | 404 |
| `src/middleware/rateLimitMiddleware.js` | D1 | D1 | Rate limit |
| `src/middleware/requestLogger.js` | D1 | D1 | Log |
| `src/middleware/roleMiddleware.js` | D1 | D1 | Role |
| `src/middleware/validationMiddleware.js` | D1 | D1 | Validasi |
| `src/controllers/authController.js` | D1 | D1 | Auth |
| `src/controllers/eventController.js` | D1 | D1 | Event + publish |
| `src/controllers/orderController.js` | D1 | D1 | Order |
| `src/controllers/paymentController.js` | D1 | D1 | Payment |
| `src/controllers/ticketTypeController.js` | D1 | D1 | Kategori |
| `src/controllers/organizerProfileController.js` | D1 | D1 | Profil |
| `src/controllers/checkInController.js` | **D2** | D1 | Termasuk attendee/export/orders (D3 read-only) |
| `src/controllers/ticketController.js` | **D2** | D1 | Tiket & verify |
| `src/controllers/eventInvitationController.js` | **D2** | D1 | Invitation & membership |
| `src/controllers/adminController.js` | **D3** | D1 | Akun |
| `src/controllers/auditLogController.js` | **D3** | D1 | Audit |
| `src/controllers/platformSettingsController.js` | **D3** | D1 | Settings |
| `src/controllers/adminOverviewController.js` | **D3** | D1 | Overview |
| `src/controllers/planController.js` | **D3** | D1 | Paket |
| `src/controllers/subscriptionController.js` | **D3** | D1 | Langganan |
| `src/controllers/revenueController.js` | **D3** | D1 | Revenue |
| `src/controllers/reportController.js` | **D3** | D1 | Laporan |
| `src/controllers/notificationController.js` | **D3** | D1 | Notifikasi |
| `src/controllers/eventMetricsController.js` | **D3** | D1 | Moderasi & metrik |
| `src/routes/authRoutes.js` | D1 | D1 | — |
| `src/routes/eventRoutes.js` | D1 | D1 | — |
| `src/routes/orderRoutes.js` | D1 | D1 | — |
| `src/routes/paymentRoutes.js` | D1 | D1 | — |
| `src/routes/ticketTypeRoutes.js` | D1 | D1 | — |
| `src/routes/checkInRoutes.js` | **D2** | D1 | — |
| `src/routes/ticketRoutes.js` | **D2** | D1 | — |
| `src/routes/invitationsRoutes.js` | **D2** | D1 | — |
| `src/routes/meRoutes.js` | **D2** | D1 | — |
| `src/routes/adminRoutes.js` | **D3** | D1 | — |
| `src/routes/planRoutes.js` | **D3** | D1 | — |
| `src/routes/subscriptionRoutes.js` | **D3** | D1 | — |
| `src/routes/revenueRoutes.js` | **D3** | D1 | — |
| `src/routes/reportRoutes.js` | **D3** | D1 | — |
| `src/routes/notificationRoutes.js` | **D3** | D1 | — |
| `src/routes/organizerRoutes.js` | **D3** | D1 | — |
| `src/services/authService.js` | D1 | D1 | — |
| `src/services/emailService.js` | D1 | D1 | — |
| `src/services/ticketTokenService.js` | **D2** | D1 | Token & hash |
| `src/services/notificationService.js` | **D3** | D1 | — |
| `src/services/adminBootstrapService.js` | D1 | D1 | — |
| `src/services/seedService.js` | D1 | D1 | — |
| `src/utils/auditLog.js` | **D3** | D1 | — |
| `src/utils/eventResponse.js` | D1 | D1 | — |
| `src/utils/eventValidation.js` | D1 | D1 | — |
| `src/utils/eventSummary.js` | D1 | D1 | — |
| `src/utils/orderResponse.js` | D1 | D1 | — |
| `src/utils/response.js` | D1 | D1 | — |
| `src/utils/validators.js` | D1 | D1 | — |
| `src/utils/constants.js` | D1 | D1 | — |
| `src/utils/logger.js` | D1 | D1 | — |
| `src/validators/authValidator.js` | D1 | D1 | — |
| `src/validators/ticketValidator.js` | **D2** | D1 | — |
| `src/models/Event.js` | D1 | D1 | Legacy; kandidat hapus |
| `src/models/Ticket.js` | D1 | D1 | Legacy; kandidat hapus |
| `src/models/User.js` | D1 | D1 | Legacy; kandidat hapus |
| `scripts/**` | D1 | D1 | Tooling; jangan hapus tanpa audit |
| `prisma/schema.prisma` | beku | beku | Tidak boleh diubah |
| `prisma/migrations/**` | beku | beku | Tidak boleh diubah |
| `supabase/migrations/**` | beku | beku | Legacy; tidak dijalankan |

---

## Bagian 7 — Inventaris `apps/lib`

| File/folder | F1 owner | F2 owner | Catatan |
|---|---|---|---|
| `app.dart` | D1 | D1 | AuthGate |
| `app_router.dart` | D1 | D1 | Route & guard |
| `main.dart` | D1 | D1 | Bootstrap |
| `routes/app_routes.dart` | D1 | D1 | Konstanta route |
| `core/**` | D1 | D1 | Config, network, theme, utils |
| `providers/auth_provider.dart` | D1 | D1 | — |
| `providers/event_provider.dart` | D1 | D1 | — |
| `providers/order_provider.dart` | D1 | D1 | — |
| `providers/payment_provider.dart` | D1 | D1 | — |
| `providers/check_in_provider.dart` | **D2** | D1 | — |
| `providers/report_provider.dart` | **D3** | D1 | — |
| `providers/notification_provider.dart` | **D3** | D1 | — |
| `models/event/**` | D1 | D1 | — |
| `models/order/**` | D1 | D1 | — |
| `models/payment/**` | D1 | D1 | — |
| `models/user/**` | D1 | D1 | — |
| `models/ticket/**` | **D2** | D1 | — |
| `models/check_in/**` | **D2** | D1 | — |
| `models/admin/**` | **D3** | D1 | — |
| `models/report/**` | **D3** | D1 | — |
| `services/api/**` | D1 | D1 | HTTP client |
| `services/auth/**` | D1 | D1 | — |
| `services/event/**` | D1 | D1 | — |
| `services/order/**` | D1 | D1 | — |
| `services/payment/**` | D1 | D1 | — |
| `services/public_event/**` | D1 | D1 | — |
| `services/organizer_events/**` | D1 | D1 | — |
| `services/ticket/**` | **D2** | D1 | — |
| `services/scanner/**` | **D2** | D1 | — |
| `services/check_in/**` | **D2** | D1 | — |
| `services/organizer_membership/**` | **D2** | D1 | — |
| `services/admin/**` | **D3** | D1 | — |
| `services/organizer_operations/**` | **D3** | D1 | Termasuk export/report |
| `services/organizer_plans/**` | **D3** | D1 | — |
| `services/organizer_support/**` | **D3** | D1 | — |
| `services/organizer_notifications/**` | **D3** | D1 | — |
| `services/organizer_shell/**` | **D3** | D1 | — |
| `services/report/**` | **D3** | D1 | — |
| `services/notification/**` | **D3** | D1 | — |
| `services/mock/mock_attendee_repository.dart` | **D3** | D1 | Mock demo |
| `features/auth/**` | D1 | D1 | — |
| `features/events/**` | D1 | D1 | — |
| `features/home/**` | D1 | D1 | — |
| `features/orders/**` | D1 | D1 | — |
| `features/payments/**` | D1 | D1 | — |
| `features/public_event/**` | D1 | D1 | — |
| `features/registration/**` | D1 | D1 | — |
| `features/organizer/events/**` | D1 | D1 | Detail, form, kategori |
| `features/organizer/screens/event_form_screen.dart` | D1 | D1 | Builder field dinamis |
| `features/organizer/screens/event_management_screen.dart` | D1 | D1 | — |
| `features/organizer/screens/organizer_profile_screen.dart` | D1 | D1 | — |
| `features/organizer/screens/organizer_dashboard_screen.dart` | **D3** | D1 | Statistik |
| `features/organizer/screens/attendee_list_screen.dart` | **D3** | D1 | — |
| `features/organizer/screens/organizer_order_list_screen.dart` | **D3** | D1 | — |
| `features/organizer/screens/staff_management_screen.dart` | **D2** | D1 | — |
| `features/organizer/membership/**` | **D2** | D1 | — |
| `features/organizer/operations/organizer_scanner_screen.dart` | **D2** | D1 | — |
| `features/organizer/operations/organizer_attendee_detail_screen.dart` | **D3** | D1 | — |
| `features/organizer/operations/organizer_report_screen.dart` | **D3** | D1 | — |
| `features/organizer/operations/organizer_activity_log_screen.dart` | **D3** | D1 | — |
| `features/organizer/operations/assisted_registration_screen.dart` | **D3** | D1 | Non-MVP; tetap ada, tidak diekspos |
| `features/organizer/shell/**` | **D3** | D1 | — |
| `features/organizer/plans/**` | **D3** | D1 | — |
| `features/organizer/support/**` | **D3** | D1 | — |
| `features/admin/**` | **D3** | D1 | Seluruh konsol Admin |
| `features/reports/**` | **D3** | D1 | — |
| `features/notifications/**` | **D3** | D1 | — |
| `features/tickets/**` | **D2** | D1 | QR & tiket |
| `features/scanner/**` | **D2** | D1 | Kamera & hasil |
| `features/check_in/**` | **D2** | D1 | Check-in & riwayat |
| `features/staff/**` | **D2** | D1 | Dashboard & accept invitation |

---

## Bagian 8 — Inventaris test

### 8.1 `apps/test`

| File | F1 owner | Catatan |
|---|---|---|
| `app_router_test.dart` | D1 | Router |
| `widget_test.dart` | D1 | Shell/auth |
| `stage1_integration_test.dart` | D1 | Integrasi Tahap 1 |
| `stage2_integration_test.dart` | D1 | Integrasi lintas domain |
| `developer_2_flow_test.dart` | D2 | Alur tiket/scan |
| `services/api_mode_no_fallback_test.dart` | D1 | Lintas service |
| `helpers/test_mock_server.dart` | D1 | Helper bersama |
| `features/auth/**` | D1 | — |
| `features/orders/**` | D1 | — |
| `features/registration/**` | D1 | — |
| `features/public_event/**` | D1 | — |
| `features/organizer/events/**` | D1 | — |
| `features/organizer/shell/organizer_membership_test.dart` | D2 | Membership |
| `features/organizer/operations/attendee_access_widget_test.dart` | D2 | Akses scanner |
| `features/organizer/operations/attendee_operations_test.dart` | D3 | Peserta |
| `features/organizer/shell/organizer_shell_test.dart` | D3 | Shell/notifikasi |
| `features/organizer/shell/organizer_plans_and_support_test.dart` | D3 | Plans/support |
| `features/admin/**` | D3 | Konsol Admin |
| `features/reports/**` | D3 | Laporan |
| `features/notifications/**` | D3 | Notifikasi |
| `features/tickets/**` | D2 | Baru |
| `features/scanner/**` | D2 | Baru |
| `features/check_in/**` | D2 | Baru |
| `features/staff/**` | D2 | Baru |
| `features/organizer/membership/**` | D2 | Baru |
| `features/organizer/operations/attendee_export_tahap3_test.dart` | D3 | Baru |
| `features/organizer/operations/organizer_report_tahap3_test.dart` | D3 | Baru |

### 8.2 `backend/test`

| File | F1 owner | Catatan |
|---|---|---|
| `stage1_integration.test.js` | D1 | Integrasi |
| `stage2_integration.test.js` | D1 | Integrasi |
| `security_and_services.test.js` | D1 | Keamanan |
| `auth_contract.test.js` | D1 | Auth |
| `admin_bootstrap.test.js` | D1 | Bootstrap |
| `order_*.test.js` | D1 | Order |
| `payment_simulation.test.js` | D1 | Payment |
| `event_auto_publish.test.js` | D1 | Publish |
| `event_public_links.test.js` | D1 | Link |
| `event_ownership_rules.test.js` | D1 | Ownership |
| `event_response.test.js` | D1 | Response |
| `event_summary.test.js` | D1 | Summary |
| `attendee_dynamic_fields.test.js` | D1 | Field dinamis |
| `ticket_type_rules.test.js` | D1 | Kategori |
| `utils.test.js` | D1 | Util |
| `integration_safety.test.js` | D1 | Safety |
| `checkin_rules.test.js` | D2 | Check-in |
| `event_invitation_tahap3.test.js` | D2 | Baru |
| `ticket_token_tahap3.test.js` | D2 | Baru |
| `admin_platform_tahap2.test.js` | D3 | Admin |
| `event_attendees_order.test.js` | D3 | Peserta (backend D2) |
| `event_export.test.js` | D3 | Export (backend D2) |
| `admin_tahap3_governance.test.js` | D3 | Baru |
| `organizer_revenue_tahap3.test.js` | D3 | Baru |
| `d3_attendee_contract_tahap3.test.js` | D3 | Baru, hanya jika perlu |

Aturan test:
- D2/D3 hanya boleh menambah file baru dengan nama yang jelas; tidak mengedit test milik developer lain.
- Bila test lintas domain gagal karena perubahan D2/D3, laporkan; D1 memperbaiki di FASE 2.
- Tidak ada test di luar direktori `test/` yang boleh dibuat. Test yang berada di luar `test/` (bila ditemukan) dihapus D1 setelah verifikasi tidak dipakai tooling.

---

## Bagian 9 — Konfigurasi, dokumentasi, dan tooling

| File | F1 owner | F2 owner | Catatan |
|---|---|---|---|
| `README.md` | D1 | D1 | Instalasi & mode |
| `backend/README.md` | D1 | D1 | Endpoint |
| `docs/ARCHITECTURE.md` | D1 | D1 | Arsitektur |
| `docs/DATABASE.md` | D1 | D1 | Skema & fungsi |
| `task/RUNBOOK_OPERASIONAL.md` | D1 | D1 | Baru |
| `task/PRD_TRACEABILITY_MATRIX.md` | D1 | D1 | Regenerasi |
| `task/FINAL_ACCEPTANCE_CHECKLIST.md` (root) | D1 | D1 | Banner ke versi Tahap 3 |
| `task/DB_CHANGE_PROPOSAL.md` | D1 | D1 | Proposal DB (tidak dieksekusi) |
| `apps/pubspec.yaml`, `pubspec.lock` | D1 | D1 | Dependency |
| `apps/analysis_options.yaml` | D1 | D1 | Lint |
| `backend/package.json`, `package-lock.json` | D1 | D1 | Dependency |
| `backend/.env.example` | D1 | D1 | Nama variabel saja |
| `.editorconfig`, `.gitattributes`, `.gitignore` | D1 | D1 | — |
| `.github/**`, `.githooks/**` | beku | beku | Tidak diubah |

---

## Bagian 10 — Bukti tidak ada overlap D2/D3

### 10.1 Pernyataan

Daftar file D2 (Bagian 2) dan D3 (Bagian 3) **tidak beririsan**. Setiap file yang berpotensi dipakai kedua domain telah dialokasikan ke satu owner:

| File berpotensi overlap | Keputusan | Alasan |
|---|---|---|
| `backend/src/controllers/checkInController.js` | **D2** | Berisi validate/record/check-in dan attendee/export/orders; D3 hanya mengonsumsi endpoint |
| `backend/src/controllers/ticketController.js` | **D2** | Tiket & verify |
| `backend/src/controllers/eventInvitationController.js` | **D2** | Invitation & membership |
| `backend/src/routes/checkInRoutes.js`, `ticketRoutes.js`, `invitationsRoutes.js`, `meRoutes.js` | **D2** | Route domain D2 |
| `backend/src/services/ticketTokenService.js` | **D2** | Token/hash |
| `backend/src/validators/ticketValidator.js` | **D2** | Validasi scan |
| `backend/src/app.js` | **D1** | Mount semua route |
| `apps/lib/app_router.dart`, `routes/app_routes.dart`, `app.dart` | **D1** | Routing & guard |
| `apps/lib/services/organizer_operations/**` | **D3** | Peserta, export, report, activity, assisted |
| `apps/lib/features/organizer/operations/organizer_scanner_screen.dart` | **D2** | Satu-satunya file di folder operations yang D2 miliki |
| `apps/lib/features/organizer/operations/` (4 file D3: `assisted_registration_screen.dart`, `organizer_activity_log_screen.dart`, `organizer_attendee_detail_screen.dart`, `organizer_report_screen.dart`) | **D3** | Peserta/report/activity/assisted |
| `apps/lib/features/organizer/screens/attendee_list_screen.dart` | **D3** | Peserta |
| `apps/lib/features/organizer/screens/staff_management_screen.dart` | **D2** | Staff |
| `apps/lib/features/organizer/membership/**` | **D2** | Membership |
| `apps/lib/features/organizer/shell/**` | **D3** | Shell/notifikasi |
| `apps/lib/features/tickets/**`, `scanner/**`, `check_in/**`, `staff/**` | **D2** | Tiket & scan |
| `apps/lib/features/admin/**`, `reports/**`, `notifications/**` | **D3** | Admin & back-office |
| `apps/lib/services/admin/**`, `organizer_plans/**`, `organizer_support/**`, `organizer_notifications/**`, `organizer_shell/**`, `report/**`, `notification/**` | **D3** | Back-office |
| `apps/lib/services/ticket/**`, `scanner/**`, `check_in/**`, `organizer_membership/**` | **D2** | Ticketing |
| `apps/lib/providers/check_in_provider.dart` | **D2** | Check-in |
| `apps/lib/providers/report_provider.dart`, `notification_provider.dart` | **D3** | Back-office |
| `apps/test/stage2_integration_test.dart` | **D1** | Lintas domain |
| `apps/test/services/api_mode_no_fallback_test.dart` | **D1** | Lintas service |
| `apps/test/helpers/test_mock_server.dart` | **D1** | Helper bersama |
| `apps/test/features/organizer/operations/attendee_access_widget_test.dart` | **D2** | Akses scanner |
| `apps/test/features/organizer/operations/attendee_operations_test.dart` | **D3** | Peserta |
| `README.md`, `backend/README.md`, `docs/**`, `task/**` | **D1** | Dokumentasi |

### 10.2 Perintah verifikasi overlap

Jalankan sebelum memulai dan sebelum menyerahkan hasil:

```powershell
# Daftar file yang benar-benar diubah per branch
$d2 = git diff --name-only origin/main...Developer-2-T3
$d3 = git diff --name-only origin/main...Developer-3-T3

# Irisan (harus kosong)
Compare-Object $d2 $d3 -IncludeEqual -ExcludeDifferent

# File di luar allow-list (harus kosong)
$allowD2 = Get-Content task/TAHAP_3/allowlist_d2.txt
$allowD3 = Get-Content task/TAHAP_3/allowlist_d3.txt
$d2 | Where-Object { $_ -notin $allowD2 }
$d3 | Where-Object { $_ -notin $allowD3 }
```

> `allowlist_d2.txt` dan `allowlist_d3.txt` dibuat oleh masing-masing developer dari Bagian 2/3 dokumen ini (satu path per baris, tanpa wildcard; wildcard diperluas manual). File daftar ini **tidak** di-commit; cukup dilampirkan pada laporan.

### 10.3 Hasil pemeriksaan perencanaan

- Pemeriksaan 2026-11-25 atas daftar path aktual (file yang ada + file baru yang dideklarasikan): **38 path D2**, **77 path D3**, **irisan 0**.
- D2 dan D3 tidak memiliki file yang sama pada daftar eksplisit.
- Satu-satunya area yang berpotensi tumpang tindih (`checkInController.js`, `organizer_operations_repository.dart`, `organizer_scanner_screen.dart`, test operasional) sudah dipisahkan per file, bukan per folder.
- File bersama (`app_router.dart`, `app.js`, `pubspec.yaml`, docs, test lintas domain) diberikan ke D1 dan **tidak** ada pada allow-list D2/D3.

---

## Bagian 11 — Keputusan penyelesaian konflik

| # | Konflik | Keputusan | Prosedur |
|---|---|---|---|
| 1 | D2 butuh `checkInController.js` untuk scan; D3 butuh untuk attendee/export/orders | D2 owner; D3 read-only | D3 menulis spesifikasi + bukti; D2 memperbaiki; bila tidak selesai, D1 di FASE 2 |
| 2 | D2 butuh `organizer_operations_repository.dart` untuk scanner | D2 pindah ke `ScannerService`; D3 owner repository | D2 tidak mengedit repository; D3 menghapus jalur mati setelah D2 selesai |
| 3 | D2 dan D3 sama-sama butuh perubahan `app_router.dart` | D1 owner | D2/D3 mencatat route + parameter di laporan; D1 mengimplementasikan |
| 4 | D2 dan D3 sama-sama butuh perubahan `backend/src/app.js` | D1 owner | Tidak perlu pada baseline; bila perlu, dicatat |
| 5 | D2 dan D3 sama-sama butuh dokumentasi endpoint | D1 owner | D2/D3 menulis di laporan; D1 memperbarui `backend/README.md` |
| 6 | D2 dan D3 sama-sama butuh test lintas domain | D1 owner | D2/D3 menambah file test baru sendiri |
| 7 | D3 butuh perubahan perilaku backend attendee/export | D2 owner | D3 melaporkan; D2 memperbaiki; D1 menyelesaikan sisa |
| 8 | D1 butuh file D2/D3 saat integrasi | D1 final owner FASE 2 | Dicatat di tabel perubahan laporan D1 |
| 9 | D2 butuh `pubspec.yaml` untuk dependency | D1 owner | Baseline sudah memuat `qr_flutter`/`mobile_scanner`; dependency baru diajukan ke D1 |
| 10 | D3 butuh file export di Android | Tidak menambah dependency di FASE 1 | Implementasi Web download + clipboard; D1 menyelesaikan file save bila dependency disetujui |

---

## Bagian 12 — Kebijakan penghapusan file

### 12.1 Urutan verifikasi sebelum menghapus

Wajib dilakukan untuk **setiap** file:

1. Cari referensi impor/require:
   ```powershell
   Get-ChildItem -Recurse -Include *.dart,*.js -File |
     Select-String -Pattern "<nama-file-tanpa-ekstensi>"
   ```
2. Cari referensi route/string/nama kelas.
3. Cari pemakaian pada `package.json`, `pubspec.yaml`, scripts, CI, dan dokumentasi.
4. Cari pemakaian pada test.
5. Jalankan `npm test`, `flutter analyze`, `flutter test` setelah penghapusan.
6. Catat file, alasan, dan bukti pada laporan.

Tidak boleh menghapus berdasarkan nama atau asumsi.

### 12.2 Kandidat penghapusan (harus diverifikasi)

| Kandidat | Kondisi | Tindakan |
|---|---|---|
| `backend/src/models/Event.js`, `Ticket.js`, `User.js` | Tidak diimpor kode runtime (hanya `config/supabase.js`) | Hapus setelah grep + test PASS |
| `backend/src/config/supabase.js` | Hanya dipakai models legacy | Hapus bersamaan models |
| Dependency `@supabase/supabase-js` | Tidak dipakai setelah models dihapus | Hapus dari `package.json` + lock; catat |
| `apps/lib/features/scanner/widgets/scanner_placeholder.dart` | Bila tidak lagi dipakai setelah kamera | Hapus setelah grep |
| `apps/lib/features/organizer/events/widgets/organizer_summary_widgets.dart` → `OrganizerQrPlaceholder` | Diganti QR nyata dari `public_url` | Hapus kelas placeholder setelah tidak dipakai |
| `apps/lib/services/admin/admin_revenue_service.dart` (isi mock) | Setelah D3 menulis ulang ke API | Pertahankan file, hapus data mock |
| `apps/lib/services/admin/admin_package_service.dart` (isi mock) | Setelah D3 menulis ulang ke API | Pertahankan file, hapus data mock |
| `apps/lib/services/organizer_plans/organizer_plans_service.dart` (isi mock) | Setelah D3 menulis ulang ke API | Pertahankan file, hapus data mock |
| `OrganizerOperationsRepository` bagian scanner/offline/assisted | Setelah D2 pindah ke `ScannerService` | Hapus method mati; jangan hapus file |
| `CheckInService` antrean offline + `syncPendingCheckIns` | Post-MVP, tidak diekspos | Hapus dari alur MVP; route backend `/sync` tetap |
| Test di luar direktori `test/` | Tidak ditemukan pada baseline; verifikasi ulang | Hapus hanya bila bukan milik tooling/plugin |
| `apps/linux|windows/macos/.../ephemeral/**` test plugin | Bagian dari plugin Flutter, bukan test proyek | Jangan hapus |

### 12.3 File yang wajib dipertahankan

- `backend/prisma/**` (schema + migration).
- `backend/supabase/migrations/**` (legacy, tidak dijalankan).
- `backend/scripts/**` (tooling validasi/audit/provisioning).
- Seluruh test di `apps/test/**` dan `backend/test/**`.
- `docs/**`, `README.md`, `backend/README.md`, `PRD.md`.
- `task/**` (kecuali banner superseded).
- Konfigurasi build Flutter (`android/`, `web/`, `pubspec.yaml`, `analysis_options.yaml`).
- `.github/**`, `.githooks/**`.
- Mock demo yang hanya aktif `MOCK_MODE=true` (`mock_organizer_event_repository.dart`, `mock_attendee_repository.dart`, `organizer_event_fixtures.dart`).
- `assisted_registration_screen.dart` (disembunyikan, bukan dihapus).

### 12.4 File yang tidak boleh dihapus meskipun tampak tidak dipakai

- `backend/src/controllers/organizerProfileController.js` (dipakai route organizer).
- `backend/src/utils/eventSummary.js` (dipakai metrik).
- `backend/src/services/notificationService.js` (dipakai controller/domain lain).
- `backend/src/services/seedService.js` (dipakai `server.js`).
- `backend/src/services/adminBootstrapService.js` (provisioning admin).
- `apps/lib/services/organizer_shell/organizer_shell_service.dart` (dashboard).
- `apps/lib/features/organizer/operations/assisted_registration_screen.dart` (non-MVP, tetap ada).

---

## Bagian 13 — Verifikasi kepemilikan

Sebelum memulai:

```powershell
git status --short
git --no-pager log --oneline -5
```

Sebelum menyerahkan:

```powershell
# 1. File yang diubah
git diff --name-only origin/main...HEAD

# 2. Tidak ada file di luar allow-list
# (bandingkan manual dengan Bagian 2/3)

# 3. Tidak ada overlap D2/D3
$d2 = git diff --name-only origin/main...Developer-2-T3
$d3 = git diff --name-only origin/main...Developer-3-T3
Compare-Object $d2 $d3 -IncludeEqual -ExcludeDifferent

# 4. Tidak menyentuh file beku
git diff --name-only origin/main...HEAD | Select-String -Pattern "prisma/|supabase/|PRD.md|task/TAHAP_1|task/TAHAP_2|task/archive"
```

Hasil yang diharapkan:
- Perintah 3 tidak menghasilkan output.
- Perintah 4 tidak menghasilkan output.
- Setiap file pada perintah 1 ada di allow-list developer.











