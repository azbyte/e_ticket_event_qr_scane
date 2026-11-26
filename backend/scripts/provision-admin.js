/**
 * Provision akun Admin dari environment variable (idempotent).
 *
 * Sumber mekanisme auth: tabel `profiles` + bcrypt + JWT (tanpa Supabase Auth).
 * Tidak ada password default di source code. Jalankan:
 *
 *   # isi ADMIN_EMAIL dan ADMIN_PASSWORD pada backend/.env (jangan commit)
 *   npm run admin:provision
 *
 * Perintah aman dijalankan berulang: bila akun Admin dengan email tersebut ada,
 * tidak ada baris baru yang dibuat. Password hanya diubah bila
 * ADMIN_RESET_PASSWORD=true. Skrip tidak menampilkan password/secret.
 */
const path = require('node:path');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const { ensureAdminAccountFromEnv } = require('../src/services/adminBootstrapService');
const { pool } = require('../src/config/db');

const main = async () => {
  const result = await ensureAdminAccountFromEnv(process.env);
  console.log(`Admin bootstrap status: ${result.status}`);
  console.log(`Detail: ${result.message}`);

  if (['INVALID_CONFIG', 'CONFLICT', 'PASSWORD_MISMATCH'].includes(result.status)) {
    process.exitCode = 1;
  }
};

main()
  .catch((error) => {
    console.error('Admin bootstrap failed:', error.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end().catch(() => {}));
