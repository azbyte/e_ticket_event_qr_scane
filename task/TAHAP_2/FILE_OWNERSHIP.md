# TAHAP 2 — FILE OWNERSHIP

Dokumen ini adalah ringkasan cepat. **Allow-list lengkap dan matriks koordinasi berada di [`INTEGRATION_CONTRACT.md`](INTEGRATION_CONTRACT.md) Bagian 2.** Bila terdapat perbedaan, `INTEGRATION_CONTRACT.md` yang berlaku.

## Prinsip

1. Satu file = satu owner per tahap.
2. File shared diberi owner tunggal; developer lain mengirim **permintaan tertulis** (spesifikasi route/query/field) dan pemiliknya yang mengedit.
3. Konflik tidak diselesaikan dengan merge manual paksa; selesaikan pada level kepemilikan.

## Ringkasan owner

| Area | Owner | Catatan |
|---|---|---|
| `apps/lib/app.dart`, `app_router.dart`, `routes/app_routes.dart` | **D1** | Semua route baru diajukan ke D1 |
| `backend/src/app.js` | **D3** | Mount route baru sesuai daftar endpoint di kontrak |
| Event domain (`eventController`, `eventRoutes`, `eventResponse`, `eventValidation`) | **D1** | Termasuk publish & `public_url` |
| Order/payment guest (`orderController`, `paymentController`, `emailService`) | **D1** | Termasuk dynamic fields |
| Ticketing & check-in (`ticketController`, `checkInController`, `ticketTokenService`, `ticketRoutes`, `checkInRoutes`) | **D2** | D3 meminta perubahan bagian attendee |
| Invitation/membership (`eventInvitationController`, `invitationsRoutes`) | **D2** | URL undangan dipakai D1 |
| Admin & platform (`adminController`, `planController`, `subscriptionController`, `revenueController`, `reportController`, `notificationController`, `eventMetricsController`, `utils/auditLog`) | **D3** | Termasuk audit & settings |
| Flutter services admin & organizer operations | **D3** | |
| Flutter services ticket/scanner/check-in/membership | **D2** | |
| Flutter services order/payment/event/public_event | **D1** | |
| `apps/pubspec.yaml` | **D2** | Dependency QR & kamera; permintaan lain diajukan ke D2 |
| `backend/prisma/**`, `backend/supabase/**`, `PRD.md`, `task/TAHAP_1/**`, `task/archive/**` | **—** | Tidak boleh diubah siapa pun pada Tahap 2 |

## Cek cepat konflik

Sebelum mulai task, jalankan:

```powershell
git --no-pager diff --name-only origin/main...HEAD
```

Pastikan setiap file yang muncul ada pada allow-list developer tersebut.

## Aturan eskalasi

| Situasi | Tindakan |
|---|---|
| Butuh perubahan file milik developer lain | Tulis spesifikasi di PR comment + laporan; tunggu owner; jangan edit sendiri |
| Butuh perubahan DB | Catat di `../DB_CHANGE_PROPOSAL.md`; jangan ubah schema/migration |
| Butuh dependency Flutter baru | Ajukan ke D2 (pemilik `pubspec.yaml`) dengan alasan & alternatif |
| Butuh endpoint baru lintas domain | Daftarkan di `INTEGRATION_CONTRACT.md` §1.3 lebih dulu |
