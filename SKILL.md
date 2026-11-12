# Katalog skills proyek E-Ticket

Instruksi umum: [`AGENTS.md`](AGENTS.md). Skill ditulis sebagai panduan yang
dapat dibaca assistant; pemuatan otomatis bergantung pada IDE/assistant. Pilih
skill yang sesuai dengan tugas, baca file skill terkait, lalu verifikasi arahan
terhadap implementasi aktual dan [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Gunakan satu atau beberapa skill hanya jika tugas menyentuh cakupannya; tidak
perlu menjalankan semua skill untuk setiap perubahan.

| Skill | Kapan digunakan |
|---|---|
| [flutter-ui](.agents/skills/flutter-ui/SKILL.md) | UI, tema, komponen dan accessibility |
| [backend-api](.agents/skills/backend-api/SKILL.md) | Express/API, auth, role, Supabase |
| [review](.agents/skills/review/SKILL.md) | Review perubahan dan risiko |
| [pr-quality-gate](.agents/skills/pr-quality-gate/SKILL.md) | Pemeriksaan kualitas lokal sebelum Pull Request (termasuk mode targeted berdasarkan dampak perubahan, sebelumnya skill `verification`), sinkron dengan CI/CD |
| [debug](.agents/skills/debug/SKILL.md) | Reproduksi dan diagnosis bug |
| [requirements](.agents/skills/requirements/SKILL.md) | Klarifikasi requirement, role, dan perubahan kontrak |
| [workspace](.agents/skills/workspace/SKILL.md) | Memelihara instruksi, skill, tooling dan dokumentasi developer |
