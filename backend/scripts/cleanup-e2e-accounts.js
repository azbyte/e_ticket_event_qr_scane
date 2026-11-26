/* eslint-disable no-console */
// Hapus akun uji sintetis yang dibuat skrip e2e
// (`*.e2e.*@example.test` / `*.e2e.*@example.com` / `*.probe.*@example.com`).
// Tidak menyentuh akun nyata. Data terkait (event, order, tiket, profil)
// dihapus lebih dulu agar foreign key tidak menghalangi.
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const E2E_PATTERN = `(email like '%e2e.%@example.test'
   or email like '%e2e.%@example.com'
   or email like '%probe.%@example.com')`;

(async () => {
  const { rows } = await pool.query(
    `select id, email from profiles where ${E2E_PATTERN}`,
  );
  console.log('Akun uji yang akan dihapus:', rows.length);
  rows.forEach((r) => console.log('  -', r.email));

  if (rows.length) {
    const ids = rows.map((r) => r.id);
    const client = await pool.connect();
    try {
      await client.query('begin');
      // Data order/tiket peserta uji milik event yang dibuat akun uji.
      await client.query(
        `delete from ticket_email_deliveries where ticket_id in
           (select id from tickets where event_id in
              (select id from events where created_by = any($1::uuid[])))`,
        [ids],
      );
      await client.query(
        `delete from tickets where event_id in
           (select id from events where created_by = any($1::uuid[]))`,
        [ids],
      );
      await client.query(
        `delete from attendees where order_item_id in
           (select oi.id from order_items oi
              join event_orders eo on eo.id = oi.order_id
             where eo.event_id in
               (select id from events where created_by = any($1::uuid[])))`,
        [ids],
      );
      // Urutan penting: item order dan pembayaran direferensikan order.
      await client.query(
        `delete from platform_transactions where order_payment_id in
           (select op.id from order_payments op
              join event_orders eo on eo.id = op.order_id
             where eo.event_id in
               (select id from events where created_by = any($1::uuid[])))`,
        [ids],
      );
      await client.query(
        `delete from order_payments where order_id in
           (select id from event_orders where event_id in
              (select id from events where created_by = any($1::uuid[])))`,
        [ids],
      );
      await client.query(
        `delete from order_items where order_id in
           (select id from event_orders where event_id in
              (select id from events where created_by = any($1::uuid[])))`,
        [ids],
      );
      await client.query(
        `delete from event_orders where event_id in
           (select id from events where created_by = any($1::uuid[]))`,
        [ids],
      );
      await client.query(
        'delete from events where created_by = any($1::uuid[])',
        [ids],
      );
      const del = await client.query(
        'delete from profiles where id = any($1::uuid[]) returning email',
        [ids],
      );
      await client.query('commit');
      console.log('Terhapus:', del.rowCount);
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  }

  const remaining = await pool.query(
    'select email, role from profiles order by created_at',
  );
  console.log('\nSisa akun di database:');
  remaining.rows.forEach((r) => console.log(`  - ${r.email} (${r.role})`));
  const orphans = await pool.query(
    `select count(*)::int c from profiles p
       left join organizer_profiles op on op.user_id = p.id
      where p.role = 'organizer' and op.id is null`,
  );
  console.log('Organizer tanpa profil:', orphans.rows[0].c);
})().finally(() => pool.end());
