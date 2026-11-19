const express = require('express');
const {
  createOrder,
  getOrder,
  listMyOrders,
} = require('../controllers/orderController');
const { authMiddleware, optionalAuth } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/', optionalAuth, createOrder);
router.get('/', authMiddleware, listMyOrders);
router.get('/:id', optionalAuth, getOrder);

module.exports = router;
