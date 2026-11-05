# Katalog skills proyek E-Ticket

Instruksi umum: [`AGENTS.md`](AGENTS.md). Skill ditulis sebagai panduan yang
dapat dibaca assistant; pemuatan otomatis bergantung pada IDE/assistant. Pilih
skill yang sesuai tugas dan baca `docs/ARCHITECTURE.md`.

| Skill | Kapan digunakan |
|---|---|
| [flutter-ui](.agents/skills/flutter-ui/SKILL.md) | UI, tema, komponen dan accessibility |
| [backend-api](.agents/skills/backend-api/SKILL.md) | Express/API, auth, role, Supabase |
| [review](.agents/skills/review/SKILL.md) | Review perubahan dan risiko |
| [verification](.agents/skills/verification/SKILL.md) | Rencana dan eksekusi validasi |
| [debug](.agents/skills/debug/SKILL.md) | Reproduksi dan diagnosis bug |
| [requirements](.agents/skills/requirements/SKILL.md) | Klarifikasi requirement, role, dan perubahan kontrak |
| [workspace](.agents/skills/workspace/SKILL.md) | Memelihara instruksi, skill, tooling dan dokumentasi developer |

Padanan ke delapan skill referensi: `siagabanjir-backend` → `backend-api`;
`siagabanjir-debug` → `debug`; `siagabanjir-flutter` → `flutter-ui`;
`siagabanjir-requirements` → `requirements`; `siagabanjir-review` → `review`;
`siagabanjir-ui` → `flutter-ui`; `siagabanjir-verification` → `verification`;
`siagabanjir-workspace` → `workspace`. UI Flutter/UI digabung karena cakupannya
bertumpang tindih; protokol bersama dipisah dalam `AGENTS.md`.
