const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const {
  recordCheckIn,
  listEventCheckIns,
  syncCheckIns,
} = require('../controllers/checkInController');

router.post('/', authMiddleware, recordCheckIn);
router.get('/events/:eventId/check-ins', authMiddleware, listEventCheckIns);
router.post('/sync', authMiddleware, syncCheckIns);

module.exports = router;
