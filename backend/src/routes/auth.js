const express = require('express');
const router = express.Router();

const {
  registerUser,
  loginUser,
  getMe,
  updateMe,
  logoutUser,
} = require('../controllers/authController');
const { myMemberships } = require('../controllers/eventInvitationController');
const { authMiddleware } = require('../middleware/authMiddleware');
const { validationMiddleware } = require('../middleware/validationMiddleware');
const { registerValidator } = require('../validators');
const { authLimiter } = require('../middleware/rateLimitMiddleware');

/**
 * Domain autentikasi & identitas pengguna.
 *
 * Menggabungkan `authRoutes.js` + `meRoutes.js`. Router ini di-mount pada
 * `/api`, sehingga path publik tetap sama:
 *   /api/auth/register, /api/auth/login, /api/auth/me, /api/auth/logout
 *   /api/me/memberships
 */

// Router khusus `/auth` agar authLimiter hanya berlaku pada endpoint
// autentikasi — sama seperti konfigurasi sebelumnya.
const authRouter = express.Router();
authRouter.post('/register', [...registerValidator, validationMiddleware], registerUser);
authRouter.post('/login', loginUser);
authRouter.get('/me', authMiddleware, getMe);
authRouter.put('/me', authMiddleware, updateMe);
authRouter.post('/logout', authMiddleware, logoutUser);

router.use('/auth', authLimiter, authRouter);

// Endpoint "milik pengguna yang sedang login" (`/api/me/*`).
// `GET /api/me/memberships` — event yang diikuti pengguna sebagai staf,
// dipakai workspace staf (D2-2) sesuai INTEGRATION_CONTRACT §1.3.
router.get('/me/memberships', authMiddleware, myMemberships);

module.exports = router;
