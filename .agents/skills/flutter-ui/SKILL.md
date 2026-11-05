---
name: flutter-ui
description: Mengembangkan atau meninjau antarmuka Flutter e-ticket, responsive layout, komponen reusable, state UI, dan aksesibilitas.
---

# Skill Flutter UI

Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, bagian UI dan role pada `prd.md`,
`apps/analysis_options.yaml`, `apps/lib/core/theme/app_theme.dart`, serta
halaman/komponen yang bersangkutan sebelum mengedit. Palette saat ini indigo
`#6366F1`, pink `#EC4899`, surface `#FAFAFA`; tema menggunakan Material 3.

1. Ikuti struktur fitur dan state Provider yang sudah ada; gunakan komponen
   reusable hanya bila mengurangi duplikasi nyata. Jangan menambah library UI.
2. Konsistenkan warna, tipografi, spacing, radius dan elevasi dengan tema aktual
   di `apps/lib/`; jangan membuat identitas visual baru atau mengganti aset.
3. Pastikan layout Android/web responsif, teks panjang tidak overflow, ukuran
   target sentuh memadai, kontras dan tooltip/semantik bermakna.
4. Pertahankan status loading, kosong, error, tanpa izin dan sukses yang relevan.
   Demo/mock bukan autentikasi atau bukti integrasi nyata.
5. Uji perilaku melalui `cd apps && flutter test`; `flutter analyze` dapat
   memiliki temuan info lama—catat keluaran dan hindari perbaikan massal tak terkait.
6. Laporkan file, status UI yang diverifikasi, hasil checks dan batas uji perangkat.
