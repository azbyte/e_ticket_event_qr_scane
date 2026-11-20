# Audit struktur proyek — 20 November 2026

## Cakupan dan batas bukti
Audit membaca `PRD.md` v2.1, `README.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `backend/README.md`, source aktif Flutter/Express, route/controller/service, schema dan migration Prisma, tests serta konfigurasi. Status Git awal sudah memiliki perubahan terdahulu (lihat pembuka dokumen utama); perubahan itu bukan hasil audit. Tidak membuka nilai `.env` atau menjalankan DB/API/provider eksternal.

## Struktur dan entry points
- Flutter Android/Web: `apps/lib/main.dart` → `apps/lib/app.dart` → `apps/lib/app_router.dart`; route declarations `apps/lib/routes/app_routes.dart`; providers/services/models/core/shared widgets di `apps/lib/{providers,services,models,core}`. Fitur `admin`, `auth`, `check_in`, `events`, `home`, `notifications`, `orders`, `organizer`, `payments`, `registration`, `reports`, `scanner`, `staff`, `tickets`.
- Backend Node CommonJS/Express 4: `backend/server.js` → `backend/src/app.js`; router per domain di `backend/src/routes`, controllers, middleware, validators, services, models, config, utils. Persistence PostgreSQL langsung melalui `pg` (`backend/src/config/db.js`); Prisma schema/migrations juga ada dan dipakai source. JWT/role middleware di `backend/src/middleware`.
- Tests: `apps/test/`; `backend/test/`; integration harness destruktif memerlukan opt-in eksplisit dan target DB/API lokal khusus.
- Config/dependencies: `apps/pubspec.yaml` + lock; `backend/package.json` + lock, `.env.example`, CI `.github/workflows`, scripts dan hook.

## Auth, role, navigation
Backend routes enforce auth/role middleware; ownership/event permission enforcement must be checked in each controller/service, not inferred from Flutter. App has login/register/profile and role-based routing, but PRD prohibits Participant account/dashboard and requires Staff event-scoped invitation. Router has legacy staff aliases; deep-link invitation acceptance/redirect to event scanner is not evidenced by route inspection. `/api/auth` exposes register/login/me/update/logout; refresh token route not found. API/demo modes explicitly separate through `MOCK_MODE` (default false); project design forbids mock fallback on API failure.

## Data model, API, integrations
Prisma schema contains users/roles, events, ticket types, memberships/permissions/invitations, orders/items/attendees, payments, tickets/check-ins, plans/subscriptions/transactions, reports/notifications/audit/email data. Migration history in `backend/prisma/migrations` has 9 directories through `20261118000400_restore_payment_status_enum_cast`. `backend/supabase/migrations` is an additional legacy location: source-of-truth/deployment migration history requires reconciliation before database work. No live migration status verified.

Routes exist for auth, admin, organizer, events/ticket types, invitations, plans/subscriptions, revenue, tickets/check-ins, notifications, support reports, orders/payments. Existence does not prove client call, contract compliance, persistence, or access safety. Order/payment services have DB transaction/idempotency paths; QR/check-in docs note bearer ticket codes and `token_hash` unused—security hardening is a priority, not an assertion of exploit.

## Product areas and shared/high-coupling surface
- Event create/update/publish/ticket categories: backend event/ticket-type API; Flutter Organizer event screens and public event screens.
- Guest registration/order/payment/ticket: Flutter registration, orders, payment, ticket and event features; backend order/payment/ticket services and DB.
- Staff/invitations/permissions/scanner/check-in: Organizer membership screens, staff/scanner/check-in Flutter; backend invitations/event/check-in/ticket controllers.
- Admin plans/subscriptions/revenue/reports/accounts/moderation/audit/support: UI plus corresponding backend routes/services; several UI pathways still in-memory or API availability incomplete per README.
- Shared hotspots: `apps/lib/app_router.dart`, `apps/lib/app.dart`, `apps/lib/main.dart`, `apps/lib/routes/app_routes.dart`, provider registration, `backend/src/app.js`, central routes/config, Prisma schema/migrations, API serializers/global middleware. Assign each hotspot to one integrator/owner per stage; feature developers must not casually edit them.

## Static observations / risks
Target backend is Express + PostgreSQL + JWT, not Supabase SDK persistence as some legacy documents imply. Prisma and direct `pg` coexist; do not assume one migration system canonical until verified. Source has legacy moderation flow; PRD requires auto-publish and post-publication admin suspension only. PRD bans assisted/manual registration, Participant dashboard, multiple tickets/order, offline scanning MVP; schema/source contains assisted fields, quantity>1 and sync endpoint—compatibility gap to resolve against approved requirements, not silent DB rewrite. API integration is partial: README lists some implemented Organizer/Admin APIs; finance/plans/subscriptions, scanner/check-in, reports, notifications and other paths include in-memory state or missing endpoints.

File duplication/unused status is **not concluded**. Candidates for dependency tracing only: legacy compatibility modules/config, duplicate/legacy migration dirs, older Organizer screens, endpoints without confirmed Flutter caller, generated Flutter dirs. Trace routes/imports/dynamic config/tests/runtime before declaring unused; no deletion in these tasks absent a separate evidence-backed change.

## Keterbatasan
Static inspection does not verify live DB schema, deployed API, CORS/network reachability, SMTP delivery, browser/mobile runtime, visual quality, demo credentials, or end-to-end transaction. Detailed statuses and test runs are in linked audit reports and `../PEMBAGIAN_TUGAS_FINAL.md`.