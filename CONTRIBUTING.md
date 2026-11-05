# Kontribusi

1. Buat branch untuk satu unit perubahan dan jelaskan tujuan serta cakupan.
2. Baca `AGENTS.md`, `docs/ARCHITECTURE.md`, PRD dan skill yang dirutekan lewat
   `SKILL.md` untuk jenis pekerjaan.
3. Jangan sertakan `.env`, secret, data pribadi, build output atau perubahan
   dependency yang tidak diperlukan. Jangan mengubah API/database/fitur bisnis
   dalam PR tooling.
4. Jalankan `npm run validate:skills` setelah mengubah instruksi/skill; jalankan
   pemeriksaan frontend/backend yang relevan menurut `README.md` dan
   laporkan perintah serta hasilnya. Untuk bug, sertakan langkah reproduksi dan
   regression test jika memungkinkan.
5. Tinjau diff, dokumentasi dan status Git sebelum membuat PR. PR menjelaskan
   risiko, pengujian, integrasi yang tidak diuji dan screenshot UI bila relevan.
