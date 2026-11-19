const bcrypt = require('bcryptjs');
const { query, getOne } = require('../config/db');

const demoAccounts = [
  { username: 'admin', email: 'admin@event.com', name: 'Super Admin', password: 'Admin123!', role: 'admin' },
  { username: 'organizer', email: 'organizer@event.com', name: 'Event Organizer', password: 'Organizer123!', role: 'organizer' },
];

const seedDemoAccounts = async () => {
  if (process.env.SEED_DEMO_ACCOUNTS !== 'true') return;
  if (!process.env.DATABASE_URL) {
    throw new Error('SEED_DEMO_ACCOUNTS=true requires DATABASE_URL');
  }

  for (const account of demoAccounts) {
    // Idempotent: perbarui profil yang sudah ada tanpa menghapus baris.
    // Menghapus profil dapat memutus relasi/histori (event, order, audit).
    const passwordHash = await bcrypt.hash(account.password, 12);
    const existing = await getOne('SELECT id FROM profiles WHERE email = $1', [account.email]);
    if (existing) {
      await query(
        `UPDATE profiles
         SET name = $1, username = $2, password_hash = $3, role = $4
         WHERE id = $5`,
        [account.name, account.username, passwordHash, account.role, existing.id]
      );
    } else {
      await query(
        `INSERT INTO profiles (id, name, email, username, password_hash, role, created_at)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())`,
        [account.name, account.email, account.username, passwordHash, account.role]
      );
    }
    console.log(`Demo ${account.role} account ready: ${account.email}`);
  }
};

module.exports = { seedDemoAccounts };
