const express = require('express');
const {
  getPayment,
  simulatePayment,
} = require('../controllers/paymentController');
const { optionalAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/:orderId', optionalAuth, getPayment);
router.post('/simulate', optionalAuth, simulatePayment);

module.exports = router;
