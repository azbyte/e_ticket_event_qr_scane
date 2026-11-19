const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const {
  listNotifications,
  markAsRead,
  markAllAsRead,
} = require('../controllers/notificationController');

router.get('/', authMiddleware, listNotifications);
router.post('/:id/read', authMiddleware, markAsRead);
router.post('/read-all', authMiddleware, markAllAsRead);

module.exports = router;
