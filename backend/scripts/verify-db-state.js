/* eslint-disable no-console */
// Ringkasan kondisi database untuk verifikasi akhir (read-only).
require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

(async () => {
  const users = await pool.query(
    `select p.email, p.role, p.username,
            (p.password_hash is not null) as has_hash,
            left(coalesce(p.password_hash,''), 7) as algo,
            op.id is not null as has_org_profile
       from profiles p
       left join organizer_profiles op on op.user_id = p.id
      order by p.created_at`
  );
  console.log('=== AKUN ===');
  users.rows.forEach((r) => console.log(
    `${r.email} | role=${r.role} | username=${r.username} | hash=${r.has_hash} (${r.algo}) | org_profile=${r.has_org_profile}`
  ));

  const counts = await pool.query(
    `select (select count(*)::int from profiles) as profiles,
            (select count(*)::int from organizer_profiles) as organizer_profiles,
            (select count(*)::int from profiles p
               left join organizer_profiles op on op.user_id=p.id
              where p.role='organizer' and op.id is null) as orphan_organizers`
  );
  console.log('\n=== RINGKASAN ===', counts.rows[0]);
})().finally(() => pool.end());
