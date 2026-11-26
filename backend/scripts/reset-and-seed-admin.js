/**
 * Reset total data transaksional + semua akun, lalu buat satu akun admin.
 *
 * PERINGATAN: operasi destruktif. Hanya untuk database lokal/sekali pakai.
 * Jalankan `node scripts/backup-db-json.js` lebih dulu.
 *
 * Yang dipertahankan: skema, migration, tabel referensi katalog
 * (`event_categories`, `plans`, `plan_features`) dan `platform_settings`
 * (kebijakan platform, bukan data pengguna).
 *
 * Pemakaian:
 *   node scripts/reset-and-seed-admin.js --yes \
 *     --email admin@eticket.local --username admin --password 123456
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('../src/config/db');

const args = process.argv.slice(2);
const readArg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const confirmed = args.includes('--yes');
const email = readArg('email', 'admin@eticket.local');
const username = readArg('username', 'admin');
const password = readArg('password', '');
const name = readArg('name', 'Administrator Platform');

// Urutan penting: anak dulu, induk terakhir.
const TABLES = [
  'check_ins',
  'scan_logs',
  'ticket_email_deliveries',
  'tickets',
  'attendees',
  'order_payments',
  'order_items',
  'event_orders',
  'event_moderations',
  'event_invitation_permissions',
  'event_invitations',
  'event_member_permissions',
  'event_members',
  'event_activity_logs',
  'support_report_activities',
  'support_reports',
  'notifications',
  'audit_logs',
  'platform_setting_history',
  'platform_transactions',
  'subscription_payments',
  'subscription_history',
  'subscriptions',
  'organizer_profiles',
  'revoked_tokens',
  'ticket_types',
  'events',
  'profiles',
];

(async () => {
  if (!confirmed) {
    console.error('Ditolak: sertakan --yes untuk mengonfirmasi operasi destruktif.');
    process.exit(1);
  }
  if (!password) {
    console.error('Ditolak: sertakan --password.');
    process.exit(1);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // TRUNCATE sekali jalan agar FK di antara tabel ini ikut ditangani.
    await client.query(`TRUNCATE TABLE ${TABLES.map((t) => `"${t}"`).join(', ')} RESTART IDENTITY CASCADE`);
    console.log(`Tabel dikosongkan: ${TABLES.length}`);

    const passwordHash = await bcrypt.hash(password, 10);
    const inserted = await client.query(
      `INSERT INTO profiles (id, name, email, username, password_hash, role)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, 'admin')
       RETURNING id, email, username, role`,
      [name, email.toLowerCase(), username, passwordHash],
    );

    await client.query('COMMIT');
    const user = inserted.rows[0];
    console.log('Admin dibuat:');
    console.log('  id      :', user.id);
    console.log('  email   :', user.email);
    console.log('  username:', user.username);
    console.log('  role    :', user.role);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('GAGAL (di-rollback):', error.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
