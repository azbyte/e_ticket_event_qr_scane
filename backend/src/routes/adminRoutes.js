const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const { listAccounts, updateAccountStatus } = require('../controllers/adminController');
const { moderateEvent } = require('../controllers/eventMetricsController');
const { listAuditLogs } = require('../controllers/auditLogController');
const { listPlatformSettings, updatePlatformSetting } = require('../controllers/platformSettingsController');
const { getAdminOverview } = require('../controllers/adminOverviewController');
const { listAdminSubscriptions } = require('../controllers/subscriptionController');

router.use(authMiddleware, allowRoles('admin'));
router.get('/accounts', listAccounts);
router.get('/organizers', (req, res, next) => { req.query.role = 'organizer'; next(); }, listAccounts);
router.put('/accounts/:id/status', updateAccountStatus);
router.put('/events/:id/moderation', moderateEvent);

// Tahap 2 D3 Endpoints
router.get('/audit-logs', listAuditLogs);
router.get('/settings', listPlatformSettings);
router.put('/settings/:key', updatePlatformSetting);
router.get('/overview', getAdminOverview);
router.get('/subscriptions', listAdminSubscriptions);

module.exports = router;
