const bcrypt = require('bcryptjs');
const { supabaseAdmin } = require('../config/supabase');

const demoAccounts = [
  { username: 'admin', email: 'admin@event.com', name: 'Super Admin', password: 'Admin123!', role: 'admin' },
  { username: 'organizer', email: 'organizer@event.com', name: 'Event Organizer', password: 'Organizer123!', role: 'organizer' },
];

const seedDemoAccounts = async () => {
  if (process.env.SEED_DEMO_ACCOUNTS !== 'true') return;
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('SEED_DEMO_ACCOUNTS=true requires SUPABASE_SERVICE_ROLE_KEY');
  }

  for (const account of demoAccounts) {
    const { data: existing, error: lookupError } = await supabaseAdmin
      .from('profiles').select('id, role, username').eq('email', account.email).maybeSingle();
    if (lookupError) throw lookupError;

    let userId = existing?.id;
    if (existing) {
      const { data: existingAuth } = await supabaseAdmin.auth.admin.getUserById(existing.id);
      if (!existingAuth?.user) {
        const { data: recreated, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email: account.email,
          password: account.password,
          email_confirm: true,
          user_metadata: { name: account.name, username: account.username },
        });
        if (createError) throw createError;
        userId = recreated.user.id;
      } else {
      const { error: resetError } = await supabaseAdmin.auth.admin.updateUserById(existing.id, { password: account.password, email_confirm: true });
      if (resetError) throw resetError;
      }
    }
    if (!userId) {
      const { data, error } = await supabaseAdmin.auth.admin.createUser({
        email: account.email,
        password: account.password,
        email_confirm: true,
        user_metadata: { name: account.name, username: account.username },
      });
      if (error) {
        if (error.code !== 'email_exists') throw error;
        const { data: users, error: listError } = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1000 });
        if (listError) throw listError;
        userId = users.users.find((user) => user.email === account.email)?.id;
        if (!userId) throw error;
        const { error: resetError } = await supabaseAdmin.auth.admin.updateUserById(userId, { password: account.password, email_confirm: true });
        if (resetError) throw resetError;
      } else {
        userId = data.user.id;
      }
    }

    const password_hash = await bcrypt.hash(account.password, 12);
    const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
      id: userId,
      name: account.name,
      username: account.username,
      email: account.email,
      password_hash,
      role: account.role,
      disabled_at: null,
    }, { onConflict: 'id' });
    if (profileError) throw profileError;
    console.log(`Demo ${account.role} account ready: ${account.email}`);
  }
};

module.exports = { seedDemoAccounts };