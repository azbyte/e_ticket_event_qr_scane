const bcrypt = require('bcryptjs');
const { query, getOne } = require('../config/db');
const { USER_ROLES } = require('../utils/constants');
const { validateEmail, validatePassword } = require('../utils/validators');

/**
 * Bootstrap akun Admin dari environment variable.
 *
 * Mekanisme authentication proyek ini adalah tabel `profiles` + bcrypt + JWT
 * (lihat `authController`/`authService`); tidak ada Supabase Auth. Karena itu
 * akun Admin dibuat langsung sebagai record `profiles` dengan `role = 'admin'`
 * dan password ter-hash, memakai mekanisme yang sama dengan login aplikasi.
 *
 * Prinsip yang dijaga:
 * - tidak ada password default/plaintext di source code;
 * - idempotent: tidak pernah membuat baris Admin duplikat;
 * - tidak menaikkan role akun yang sudah ada secara diam-diam (menghindari
 *   eskalasi hak akses hanya karena email cocok dengan ADMIN_EMAIL);
 * - password hanya di-hash dan tidak pernah dicatat ke log.
 */

const MIN_ADMIN_PASSWORD_LENGTH = 8;
const DEFAULT_ADMIN_NAME = 'Administrator Platform';

const readAdminConfig = (env = process.env) => ({
  email: String(env.ADMIN_EMAIL || '').trim().toLowerCase(),
  password: String(env.ADMIN_PASSWORD || ''),
  name: String(env.ADMIN_NAME || DEFAULT_ADMIN_NAME).trim() || DEFAULT_ADMIN_NAME,
  username: String(env.ADMIN_USERNAME || '').trim(),
  rotatePassword: String(env.ADMIN_RESET_PASSWORD || '').trim().toLowerCase() === 'true',
});

const isAdminConfigComplete = (config) => Boolean(config.email && config.password);

const validateAdminConfig = (config) => {
  const problems = [];
  if (!validateEmail(config.email)) problems.push('ADMIN_EMAIL must be a valid email address');
  if (!validatePassword(config.password) || config.password.length < MIN_ADMIN_PASSWORD_LENGTH) {
    problems.push(`ADMIN_PASSWORD must be at least ${MIN_ADMIN_PASSWORD_LENGTH} characters`);
  }
  if (config.username && config.username.length > 64) problems.push('ADMIN_USERNAME must be at most 64 characters');
  if (config.name.length > 120) problems.push('ADMIN_NAME must be at most 120 characters');
  return problems;
};

const defaultHashPassword = (password) => bcrypt.hash(password, 12);
const defaultComparePassword = (password, passwordHash) => bcrypt.compare(password, passwordHash);

const createAdminBootstrapService = ({
  query: runQuery = query,
  getOne: getFirst = getOne,
  hashPassword = defaultHashPassword,
  comparePassword = defaultComparePassword,
} = {}) => {
  const resolveUsername = async (baseUsername, existingId) => {
    const base = String(baseUsername || 'admin').trim().toLowerCase() || 'admin';
    const taken = await runQuery('SELECT id FROM profiles WHERE username = $1', [base]);
    const takenByOther = taken.some((row) => row.id !== existingId);
    return takenByOther ? `${base}_${Date.now().toString(36)}` : base;
  };

  /**
   * Bandingkan password konfigurasi dengan hash tersimpan.
   * Mengembalikan `null` bila hash tidak tersedia/ tidak dapat dibandingkan,
   * sehingga ketidakcocokan tidak pernah diklaim tanpa bukti.
   */
  const passwordMatchesStoredHash = async (row, password) => {
    if (!row || !row.password_hash) return null;
    try {
      return Boolean(await comparePassword(password, row.password_hash));
    } catch {
      return null;
    }
  };

  /**
   * Pastikan satu akun Admin ada. Tidak pernah membuat duplikat.
   * @param {{email:string,password:string,name?:string,username?:string,rotatePassword?:boolean}} config
   * @returns {Promise<{status:string, message:string, userId?:string, email?:string}>}
   */
  const ensureAdminAccount = async (config) => {
    const problems = validateAdminConfig(config);
    if (problems.length > 0) {
      return { status: 'INVALID_CONFIG', message: problems.join('; ') };
    }

    const existing = await getFirst(
      'SELECT id, role, disabled_at, password_hash FROM profiles WHERE email = $1',
      [config.email]
    );

    if (existing) {
      if (existing.role !== USER_ROLES.ADMIN) {
        return {
          status: 'CONFLICT',
          email: config.email,
          userId: existing.id,
          message:
            'ADMIN_EMAIL already belongs to a non-admin account; refusing to change its role automatically. ' +
            'Use a dedicated admin email or promote the account through a reviewed database change.',
        };
      }

      if (!config.rotatePassword) {
        // Akun sudah ada dan password tidak boleh diubah otomatis. Namun bila
        // hash tersimpan tidak cocok dengan ADMIN_PASSWORD, login dengan
        // kredensial yang terdokumentasi akan selalu 401 "Invalid credentials".
        // Kondisi ini dilaporkan eksplisit (tanpa mengubah data) agar penyebabnya
        // tidak tersamar sebagai "UNCHANGED".
        const passwordMatches = await passwordMatchesStoredHash(existing, config.password);
        if (passwordMatches === false) {
          return {
            status: 'PASSWORD_MISMATCH',
            email: config.email,
            userId: existing.id,
            message:
              'Admin account exists but its stored password does not match ADMIN_PASSWORD; ' +
              'login with the configured credentials will fail with 401. ' +
              'Set ADMIN_RESET_PASSWORD=true and run `npm run admin:provision` to rotate it, ' +
              'or sign in with the password that was used when the account was created.',
          };
        }
        return {
          status: 'UNCHANGED',
          email: config.email,
          userId: existing.id,
          message: 'Admin account already exists; no duplicate created.',
        };
      }

      const passwordHash = await hashPassword(config.password);
      await runQuery(
        'UPDATE profiles SET password_hash = $1 WHERE id = $2 AND role = $3',
        [passwordHash, existing.id, USER_ROLES.ADMIN]
      );
      return {
        status: 'PASSWORD_ROTATED',
        email: config.email,
        userId: existing.id,
        message: 'Existing admin password rotated from ADMIN_PASSWORD (ADMIN_RESET_PASSWORD=true).',
      };
    }

    const username = await resolveUsername(config.username || config.email.split('@')[0]);
    const passwordHash = await hashPassword(config.password);
    const created = await getFirst(
      `INSERT INTO profiles (id, name, email, username, password_hash, role, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())
       RETURNING id, email, role`,
      [config.name, config.email, username, passwordHash, USER_ROLES.ADMIN]
    );

    return {
      status: 'CREATED',
      email: created.email,
      userId: created.id,
      message: 'Admin account created in profiles with bcrypt password hash.',
    };
  };

  /**
   * Jalankan bootstrap dari environment. SKIPPED bila pasangan
   * ADMIN_EMAIL/ADMIN_PASSWORD belum dikonfigurasi (bukan error).
   */
  const ensureAdminAccountFromEnv = async (env = process.env) => {
    const config = readAdminConfig(env);
    if (!isAdminConfigComplete(config)) {
      return {
        status: 'SKIPPED',
        message:
          'ADMIN_EMAIL/ADMIN_PASSWORD are not configured; admin bootstrap skipped. ' +
          'Set both in the local .env (never commit it) and run npm run admin:provision.',
      };
    }
    return ensureAdminAccount(config);
  };

  return { ensureAdminAccount, ensureAdminAccountFromEnv };
};

const service = createAdminBootstrapService();

/**
 * Bootstrap akun istimewa dari environment variable (dipakai `server.js`).
 *
 * Sebelumnya berada di `services/seedService.js` sebagai pembungkus tipis.
 * Dilebur ke sini agar bootstrap akun hanya punya satu modul. Tidak ada
 * password default di source code: akun Admin hanya dibuat bila `ADMIN_EMAIL`
 * dan `ADMIN_PASSWORD` diisi. Akun Organizer tidak di-seed; Organizer dibuat
 * melalui `POST /api/auth/register`.
 *
 * Idempotent: dijalankan berulang tidak membuat akun duplikat dan tidak
 * mengubah password kecuali `ADMIN_RESET_PASSWORD=true`.
 */
const bootstrapConfiguredAccounts = async (env = process.env) => {
  if (!env.DATABASE_URL) {
    throw new Error('Account bootstrap requires DATABASE_URL');
  }
  return service.ensureAdminAccountFromEnv(env);
};

module.exports = {
  ...service,
  bootstrapConfiguredAccounts,
  createAdminBootstrapService,
  readAdminConfig,
  isAdminConfigComplete,
  validateAdminConfig,
  MIN_ADMIN_PASSWORD_LENGTH,
};
