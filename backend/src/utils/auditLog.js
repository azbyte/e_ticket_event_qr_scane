const { query } = require('../config/db');
const logger = require('./logger');

/**
 * Record an entry into audit_logs.
 *
 * @param {Object} params
 * @param {Object} [params.actor] - User object (req.user) containing id, name, email, role
 * @param {string} [params.actorId] - Explicit actor ID (UUID)
 * @param {string} [params.actorName] - Explicit actor name
 * @param {string} [params.actorRole] - Explicit actor role
 * @param {string} params.action - Action identifier, e.g. 'SUSPEND_ACCOUNT', 'ACTIVATE_ACCOUNT', 'UPDATE_SETTING', 'UPDATE_PACKAGE'
 * @param {string} params.entityType - Entity type, e.g. 'ACCOUNT', 'SETTING', 'EVENT', 'PACKAGE'
 * @param {string} params.entityId - Target entity ID or key
 * @param {string} [params.reason] - Mandatory reason for sensitive actions like suspend
 * @param {string} [params.details] - Human-readable details
 * @param {Object} [params.metadata] - Extra JSON payload
 * @returns {Promise<Object|null>} The created audit_logs row
 */
async function writeAuditLog({
  actor,
  actorId,
  actorName,
  actorRole,
  action,
  entityType,
  entityId,
  reason = null,
  details = null,
  metadata = null,
}) {
  const finalActorId = actorId || (actor && actor.id) || null;
  const finalActorName = actorName || (actor && (actor.name || actor.email)) || null;
  const finalActorRole = actorRole || (actor && actor.role) || null;

  try {
    const rows = await query(
      `INSERT INTO audit_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id, reason, details, metadata, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
      RETURNING id, actor_id, actor_name, actor_role, action, entity_type, entity_id, reason, details, metadata, created_at`,
      [
        finalActorId,
        finalActorName,
        finalActorRole,
        String(action || '').trim().toUpperCase(),
        String(entityType || '').trim().toUpperCase(),
        String(entityId || ''),
        reason ? String(reason).trim() : null,
        details ? String(details).trim() : null,
        metadata ? (typeof metadata === 'object' ? JSON.stringify(metadata) : metadata) : null,
      ]
    );
    return rows[0] || null;
  } catch (err) {
    logger.error('audit_log_write_failed', {
      error: err.message,
      action,
      entityType,
      entityId,
    });
    return null;
  }
}

module.exports = {
  writeAuditLog,
  recordAuditLog: writeAuditLog,
  createAuditLog: writeAuditLog,
};
