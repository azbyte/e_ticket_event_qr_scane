---
name: debug
description: Reproduksi dan diagnosis bug Flutter, Express/API, auth, Supabase atau QR/check-in; gunakan untuk gejala/error, bukan implementasi fitur biasa.
---

# Debugging

1. Catat gejala dan reproduksi minimum dengan data sintetis; pisahkan fakta teramati dari hipotesis.
2. Telusuri alur aktual dari input → state/request → service/backend → response/error. Periksa log/konfigurasi tanpa menampilkan secret, token atau PII.
3. Temukan akar sebab sebelum mengubah kode. Terapkan perbaikan terkecil dan tambahkan regression test yang mengunci perilaku bila memungkinkan.
4. Jalankan checks relevan, lalu laporkan sebab terbukti, perubahan, perintah/hasil, risiko tersisa dan batas integrasi/perangkat. Jangan mengklaim provider/DB/produksi teruji tanpa environment uji.

## Pilih pemeriksaan menurut gejala
- Backend JS: `node --check <file>` untuk satu file; `npm run check` untuk syntax source; `npm test` untuk behavior. `npm run format:check` bila format/JSON terdampak.
- Sinkronisasi workflow/config: tambahkan `npm run test:sync-config`.
- Flutter: `flutter analyze` dan test yang relevan; untuk regresi luas jalankan `flutter test`. Jalankan keduanya bila perubahan backend memengaruhi klien.
- Supabase/provider hanya diuji dengan environment uji yang tersedia; jangan mutasi data produksi.

Tambahkan `backend-api` bila solusi menyentuh endpoint, authorization, validasi atau persistence; `flutter-ui` bila tampilan/state UI ikut berubah; `requirements` bila perilaku/kontrak ambigu. Tidak perlu memanggil semua Skill.