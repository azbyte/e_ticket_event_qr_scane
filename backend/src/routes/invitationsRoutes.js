const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const {
  acceptInvitation,
  myInvitations,
} = require('../controllers/eventInvitationController');

router.post('/:token/accept', authMiddleware, acceptInvitation);
router.get('/me', authMiddleware, myInvitations);

module.exports = router;
