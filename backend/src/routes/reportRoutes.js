const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const {
  listReports,
  createReport,
  getReport,
  updateReportStatus,
  updateReportPriority,
  addReply,
  addInternalNote,
} = require('../controllers/reportController');

router.get('/', authMiddleware, listReports);
router.post('/', authMiddleware, createReport);
router.get('/:id', authMiddleware, getReport);
// PUT dipertahankan sesuai dokumentasi; POST dipakai klien Flutter saat ini.
router.put('/:id/status', authMiddleware, updateReportStatus);
router.post('/:id/status', authMiddleware, updateReportStatus);
router.put('/:id/priority', authMiddleware, updateReportPriority);
router.post('/:id/priority', authMiddleware, updateReportPriority);
router.post('/:id/reply', authMiddleware, addReply);
router.post('/:id/internal-note', authMiddleware, addInternalNote);

module.exports = router;
