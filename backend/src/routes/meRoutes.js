const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const { myMemberships } = require('../controllers/eventInvitationController');

/**
 * Endpoint "milik pengguna yang sedang login" (`/api/me/*`).
 *
 * `GET /api/me/memberships` — event yang diikuti pengguna sebagai staf, dipakai
 * workspace staf (D2-2) sesuai `INTEGRATION_CONTRACT.md` §1.3.
 */
router.get('/memberships', authMiddleware, myMemberships);

module.exports = router;