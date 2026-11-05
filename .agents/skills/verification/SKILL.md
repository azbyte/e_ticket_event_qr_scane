---
name: verification
description: Memilih dan menjalankan pemeriksaan Flutter/backend yang sesuai dengan dampak perubahan serta melaporkan bukti dan batasannya.
---

# Skill verification

1. Cocokkan perubahan dengan risiko dan pilih checks terkecil yang membuktikannya.
2. Frontend: `cd apps && flutter analyze && flutter test`. Widget tests bukan
   uji perangkat nyata, browser, kamera QR atau provider.
3. Backend: `cd backend && npm test && npm run check`. `node --check` membuktikan
   syntax saja; unit test helper tidak membuktikan integrasi Supabase/API.
4. Periksa format diff, secret, status Git dan dokumentasi terkait.
5. Catat perintah, hasil PASS/FAIL/BLOCKED/NOT RUN dan batasan. Jangan menyebut
   semua fitur/regresi lulus bila hanya menjalankan pemeriksaan sebagian.
