# Katalog skills proyek E-Ticket

Instruksi umum: [`AGENTS.md`](AGENTS.md). Skill ditulis sebagai panduan yang
dapat dibaca assistant; pemuatan otomatis bergantung pada IDE/assistant. Pilih
skill yang sesuai dengan tugas, baca file skill terkait, lalu verifikasi arahan
terhadap implementasi aktual dan [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Gunakan satu atau beberapa skill hanya jika tugas menyentuh cakupannya; tidak
perlu menjalankan semua skill untuk setiap perubahan.

| Skill | Kapan digunakan |
|---|---|
| [flutter-ui](.agents/skills/flutter-ui/SKILL.md) | UI Flutter; relevan bersama backend hanya jika perubahan juga menyentuh UI atau integrasi tampilannya |
| [backend-api](.agents/skills/backend-api/SKILL.md) | Endpoint Express, middleware, auth, role, validasi, dan persistence Supabase |
| [review](.agents/skills/review/SKILL.md) | Review diff Flutter maupun backend, termasuk kontrak, regresi, dan akses kontrol |
| [pr-quality-gate](.agents/skills/pr-quality-gate/SKILL.md) | Pemeriksaan kualitas backend/Flutter: mode targeted sesuai dampak atau gate lengkap sebelum PR |
| [debug](.agents/skills/debug/SKILL.md) | Reproduksi dan diagnosis bug backend Express/API maupun Flutter |
| [requirements](.agents/skills/requirements/SKILL.md) | Requirement, role, acceptance criteria, serta kontrak API/data backend maupun Flutter |
| [workspace](.agents/skills/workspace/SKILL.md) | Memelihara instruksi, skill, tooling, konfigurasi, dan dokumentasi developer |

## Alur pemilihan skill untuk backend

- Implementasi atau perubahan kontrak endpoint: `backend-api`; tambahkan
  `requirements` untuk perubahan perilaku, role, acceptance criteria, atau
  payload yang dikonsumsi klien.
- Bug atau error backend: `debug`; libatkan `backend-api` bila diagnosis
  menyentuh route, middleware, authorization, validasi, atau persistence.
- Pemeriksaan diff backend: `review`.
- Validasi perubahan backend: `pr-quality-gate`; pilih checks sesuai dampak,
  dan gunakan gate lengkap sebelum PR.
- Instruksi, workflow, konfigurasi, atau tooling backend: `workspace`.
- Jika backend dan UI Flutter berubah bersama, gunakan juga `flutter-ui` untuk
  memvalidasi tampilan dan state klien. Untuk backend saja, skill UI tidak perlu
  dijalankan.

Skill yang tercantum adalah panduan yang dipilih sesuai cakupan, bukan prosedur
yang harus seluruhnya dijalankan pada setiap tugas.

## Eksekusi tugas developer

Untuk perintah berbentuk “Kerjakan Developer N Tahap M”, “Lanjutkan tugas
Developer N”, atau “Perbaiki bug tahap sebelumnya”, ikuti *Autonomous Execution
Protocol* yang diringkas di [`AGENTS.md`](AGENTS.md): perintah pemilik proyek adalah
otorisasi implementasi, keputusan teknis diambil mandiri tanpa approval tambahan,
dan skill di atas dipilih sesuai cakupan pekerjaan. Mode read-only hanya bila
diminta eksplisit. Pengecualian: Developer 1 Tahap 1 berstatus FROZEN dan tidak
dikerjakan ulang.

Folder `task/` berstatus arsip historis dan tidak dibaca secara default; jangan
membuka file di dalamnya kecuali pemilik proyek menyebutnya eksplisit.
