const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');

/**
 * GET /api/admin/audit-logs
 * Filter by: action, actor_id, entity_type, from, to, limit, offset
 */
const listAuditLogs = asyncHandler(async (req, res) => {
  const { action, actor_id, entity_type, from, to, limit = 50, offset = 0 } = req.query;
  const whereClauses = [];
  const params = [];

  if (action) {
    params.push(String(action).toUpperCase());
    whereClauses.push(`action = $${params.length}`);
  }
  if (actor_id) {
    params.push(actor_id);
    whereClauses.push(`actor_id = $${params.length}`);
  }
  if (entity_type) {
    params.push(String(entity_type).toUpperCase());
    whereClauses.push(`entity_type = $${params.length}`);
  }
  if (from) {
    params.push(new Date(from).toISOString());
    whereClauses.push(`created_at >= $${params.length}`);
  }
  if (to) {
    params.push(new Date(to).toISOString());
    whereClauses.push(`created_at <= $${params.length}`);
  }

  const whereStr = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
  const pageLimit = Math.min(Number(limit) || 50, 100);
  const pageOffset = Number(offset) || 0;

  const rows = await query(
    `SELECT id, actor_id, actor_name, actor_role, action, entity_type, entity_id, reason, details, metadata, created_at
     FROM audit_logs
     ${whereStr}
     ORDER BY created_at DESC
     LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, pageLimit, pageOffset]
  );

  const countRow = await getOne(
    `SELECT COUNT(*)::bigint AS total FROM audit_logs ${whereStr}`,
    params
  );

  res.json({
    success: true,
    count: rows.length,
    total: Number(countRow?.total) || rows.length,
    logs: rows,
  });
});

module.exports = { listAuditLogs };
