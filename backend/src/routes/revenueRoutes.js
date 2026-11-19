const { Router } = require('express');
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const controller = require('../controllers/revenueController');
const router = Router();
router.get('/me', authMiddleware, allowRoles('organizer'), controller.getOrganizerRevenue);
router.get('/admin/summary', authMiddleware, allowRoles('admin'), controller.getAdminRevenueSummary);
router.get('/admin/transactions', authMiddleware, allowRoles('admin'), controller.listAdminTransactions);
module.exports = router;
