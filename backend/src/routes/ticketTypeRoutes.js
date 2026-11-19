const express = require('express');
const router = express.Router();
const { getTicketType } = require('../controllers/ticketTypeController');
const { optionalAuth } = require('../middleware/authMiddleware');

router.get('/:id', optionalAuth, getTicketType);

module.exports = router;
