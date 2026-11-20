# Audit file dan dependency — 20 November 2026

## Metode
Inventaris source aktif, route registration, central router, imports/entry points/config dan tests; pencarian nama yang tidak direferensikan tidak dipakai sendirian sebagai alasan menyebut dead code. Tidak ada penghapusan file.

## Entry point / konfigurasi / shared
- Flutter bootstrap: `apps/lib/main.dart`, `app.dart`; router `app_router.dart`, `routes/app_routes.dart`; shared `core/network/api_client.dart`, `core/config/app_config.dart`, `core/services/session_service.dart`, root Provider wiring, models/services.
- Backend: `backend/server.js`, `src/app.js`, `src/config/*`, `src/routes/*`, `src/middleware/*`, Prisma schema/migrations, `.env.example`, scripts.
- Perubahan router/provider registration/API global/DB schema/migration bersifat cross-cutting. Hindari memecah ownership melintasi developers; pilih satu owner (idealnya tidak diubah oleh fitur, atau satu Developer 4 hanya untuk integrasi mini yang sudah dialokasikan).

## Dependency/coupling dan delegasi
| Modul | File area aktif yang ditelusuri | Ketergantungan/risiko | Owner tahap yang disarankan |
|---|---|---|---|
| Auth dan shared API | `apps/lib/features/auth/**`, auth providers/services, `core/network`, backend auth middleware/routes/controllers/services | Provider/API client/role payload lintas fitur; pusatkan perubahan kontrak | Tetapkan satu owner hanya pada tahap pembaruan; fitur lain pakai interface tetap |
| Event + ticket type | Flutter `features/organizer/events/**`, `features/events/**`; backend event/ticket-type routes/controllers | Event response/common routing/schema; auto-publish berkonflik legacy moderation | Pasangkan satu domain developer per tier; shared routes/DB owner tunggal |
| Checkout/orders/payment/tickets | Flutter `features/registration`, `orders`, `payments`, `tickets`; backend order/payment/ticket controllers/services/utils | Fee/auth/expiry/quantity; sangat tinggi dan menyentuh DB | Satu developer end-to-end pada tahap order, tanpa dev lain edit service/contract bersama |
| Staff/scan/check-in | Flutter `features/organizer/membership`, `staff`, `scanner`, `check_in`; backend invitations/event/checkin/ticket | Token + permissions + camera/routing; risiko safety | Satu domain owner; route/deep-link contracts ditetapkan lebih dulu |
| Admin/analytics | Flutter `features/admin`, `reports`, `notifications`; backend admin/revenue/plans/subscriptions/report/notification | Beberapa screen in-memory, report serialization | Satu domain owner per tier |

## File/referensi kandidat (bukan keputusan hapus)
- Prisma schema/migration vs `backend/supabase/migrations`: dual history/kepemilikan migrasi belum disahkan; jangan edit keduanya secara bersamaan tanpa rencana tertulis, backup/test DB, dan approval.
- Legacy `submit-review`/moderation endpoints/screens versus PRD auto-publish: bukan dead code; perilaku produk bertentangan, perlu migrasi bertahap.
- `syncCheckIns`/offline scanner code versus PRD offline Post-MVP: keberadaan endpoint belum membuktikan digunakan; jangan hapus saat audit.
- `backend/src/config/supabase.js` disebut kompatibilitas; cek importer lengkap sebelum ubah.
- Screen/route/provider yang tidak nampak pemanggil langsung mungkin digunakan melalui `AppRouter`, named routes, DI atau tests. Belum ada file yang dapat dinyatakan tidak relevan dengan bukti cukup.
- Generated folders (`apps/build`, platform folders) bukan ruang lingkup feature; jangan edit artifact build.

## Prinsip pembatasan file antar-dev
Per-task FILE_OWNERSHIP harus berupa path globs eksplisit, disjoint antar tiga developer. Shared/public files dimiliki tepat satu orang atau dikecualikan bagi semua feature developers. Buat kontrak/interface sebelum coding, jangan menambah “file lain jika perlu”. Ketika perlu perubahan file milik orang lain: buka laporan dependency, jangan mengedit; owner file atau Developer 4 memutuskan melalui PR terpisah.
