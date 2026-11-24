const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const {
  acceptInvitation,
  myInvitations,
  getInvitationPreview,
} = require('../controllers/eventInvitationController');

// Rute statis harus dideklarasikan sebelum `/:token` agar tidak tertangkap
// sebagai token undangan.
router.get('/me', authMiddleware, myInvitations);
router.post('/:token/accept', authMiddleware, acceptInvitation);

// Pratinjau undangan publik (tanpa auth). Data minimal, tanpa PII lengkap.
router.get('/:token', getInvitationPreview);

module.exports = router;
