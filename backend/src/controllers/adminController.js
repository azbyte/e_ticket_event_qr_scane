const asyncHandler = require('express-async-handler');
const { query } = require('../config/db');

const listAccounts = asyncHandler(async (req, res) => {
  const where = req.query.role ? `role = $1` : '';
  const params = req.query.role ? [req.query.role] : [];
  const rows = await query(
    `SELECT id, name, email, username, role, avatar_url, created_at, disabled_at
     FROM profiles ${where ? `WHERE ${where}` : ''} ORDER BY created_at DESC`,
    params
  );
  res.json({ success: true, count: rows.length, accounts: rows });
});

const updateAccountStatus = asyncHandler(async (req, res) => {
  if (req.params.id === req.user.id) {
    res.status(400);
    throw new Error('Administrators cannot disable their own account');
  }
  const disabled_at = req.body.disabled ? new Date().toISOString() : null;
  const updated = await query(
    `UPDATE profiles SET disabled_at = $1 WHERE id = $2 RETURNING id, name, email, role, disabled_at`,
    [disabled_at, req.params.id]
  );
  const user = updated[0];
  if (!user) {
    res.status(404);
    throw new Error('Account not found');
  }
  res.json({ success: true, user });
});

module.exports = { listAccounts, updateAccountStatus };
