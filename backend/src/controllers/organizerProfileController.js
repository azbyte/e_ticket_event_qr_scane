const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { pool } = require('../config/db');

const getMyProfile = asyncHandler(async (req, res) => {
  const profile = await getOne(
    `SELECT id, organization_name, contact_name, phone, website, description, logo_url, created_at, updated_at
     FROM organizer_profiles WHERE user_id=$1`, [req.user.id]
  );
  res.json({ success: true, profile: profile || null });
});

const updateMyProfile = asyncHandler(async (req, res) => {
  const fields = [
    ['organization_name','organization_name'], ['contact_name','contact_name'],
    ['phone','phone'], ['website','website'], ['description','description'], ['logo_url','logo_url'],
  ];
  const supplied = fields.filter(([key]) => req.body[key] !== undefined);
  if (supplied.length === 0) { res.status(400); throw new Error('Tidak ada field profil untuk diperbarui'); }
  const client = await pool.connect();
  let row;
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO organizer_profiles (id,user_id,created_at,updated_at)
       VALUES (gen_random_uuid(),$1,NOW(),NOW()) ON CONFLICT (user_id) DO NOTHING`, [req.user.id]
    );
    const set = [];
    const params = [];
    let i = 1;
    for (const [key,column] of supplied) {
      const value = req.body[key];
      if (value !== null && typeof value !== 'string') {
        const err = new Error(`${key} harus berupa teks atau null`); err.statusCode = 400; throw err;
      }
      set.push(`${column}=$${i++}`);
      params.push(typeof value === 'string' ? value.trim() || null : value);
    }
    set.push('updated_at=NOW()');
    params.push(req.user.id);
    const updated = await client.query(
      `UPDATE organizer_profiles SET ${set.join(',')} WHERE user_id=$${i}
       RETURNING id, organization_name, contact_name, phone, website, description, logo_url, created_at, updated_at`, params
    );
    row = updated.rows[0];
    await client.query('COMMIT');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* sudah berakhir */ }
    throw error;
  } finally { client.release(); }
  res.json({ success: true, profile: row });
});

module.exports = { getMyProfile, updateMyProfile };
