---
name: flutter-ui
description: Mengembangkan atau meninjau antarmuka Flutter e-ticket, responsive layout, komponen reusable, state UI, dan aksesibilitas.
---

# Skill Flutter UI

Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, bagian UI dan role pada `prd.md`,
`apps/analysis_options.yaml`, `apps/lib/core/theme/app_theme.dart`, serta
halaman/komponen yang bersangkutan sebelum mengedit.

## 1. Struktur dan Komponen
1. Ikuti struktur fitur dan state Provider yang sudah ada.
2. Gunakan komponen reusable hanya bila mengurangi duplikasi nyata.
3. Jangan menambah library UI baru tanpa evaluasi rinci.

## 2. Desain Visual dan Tema
1. Konsistenkan warna, tipografi, spacing, radius dan elevasi dengan tema aktual
   di `apps/lib/`; jangan membuat identitas visual baru atau mengganti aset.
2. Gunakan palette indigo `#6366F1`, pink `#EC4899`, surface `#FAFAFA`.
3. Tema menggunakan Material 3.

## 3. Layout dan Aksesibilitas
1. Pastikan layout Android/web responsif, teks panjang tidak overflow.
2. Ukuran target sentuh memadai, kontras dan tooltip/semantik bermakna.

## 4. Status UI
1. Pertahankan status loading, kosong, error, tanpa izin dan sukses yang relevan.
2. Demo/mock bukan autentikasi atau bukti integrasi nyata.

## 5. Perintah Validasi
Di direktori `apps/`, jalankan `flutter test`; `flutter analyze` dapat
menemukan temuan info lama—catat keluaran dan hindari perbaikan massal tak terkait.
Laporkan file, status UI yang diverifikasi, hasil checks dan batas uji perangkat.