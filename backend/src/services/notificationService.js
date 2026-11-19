const { query } = require('../config/db');
const logger = require('../utils/logger');

/**
 * Producer notifikasi.
 *
 * `dedupeKey` mencegah notifikasi ganda saat request di-retry (mis. pembayaran
 * yang dipanggil ulang atau job email yang dijalankan dua kali). Kunci disimpan
 * pada `metadata->>'dedupeKey'` sehingga tidak memerlukan perubahan schema.
 *
 * @returns {Promise<object|null>} baris notifikasi baru, atau null bila duplikat.
 */
const notify = async ({
  userId,
  category,
  title,
  body,
  targetUrl = null,
  metadata = {},
  dedupeKey = null,
}) => {
  if (!userId) return null;
  try {
    if (dedupeKey) {
      const existing = await query(
        `SELECT id FROM notifications
         WHERE user_id = $1 AND category = $2 AND metadata->>'dedupeKey' = $3
         LIMIT 1`,
        [userId, category, dedupeKey]
      );
      if (existing.length > 0) return null;
    }
    const rows = await query(
      `INSERT INTO notifications (id, user_id, category, title, body, target_url, metadata, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6::jsonb, NOW())
       RETURNING *`,
      [userId, category, title, body, targetUrl, JSON.stringify(dedupeKey ? { ...metadata, dedupeKey } : metadata)]
    );
    return rows[0];
  } catch (error) {
    // Notifikasi tidak boleh menggagalkan transaksi bisnis utama.
    logger.warn('notification_insert_failed', { error: error.message, category });
    return null;
  }
};

module.exports = { notify };
