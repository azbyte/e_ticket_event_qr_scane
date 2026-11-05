const express = require('express');
const router = express.Router();
const { registerUser, loginUser, getMe, updateMe, logoutUser } = require('../controllers/authController');
const { authMiddleware } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const { registerValidator } = require('../validators/authValidator');

router.post('/register', [...registerValidator, validationMiddleware], registerUser);
router.post('/login', loginUser);
router.get('/me', authMiddleware, getMe);
router.put('/me', authMiddleware, updateMe);
router.post('/logout', authMiddleware, logoutUser);

module.exports = router;