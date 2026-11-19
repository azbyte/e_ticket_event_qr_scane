const express = require('express');
const router = express.Router();
const {
  getMyTickets,
  getTicketById,
  verifyTicket,
  resendTicketEmail,
} = require('../controllers/ticketController');
const { validateTicket } = require('../controllers/checkInController');
const { authMiddleware, optionalAuth } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const { verifyTicketValidator } = require('../validators/ticketValidator');
const { scanLimiter } = require('../middleware/rateLimitMiddleware');

// Tidak ada lagi POST /api/tickets (legacy): tiket hanya terbit lewat order yang
// sudah dibayar. Lihat POST /api/orders dan POST /api/payments/simulate.
router.get('/my-tickets', optionalAuth, getMyTickets);
router.get('/:id', optionalAuth, getTicketById);
router.post('/:id/email', optionalAuth, resendTicketEmail);
router.post('/validate', authMiddleware, scanLimiter, [...verifyTicketValidator, validationMiddleware], validateTicket);
router.post('/verify', authMiddleware, scanLimiter, [...verifyTicketValidator, validationMiddleware], verifyTicket);

module.exports = router;