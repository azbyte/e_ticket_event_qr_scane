# Tahap 3 — Developer 2: public guest purchase journey

> Conditional on Tahap 2 GO and signed contracts relevant to each behavior. Payment fee formula (C-01) and guest payment authorization (C-02) remain blocking for affected checkout steps. Dynamic form display also requires a frozen form payload contract from the baseline; if absent, block only that acceptance and request an interface owner. Screen states/flow independent of these dependencies may proceed only if task acceptance and API allow it. UI/API-client screen scope only; no backend/DB/schema edits.

## Tujuan/kondisi awal
Selesaikan guest journey Android/Web melalui API: public event → category → one-person form → order → payment simulation → status/ticket. Tidak ada Participant account/dashboard. Baca PRD §§6.1, 7–11, 13–16, contract/ownership, existing public APIs/client/screens/tests.

## Pekerjaan
1. Trace public event link/detail/category → registration form → order/payment/status/ticket.
2. Pakai hanya API existing; jangan mengarang endpoint/payload, mempercayai client price/status; ikuti C-01/C-02 final.
3. Implement loading/error/empty/unauthorized/expiry/retry/success. API failure tidak boleh fallback mock.
4. Uji narrow/wide, keyboard/focus/semantics, long text/error, public navigation and safe guest access.
5. Regression tests single order, API errors, order ownership, ticket view; no provider delivery claims.

## Ownership/dependensi
Hanya D2 paths di `FILE_OWNERSHIP.md`; D1/D3 paths, routes/global client/services/backend/schema/dependencies locked. Gunakan contract yang ada pada baseline; tidak menunggu branch D1. Jika dynamic form API/interface tidak ada, rekonstruksi kontraknya dari kode/PRD, buat adapter minimum pada path D2, catat kebutuhan interface pada laporan, dan jangan import kode branch lain.

## Kriteria/laporan
Guest menyelesaikan flow approved melalui existing API; one attendee/ticket; tanpa login/dashboard Participant; error state jelas; tests/analyze pass. Build/API/DB E2E dilaporkan terpisah dari mock tests; sertakan actual files, contract, output dan blocker.

