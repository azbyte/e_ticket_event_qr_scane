const express = require('express');
const router = express.Router();
const {
  createTicket,
  getMyTickets,
  verifyTicket,
} = require('../controllers/ticketController');
const { authMiddleware } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const {
  createTicketValidator,
  verifyTicketValidator,
} = require('../validators/ticketValidator');

router.post('/', authMiddleware, [...createTicketValidator, validationMiddleware], createTicket);
router.get('/my-tickets', authMiddleware, getMyTickets);
router.post('/verify', authMiddleware, [...verifyTicketValidator, validationMiddleware], verifyTicket);

module.exports = router;