---
name: workspace
description: Memelihara instruksi AI, skill, workflow, tools, dan dokumentasi developer di repository e-ticket tanpa mengubah aplikasi atau konfigurasi global.
---

# Skill Pemeliharaan Workspace

Baca `AGENTS.md`, katalog root `SKILL.md`, `CONTRIBUTING.md`, README, status Git
dan file konfigurasi yang terkait. Tujuan hasil adalah workflow yang benar-benar
dapat dipakai; bukan sekadar membuat banyak file.

## 1. Inventarisasi Perubahan
1. Inventarisasi perubahan tracked/untracked dan manifest; bedakan hasil generate,
   vendor, file awal yang untracked, dan file yang dibuat untuk tugas ini.
2. Cari tool yang sudah tersedia sebelum menambah dependency. Cek versi runtime,
   lockfile dan konfigurasi aktual.

## 2. Pembuatan Skill
1. Buat skill hanya untuk prosedur berulang yang berbeda; metadata `name` dan
   `description` harus punya trigger jelas.
2. Tambahkan routing di `AGENTS.md` dan `SKILL.md`, bukan berasumsi folder otomatis
   dimuat assistant.

## 3. Path dan Keamanan
1. Jaga path relatif/case benar, secret tidak masuk, workflow permissions minimum.
2. Jangan memasang konfigurasi IDE global. Jangan mengubah bisnis/API/schema.

## 4. Validasi Katalog
1. Dari root repository, validasi katalog dan skills via
   `npm --prefix backend run validate:skills`.
2. Jalankan pemeriksaan aplikasi terdampak, baca ulang link, tinjau diff dan
   dokumentasikan hal yang gagal/terhalang.
3. Validasi file tidak membuktikan assistant runtime memuatnya.