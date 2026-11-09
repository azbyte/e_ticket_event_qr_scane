---
name: workspace
description: Memelihara instruksi AI, skill, workflow, tools, dan dokumentasi developer di repository e-ticket tanpa mengubah aplikasi atau konfigurasi global.
---

# Skill pemeliharaan workspace

Baca `AGENTS.md`, katalog root `SKILL.md`, `CONTRIBUTING.md`, README, status Git
dan file konfigurasi yang terkait. Tujuan hasil adalah workflow yang benar-benar
dapat dipakai; bukan sekadar membuat banyak file.

1. Inventaris perubahan tracked/untracked dan manifest; bedakan hasil generate,
   vendor, file awal yang untracked, dan file yang dibuat untuk tugas ini.
2. Cari tool yang sudah tersedia sebelum menambah dependency. Cek versi runtime,
   lockfile dan konfigurasi aktual. Jangan menyalin stack atau branch policy
   proyek referensi.
3. Buat skill hanya untuk prosedur berulang yang berbeda; metadata `name` dan
   `description` harus punya trigger jelas. Tambahkan routing di `AGENTS.md` dan
   `SKILL.md`, bukan berasumsi folder otomatis dimuat assistant.
4. Jaga path relatif/case benar, secret tidak masuk, workflow permissions minimum,
   serta jangan memasang konfigurasi IDE global. Jangan mengubah bisnis/API/schema.
5. Validasi katalog dan skills via `npm run validate:skills`; jalankan pemeriksaan
   aplikasi terdampak, baca ulang link, tinjau diff dan dokumentasikan hal yang
   gagal/terhalang. Validasi file tidak membuktikan assistant runtime memuatnya.
