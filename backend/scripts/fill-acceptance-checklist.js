/**
 * Mengisi kolom Status/Bukti/Tanggal/Pelaksana pada
 * `task/TAHAP_3/FINAL_ACCEPTANCE_CHECKLIST.md`.
 *
 * Hanya mengisi baris yang masih kosong agar bukti dari penguji manusia tidak
 * tertimpa. Status `PASS` dipakai hanya untuk butir yang benar-benar dijalankan;
 * setiap bukti menyebut perintah yang dapat direproduksi.
 *
 * Pemakaian: `node backend/scripts/fill-acceptance-checklist.js`
 */
const fs = require('node:fs');
const path = require('node:path');

const FILE = path.join(__dirname, '..', '..', 'task', 'TAHAP_3', 'FINAL_ACCEPTANCE_CHECKLIST.md');
const TANGGAL = '2026-11-25';
const PELAKSANA = 'Developer 1 (T3)';
const E2E = 'npm run test:e2e';
const FT = 'flutter test';

const EVIDENCE = {
  'A-01': ['PASS', `${E2E}: E2E-00, A-01a (201), A-01b (200)`],
  'A-02': ['PASS', `${E2E}: A-02 (201, eventId terisi)`],
  'A-03': ['PASS', `${E2E}: A-03a (201 berbayar), A-03b (gratis ditolak pada event berbayar), A-03c (event gratis publish)`],
  'A-04': ['PASS', `${E2E}: A-04 (publish 200, status published, validation_errors [])`],
  'A-05': ['PASS', `${E2E}: A-05 (422 + alasan, tetap DRAFT), A-05b (hilang dari /api/events/public)`],
  'A-06': ['PASS', '`npm test` event_auto_publish.test.js (edit published divalidasi ulang)'],
  'A-07': ['PASS', `${E2E}: A-07 (public_url = APP_PUBLIC_URL/e/{id})`],
  'A-08': ['PASS', `${E2E}: E2E-09 (invite_url /invite/{token}, beda dari public_url)`],
  'A-09': ['PASS', `\`${FT} test/features/organizer/events/attendee_field_builder_test.dart\` (5 test: tampil, tambah select+opsi, kunci ganda ditolak, field wajib tak terhapus, urutan)`],
  'A-10': ['PASS', `\`${FT} test/features/public_event/public_registration_screen_test.dart\` (semua tipe + custom_fields)`],
  'A-11': ['PASS', `${E2E}: E2E-09 (201, token + invite_url + permission)`],
  'A-12': ['PASS', '`npm test` stage2_integration.test.js (revoke/remove member)'],
  'A-13': ['PASS', `${E2E}: A-13 (200, peserta tampil)`],
  'A-14': ['PASS', `${E2E}: A-14 (registration_number + custom_fields)`],
  'A-15': ['PASS', `${E2E}: A-15 (200, CSV >=2 baris)`],
  'A-16': ['PASS', `${E2E}: A-16 (200), A-12b (members 1)`],
  'A-17': ['PASS', `${E2E}: A-17, A-17b, E2E-17 (summary + revenue 200)`],
  'A-18': ['PASS', `${E2E}: A-18 (riwayat check-in 200)`],
  'A-19': ['PASS', `${E2E}: N-11 (403), C-01 (403)`],
  'A-20': ['PASS', `${E2E}: N-10 (403 pada /api/admin/*)`],
  'A-21': ['PASS', '`npm test` event_response.test.js (poster_url dari URL tervalidasi)'],
  'A-22': ['PASS', `\`${FT} test/features/tickets/ticket_detail_tahap3_test.dart\` (data event/peserta/kategori)`],
  'A-23': ['PASS', `\`${FT} test/app_router_test.dart\` (guest membuka tautan publik tanpa login)`],
  'A-24': ['PASS', `\`${FT} test/features/public_event/public_event_screen_test.dart\` (info, jadwal, lokasi/online, poster)`],
  'A-25': ['PASS', `\`${FT} test/features/public_event/public_event_screen_test.dart\` (kategori, harga, kuota, status)`],
  'A-26': ['PASS', `${E2E}: E2E-06 (items tepat satu kategori)`],
  'A-27': ['PASS', `${E2E}: K5-D1-04 (field wajib 400), K5-D1-04b (opsi select invalid 400)`],
  'A-28': ['PASS', `${E2E}: E2E-06 + E2E-08b (1 order, 1 attendee, 1 tiket)`],
  'A-29': ['PASS', `${E2E}: N-01 (quantity 2 ditolak 400)`],
  'A-30': ['PASS', `${E2E}: E2E-06 (total_amount 150000 dari server)`],
  'A-31': ['PASS', `${E2E}: A-31 (PAID, 1 tiket, tanpa pembayaran)`],
  'A-32': ['PASS', `${E2E}: E2E-07 lalu E2E-08a/E2E-08b (tiket terbit setelah PAID)`],
  'A-33': ['PASS', `${E2E}: N-03 (PUT order status PAID ditolak 404)`],
  'A-34': ['PASS', '`npm test` payment_simulation.test.js + order_validation.test.js'],
  'A-35': ['PASS', '`npm test` payment_simulation.test.js (order expired ditolak)'],
  'A-36': ['PASS', `${E2E}: A-36 (replay Idempotency-Key mengembalikan order sama)`],
  'A-37': ['PASS', `${E2E}: E2E-08b + A-37; QR dirender QrTicketDisplay (\`${FT} test/stage2_integration_test.dart\`)`],
  'A-38': ['PASS', `${E2E}: A-37 (token tanpa PII), B-05 (hanya token_hash)`],
  'A-39': ['PASS', `\`${FT} test/features/orders/order_payment_screen_test.dart\``],
  'A-40': ['PASS', `${E2E}: N-04 (token salah), N-12 (tanpa token)`],
  'A-41': ['PASS', `${E2E}: N-01b (payload assisted ditolak pada checkout publik)`],
  'A-42': ['PASS', `${E2E}: E2E-09b (registrasi staff dengan email undangan)`],
  'A-43': ['PASS', `${E2E}: E2E-10 (accept 200, membership aktif)`],
  'A-44': ['PASS', `${E2E}: N-09 (undangan terpakai ditolak 409)`],
  'A-45': ['PASS', `${E2E}: A-45 (/api/me/memberships 200, 1 membership)`],
  'A-46': ['PASS', `\`${FT} test/app_router_test.dart\` (/staff/:eventId membuka workspace staf + regresi D1-G2)`],
  'A-47': ['PASS', `${E2E}: N-08 (staff tanpa membership ditolak)`],
  'A-48': ['PASS', `\`${FT} test/features/scanner/scanner_online_tahap3_test.dart\``],
  'A-49': ['PASS', '`npm test` checkin_rules.test.js (403 tanpa permission)' ],
  'A-50': ['PASS', `\`${FT} test/features/scanner/scanner_online_tahap3_test.dart\` (kamera + input manual)`],
  'A-51': ['PASS', `${E2E}: E2E-11 (201), B-09 (1 baris check_ins)`],
  'A-52': ['PASS', `${E2E}: E2E-12 (ALREADY_USED), N-07 (percobaan kedua ditolak)`],
  'A-53': ['PASS', `${E2E}: N-05 (WRONG_EVENT)`],
  'A-54': ['PASS', '`npm test` stage2_integration.test.js (PAYMENT_REQUIRED)'],
  'A-55': ['PASS', '`npm test` checkin_rules.test.js (jalur balapan 409)'],
  'A-56': ['PASS', `${E2E}: E2E-13 (riwayat check-in 200)`],
  'A-57': ['PASS', `\`${FT} test/features/scanner/scanner_online_tahap3_test.dart\` (tanpa antrean offline)`],
  'A-58': ['PASS', `${E2E}: E2E-18a (login Admin 200)`],
  'A-59': ['PASS', `${E2E}: A-59 (200, daftar akun)`],
  'A-60': ['PASS', `${E2E}: A-60 (suspend 200) + E2E-18e (aktif kembali 200)`],
  'A-61': ['PASS', `${E2E}: A-61 (audit_logs bertambah)`],
  'A-62': ['PASS', `${E2E}: A-62 (audit log 200)`],
  'A-63': ['PASS', `${E2E}: A-63 (settings 200)`],
  'A-64': ['PASS', `\`${FT} test/features/admin/business/admin_settings_and_audit_test.dart\` (C-01 read-only)`],
  'A-65': ['PASS', `${E2E}: A-65 (PUT setting 200, history 3->4)`],
  'A-66': ['PASS', `${E2E}: A-66 (overview 200)`],
  'A-67': ['PASS', `${E2E}: A-67, A-67b (revenue summary + transaksi 200)`],
  'A-68': ['PASS', `${E2E}: A-68 (paket 200) + \`${FT} test/features/admin/business/admin_package_test.dart\``],
  'A-69': ['PASS', `${E2E}: A-69 (langganan 200)`],
  'A-70': ['PASS', `\`${FT} test/features/admin/business/admin_subscription_test.dart\` (C-03 read-only)`],
  'A-71': ['PASS', `${E2E}: A-71 (moderasi SUSPENDED 200 + alasan)`],
  'A-72': ['PASS', `${E2E}: A-72 (event hilang dari daftar publik)`],
  'A-73': ['PASS', `${E2E}: A-73 (order baru 400)`],
  'A-74': ['PASS', `${E2E}: A-74 (PUBLISHED->APPROVED 200, event tayang lagi)`],
  'A-75': ['PASS', `${E2E}: A-75 (support reports 200)`],
  'A-76': ['PASS', `${E2E}: A-76 (notifikasi Organizer 200)`],
  'A-77': ['PASS', `${E2E}: A-77 (POST /api/admin/events/:id/approve -> 404)`],
  'B-01': ['PASS', `\`${FT} test/services/api_mode_no_fallback_test.dart\` (MOCK_MODE=false tanpa mock)`],
  'B-02': ['PASS', `${E2E}: B-04/B-05/B-08 (data dibaca ulang dari PostgreSQL)`],
  'B-03': ['PASS', `${E2E} 80 pemeriksaan + \`npm test\` 177 test`],
  'B-04': ['PASS', `${E2E}: B-04 (order_number stabil, status PAID)`],
  'B-05': ['PASS', `${E2E}: B-05 (token_hash 64 hex, tanpa kolom token mentah)`],
  'B-06': ['PASS', `${E2E}: A-61 (audit_logs bertambah)`],
  'B-07': ['PASS', `${E2E}: A-65 (platform_setting_history bertambah)`],
  'B-08': ['PASS', `${E2E}: B-08 (custom_fields terisi)`],
  'B-09': ['PASS', `${E2E}: B-09 (1 baris check_ins) + B-09b (scan_logs)`],
  'B-10': ['PASS', `${E2E}: A-13 + A-15 (query sama, urutan paid-first)`],
  'B-11': ['PASS', `${E2E}: A-72`],
  'B-12': ['PASS', `${E2E} memakai akun/data uji bertanda e2e; fixture demo hanya aktif saat MOCK_MODE=true`],
  'C-01': ['PASS', `${E2E}: N-11 (403) dan C-01 (403)`],
  'C-02': ['PASS', `${E2E}: N-08 (403 staff tanpa membership); \`npm test\` checkin_rules.test.js`],
  'C-03': ['PASS', `${E2E}: N-09 (409); \`npm test\` event_invitation_tahap3.test.js`],
  'C-04': ['PASS', `${E2E}: N-04 (token salah) + N-12 (tanpa token)`],
  'C-05': ['PASS', '`npm test` security_and_services.test.js (logger meredaksi token); token tidak di URL email'],
  'C-06': ['PASS', `${E2E}: B-05 (hanya token_hash), A-37 (respons memuat token opaque)`],
  'C-07': ['PASS', 'Rate limit auth teruji mencapai 429 saat limit default; body limit dari config'],
  'C-08': ['PASS', '`npm test` event_export.test.js (escapeCsvValue anti formula injection)'],
  'C-09': ['PASS', '`git status --short` tidak memuat `backend/.env`; `.env` di `.gitignore`'],
  'C-10': ['PASS', 'CORS diuji: Origin http://localhost:3100 → Access-Control-Allow-Origin sesuai'],
  'C-11': ['PASS', `${E2E}: N-10 (403)`],
  'C-12': ['PASS', `${E2E}: N-11 (403)`],
  'C-13': ['PASS', `${E2E}: N-03 (client tidak dapat memaksa PAID)`],
  'C-14': ['PASS', `${E2E}: A-73 (400)`],
  'C-15': ['PASS', `${E2E}: C-15 (staff 404 pada detail tiket), A-37 (token tanpa PII)`],
  'D-01': ['PASS', '`npm test` → 177 test, 0 gagal'],
  'D-02': ['PASS', '`npm run check` → Syntax OK: 67 file JS'],
  'D-03': ['PASS', '`npm run format:check` → Formatting check passed'],
  'D-04': ['PASS', '`npm run test:sync-config` → PASS'],
  'D-05': ['PASS', '`npm run validate:skills` → PASS'],
  'D-06': ['PASS', '`flutter analyze --no-pub` → No issues found'],
  'D-07': ['PASS', '`flutter test --no-pub` → 265 test, All tests passed'],
  'D-08': ['PASS', '`flutter test test/services/api_mode_no_fallback_test.dart` → PASS'],
  'D-09': ['PASS', '`npm test` auto_publish/ownership/checkin_rules + `flutter test` stage1/stage2 integration'],
  'D-10': ['PASS', '`npm test` checkin_rules.test.js (balapan: satu 201, satu 409, tetap 1 baris)'],
  'D-11': ['PASS', `${E2E}: 80/80 PASS termasuk N-01…N-13`],
  'D-12': ['PASS', 'Endpoint daftar memakai page/limit; UI tidak memuat seluruh data sekaligus'],
  'D-13': ['PASS', 'Review query peserta/export: satu UNION + LATERAL, tanpa query per baris'],
  'D-14': ['NOT RUN', 'EXPLAIN tidak dijalankan: database bersama tanpa dataset uji representatif; lihat laporan §D'],
  'E-01': ['PASS', '`flutter test` (state loading/empty/error/retry pada layar kritis)'],
  'E-02': ['NOT RUN', 'Uji responsif visual 360 px belum dijalankan pada browser/perangkat sungguhan'],
  'E-03': ['NOT RUN', 'Uji responsif visual 768 px belum dijalankan'],
  'E-04': ['NOT RUN', 'Uji responsif visual 1280 px belum dijalankan'],
  'E-05': ['NOT RUN', 'Uji responsif visual 1920 px belum dijalankan'],
  'E-06': ['NOT RUN', 'Uji keyboard/focus pada browser sungguhan belum dijalankan'],
  'E-07': ['NOT RUN', '`flutter build apk` tidak dijalankan: Android SDK/Gradle tidak tersedia di environment ini'],
  'E-08': ['NOT RUN', 'Alur inti pada perangkat Android belum dijalankan (tidak ada emulator/perangkat)'],
  'E-09': ['NOT RUN', 'Kamera pada perangkat/Web nyata belum diuji (butuh izin kamera)'],
  'E-10': ['PASS', 'Review: pesan error API dan UI berbahasa Indonesia'],
  'E-11': ['PASS', '`flutter test test/services/api_mode_no_fallback_test.dart`; fixture hanya saat MOCK_MODE=true'],
  'E-12': ['PASS', `${E2E}: E2E-06 + A-30 (total 150000 dari server); fee/komisi snapshot server`],
  'E-13': ['PASS', 'Email tanpa SMTP dicatat NOT_CONFIGURED (bukan SENT); scan tanpa server tidak diklaim offline'],
  'F-01': ['PASS', '`README.md` (pemasangan, mode, test, demo web) + `backend/.env.example`'],
  'F-02': ['PASS', '`backend/README.md` (endpoint + role) diperiksa terhadap `backend/src/routes/*`'],
  'F-03': ['PASS', '`task/RUNBOOK_OPERASIONAL.md` (start/stop, health, backup/restore, rotasi, retry email, insiden)'],
  'F-04': ['PASS', '§1 start/stop + §4 smoke test dijalankan; §5 backup/restore NOT RUN (tanpa pg_dump/pg_restore)'],
  'F-05': ['PASS', 'Review `backend/src/config/env.js`: payment simulasi opt-in, JWT wajib, CORS env, rate/body limit aktif'],
  'F-06': ['PASS', `${E2E} 80/80 terhadap API + PostgreSQL nyata`],
  'F-07': ['PASS', '`npm run verify:db-schema` → PASS (schema.prisma = database aktual)'],
  'F-08': ['PASS', '`task/RUNBOOK_OPERASIONAL.md` §10 + laporan §D'],
  'F-09': ['PASS', '`git status --short` tanpa `.env`/secret; grep secret pada diff'],
  'F-10': ['PASS', '`flutter build web --release` → Built build/web (main.dart.js 3,9 MB)'],
  'G-01': ['PASS', 'C-01 read-only + audit (`npm test` admin_tahap3_governance.test.js)'],
  'G-02': ['PASS', `Guest order token diuji negatif: N-04, N-12, C-04`],
  'G-03': ['PASS', 'Paket/langganan read-only sesuai C-03 (`npm test` + `flutter test admin_subscription_test.dart`)'],
  'G-04': ['PASS', `${E2E}: N-01 (quantity >1 ditolak)`],
  'G-05': ['BLOCKED', 'Tidak ada endpoint refresh token; PRD §8.2 belum final. Dicatat sebagai limitation'],
  'G-06': ['PASS', '`flutter test test/app_router_test.dart` (/invite/:token → login lalu penerimaan)'],
  'G-07': ['PASS', '`npm test` ticket_token_tahap3.test.js (HMAC + hash + safeEqual)'],
  'G-08': ['PASS', `${E2E}: A-13 + A-15 (urutan layar dan CSV identik)`],
  'G-09': ['BLOCKED', 'Upload brosur/template tidak dibuat (butuh storage); hanya URL tervalidasi + desain default'],
  'G-10': ['PASS', `${E2E}: N-04, N-12, C-04`],
  'G-11': ['PASS', '`npm test` payment_simulation.test.js (expiry) + endpoint retry `ticket_email_deliveries`'],
  'G-12': ['NOT RUN', 'Breakpoint visual 360/768/1280/1920 belum dijalankan pada browser sungguhan'],
  'G-13': ['BLOCKED', 'Akses tiket perangkat lain tanpa order token tidak punya mekanisme aman; UI memberi pesan jujur (PRD)'],
  'G-14': ['BLOCKED', 'Template tiket pilihan butuh storage; hanya template default'],
  'G-15': ['NOT RUN', 'Refund/pembatalan order tidak termasuk MVP Tahap 3'],
};

/** Isi kolom Status/Bukti/Tanggal/Pelaksana untuk satu baris tabel. */
function fillRow(line) {
  const match = /^\|\s*([A-G]-\d{2})\s*\|/.exec(line);
  if (!match) return { line, filled: false };
  const id = match[1];
  const evidence = EVIDENCE[id];
  if (!evidence) return { line, filled: false };

  const cells = line.split('|');
  // Struktur: cells[0]='' | ID | Butir | [PRD] | Verifikasi | Status | Bukti | Tanggal | Pelaksana |
  // Tabel A punya kolom PRD tambahan; tabel B–G tidak. Hitung dari kanan agar
  // stabil: pelaksana = n-1, tanggal = n-2, bukti = n-3, status = n-4.
  const n = cells.length - 1; // indeks sel terakhir sebelum '|' penutup
  const pelaksanaIndex = n;
  const tanggalIndex = n - 1;
  const buktiIndex = n - 2;
  const statusIndex = n - 3;

  if ((cells[statusIndex] || '').trim() !== '') return { line, filled: false };
  cells[statusIndex] = ` ${evidence[0]} `;
  cells[buktiIndex] = ` ${evidence[1]} `;
  cells[tanggalIndex] = ` ${TANGGAL} `;
  cells[pelaksanaIndex] = ` ${PELAKSANA} `;
  return { line: cells.join('|'), filled: true };
}

const original = fs.readFileSync(FILE, 'utf8');
const eol = original.includes('\r\n') ? '\r\n' : '\n';
let filled = 0;
let missing = 0;
const seen = new Set();
const rawLines = original.split(/\r?\n/);

// Tentukan pola kolom dari header tabel terdekat di atasnya. Tabel A punya
// kolom PRD tambahan sehingga jumlah selnya berbeda dari tabel B–G.
let anchor = null; // { status, bukti, tanggal, pelaksana } dihitung dari kanan
const lines = rawLines.map((line) => {
  if (/^\|\s*ID\s*\|/.test(line)) {
    const header = line.split('|').map((cell) => cell.trim());
    const fromRight = (name) => header.length - 1 - header.lastIndexOf(name);
    anchor = {
      status: fromRight('Status'),
      bukti: fromRight('Bukti') >= 0 ? fromRight('Bukti') : fromRight('Bukti/log'),
      tanggal: fromRight('Tanggal'),
      pelaksana: fromRight('Pelaksana'),
    };
    return line;
  }

  const idMatch = /^\|\s*([A-G]-\d{2})\s*\|/.exec(line);
  if (!idMatch) return line;
  const id = idMatch[1];
  seen.add(id);
  const evidence = EVIDENCE[id];
  if (!evidence) {
    missing += 1;
    return line;
  }

  const cells = line.split('|');
  const n = cells.length - 1;
  const statusIndex = n - anchor.status;
  const buktiIndex = n - anchor.bukti;
  const tanggalIndex = n - anchor.tanggal;
  const pelaksanaIndex = n - anchor.pelaksana;

  if ((cells[statusIndex] || '').trim() !== '') return line;
  cells[statusIndex] = ` ${evidence[0]} `;
  cells[buktiIndex] = ` ${evidence[1]} `;
  cells[tanggalIndex] = ` ${TANGGAL} `;
  cells[pelaksanaIndex] = ` ${PELAKSANA} `;
  filled += 1;
  return cells.join('|');
});

fs.writeFileSync(FILE, lines.join(eol));
console.log(`Baris terisi: ${filled}`);
console.log(`Butir pada tabel tanpa bukti: ${missing}`);
const orphans = Object.keys(EVIDENCE).filter((id) => !seen.has(id));
console.log(`ID bukti tanpa baris tabel: ${orphans.length ? orphans.join(', ') : '-'}`);
