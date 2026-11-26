const express = require('express');
const router = express.Router();

const { createOrder, getOrder, listMyOrders } = require('../controllers/orderController');
const { getPayment, simulatePayment } = require('../controllers/paymentController');
const {
  getMyTickets,
  getTicketById,
  getTicketPdf,
  verifyTicket,
  resendTicketEmail,
} = require('../controllers/ticketController');
const {
  validateTicket,
  recordCheckIn,
  listEventCheckIns,
  syncCheckIns,
} = require('../controllers/checkInController');
const { authMiddleware, optionalAuth } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const { verifyTicketValidator } = require('../validators');
const { scanLimiter, writeLimiter } = require('../middleware/rateLimitMiddleware');

/**
 * Domain transaksi: order, pembayaran, tiket, dan check-in.
 *
 * Menggabungkan `orderRoutes.js` + `paymentRoutes.js` + `ticketRoutes.js` +
 * `checkInRoutes.js`. Di-mount pada `/api`, sehingga path tetap sama:
 *   /api/orders/**, /api/payments/**, /api/tickets/**, /api/check-ins/**
 *
 * `writeLimiter` dipertahankan khusus pada order & pembayaran (operasi tulis),
 * persis seperti konfigurasi sebelumnya.
 */

const orderRouter = express.Router();
orderRouter.post('/', optionalAuth, createOrder);
orderRouter.get('/', authMiddleware, listMyOrders);
orderRouter.get('/:id', optionalAuth, getOrder);

const paymentRouter = express.Router();
paymentRouter.get('/:orderId', optionalAuth, getPayment);
paymentRouter.post('/simulate', optionalAuth, simulatePayment);

const ticketRouter = express.Router();
// Tidak ada lagi POST /api/tickets (legacy): tiket hanya terbit lewat order yang
// sudah dibayar. Lihat POST /api/orders dan POST /api/payments/simulate.
ticketRouter.get('/my-tickets', optionalAuth, getMyTickets);
ticketRouter.get('/:id/pdf', optionalAuth, getTicketPdf);
ticketRouter.get('/:id', optionalAuth, getTicketById);
ticketRouter.post('/:id/email', optionalAuth, resendTicketEmail);
ticketRouter.post('/validate', authMiddleware, scanLimiter, [...verifyTicketValidator, validationMiddleware], validateTicket);
ticketRouter.post('/verify', authMiddleware, scanLimiter, [...verifyTicketValidator, validationMiddleware], verifyTicket);

const checkInRouter = express.Router();
checkInRouter.post('/', authMiddleware, recordCheckIn);
checkInRouter.get('/events/:eventId/check-ins', authMiddleware, listEventCheckIns);
checkInRouter.post('/sync', authMiddleware, syncCheckIns);

router.use('/orders', writeLimiter, orderRouter);
router.use('/payments', writeLimiter, paymentRouter);
router.use('/tickets', ticketRouter);
router.use('/check-ins', checkInRouter);

module.exports = router;
