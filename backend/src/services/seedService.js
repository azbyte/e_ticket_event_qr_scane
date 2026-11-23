const { ensureAdminAccountFromEnv } = require('./adminBootstrapService');

/**
 * Bootstrap akun istimewa dari environment variable.
 *
 * Sebelumnya modul ini menyimpan password demo di source code
 * (akun admin/organizer dengan password tetap), yang bertentangan dengan aturan
 * keamanan proyek. Sekarang tidak ada password default: akun Admin hanya dibuat
 * bila `ADMIN_EMAIL` dan `ADMIN_PASSWORD` diisi pada environment lokal.
 * Akun Organizer tidak di-seed; Organizer dibuat melalui
 * `POST /api/auth/register` (role selalu organizer).
 *
 * Idempotent: dijalankan berulang kali tidak membuat akun duplikat dan tidak
 * mengubah password kecuali `ADMIN_RESET_PASSWORD=true` diminta eksplisit.
 */

const bootstrapConfiguredAccounts = async (env = process.env) => {
  if (!env.DATABASE_URL) {
    throw new Error('Account bootstrap requires DATABASE_URL');
  }
  return ensureAdminAccountFromEnv(env);
};

// Alias kompatibilitas untuk `server.js`/`npm start` yang memakai nama lama.
const seedDemoAccounts = bootstrapConfiguredAccounts;

module.exports = { bootstrapConfiguredAccounts, seedDemoAccounts };
