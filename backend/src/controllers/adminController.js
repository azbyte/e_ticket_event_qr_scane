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
  // `is_active` adalah bentuk kanonik yang dipakai klien Flutter
  // (`account_management_screen.dart`); `disabled_at` tetap dikirim agar klien
  // lama dan audit tetap kompatibel.
  const accounts = rows.map((row) => ({ ...row, is_active: !row.disabled_at }));
  res.json({ success: true, count: accounts.length, accounts });
});

/**
 * Ubah status akun. Menerima tiga bentuk payload:
 * - `{ is_active: boolean }` — dipakai aplikasi Flutter (kanonik)
 * - `{ disabled: boolean }` — bentuk lama
 * - `{ status: 'ACTIVE' | 'SUSPENDED' }` — bentuk eksplisit
 * Tanpa salah satunya permintaan ditolak agar status tidak berubah diam-diam.
 */
const updateAccountStatus = asyncHandler(async (req, res) => {
  if (req.params.id === req.user.id) {
    res.status(400);
    throw new Error('Administrators cannot disable their own account');
  }

  const body = req.body || {};
  let isDisabling;
  if (typeof body.is_active === 'boolean') {
    isDisabling = !body.is_active;
  } else if (typeof body.disabled === 'boolean') {
    isDisabling = body.disabled;
  } else if (typeof body.status === 'string') {
    const normalized = body.status.trim().toUpperCase();
    if (['SUSPENDED', 'DISABLED', 'INACTIVE'].includes(normalized)) {
      isDisabling = true;
    } else if (['ACTIVE', 'ENABLED'].includes(normalized)) {
      isDisabling = false;
    } else {
      res.status(400);
      throw new Error('Status akun tidak dikenal; gunakan ACTIVE atau SUSPENDED');
    }
  } else {
    res.status(400);
    throw new Error('Sertakan is_active (boolean), disabled (boolean), atau status akun');
  }

  const reason = typeof body.reason === 'string' ? body.reason.trim() : '';

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

  res.json({ success: true, user: { ...user, is_active: !user.disabled_at } });
});

module.exports = { listAccounts, updateAccountStatus };
