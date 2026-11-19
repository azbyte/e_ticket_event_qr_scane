---
name: workspace
description: Audit atau ubah instruksi AI, Skill, workflow, konfigurasi dan dokumentasi developer repository tanpa mengubah aplikasi atau konfigurasi global.
---

# Workspace Maintenance

Gunakan untuk tooling/instruksi/dokumentasi workflow. Baca `AGENTS.md`, katalog `SKILL.md`, status Git, serta README/CONTRIBUTING/config yang relevan. Inventarisasi diff tracked/untracked terlebih dahulu; jangan menimpa atau mengatribusikan perubahan awal. Tujuannya workflow yang dapat dijalankan, bukan menambah file tanpa kebutuhan.

- Ikuti tool, runtime, lockfile dan pola yang tersedia; jangan tambah dependency/config IDE global tanpa alasan.
- Skill baru hanya untuk prosedur berulang yang berbeda. Beri metadata `name`/`description` dengan trigger jelas dan tambahkan routing katalog/instruksi; jangan mengasumsikan folder otomatis dimuat runtime.
- Jaga path/link relatif, secret, least privilege dan batas perubahan. Jangan ubah business logic/API/database sebagai efek samping tooling.
- Setelah mengubah Skill/katalog, jalankan `npm --prefix backend run validate:skills`; jalankan checks lain sesuai file terdampak, baca ulang link dan tinjau diff.
- Laporkan PASS/FAIL/BLOCKED/NOT RUN. Validasi file tidak membuktikan runtime assistant memuatnya.