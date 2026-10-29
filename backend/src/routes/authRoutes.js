const express = require('express');
const router = express.Router();
const { registerUser, loginUser, getMe } = require('../controllers/authController');
const { authMiddleware } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const {
  registerValidator,
  loginValidator,
} = require('../validators/authValidator');

router.post('/register', [...registerValidator, validationMiddleware], registerUser);
router.post('/login', [...loginValidator, validationMiddleware], loginUser);
router.get('/me', authMiddleware, getMe);

module.exports = router;