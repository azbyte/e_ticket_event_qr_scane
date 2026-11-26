const express = require('express');
const asyncHandler = require('express-async-handler');
const router = express.Router();

const { authMiddleware } = require('../middleware/authMiddleware');
const allowRoles = require('../middleware/roleMiddleware');
const { listAccounts, updateAccountStatus } = require('../controllers/adminController');
const { moderateEvent } = require('../controllers/eventMetricsController');
const { listAuditLogs } = require('../controllers/auditLogController');
const {
  listPlatformSettings,
  updatePlatformSetting,
} = require('../controllers/platformSettingsController');
const { getAdminOverview } = require('../controllers/adminOverviewController');
const subscriptionController = require('../controllers/subscriptionController');
const planController = require('../controllers/planController');
const revenueController = require('../controllers/revenueController');
const reportController = require('../controllers/reportController');
const notificationController = require('../controllers/notificationController');
const emailService = require('../services/emailService');

/**
 * Domain konsol Admin + katalog paket, langganan, pendapatan, laporan
 * dukungan, dan notifikasi in-app.
 *
 * Menggabungkan `adminRoutes.js` + `planRoutes.js` + `subscriptionRoutes.js` +
 * `revenueRoutes.js` + `reportRoutes.js` + `notificationRoutes.js`.
 * Di-mount pada `/api`, sehingga path tetap sama:
 *   /api/admin/**, /api/plans/**, /api/subscriptions/**, /api/revenue/**,
 *   /api/support-reports/**, /api/notifications/**
 */

// --- Konsol Admin -----------------------------------------------------------
const adminRouter = express.Router();
adminRouter.use(authMiddleware, allowRoles('admin'));
adminRouter.get('/accounts', listAccounts);
adminRouter.get('/organizers', (req, res, next) => { req.query.role = 'organizer'; next(); }, listAccounts);
adminRouter.put('/accounts/:id/status', updateAccountStatus);
adminRouter.put('/events/:id/moderation', moderateEvent);
adminRouter.get('/audit-logs', listAuditLogs);
adminRouter.get('/settings', listPlatformSettings);
adminRouter.put('/settings/:key', updatePlatformSetting);
adminRouter.get('/overview', getAdminOverview);
adminRouter.get('/subscriptions', subscriptionController.listAdminSubscriptions);

// Kirim ulang email tiket yang tertunda. Sebelumnya didaftarkan langsung di
// `app.js`; sekarang berada di domainnya sendiri dengan gate Admin yang sama.
adminRouter.post('/email/retry', asyncHandler(async (req, res) => {
  const results = await emailService.retryPendingDeliveries(Math.min(Number(req.body.limit) || 20, 100));
  res.json({
    success: true,
    attempted: results.length,
    sent: results.filter((item) => item.status === 'SENT').length,
    pending: results.filter((item) => item.status === 'NOT_CONFIGURED').length,
    failed: results.filter((item) => item.status === 'FAILED').length,
    results,
  });
}));

// --- Katalog paket langganan ------------------------------------------------
// Katalog publik hanya mengembalikan paket ACTIVE; endpoint admin mengelola
// katalog. `GET /api/plans/admin/all` dideklarasikan sebelum `/:id`.
const planRouter = express.Router();
planRouter.get('/admin/all', authMiddleware, allowRoles('admin'), planController.listAllPlans);
planRouter.get('/', planController.listPlans);
planRouter.get('/:id', planController.getPlan);
planRouter.post('/admin', authMiddleware, allowRoles('admin'), planController.createPlan);
planRouter.put('/admin/:id', authMiddleware, allowRoles('admin'), planController.updatePlan);
planRouter.delete('/admin/:id', authMiddleware, allowRoles('admin'), planController.deletePlan);

// --- Langganan Organizer ----------------------------------------------------
const subscriptionRouter = express.Router();
subscriptionRouter.use(authMiddleware, allowRoles('organizer'));
subscriptionRouter.get('/me', subscriptionController.getMySubscription);
subscriptionRouter.post('/', subscriptionController.subscribe);
subscriptionRouter.post('/cancel', subscriptionController.cancelSubscription);
subscriptionRouter.get('/payments', subscriptionController.listMyPayments);

// --- Pendapatan -------------------------------------------------------------
const revenueRouter = express.Router();
revenueRouter.get('/me', authMiddleware, allowRoles('organizer'), revenueController.getOrganizerRevenue);
revenueRouter.get('/admin/summary', authMiddleware, allowRoles('admin'), revenueController.getAdminRevenueSummary);
revenueRouter.get('/admin/transactions', authMiddleware, allowRoles('admin'), revenueController.listAdminTransactions);

// --- Laporan dukungan -------------------------------------------------------
const reportRouter = express.Router();
reportRouter.get('/', authMiddleware, reportController.listReports);
reportRouter.post('/', authMiddleware, reportController.createReport);
reportRouter.get('/:id', authMiddleware, reportController.getReport);
// PUT dipertahankan sesuai dokumentasi; POST dipakai klien Flutter saat ini.
reportRouter.put('/:id/status', authMiddleware, reportController.updateReportStatus);
reportRouter.post('/:id/status', authMiddleware, reportController.updateReportStatus);
reportRouter.put('/:id/priority', authMiddleware, reportController.updateReportPriority);
reportRouter.post('/:id/priority', authMiddleware, reportController.updateReportPriority);
reportRouter.post('/:id/reply', authMiddleware, reportController.addReply);
reportRouter.post('/:id/internal-note', authMiddleware, reportController.addInternalNote);

// --- Notifikasi in-app ------------------------------------------------------
const notificationRouter = express.Router();
notificationRouter.get('/', authMiddleware, notificationController.listNotifications);
notificationRouter.post('/:id/read', authMiddleware, notificationController.markAsRead);
notificationRouter.post('/read-all', authMiddleware, notificationController.markAllAsRead);

router.use('/admin', adminRouter);
router.use('/plans', planRouter);
router.use('/subscriptions', subscriptionRouter);
router.use('/revenue', revenueRouter);
router.use('/support-reports', reportRouter);
router.use('/notifications', notificationRouter);

module.exports = router;

