const asyncHandler = require('express-async-handler');
const { query } = require('../config/db');

const notificationSelect = `
  id, user_id, category, title, body, target_url, read_at, created_at
`;

const listNotifications = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const where = `user_id = $1`;
  const params = [user.id];
  let paramIndex = 2;
  if (req.query.unread === 'true') {
    where += ` AND read_at IS NULL`;
  }
  const rows = await query(
    `SELECT ${notificationSelect} FROM notifications WHERE ${where} ORDER BY created_at DESC`,
    params
  );
  res.json({ success: true, count: rows.length, data: rows });
});

const markAsRead = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  const updated = await query(
    `UPDATE notifications SET read_at = NOW() WHERE id = $1 AND user_id = $2 RETURNING id, read_at`,
    [req.params.id, user.id]
  );
  const row = updated[0];
  if (!row) {
    res.status(404);
    throw new Error('Notifikasi tidak ditemukan');
  }
  res.json({ success: true, message: 'Notifikasi ditandai telah dibaca', notification: row });
});

const markAllAsRead = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }
  await query('UPDATE notifications SET read_at = NOW() WHERE user_id = $1 AND read_at IS NULL', [user.id]);
  res.json({ success: true, message: 'Semua notifikasi ditandai telah dibaca' });
});

module.exports = {
  listNotifications,
  markAsRead,
  markAllAsRead,
};
