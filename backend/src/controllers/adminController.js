const asyncHandler = require('express-async-handler');
const { query } = require('../config/db');
const { writeAuditLog } = require('../utils/auditLog');

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

  const isDisabling = Boolean(req.body.disabled);
  const reason = typeof req.body.reason === 'string' ? req.body.reason.trim() : '';

  if (isDisabling && reason.length < 5) {
    res.status(400);
    throw new Error('Alasan penangguhan akun wajib diisi minimal 5 karakter');
  }

  const disabled_at = isDisabling ? new Date().toISOString() : null;
  const updated = await query(
    `UPDATE profiles SET disabled_at = $1 WHERE id = $2 RETURNING id, name, email, role, disabled_at`,
    [disabled_at, req.params.id]
  );
  const user = updated[0];
  if (!user) {
    res.status(404);
    throw new Error('Account not found');
  }

  // Tulis audit log
  await writeAuditLog({
    actor: req.user,
    action: isDisabling ? 'SUSPEND_ACCOUNT' : 'ACTIVATE_ACCOUNT',
    entityType: 'ACCOUNT',
    entityId: req.params.id,
    reason: isDisabling ? reason : (reason || 'Akun dipulihkan kembali oleh admin'),
    details: isDisabling
      ? `Akun ${user.email} dinonaktifkan: ${reason}`
      : `Akun ${user.email} diaktifkan kembali`,
    metadata: { userId: user.id, email: user.email, role: user.role },
  });

  res.json({ success: true, user });
});

module.exports = { listAccounts, updateAccountStatus };
