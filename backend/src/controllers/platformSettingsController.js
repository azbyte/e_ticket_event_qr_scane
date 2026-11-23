const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { writeAuditLog } = require('../utils/auditLog');

/**
 * GET /api/admin/settings
 * Retrieves all platform settings and fee history.
 */
const listPlatformSettings = asyncHandler(async (req, res) => {
  const rows = await query(
    'SELECT key, value, updated_at FROM platform_settings ORDER BY key ASC'
  );

  const settingsMap = {};
  for (const row of rows) {
    settingsMap[row.key] = row.value;
  }

  const historyRows = await query(
    `SELECT psh.*, p.name AS changed_by_name
     FROM platform_setting_history psh
     LEFT JOIN profiles p ON p.id = psh.changed_by_id
     ORDER BY psh.changed_at DESC
     LIMIT 50`
  );

  res.json({
    success: true,
    count: rows.length,
    settings: settingsMap,
    history: historyRows,
  });
});

/**
 * PUT /api/admin/settings/:key
 * Updates a setting, records history, and writes an audit log.
 */
const updatePlatformSetting = asyncHandler(async (req, res) => {
  const { key } = req.params;
  const { value, reason } = req.body;

  if (value === undefined) {
    res.status(400);
    throw new Error('Setting value is required');
  }

  const existing = await getOne(
    'SELECT key, value FROM platform_settings WHERE key = $1',
    [key]
  );
  const oldValue = existing ? existing.value : null;

  const updated = await query(
    `INSERT INTO platform_settings (key, value, updated_at)
     VALUES ($1, $2::jsonb, NOW())
     ON CONFLICT (key) DO UPDATE
     SET value = EXCLUDED.value, updated_at = NOW()
     RETURNING key, value, updated_at`,
    [key, typeof value === 'object' ? JSON.stringify(value) : JSON.stringify(value)]
  );

  // Record history in platform_setting_history
  await query(
    `INSERT INTO platform_setting_history (
      id, setting_key, old_value, new_value, changed_by_id, reason, changed_at
    ) VALUES (
      gen_random_uuid(), $1, $2::jsonb, $3::jsonb, $4, $5, NOW()
    )`,
    [
      key,
      oldValue ? JSON.stringify(oldValue) : null,
      typeof value === 'object' ? JSON.stringify(value) : JSON.stringify(value),
      req.user.id,
      reason ? String(reason).trim() : null,
    ]
  );

  // Write audit log
  await writeAuditLog({
    actor: req.user,
    action: 'UPDATE_SETTING',
    entityType: 'SETTING',
    entityId: key,
    reason: reason || null,
    details: `Updated platform setting: ${key}`,
    metadata: { oldValue, newValue: value },
  });

  res.json({
    success: true,
    message: 'Platform setting updated successfully',
    setting: updated[0],
  });
});

module.exports = {
  listPlatformSettings,
  updatePlatformSetting,
};
